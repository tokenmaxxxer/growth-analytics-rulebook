#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-trust plugin (issue-7 phase 2,
# hardened issue-10 phase 2).
#
# Enforces the Kohavi trust-gate order on docs/issue-<n>/reports/
# growth-analytics.md writes that declare an "experiment trust verdict"
# section: SRM -> A/A validity -> guardrails -> effect size/CI -> Twyman
# flag, ORDER-ENFORCED via session state (re-derived from content every
# time; state only catches a regression — content that removes a
# previously-validated step's evidence). Fail-closed shape per docs/
# issue-7/proposals/growth-analytics.md sections 3.1/3.4 (pattern from
# pricing/hooks/methodology-gate.sh and implementation-rulebook/coding/
# hooks/state.sh, not copied).
#
# issue-10 hardening: trap installed before the kill-switch/python3
# preamble; kill-switch default inverted (unrecognized value fails
# closed); absolute-path containment resolved through symlinks
# (realpath); Edit/MultiEdit reconstruction honors per-edit replace_all;
# the "experiment trust verdict" arm-phrase now requires a markdown
# heading, and every step check runs only inside that heading's section
# span (no more whole-document leakage from unrelated prose); the SRM-
# before-effect-size check gained a genuine positional check inside the
# section (in addition to the existing state-based regression check);
# the Twyman cross-check now requires the section to name the specific
# governing proposal file (no more listdir-order-dependent guessing) and
# compares reported vs. expected effect only when both sides state the
# same unit. No shared gate-lib.sh exists yet in this repo (core issue
# #72 unlanded) — see docs/issue-10/proposals/gate-a-plus.md section 5 —
# so these fixes are applied inline, not reference-adopted from a
# library.
#
# Kill switch: export GA_TRUST_GATE_OFF=1 (or 0/false/no/off to leave it
# on explicitly). Any other value, including an unrecognized one, leaves
# the gate enabled — there is no fail-open default.
set -uo pipefail

__fc() {
  code=$?
  if [ "$code" -ne 0 ] && [ "$code" -ne 2 ]; then
    echo "ga-trust: internal error (exit $code) — failing closed." >&2
    exit 2
  fi
}
trap __fc EXIT

deny() { echo "ga-trust: refused — $1" >&2; exit 2; }

case "${GA_TRUST_GATE_OFF:-}" in
  ""|0|false|no|off) ;;   # recognized off-value: gate stays ENABLED
  1|true|yes|on) exit 0 ;; # recognized on-value: gate DISABLED
  *) ;;                    # unrecognized value: gate stays ENABLED (fail closed)
esac

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ] || { [ ! -d "$root/.git" ] && [ ! -f "$root/.git" ]; }; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] && { [ -d "$root/.git" ] || [ -f "$root/.git" ]; } || deny "no project root (no CLAUDE_PROJECT_DIR/.git and no resolvable git toplevel)"

GA_PAYLOAD="$payload" GA_ROOT="$root" python3 <<'PY'
import json, os, re, sys

def deny(m):
    sys.stderr.write("ga-trust: refused — %s\n" % m)
    sys.exit(2)

raw = os.environ.get("GA_PAYLOAD", "")
root = os.environ.get("GA_ROOT", "")
try:
    ev = json.loads(raw)
except ValueError:
    deny("malformed tool-use payload JSON")
if not isinstance(ev, dict):
    deny("tool-use payload is not a JSON object")

tool = ev.get("tool_name")
ti = ev.get("tool_input")
if tool not in ("Write", "Edit", "MultiEdit") or not isinstance(ti, dict):
    sys.exit(0)

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    sys.exit(0)


def contained(root_dir, abspath):
    try:
        root_r = os.path.realpath(root_dir)
        path_r = os.path.realpath(abspath)
        return os.path.commonpath([root_r, path_r]) == root_r
    except ValueError:
        return False


norm = path.replace("\\", "/")
abspath = norm if os.path.isabs(norm) else os.path.join(root, norm)
abspath = os.path.normpath(abspath)
if root and not contained(root, abspath):
    deny("target path resolves outside the project root")

m = re.search(r'docs/issue-([0-9]+)/reports/growth-analytics\.md$', norm)
if not m:
    sys.exit(0)
issue_n = m.group(1)

