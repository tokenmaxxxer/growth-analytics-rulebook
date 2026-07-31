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
Sample size: 12000 per arm, MDE 5%->6% at 80% power
Duration: 14 days
Guardrail: churn rate, must not exceed 2% breach bound
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"

NO_KEYWORDS="This is a plain design proposal with no experiment plans at all."

MISSING_RULE="We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: nudges raise activation, expected effect +3pp
Sample size: 12000 per arm, MDE 5%->6% at 80% power
Duration: 14 days
Guardrail: churn rate, must not exceed 2%"

GUARDRAIL_IS_PRIMARY="We recommend running an A/B test.
Primary metric: activation rate
Hypothesis: nudges raise activation, expected effect +3pp
Sample size: 12000 per arm, MDE 5%->6% at 80% power
Duration: 14 days
Guardrail: activation rate
Decision rule: ship if activation rate lift >= 1pp with practical significance threshold"

run_case "PASS: all 5 items present" 0 "$(mkjson Write docs/issue-9/proposals/x.md "$FULL")"
run_case "PASS: no experiment keywords, gate does not engage" 0 "$(mkjson Write docs/issue-9/proposals/x.md "$NO_KEYWORDS")"
grep_case "REJECT: missing decision rule" "decision rule" "$(mkjson Write docs/issue-9/proposals/x.md "$MISSING_RULE")"
grep_case "REJECT: guardrail = primary metric restated" "guardrail" "$(mkjson Write docs/issue-9/proposals/x.md "$GUARDRAIL_IS_PRIMARY")"

# REJECT (fail-closed): malformed JSON payload
workdir="$(mktemp -d)"; git init -q "$workdir"
out="$(cd "$workdir" && CLAUDE_PROJECT_DIR="$workdir" CLAUDE_ROLE=growth-analytics printf '%s' '{not valid json' | "$gate" 2>&1)"; rc=$?
rm -rf "$workdir"
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "PASS: REJECT malformed JSON payload"; else fail=$((fail+1)); echo "FAIL: REJECT malformed JSON payload (got $rc) — $out"; fi

echo "---"
echo "ga-prereg: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
