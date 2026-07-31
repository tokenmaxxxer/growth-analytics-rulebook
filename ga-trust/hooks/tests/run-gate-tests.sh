#!/usr/bin/env bash
# Gate tests for ga-trust-gate.sh (issue-7 phase 2).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/../ga-trust-gate.sh"
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

invoke() {
  local workdir="$1" json="$2"
  (cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$json" | "$gate" 2>&1)
}

expect() {
  local name="$1" want="$2" out="$3" rc="$4"
  if [ "$rc" -eq "$want" ]; then pass=$((pass+1)); echo "PASS: $name"; else fail=$((fail+1)); echo "FAIL: $name (expected $want, got $rc) — $out"; fi
}

expect_grep() {
  local name="$1" pattern="$2" out="$3" rc="$4"
  if [ "$rc" -eq 2 ] && echo "$out" | grep -qi "$pattern"; then pass=$((pass+1)); echo "PASS: $name"; else fail=$((fail+1)); echo "FAIL: $name (expected 2 mentioning '$pattern', got $rc) — $out"; fi
}

FULL="## Experiment trust verdict
SRM: chi-square = 0.8, p-value = 0.45, expected 50/50 observed 50.1/49.9
A/A validation status: validated, observed false-positive rate 5%
Guardrail: churn rate delta +0.1%, bound 1%
Effect size: +3% CI: 2% to 4%"

# --- PASS: full verdict, all 5, one Write ---
w="$(mktemp -d)"; git init -q "$w"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$FULL")")"; rc=$?
expect "PASS: full verdict, one Write" 0 "$out" "$rc"
rm -rf "$w"

# --- REJECT: effect/CI only, no SRM at all ---
w="$(mktemp -d)"; git init -q "$w"
NOSRM="## Experiment trust verdict
Effect size: +3% CI: 2% to 4%"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$NOSRM")")"; rc=$?
expect_grep "REJECT: effect/CI with no SRM (ordering)" "SRM must be checked" "$out" "$rc"
rm -rf "$w"

# --- Two-step sequence + Twyman, then regression on a persistent workdir ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/reports" "$w/docs/issue-9/proposals"
printf '%s' "Primary metric: activation rate
Expected effect: +2%%" > "$w/docs/issue-9/proposals/x.md"

SRM_ONLY="## Experiment trust verdict
SRM: chi-square = 0.8, p-value = 0.45, expected 50/50 observed 50.1/49.9"
printf '%s' "$SRM_ONLY" > "$w/docs/issue-9/reports/growth-analytics.md"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$SRM_ONLY")")"; rc=$?
expect "PASS: step 1 (SRM) only, first write" 0 "$out" "$rc"

ANOMALOUS_NO_FLAG="$SRM_ONLY
A/A validation status: validated
Guardrail: churn delta +0.1%, bound 1%
Effect size: +8% CI: 7% to 9%"
out="$(invoke "$w" "$(mkjson_edit docs/issue-9/reports/growth-analytics.md "$SRM_ONLY" "$ANOMALOUS_NO_FLAG")")"; rc=$?
expect_grep "REJECT: anomalous effect (4x expected) with no Twyman flag" "Twyman" "$out" "$rc"

ANOMALOUS_WITH_FLAG="$ANOMALOUS_NO_FLAG
Twyman: unconfirmed, pending independent check"
out="$(invoke "$w" "$(mkjson_edit docs/issue-9/reports/growth-analytics.md "$SRM_ONLY" "$ANOMALOUS_WITH_FLAG")")"; rc=$?
expect "PASS: anomalous effect with Twyman flag present" 0 "$out" "$rc"
printf '%s' "$ANOMALOUS_WITH_FLAG" > "$w/docs/issue-9/reports/growth-analytics.md"

REGRESSED="$(printf '%s' "$ANOMALOUS_WITH_FLAG" | grep -v '^SRM:')"
out="$(invoke "$w" "$(mkjson_edit docs/issue-9/reports/growth-analytics.md "$ANOMALOUS_WITH_FLAG" "$REGRESSED")")"; rc=$?
expect_grep "REJECT: regression removing previously-validated SRM" "regression" "$out" "$rc"
rm -rf "$w"

# --- REJECT (fail-closed): no project root ---
w="$(mktemp -d)"
out="$(cd "$w" && CLAUDE_PROJECT_DIR="$w" CLAUDE_ROLE=growth-analytics printf '%s' "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$FULL")" | "$gate" 2>&1)"; rc=$?
expect "REJECT: no project root" 2 "$out" "$rc"
rm -rf "$w"

echo "---"
echo "ga-trust: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
