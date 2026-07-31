#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — issue-1 phase 2.
#
# On a write to this role's own record (docs/issue-<n>/reports/
# growth-analytics.md), require the per-artifact component checklist from
# docs/issue-1/proposals/rulebook-maturation.md (b): a funnel-diagnosis
# section must show all 5 required components, an experiment-trust-verdict
# section must show all 5. Runs on top of core's generic record-fields-gate
# (§20 what/why/upstream/loop_state/open-findings); this gate only adds the
# role-specific sub-component check core's gate does not (yet) do.
#
# Kill switch: export GROWTH_ANALYTICS_OUTPUT_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-}"
deny() { echo "${role:-growth-analytics}: refused — $1" >&2; exit 2; }

case "${GROWTH_ANALYTICS_OUTPUT_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

[ "$role" = "growth-analytics" ] || exit 0
command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

RGA_PAYLOAD="$payload" python3 <<'PY'
import json, os, posixpath, re, sys

def deny(m):
    sys.stderr.write("growth-analytics: refused — %s\n" % m)
    sys.exit(2)

raw = os.environ.get("RGA_PAYLOAD", "")
try:
    ev = json.loads(raw) if raw else {}
except ValueError:
    sys.exit(0)
if not isinstance(ev, dict):
    sys.exit(0)

tool = ev.get("tool_name")
ti = ev.get("tool_input")
if tool not in ("Write", "Edit", "MultiEdit") or not isinstance(ti, dict):
    sys.exit(0)

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    sys.exit(0)

if not re.search(r'docs/issue-[0-9]+/reports/growth-analytics\.md$', path.replace("\\", "/")):
    sys.exit(0)

current = None
if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        deny("%s exists but cannot be read; failing closed on the component check." % path)

new_text = None
if tool == "Write":
    c = ti.get("content")
    if isinstance(c, str):
        new_text = c
elif tool == "Edit":
    o, n = ti.get("old_string"), ti.get("new_string")
    if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
        new_text = current.replace(o, n, 1)
elif tool == "MultiEdit":
    edits = ti.get("edits")
    text = current
    if isinstance(edits, list) and text is not None:
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                ok = False; break
            text = text.replace(o, n, 1)
        if ok:
            new_text = text

if new_text is None:
    sys.exit(0)  # can't determine resulting content; core's §20 gate already fails closed on this

low = new_text.lower()

def has_any(*needles):
    return any(nd in low for nd in needles)

FUNNEL_COMPONENTS = [
    ("stage/event definitions", ["stage definition", "event definition", "stage/event"]),
    ("stage-to-stage drop-off quantification", ["drop-off", "dropoff", "conversion rate", "conversion %"]),
    ("segment breakdown", ["segment", "cohort", "channel", "device"]),
    ("bottleneck hypothesis", ["bottleneck", "root cause"]),
    ("prioritized single-stage recommendation", ["recommendation", "prioritized"]),
]
EXPERIMENT_COMPONENTS = [
    ("SRM chi-square result", ["srm", "sample ratio mismatch", "chi-square"]),
    ("platform A/A validation status", ["a/a validation", "a/a test", "aa validation"]),
    ("effect size + CI vs. practical-significance bar", ["confidence interval", " ci ", "effect size"]),
    ("guardrail delta/bound check", ["guardrail"]),
    ("Twyman's-law flag", ["twyman"]),
]

missing = []
if has_any("funnel diagnosis", "funnel-diagnosis"):
    for label, needles in FUNNEL_COMPONENTS:
        if not has_any(*needles):
            missing.append("funnel-diagnosis: " + label)
if has_any("experiment trust verdict", "experiment-trust-verdict"):
    for label, needles in EXPERIMENT_COMPONENTS:
        if not has_any(*needles):
            missing.append("experiment-trust-verdict: " + label)

if missing:
    deny(
        "record declares an artifact section but is missing required component(s): %s. "
        "Per docs/issue-1/proposals/rulebook-maturation.md (b), each artifact type must show "
        "all 5 required components." % "; ".join(missing)
    )

sys.exit(0)
PY
