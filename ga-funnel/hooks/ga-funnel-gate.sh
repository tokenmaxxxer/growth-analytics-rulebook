#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-funnel plugin (issue-7 phase 2).
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
# Kill switch: export GA_FUNNEL_GATE_OFF=1
set -uo pipefail

deny() { echo "ga-funnel: refused — $1" >&2; exit 2; }

__fc() {
  code=$?
  if [ "$code" -ne 0 ] && [ "$code" -ne 2 ]; then
    echo "ga-funnel: internal error (exit $code) — failing closed." >&2
    exit 2
  fi
}
trap __fc EXIT

case "${GA_FUNNEL_GATE_OFF:-}" in
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

norm = path.replace("\\", "/")
abspath = norm if os.path.isabs(norm) else os.path.join(root, norm)
abspath = os.path.normpath(abspath)
if root and os.path.commonpath([os.path.normpath(root), abspath]) != os.path.normpath(root):
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

if not has_any("funnel diagnosis", "funnel-diagnosis"):
    sys.exit(0)  # section not declared in this write; gate does not engage

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
seg_section = re.search(r'(segment[^\n]{0,400})', low)
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
