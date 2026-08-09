#!/usr/bin/env bash
# Gate tests for ga-funnel-gate.sh (issue-7 phase 2).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/../ga-funnel-gate.sh"
pass=0
fail=0

# test-env resolution: docs/specs/test-env-resolution.md (on-the-record issue #551)
resolve_core() {
  if [ -n "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] && [ -s "$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh" ]; then
    return 0
  fi
  local sibling="$here/../../../core"
  if [ -s "$sibling/hooks/lib/gate-lib.sh" ]; then
    CLAUDE_PLUGIN_ROOT_CORE="$(cd "$sibling" && pwd)"
    return 0
  fi
  echo "SKIP: core plugin unreachable — unverifiable outside spawn env" >&2
  exit 75
}
resolve_core
export CLAUDE_PLUGIN_ROOT_CORE

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
Stage definition: stage 1 = acquisition, stage 2 = activation, stage 3 = revenue
Drop-off: stage 2 -> stage 3: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect on mobile paid-social traffic
is_north_star: true (checkout conversion rate)
Recommendation:
- Fix the mobile payment redirect for stage 3"

TWO_RECS="## Funnel diagnosis
Stage definition: stage 1 = acquisition, stage 2 = activation, stage 3 = revenue
Drop-off: stage 2 -> stage 3: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect on mobile paid-social traffic
is_north_star: true (checkout conversion rate)
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

# --- issue-17: funnel_stage label + is_north_star anchored value ---
NO_FUNNEL_STAGE_LABEL="## Funnel diagnosis
Stage definition: stage 1 = signup, stage 2 = purchase
Drop-off: stage 1 -> stage 2: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect
is_north_star: true (checkout conversion rate)
Recommendation:
- Fix the payment redirect"
grep_case "REJECT: no canonical funnel_stage label on a stage-pair line" "funnel_stage" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$NO_FUNNEL_STAGE_LABEL")" ""

BARE_NORTH_STAR="## Funnel diagnosis
Stage definition: stage 1 = acquisition, stage 2 = revenue
Drop-off: stage 1 -> stage 2: 60% drop
Segment: channel breakdown shows drop concentrated in paid-social channel
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect
This metric is_north_star for the team.
Recommendation:
- Fix the payment redirect"
grep_case "REJECT: bare is_north_star mention with no anchored true/false value" "is_north_star" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$BARE_NORTH_STAR")" ""

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

# --- issue-10 mandatory: section-scoping (checks other than recommendation
# extraction must not be satisfied by content outside the funnel-diagnosis
# heading's section) ---
LEAK="## Appendix
Segment: channel breakdown shows drop concentrated in paid-social channel
Stage definition: stage 1 = signup, stage 2 = activation
Drop-off: stage 1 -> stage 2: 40%

## Funnel diagnosis
Bottleneck hypothesis: checkout drop is caused by a broken payment redirect
Recommendation:
- Fix the payment redirect"
grep_case "REJECT: section-scoping, appendix content outside heading not credited" "stage/event definitions" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$LEAK")" ""

# --- issue-10 mandatory: arm-phrase without a heading must deny, not skip ---
NO_HEADING="This report mentions a funnel diagnosis in passing but never
puts it under its own section heading."
grep_case "REJECT: arm-phrase present but no markdown heading" "markdown heading" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$NO_HEADING")" ""

# --- issue-10 mandatory: malformed JSON ---
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' '{not valid json' | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: REJECT malformed JSON payload"; else fail=$((fail+1)); echo "FAIL: REJECT malformed JSON payload (got $rc) — $out"; fi

# --- issue-10 mandatory: kill switch ---
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics GA_FUNNEL_GATE_OFF=maybe bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$TWO_RECS")" "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: kill switch unrecognized value stays enabled"; else fail=$((fail+1)); echo "FAIL: kill switch unrecognized value stays enabled (got $rc) — $out"; fi

workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics GA_FUNNEL_GATE_OFF=1 bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$TWO_RECS")" "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: kill switch recognized on-value disables gate"; else fail=$((fail+1)); echo "FAIL: kill switch recognized on-value disables gate (got $rc) — $out"; fi

# --- issue-10 mandatory: absolute path outside project root denied ---
workdir="$(mktemp -d)"; git init -q "$workdir"
outside="$(mktemp -d)"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$(mkjson_write "$outside/docs/issue-9/reports/growth-analytics.md" "$FULL")" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir" "$outside"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: absolute path outside project root denied"; else fail=$((fail+1)); echo "FAIL: absolute path outside project root denied (got $rc) — $out"; fi

# --- issue-10 mandatory: Edit replace_all reconstruction doesn't crash ---
workdir="$(mktemp -d)"; git init -q "$workdir"
mkdir -p "$workdir/docs/issue-9/reports"
printf '%s' "$FULL" > "$workdir/docs/issue-9/reports/growth-analytics.md"
edit_json="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "stage 3", "new_string": "stage 3 (mobile)", "replace_all": True}}))
' docs/issue-9/reports/growth-analytics.md)"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$edit_json" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: Edit replace_all=true reconstructs all occurrences"; else fail=$((fail+1)); echo "FAIL: Edit replace_all=true reconstructs all occurrences (got $rc) — $out"; fi

# --- issue-10 mandatory: MultiEdit with per-edit replace_all ---
workdir="$(mktemp -d)"; git init -q "$workdir"
mkdir -p "$workdir/docs/issue-9/reports"
printf '%s' "$FULL" > "$workdir/docs/issue-9/reports/growth-analytics.md"
multi_json="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": sys.argv[1], "edits": [{"old_string": "Fix the mobile payment redirect for stage 3", "new_string": "Fix the mobile payment redirect for stage 3 today", "replace_all": False}]}}))
' docs/issue-9/reports/growth-analytics.md)"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$multi_json" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: MultiEdit per-edit replace_all=false reconstructs correctly"; else fail=$((fail+1)); echo "FAIL: MultiEdit per-edit replace_all=false reconstructs correctly (got $rc) — $out"; fi

# --- issue-13 mandatory: missing-core (source guard fails closed) ---
missing_core_ran=0
workdir="$(mktemp -d)"; git init -q "$workdir"
nocore_root="$(mktemp -d)"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics \
  CLAUDE_PLUGIN_ROOT_CORE="/nonexistent-core-$$" CLAUDE_PLUGIN_ROOT="$nocore_root" \
  bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$FULL")" "$gate" 2>&1)"; rc=$?
rm -rf "$workdir" "$nocore_root"
missing_core_ran=1
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: missing core (CLAUDE_PLUGIN_ROOT_CORE unresolvable) fails closed"; else fail=$((fail+1)); echo "FAIL: missing core fails closed (expected 2, got $rc) — $out"; fi

# --- issue-13 mandatory: bash-write-coverage (Bash redirect bypass closed) ---
bash_write_ran=0
workdir="$(mktemp -d)"; git init -q "$workdir"
bash_json='{"tool_name":"Bash","tool_input":{"command":"echo x > docs/issue-9/reports/growth-analytics.md"}}'
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$bash_json" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
bash_write_ran=1
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: Bash write to guarded path denied"; else fail=$((fail+1)); echo "FAIL: Bash write to guarded path denied (expected 2, got $rc) — $out"; fi

if [ "$missing_core_ran" -ne 1 ] || [ "$bash_write_ran" -ne 1 ]; then
  echo "HARNESS FAILURE: mandatory groups (missing-core, bash-write-coverage) did not both run" >&2
  fail=$((fail+1))
fi

echo "---"
echo "ga-funnel: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
