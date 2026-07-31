#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-prereg plugin (issue-7 phase 2).
#
# Enforces pre-registration-first on docs/issue-<n>/proposals/*.md writes
# that recommend running/trusting an experiment: primary metric,
# hypothesis + expected effect, sample size + duration, guardrail metrics
# (each with a stated bound), decision rule. Fail-closed shape per
# docs/issue-7/proposals/growth-analytics.md section 3.1 (pattern from
# pricing/hooks/methodology-gate.sh, not copied): trap-wrapped, denies on
# empty payload, resolves/validates the project root, reconstructs
# post-write content for Write/Edit/MultiEdit rather than diffing.
#
# Kill switch: export GA_PREREG_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-growth-analytics}"
deny() { echo "ga-prereg: refused — $1" >&2; exit 2; }

__fc() {
  code=$?
  if [ "$code" -ne 0 ] && [ "$code" -ne 2 ]; then
    echo "ga-prereg: internal error (exit $code) — failing closed." >&2
    exit 2
  fi
}
trap __fc EXIT

case "${GA_PREREG_GATE_OFF:-}" in
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
    sys.stderr.write("ga-prereg: refused — %s\n" % m)
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

if not re.search(r'docs/issue-[0-9]+/proposals/.*\.md$', norm):
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

# Keyword pre-gate: only proposals recommending running/trusting an
# experiment are in scope.
if not has_any("a/b", "a/b test", "experiment", "실험"):
    sys.exit(0)
if not has_any("run", "trust", "권장", "제안", "recommend", "실행"):
    sys.exit(0)

missing = []

if not re.search(r'primary metric\s*[:\-]\s*\S', low):
    missing.append("primary metric (need a labeled line with a value, not just the words)")

if not (has_any("hypothesis") and re.search(r'(expected effect|effect size|magnitude)\s*[:\-]?\s*\S', low)):
    missing.append("hypothesis + expected effect direction/magnitude")

has_sample = re.search(r'(sample size|n per arm|n=)\s*[:\-]?\s*\S', low) is not None
has_duration = re.search(r'duration\s*[:\-]?\s*\S', low) is not None
has_power_basis = has_any("power analysis", "mde", "80% power", "power basis")
if not (has_sample and has_duration and has_power_basis):
    missing.append("sample size AND duration together, with a named power-analysis basis")

guardrail_lines = re.findall(r'guardrail[^\n]*', low)
primary_match = re.search(r'primary metric\s*[:\-]\s*([^\n,.;]+)', low)
primary_val = primary_match.group(1).strip() if primary_match else None
guardrail_ok = False
for gl in guardrail_lines:
    if primary_val and primary_val in gl:
        continue
    if re.search(r'(bound|threshold|breach|no more than|at most|<=|>=|not exceed)', gl):
        guardrail_ok = True
        break
if not guardrail_lines:
    missing.append("guardrail metric(s) distinct from the primary metric")
elif not guardrail_ok:
    missing.append("guardrail metric with a stated breach bound (name alone is not enough)")

if not re.search(r'decision rule\s*[:\-]\s*\S', low):
    missing.append("decision rule (threshold on the primary metric, committed before data)")
elif has_any("evaluate holistically"):
    missing.append("decision rule must not defer to 'evaluate holistically'")

if re.search(r'decision rule\s*[:\-][^\n]*(statistical significance|p-value|p<)', low) and not has_any("practical significance", "practical-significance"):
    missing.append("decision rule must include a practical-significance threshold, not significance alone")

if missing:
    deny(
        "experiment proposal missing pre-registration item(s): %s. Per docs/issue-1/proposals/"
        "rulebook-maturation.md (a) via ga-prereg, all items must be literal, locatable lines "
        "before any data is interpreted." % "; ".join(missing)
    )

sys.exit(0)
PY
