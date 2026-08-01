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
Effect size: +3% CI: 2% to 4%
Proposal: docs/issue-9/proposals/x.md"

# --- PASS: full verdict, all 5, one Write ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/proposals"
printf '%s' "Primary metric: activation rate
Expected effect: +2%%" > "$w/docs/issue-9/proposals/x.md"
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
SRM: chi-square = 0.8, p-value = 0.45, expected 50/50 observed 50.1/49.9
Proposal: docs/issue-9/proposals/x.md"
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

# --- issue-10 mandatory case 3.1: section-boundary leakage ---
LEAK="## Appendix: unrelated notes
Some background on statistical testing methodology, unrelated to this
issue's verdict.

## Experiment Trust Verdict
Guardrails: latency (no bound stated)"
w="$(mktemp -d)"; git init -q "$w"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$LEAK")")"; rc=$?
expect "REJECT: section-boundary leakage, appendix content not credited" 2 "$out" "$rc"
rm -rf "$w"

# --- issue-10 mandatory case 3.2: ordering violation within one write ---
ORDER_VIOLATION="## Experiment Trust Verdict
Effect size: +8% CI 5%-11%
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
Proposal: docs/issue-9/proposals/x.md"
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/proposals"
printf '%s' "Primary metric: activation rate
Expected effect: +4%%" > "$w/docs/issue-9/proposals/x.md"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$ORDER_VIOLATION")")"; rc=$?
expect_grep "REJECT: effect size appears before SRM within the section (positional)" "before SRM" "$out" "$rc"
rm -rf "$w"

# --- issue-10 mandatory case 3.3: Twyman unit mismatch ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/proposals"
printf '%s' "Primary metric: activation rate
Expected effect: +3pp" > "$w/docs/issue-9/proposals/x.md"
UNIT_MISMATCH="## Experiment Trust Verdict
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
A/A validation status: validated
Guardrail: latency delta +2ms, bound <= 10ms
Effect size: +6% CI 4%-8%
Proposal: docs/issue-9/proposals/x.md"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$UNIT_MISMATCH")")"; rc=$?
expect_grep "REJECT: Twyman comparison across mismatched units (pp vs %)" "units differ" "$out" "$rc"
rm -rf "$w"

UNIT_MATCH="## Experiment Trust Verdict
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
A/A validation status: validated
Guardrail: latency delta +2ms, bound <= 10ms
Effect size: +4pp CI 2pp-6pp
Proposal: docs/issue-9/proposals/x.md"
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/proposals"
printf '%s' "Primary metric: activation rate
Expected effect: +3pp" > "$w/docs/issue-9/proposals/x.md"
out="$(invoke "$w" "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$UNIT_MATCH")")"; rc=$?
expect "PASS: Twyman comparison, matching units under threshold" 0 "$out" "$rc"
rm -rf "$w"

# --- issue-10 mandatory case 3.4: proposal-selection ambiguity ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-99/proposals"
printf '%s' "Primary metric: x
Expected effect: +20pp" > "$w/docs/issue-99/proposals/old-draft.md"
printf '%s' "Primary metric: x
Expected effect: +2pp" > "$w/docs/issue-99/proposals/current.md"
NO_PROPOSAL_NAMED="## Experiment Trust Verdict
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
A/A validation status: validated
Guardrail: latency delta +2ms, bound <= 10ms
Effect size: +4pp CI 2pp-6pp"
out="$(invoke "$w" "$(mkjson_write docs/issue-99/reports/growth-analytics.md "$NO_PROPOSAL_NAMED")")"; rc=$?
expect_grep "REJECT: no governing proposal named, ambiguous listdir order avoided" "no governing proposal named" "$out" "$rc"
rm -rf "$w"

