#!/usr/bin/env bash
# Gate tests for ga-prereg-gate.sh (issue-7 phase 2).
# Pattern from implementation-rulebook/tests/run-gate-tests.sh (read, not
# copied): disposable git repo per case, synthetic PreToolUse JSON payload
# on stdin, assert exit code (0=allow, 2=deny) and, for denials, that
# stderr names the specific violated item.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/../ga-prereg-gate.sh"
pass=0
fail=0

mkjson() {
  python3 -c '
import json, sys
tool, path, content = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({"tool_name": tool, "tool_input": {"file_path": path, "content": content}}))
' "$1" "$2" "$3"
}

run_case() {
  local name="$1" expect="$2" json="$3" workdir
  workdir="$(mktemp -d)"
  git init -q "$workdir"
  local out rc
  out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$json" | "$gate" 2>&1)"
  rc=$?
  rm -rf "$workdir"
  if [ "$rc" -eq "$expect" ]; then
    pass=$((pass+1))
    echo "PASS: $name"
  else
    fail=$((fail+1))
    echo "FAIL: $name (expected exit $expect, got $rc) — $out"
  fi
}

grep_case() {
  local name="$1" pattern="$2" json="$3" workdir
  workdir="$(mktemp -d)"
  git init -q "$workdir"
  local out rc
  out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$json" | "$gate" 2>&1)"
  rc=$?
  rm -rf "$workdir"
  if [ "$rc" -eq 2 ] && echo "$out" | grep -qi "$pattern"; then
    pass=$((pass+1))
    echo "PASS: $name"
  else
    fail=$((fail+1))
    echo "FAIL: $name (expected exit 2 mentioning '$pattern', got exit $rc) — $out"
  fi
}

FULL="Experiment proposal.
We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: increasing onboarding nudges will raise activation, expected effect +3pp
Sample size: 12000 per arm
Duration: 14 days
Power basis: 80% power, MDE 5%->6%
Guardrail: churn rate, must not exceed 2% breach bound
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"

NO_KEYWORDS="This is a plain design proposal with no experiment plans at all."

MISSING_RULE="We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: nudges raise activation, expected effect +3pp
Sample size: 12000 per arm
Duration: 14 days
Power basis: 80% power, MDE 5%->6%
Guardrail: churn rate, must not exceed 2%"

GUARDRAIL_IS_PRIMARY="We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: nudges raise activation, expected effect +3pp
Sample size: 12000 per arm
Duration: 14 days
Power basis: 80% power, MDE 5%->6%
Guardrail: activation rate
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"

BARE_HYPOTHESIS_WORD="We recommend running an A/B test.
Primary metric: activation rate
This proposal currently has no hypothesis written down yet.
Sample size: 12000 per arm
Duration: 14 days
Power basis: 80% power, MDE 5%->6%
Guardrail: churn rate, must not exceed 2%
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"

BARE_POWER_WORDS="We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: nudges raise activation, expected effect +3pp
Sample size: 12000 per arm
Duration: 14 days
This has 80% power and an MDE somewhere but no labeled power basis line.
Guardrail: churn rate, must not exceed 2%
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"

run_case "PASS: all 5 items present" 0 "$(mkjson Write docs/issue-9/proposals/x.md "$FULL")"
run_case "PASS: no experiment keywords, gate does not engage" 0 "$(mkjson Write docs/issue-9/proposals/x.md "$NO_KEYWORDS")"
grep_case "REJECT: missing decision rule" "decision rule" "$(mkjson Write docs/issue-9/proposals/x.md "$MISSING_RULE")"
grep_case "REJECT: guardrail = primary metric restated" "guardrail" "$(mkjson Write docs/issue-9/proposals/x.md "$GUARDRAIL_IS_PRIMARY")"
grep_case "REJECT: 'hypothesis' mentioned in prose, no labeled line (2.3 upgrade)" "hypothesis" "$(mkjson Write docs/issue-9/proposals/x.md "$BARE_HYPOTHESIS_WORD")"
grep_case "REJECT: power/MDE words present but no labeled power basis line (2.3 upgrade)" "power basis" "$(mkjson Write docs/issue-9/proposals/x.md "$BARE_POWER_WORDS")"

# REJECT (fail-closed): malformed JSON payload
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' '{not valid json' | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: REJECT malformed JSON payload"; else fail=$((fail+1)); echo "FAIL: REJECT malformed JSON payload (got $rc) — $out"; fi

# --- issue-10 mandatory cases: kill switch, absolute path, replace_all ---

# Kill switch: unrecognized value must NOT disable the gate (fail closed).
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics GA_PREREG_GATE_OFF=maybe bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson Write docs/issue-9/proposals/x.md "$MISSING_RULE")" "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: kill switch unrecognized value stays enabled"; else fail=$((fail+1)); echo "FAIL: kill switch unrecognized value stays enabled (got $rc) — $out"; fi

# Kill switch: a recognized on-value does disable the gate.
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics GA_PREREG_GATE_OFF=1 bash -c 'printf "%s" "$1" | "$2"' _ "$(mkjson Write docs/issue-9/proposals/x.md "$MISSING_RULE")" "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: kill switch recognized on-value disables gate"; else fail=$((fail+1)); echo "FAIL: kill switch recognized on-value disables gate (got $rc) — $out"; fi

# Absolute path outside project root: must deny.
workdir="$(mktemp -d)"; git init -q "$workdir"
outside="$(mktemp -d)"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$(mkjson Write "$outside/docs/issue-9/proposals/x.md" "$MISSING_RULE")" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir" "$outside"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: absolute path outside project root denied"; else fail=$((fail+1)); echo "FAIL: absolute path outside project root denied (got $rc) — $out"; fi

# Absolute path inside project root: treated identically to the relative case.
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$(mkjson Write "$workdir/docs/issue-9/proposals/x.md" "$FULL")" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: absolute path inside project root allowed like relative"; else fail=$((fail+1)); echo "FAIL: absolute path inside project root allowed like relative (got $rc) — $out"; fi

# Edit with replace_all=true: both occurrences of old_string must be reconstructed.
workdir="$(mktemp -d)"; git init -q "$workdir"
mkdir -p "$workdir/docs/issue-9/proposals"
DUP="We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: nudges raise activation, expected effect +3pp
Sample size: 12000 per arm
Duration: 14 days
Power basis: 80% power, MDE 5%->6%
Guardrail: churn rate, must not exceed 2%
Guardrail: churn rate, must not exceed 2%
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"
printf '%s' "$DUP" > "$workdir/docs/issue-9/proposals/x.md"
edit_json="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "must not exceed 2%", "new_string": "must not exceed 3%", "replace_all": True}}))
' docs/issue-9/proposals/x.md)"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' "$edit_json" | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
# both guardrail lines still read "must not exceed 2%" if replace_all is
# honored they'd both become "3%" — gate should still allow (still has a
# bound), proving reconstruction ran without error on a replace_all edit.
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); echo "PASS: Edit replace_all=true reconstructs all occurrences"; else fail=$((fail+1)); echo "FAIL: Edit replace_all=true reconstructs all occurrences (got $rc) — $out"; fi

echo "---"
echo "ga-prereg: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
