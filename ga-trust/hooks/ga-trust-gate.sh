#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-trust plugin (issue-7 phase 2).
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
# Kill switch: export GA_TRUST_GATE_OFF=1
set -uo pipefail

deny() { echo "ga-trust: refused — $1" >&2; exit 2; }

__fc() {
  code=$?
  if [ "$code" -ne 0 ] && [ "$code" -ne 2 ]; then
    echo "ga-trust: internal error (exit $code) — failing closed." >&2
    exit 2
  fi
}
trap __fc EXIT

case "${GA_TRUST_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
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

norm = path.replace("\\", "/")
abspath = norm if os.path.isabs(norm) else os.path.join(root, norm)
abspath = os.path.normpath(abspath)
if root and os.path.commonpath([os.path.normpath(root), abspath]) != os.path.normpath(root):
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
    if isinstance(o, str) and isinstance(n, str):
        if o == "" or o in current:
            new_text = current.replace(o, n, 1) if o else (current + n)
elif tool == "MultiEdit":
    edits = ti.get("edits")
    text = current
    if isinstance(edits, list):
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str):
                ok = False; break
            if o == "":
                text = text + n
            elif o in text:
                text = text.replace(o, n, 1)
            else:
                ok = False; break
        if ok:
            new_text = text

if new_text is None:
    deny("could not reconstruct post-write content for %s (old_string not found in current content); failing closed rather than skipping the check." % path)

low = new_text.lower()

def has_any(*needles):
    return any(nd in low for nd in needles)

if not has_any("experiment trust verdict", "experiment-trust-verdict"):
    sys.exit(0)  # section not declared in this write; gate does not engage

# --- per-step presence/validity, recomputed from content every time ---
step1 = bool(
    has_any("chi-square", "chi2", "chi square")
    and re.search(r'p\s*[-=]?\s*value|p\s*=\s*0?\.\d', low)
    and has_any("expected") and has_any("observed")
)
step2 = bool(re.search(r'a/a[^\n]{0,20}(validation|status)?[^\n]{0,10}(validated|failed|unvalidated)', low))
step3_lines = re.findall(r'guardrail[^\n]*', low)
step3 = any(re.search(r'(delta|bound|threshold|breach)', gl) for gl in step3_lines)
step4 = bool(
    has_any("effect size")
    and re.search(r'(ci|confidence interval)[^\n]{0,40}[\d.]+\s*%?\s*(-|to|,|–)\s*[\d.]+\s*%?', low)
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

# Ordering: step 4/5 content may not appear before step 1 has cleared.
if (4 in current_present or 5 in current_present or has_any("effect size", "confidence interval")) \
        and 1 not in current_present and 1 not in prev_validated:
    deny("SRM must be checked before effect size is reported (Kohavi trust-gate order)")

# Twyman's-law numeric trigger: compare step-4 reported effect against the
# linked ga-prereg proposal's expected effect for the same issue number.
if step4:
    eff_match = re.search(r'effect size\s*[:\-]?\s*\+?(-?[\d.]+)\s*%?', low)
    reported_effect = float(eff_match.group(1)) if eff_match else None
    prop_glob_dir = os.path.join(root, "docs", "issue-%s" % issue_n, "proposals")
    expected_effect = None
    if os.path.isdir(prop_glob_dir):
        for fn in os.listdir(prop_glob_dir):
            if not fn.endswith(".md"):
                continue
            try:
                with open(os.path.join(prop_glob_dir, fn), encoding="utf-8-sig") as fh:
                    ptxt = fh.read(1 << 20).lower()
            except OSError:
                continue
            em = re.search(r'expected effect[,:]?\s*\+?(-?[\d.]+)\s*(pp|%)?', ptxt)
            if em:
                expected_effect = float(em.group(1))
                break
    else:
        sys.stderr.write(
            "ga-trust: warning — no docs/issue-%s/proposals/ found; skipping Twyman "
            "cross-check against ga-prereg's expected effect (fail-open on this one "
            "cross-file lookup only).\n" % issue_n
        )

    if reported_effect is not None and expected_effect not in (None, 0):
        ratio = abs(reported_effect) / abs(expected_effect)
        if ratio > 2 and not step5_flag:
            deny(
                "Twyman's-law flag required: reported effect (%.2f) exceeds 2x the ga-prereg "
                "expected effect (%.2f) with no 'unconfirmed, pending independent check' flag."
                % (reported_effect, expected_effect)
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