NAMED_PROPOSAL="## Experiment Trust Verdict
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
A/A validation status: validated
Guardrail: latency delta +2ms, bound <= 10ms
Effect size: +4pp CI 2pp-6pp
Proposal: docs/issue-99/proposals/current.md"
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-99/proposals"
printf '%s' "Primary metric: x
Expected effect: +20pp" > "$w/docs/issue-99/proposals/old-draft.md"
printf '%s' "Primary metric: x
Expected effect: +2pp" > "$w/docs/issue-99/proposals/current.md"
out="$(invoke "$w" "$(mkjson_write docs/issue-99/reports/growth-analytics.md "$NAMED_PROPOSAL")")"; rc=$?
expect "PASS: named proposal read directly, superseded draft ignored" 0 "$out" "$rc"
rm -rf "$w"

# --- issue-10 mandatory: Edit/MultiEdit replace_all reconstruction ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/reports"
DUP="## Experiment Trust Verdict
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
Proposal: docs/issue-9/proposals/x.md
Proposal: docs/issue-9/proposals/x.md"
printf '%s' "$DUP" > "$w/docs/issue-9/reports/growth-analytics.md"
edit_json="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "Proposal: docs/issue-9/proposals/x.md", "new_string": "Proposal: docs/issue-9/proposals/y.md", "replace_all": True}}))
' docs/issue-9/reports/growth-analytics.md)"
out="$(invoke "$w" "$edit_json")"; rc=$?
rm -rf "$w"
# Gate should not error out on reconstruction (it passes/denies on its own
# merits, but must not crash) — the case asserts it ran to a clean exit.
if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: Edit replace_all=true reconstructs both occurrences without crashing"; else fail=$((fail+1)); echo "FAIL: Edit replace_all=true reconstructs both occurrences without crashing (got $rc) — $out"; fi

# --- issue-10 mandatory: MultiEdit with per-edit replace_all ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/reports"
printf '%s' "$SRM_ONLY" > "$w/docs/issue-9/reports/growth-analytics.md"
multi_json="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": sys.argv[1], "edits": [{"old_string": "chi-square = 0.8", "new_string": "chi-square = 0.9", "replace_all": False}]}}))
' docs/issue-9/reports/growth-analytics.md)"
out="$(invoke "$w" "$multi_json")"; rc=$?
rm -rf "$w"
expect "PASS: MultiEdit with per-edit replace_all=false reconstructs correctly" 0 "$out" "$rc"

# --- issue-10 mandatory: kill switch stays enabled on unrecognized value ---
w="$(mktemp -d)"; git init -q "$w"
mkdir -p "$w/docs/issue-9/proposals"
printf '%s' "Primary metric: activation rate
Expected effect: +2%%" > "$w/docs/issue-9/proposals/x.md"
out="$(cd "$w" && CLAUDE_PROJECT_DIR="$w" CLAUDE_ROLE=growth-analytics GA_TRUST_GATE_OFF=maybe bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$LEAK")" "$gate" 2>&1)"; rc=$?
rm -rf "$w"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: kill switch unrecognized value stays enabled"; else fail=$((fail+1)); echo "FAIL: kill switch unrecognized value stays enabled (got $rc) — $out"; fi

w="$(mktemp -d)"; git init -q "$w"
out="$(cd "$w" && CLAUDE_PROJECT_DIR="$w" CLAUDE_ROLE=growth-analytics GA_TRUST_GATE_OFF=1 bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson_write docs/issue-9/reports/growth-analytics.md "$LEAK")" "$gate" 2>&1)"; rc=$?
rm -rf "$w"
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: kill switch recognized on-value disables gate"; else fail=$((fail+1)); echo "FAIL: kill switch recognized on-value disables gate (got $rc) — $out"; fi

# --- issue-10 mandatory: absolute path outside project root denied ---
w="$(mktemp -d)"; git init -q "$w"
outside="$(mktemp -d)"
out="$(invoke "$w" "$(mkjson_write "$outside/docs/issue-9/reports/growth-analytics.md" "$FULL")")"; rc=$?
rm -rf "$w" "$outside"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: absolute path outside project root denied"; else fail=$((fail+1)); echo "FAIL: absolute path outside project root denied (got $rc) — $out"; fi

echo "---"
echo "ga-trust: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
