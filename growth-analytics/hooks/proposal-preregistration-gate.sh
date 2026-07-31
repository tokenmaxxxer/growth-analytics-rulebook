#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — issue-1 phase 2.
#
# On a write to this role's own phase-1 proposal (docs/issue-<n>/proposals/
# *.md) that recommends running or trusting an experiment, require the 5
# pre-registration-first items from docs/issue-1/proposals/
# rulebook-maturation.md (a): primary metric, hypothesis/expected effect,
# sample size + duration, guardrail metrics, decision rule. Only fires when
# the proposal text itself signals an experiment recommendation (keyword
# gate), so non-experiment proposals (e.g. this rulebook-maturation
# proposal itself) are unaffected.
#
# Kill switch: export GROWTH_ANALYTICS_PROPOSAL_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-}"
deny() { echo "${role:-growth-analytics}: refused — $1" >&2; exit 2; }

case "${GROWTH_ANALYTICS_PROPOSAL_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

[ "$role" = "growth-analytics" ] || exit 0
command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

RGA_PAYLOAD="$payload" python3 <<'PY'
import json, os, re, sys

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

if not re.search(r'docs/issue-[0-9]+/proposals/.*\.md$', path.replace("\\", "/")):
    sys.exit(0)

current = None
if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        deny("%s exists but cannot be read; failing closed on the pre-registration check." % path)

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
    sys.exit(0)

low = new_text.lower()

def has_any(*needles):
    return any(nd in low for nd in needles)

# Keyword gate: only proposals that recommend running/trusting an
# experiment are in scope.
if not has_any("a/b", "a/b test", "experiment", "실험"):
    sys.exit(0)
if not has_any("run", "trust", "권장", "제안", "recommend", "실행"):
    sys.exit(0)

REQUIRED = [
    ("primary metric", ["primary metric"]),
    ("hypothesis / expected effect", ["hypothesis", "expected effect"]),
    ("sample size + duration", ["sample size", "power analysis"]),
    ("guardrail metrics", ["guardrail"]),
    ("decision rule", ["decision rule", "go/kill", "kill/pivot"]),
]

missing = [label for label, needles in REQUIRED if not has_any(*needles)]
if missing:
    deny(
        "proposal recommends running/trusting an experiment but is missing pre-registration "
        "item(s): %s. Per docs/issue-1/proposals/rulebook-maturation.md (a), all 5 items must "
        "be literal, locatable lines before any data is interpreted." % "; ".join(missing)
    )

sys.exit(0)
PY
