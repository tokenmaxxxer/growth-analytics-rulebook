---
code_under_review:
  - ga-funnel/hooks/tests/run-gate-tests.sh
  - ga-trust/hooks/tests/run-gate-tests.sh
  - ga-prereg/hooks/tests/run-gate-tests.sh
type: fix
breaking: false
verdict: pass
loop_state: landed
---

# Implementation record — issue #20

## Summary of work
Applying the approved phase-1 proposal
(`docs/issue-20/proposals/2026-08-09-test-env-resolution.md`): add a
`resolve_core()` step to the top of each of the 3 `run-gate-tests.sh`
scripts (ga-funnel, ga-trust, ga-prereg), implementing the
on-the-record test-env-resolution convention's order + SKIP contract,
before any test case runs.

## Why
Subject: issue-20. On a plain checkout without `CLAUDE_PLUGIN_ROOT_CORE`
set, the 3 gate-test runners currently misreport 12/17 cases as FAIL
(confirmed in the survey) instead of SKIPping — this adopts the
canonical convention landed at on-the-record `docs/specs/test-env-resolution.md`
(issue #551) to fix that.

## Upstream / basis
docs/issue-20/proposals/2026-08-09-test-env-resolution.md

## What was done
- Added `resolve_core()` to the top of each of the 3
  `run-gate-tests.sh` scripts (ga-funnel, ga-trust, ga-prereg),
  implementing the convention's order (`CLAUDE_PLUGIN_ROOT_CORE` →
  sibling `../../../core` → SKIP) and unconditionally exporting the
  resolved `CLAUDE_PLUGIN_ROOT_CORE` for the rest of the script.
- Doc-placement ladder: updated `docs/handbooks/growth-analytics-plugins.md`
  ("Running the gate tests" section) with the new SKIP-contract
  behavior, same commit as the script changes (operational-surface
  handbook-trigger-gate requirement).
- Verified (executed): `env -u CLAUDE_PLUGIN_ROOT_CORE -u
  CLAUDE_PLUGIN_ROOT bash <script>` exits 75 with the exact SKIP message
  for all 3 scripts; with core reachable (current spawn env), all 3
  scripts pass unchanged (17/17, 21/21, 14/14); `grep -rl
  test-env-resolution ga-funnel ga-trust ga-prereg` finds all 3 scripts.

## What did not work
None.

## Open findings
None.
