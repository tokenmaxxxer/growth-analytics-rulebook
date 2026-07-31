#!/usr/bin/env bash
# Gate tests for ga-funnel-gate.sh (issue-7 phase 2).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/../ga-funnel-gate.sh"
pass=0
fail=0

mkjson_write() {
  python3 -c '
import json, sys
path, content = sys.argv[1], sys.argv[2]
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
' "$1" "$2"
}

mkjson_edit() {
  python3 -c '
import json, sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": path, "old_string": old, "new_string": new}}))
' "$1" "$2" "$3"
}

run_pass() {
  local name="$1" json="$2" workdir="$3" out rc
  local created=0
  if [ -z "$workdir" ]; then workdir="$(mktemp -d)"; git init -q "$workdir"; created=1; fi
  out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$json" | "$gate" 2>&1)"; rc=$?
  [ "$created" -eq 1 ] && rm -rf "$workdir"
  if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: $name"; else fail=$((fail+1)); echo "FAIL: $name (expected 0, got $rc) — $out"; fi
}

grep_case() {
  local name="$1" pattern="$2" json="$3" workdir="$4" out rc
  local created=0
  if [ -z "$workdir" ]; then workdir="$(mktemp -d)"; git init -q "$workdir"; created=1; fi
  out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$json" | "$gate" 2>&1)"; rc=$?
  [ "$created" -eq 1 ] && rm -rf "$workdir"
  if [ "$rc" -eq 2 ] && echo "$out" | grep -qi "$pattern"; then pass=$((pass+1)); echo "PASS: $name"; else fail=$((fail+1)); echo "FAIL: $name (expected 2 mentioning '$pattern', got $rc) — $out"; fi
}

FULL="## Funnel diagnosis
Stage definition: stage 1 = signup, stage 2 = activation, stage 3 = purchase
Drop-off: stage 2 -> stage 3: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect on mobile paid-social traffic
Recommendation:
- Fix the mobile payment redirect for stage 3"

TWO_RECS="## Funnel diagnosis
Stage definition: stage 1 = signup, stage 2 = activation, stage 3 = purchase
Drop-off: stage 2 -> stage 3: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect on mobile paid-social traffic
Recommendation:
- Fix the mobile payment redirect for stage 3
- Also redesign the onboarding stage entirely"

NO_CONCENTRATION="## Funnel diagnosis
Stage definition: stage 1 = signup, stage 2 = activation, stage 3 = purchase
Drop-off: stage 2 -> stage 3: 60% drop
Segment: channel table: paid-social 60%, organic 20%, email 10%
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect
Recommendation:
- Fix the payment redirect"

RESTATED_HYPOTHESIS="## Funnel diagnosis
Stage definition: stage 1 = signup, stage 2 = activation, stage 3 = purchase
Drop-off: stage 2 -> stage 3: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: stage 3 has the biggest drop
Recommendation:
- Fix the payment redirect"

run_pass "PASS: all 5 components, one recommendation" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$FULL")" ""
grep_case "REJECT: two recommendations" "exactly one recommendation" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$TWO_RECS")" ""
grep_case "REJECT: segment table, no concentration sentence" "does not identify concentration" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$NO_CONCENTRATION")" ""
grep_case "REJECT: hypothesis is verbatim restatement" "restatement" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$RESTATED_HYPOTHESIS")" ""

# PASS: an Edit that only touches the recommendation section of a file
# whose funnel-diagnosis section was already complete from a prior Write.
workdir="$(mktemp -d)"; git init -q "$workdir"
mkdir -p "$workdir/docs/issue-9/reports"
printf '%s' "$FULL" > "$workdir/docs/issue-9/reports/growth-analytics.md"
edit_json="$(mkjson_edit docs/issue-9/reports/growth-analytics.md "Fix the mobile payment redirect for stage 3" "Fix the mobile payment redirect for stage 3 immediately")"
run_pass "PASS: Edit on top of already-complete Write (content reconstruction)" "$edit_json" "$workdir"
rm -rf "$workdir"

echo "---"
echo "ga-funnel: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