current = None
if os.path.isfile(abspath):
    try:
        with open(abspath, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        deny("%s exists but cannot be read; failing closed." % path)
else:
    current = ""

new_text = None
if tool == "Write":
    c = ti.get("content")
    if isinstance(c, str):
        new_text = c
elif tool == "Edit":
    o, n = ti.get("old_string"), ti.get("new_string")
    use_all = bool(ti.get("replace_all", False))
    if isinstance(o, str) and isinstance(n, str):
        if o == "":
            new_text = current + n
        elif o in current:
            new_text = current.replace(o, n) if use_all else current.replace(o, n, 1)
elif tool == "MultiEdit":
    edits = ti.get("edits")
    text = current
    if isinstance(edits, list):
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            use_all = bool(e.get("replace_all", False))
            if not isinstance(o, str) or not isinstance(n, str):
                ok = False; break
            if o == "":
                text = text + n
            elif o in text:
                text = text.replace(o, n) if use_all else text.replace(o, n, 1)
            else:
                ok = False; break
        if ok:
            new_text = text

if new_text is None:
    deny("could not reconstruct post-write content for %s (old_string not found in current content, or replace_all left it unmatched); failing closed rather than skipping the check." % path)

whole_low = new_text.lower()

def has_any_in(text, *needles):
    return any(nd in text for nd in needles)

if not has_any_in(whole_low, "experiment trust verdict", "experiment-trust-verdict"):
    sys.exit(0)  # arm-phrase not present anywhere; gate does not engage


def extract_section(text, heading_pattern):
    """Text spanning a heading matching heading_pattern (case-insensitive)
    up to the next same-or-higher-level heading or EOF. None if no such
    heading exists."""
    lines = text.split("\n")
    start = None
    level = None
    for i, line in enumerate(lines):
        hm = re.match(r'^(#{1,6})\s*(.*)$', line)
        if hm and re.search(heading_pattern, hm.group(2), re.IGNORECASE):
            start = i + 1
            level = len(hm.group(1))
            break
    if start is None:
        return None
    end = len(lines)
    for j in range(start, len(lines)):
        hm = re.match(r'^(#{1,6})\s+', lines[j])
        if hm and len(hm.group(1)) <= level:
            end = j
            break
    return "\n".join(lines[start:end])


section = extract_section(new_text, r'experiment[\s-]+trust[\s-]+verdict')
if section is None:
    deny(
        "the phrase 'experiment trust verdict' appears in this write but not as a markdown "
        "heading (e.g. '## Experiment Trust Verdict') — the trust-gate section must be "
        "structurally identifiable, not just mentioned in prose."
    )

low = section.lower()

def has_any(*needles):
    return has_any_in(low, *needles)

# --- per-step presence/validity, recomputed from the section's content every time ---
srm_match = re.search(r'(chi-square|chi2|chi square)', low)
step1 = bool(
    srm_match
    and re.search(r'p\s*[-=]?\s*value|p\s*=\s*0?\.\d', low)
    and has_any("expected") and has_any("observed")
)
step2 = bool(re.search(r'a/a[^\n]{0,20}(validation|status)?[^\n]{0,10}(validated|failed|unvalidated)', low))
step3_lines = re.findall(r'guardrail[^\n]*', low)
step3 = any(
    re.search(r'(delta|bound|threshold|breach)', gl) and re.search(r'\d', gl)
    for gl in step3_lines
)
eff_label_match = re.search(r'effect size', low)
step4 = bool(
    eff_label_match
    and re.search(r'(ci|confidence interval)[^\n]{0,40}[\d.]+\s*(%|pp)?\s*(-|to|,|–)\s*[\d.]+\s*(%|pp)?', low)
)
step5_flag = has_any("unconfirmed, pending independent check", "twyman")

state_dir = os.path.join(root, ".claude", "state", "growth-analytics")
state_path = os.path.join(state_dir, "ga-trust-%s.json" % issue_n)

prev_validated = set()
if os.path.isfile(state_path):
    try:
        with open(state_path, encoding="utf-8") as fh:
            data = json.load(fh)
        prev_validated = set(int(x) for x in data.get("validated_steps", []))
    except (OSError, ValueError, TypeError):
        prev_validated = set()  # corrupt/missing state: re-derive from content only, safe default

current_present = set()
if step1: current_present.add(1)
if step2: current_present.add(2)
if step3: current_present.add(3)
if step4: current_present.add(4)
if step5_flag: current_present.add(5)

# Regression check: a step previously validated must not disappear.
regressed = sorted(s for s in prev_validated if s not in current_present)
if regressed:
    deny(
        "step(s) %s were previously validated but are no longer present in this write "
        "(content regression) — the gate re-derives from content every time, it does not "
        "trust stale state across a content change." % regressed
    )

# Ordering (state-based, across separate writes): step 4/5 content may not
# appear before step 1 has cleared in this or any prior write.
if (4 in current_present or 5 in current_present or has_any("effect size", "confidence interval")) \
        and 1 not in current_present and 1 not in prev_validated:
    deny("SRM must be checked before effect size is reported (Kohavi trust-gate order)")

# Ordering (positional, within this single write): if both SRM evidence and
# an effect-size label appear in the section, SRM must appear first.
if srm_match and eff_label_match and eff_label_match.start() < srm_match.start():
    deny(
        "effect size appears before SRM evidence within the experiment-trust-verdict section "
        "(Kohavi trust-gate order requires SRM first, even though both pieces of evidence are "
        "present)"
    )

# Twyman's-law numeric trigger: compare step-4 reported effect against the
# linked ga-prereg proposal's expected effect for the same issue number.
# The section must name which proposal file governs (no listdir-order
# guessing), and units must match before the ratio is computed.
if step4:
    eff_match = re.search(r'effect size\s*[:\-]?\s*\+?(-?[\d.]+)\s*(pp|%)?', low)
    reported_effect = float(eff_match.group(1)) if eff_match else None
    reported_unit = eff_match.group(2) if eff_match else None

    prop_ref = re.search(r'proposal\s*[:\-]\s*(docs/issue-[0-9]+/proposals/\S+\.md)', low)
    if reported_effect is not None and not prop_ref:
        deny(
            "effect size reported but no governing proposal named — add a labeled line such as "
            "'Proposal: docs/issue-%s/proposals/<name>.md' so the Twyman cross-check knows which "
            "proposal's expected effect applies (no more picking whichever file listdir() "
            "returns first)." % issue_n
        )

    expected_effect = None
    expected_unit = None
    if reported_effect is not None and prop_ref:
        prop_rel = prop_ref.group(1)
        prop_abspath = os.path.normpath(os.path.join(root, prop_rel))
        if not (root and contained(root, prop_abspath) and os.path.isfile(prop_abspath)):
            deny("named proposal file %s does not exist (or resolves outside the project root)" % prop_rel)
        try:
            with open(prop_abspath, encoding="utf-8-sig") as fh:
                ptxt = fh.read(1 << 20).lower()
        except OSError:
            deny("named proposal file %s exists but cannot be read; failing closed." % prop_rel)
        em = re.search(r'expected effect[,:]?\s*\+?(-?[\d.]+)\s*(pp|%)?', ptxt)
        if em:
            expected_effect = float(em.group(1))
            expected_unit = em.group(2)

    if reported_effect is not None and expected_effect not in (None, 0):
        if reported_unit != expected_unit:
            deny(
                "cannot compare effect size %s%s against expected effect %s%s — units differ or "
                "are unstated; state both in the same unit."
                % (reported_effect, reported_unit or "(none)", expected_effect, expected_unit or "(none)")
            )
        ratio = abs(reported_effect) / abs(expected_effect)
        if ratio > 2 and not step5_flag:
            deny(
                "Twyman's-law flag required: reported effect (%.2f%s) exceeds 2x the ga-prereg "
                "expected effect (%.2f%s) with no 'unconfirmed, pending independent check' flag."
                % (reported_effect, reported_unit or "", expected_effect, expected_unit or "")
            )

if not current_present:
    deny(
        "experiment-trust-verdict section declared but shows none of the 5 required Kohavi "
        "steps yet (SRM/A-A/guardrails/effect-CI/Twyman). Per docs/issue-1/proposals/"
        "rulebook-maturation.md (b) via ga-trust."
    )

os.makedirs(state_dir, exist_ok=True)
tmp_path = state_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as fh:
    json.dump({"validated_steps": sorted(current_present)}, fh)
os.replace(tmp_path, state_path)

sys.exit(0)
PY
