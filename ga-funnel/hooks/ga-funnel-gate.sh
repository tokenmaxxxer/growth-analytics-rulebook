#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-funnel plugin (issue-7 phase 2,
# hardened issue-10 phase 2).
#
# Enforces stage/segment localization on docs/issue-<n>/reports/
# growth-analytics.md writes that declare a "funnel diagnosis" section:
# stage/event definitions, quantified per-stage-pair drop-off, segment
# breakdown with a concentration sentence, a causal bottleneck
# hypothesis tracing to the segment evidence, and exactly one
# prioritized recommendation. Fail-closed shape per docs/issue-7/
# proposals/growth-analytics.md section 3.1 (pattern from pricing/hooks/
# methodology-gate.sh, not copied).
#
# issue-10 hardening: trap installed before the kill-switch/python3
# preamble; kill-switch default inverted (unrecognized value fails
# closed); absolute-path containment resolved through symlinks
# (realpath); Edit/MultiEdit reconstruction honors per-edit replace_all;
# the "funnel diagnosis" arm-phrase now requires a markdown heading, and
# every check (stage definitions, stage-pair drop-off, segment/
# concentration, bottleneck hypothesis) runs only inside that heading's
# section span — previously only the recommendation extraction was
# section-scoped. No shared gate-lib.sh exists yet in this repo (core
# issue #72 unlanded) — see docs/issue-10/proposals/gate-a-plus.md
# section 5 — so these fixes are applied inline, not reference-adopted
# from a library.
#
# Kill switch: export GA_FUNNEL_GATE_OFF=1 (or 0/false/no/off to leave it
# on explicitly). Any other value, including an unrecognized one, leaves
# the gate enabled — there is no fail-open default.
set -uo pipefail

__fc() {
  code=$?
  if [ "$code" -ne 0 ] && [ "$code" -ne 2 ]; then
    echo "ga-funnel: internal error (exit $code) — failing closed." >&2
    exit 2
  fi
}
trap __fc EXIT

deny() { echo "ga-funnel: refused — $1" >&2; exit 2; }

case "${GA_FUNNEL_GATE_OFF:-}" in
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
    sys.stderr.write("ga-funnel: refused — %s\n" % m)
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

if not re.search(r'docs/issue-[0-9]+/reports/growth-analytics\.md$', norm):
    sys.exit(0)

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

if not has_any_in(whole_low, "funnel diagnosis", "funnel-diagnosis"):
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


section = extract_section(new_text, r'funnel[\s-]+diagnosis')
if section is None:
    deny(
        "the phrase 'funnel diagnosis' appears in this write but not as a markdown heading "
        "(e.g. '## Funnel Diagnosis') — the funnel-diagnosis section must be structurally "
        "identifiable, not just mentioned in prose."
    )

low = section.lower()

def has_any(*needles):
    return has_any_in(low, *needles)

missing = []

if not has_any("stage definition", "event definition", "stage/event"):
    missing.append("stage/event definitions")

# step 2: numbers attributable to a specific stage pair, e.g. "stage 1 -> stage 2: 40%"
stage_pair_pattern = re.search(
    r'(stage\s*\d+[^\n]{0,40}(->|→|to)[^\n]{0,40}stage\s*\d+)[^\n]{0,60}\d+(\.\d+)?\s*%',
    low,
) or re.search(r'(drop-off|dropoff|conversion)[^\n]{0,80}stage\s*\d+[^\n]{0,80}\d+(\.\d+)?\s*%', low)
if not stage_pair_pattern:
    missing.append("stage-to-stage drop-off quantified with numbers attributable to a specific stage pair")

# step 3: segment axis + concentration sentence
has_segment_axis = has_any("channel", "cohort", "device", "segment")
concentration = re.search(r'(concentrat|mostly in|driven by|primarily (from|in))', low)
if not has_segment_axis:
    missing.append("segment breakdown (channel/cohort/device or named equivalent)")
elif not concentration:
    missing.append("segment breakdown does not identify concentration")

# step 4: causal hypothesis, must not be a bare restatement
hyp_match = re.search(r'bottleneck hypothesis\s*[:\-]\s*([^\n]+)', low)
if not hyp_match:
    missing.append("bottleneck hypothesis")
else:
    hyp_text = hyp_match.group(1)
    if not re.search(r'(because|due to|caused by|driven by)', hyp_text):
        missing.append("bottleneck hypothesis is a verbatim restatement of the drop-off number (no causal cue like 'because'/'due to'/'caused by')")

# step 5: exactly one recommendation
rec_section = re.search(r'recommendation[s]?\s*[:\-]?\s*\n?(.*?)(\n\n|\Z)', low, re.S)
rec_bullets = 0
if rec_section:
    rec_bullets = len(re.findall(r'^\s*[-*\d]', rec_section.group(1), re.M))
if rec_bullets == 0:
    missing.append("prioritized single-stage recommendation")
elif rec_bullets > 1:
    missing.append("exactly one recommendation required (found %d recommendation-shaped bullets)" % rec_bullets)

if missing:
    deny(
        "funnel-diagnosis section is missing/violates required component(s): %s. Per docs/"
        "issue-1/proposals/rulebook-maturation.md (b) via ga-funnel." % "; ".join(missing)
    )

sys.exit(0)
PY
