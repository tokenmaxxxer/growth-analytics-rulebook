---
status: proposed
files:
  - ga-funnel/hooks/tests/run-gate-tests.sh
  - ga-trust/hooks/tests/run-gate-tests.sh
  - ga-prereg/hooks/tests/run-gate-tests.sh
  - docs/issue-20/reports/implementation/survey.md
  - docs/issue-20/proposals/2026-08-09-test-env-resolution.md
---

## Request
Adopt the canonical test-env resolution convention landed at
on-the-record `docs/specs/test-env-resolution.md` (issue #551) in this
rulebook's 3 gate-test runner scripts, so that outside the spawn session
env they SKIP with an explicit message and distinct exit code instead of
misreporting as failures.

## Constraints
- Do not weaken any assertion that runs when core IS reachable.
- Resolution order must match the convention exactly: `$CLAUDE_PLUGIN_ROOT_CORE`
  (if it contains a non-empty `hooks/lib/gate-lib.sh`) → first
  caller-supplied sibling candidate with the same file → SKIP.
- SKIP must print `SKIP: core plugin unreachable — unverifiable outside
  spawn env` to stderr and exit `75` (EX_TEMPFAIL) — distinct from a
  gate's own pass(0)/fail(1)/deny(2) exits and from a test-content
  failure.
- Each script must reference the convention (grep for
  `test-env-resolution` must find it).
- No network fetch fallback (out of scope per the convention doc).

## Rationale
Two ways to adopt were considered (full detail in the survey):
1. **Vendor on-the-record's `gates/test_env_resolve.py` and shell out to
   it via `python3 -m gates.test_env_resolve`** — the doc's literal
   "Bash test runner" recipe. Rejected: that module lives in a separate
   repo (on-the-record, issue #551) with no vendoring/sync mechanism
   into this rulebook; copying it here creates a second, driftable copy
   with no update path, and adds a Python dependency to scripts that are
   otherwise pure bash for a resolution check this small (~15 lines).
2. **Inline the same order + SKIP contract directly in bash**, at the
   top of each `run-gate-tests.sh`, before any gate subprocess runs —
   chosen. No new dependency, same order/message/exit code as the
   convention, and a comment in each script naming the convention
   path/issue satisfies the "references the convention" acceptance
   check without requiring the external module to be present.

## What will be done
For each of the 3 `run-gate-tests.sh` scripts:
- Add a `resolve_core()` step at the top, before any test case runs,
  implementing the convention's order: check
  `$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh` (non-empty file) →
  check `$CLAUDE_PLUGIN_ROOT/../core/hooks/lib/gate-lib.sh` (the same
  sibling candidate each gate script already falls back to, per the
  survey) → if neither resolves, print
  `SKIP: core plugin unreachable — unverifiable outside spawn env` to
  stderr, print a one-line comment/echo naming the convention
  (`docs/specs/test-env-resolution.md`, on-the-record issue #551), and
  `exit 75` before any test case executes.
- When core resolves, **always** `export CLAUDE_PLUGIN_ROOT_CORE` to the
  path `resolve_core()` actually validated — unconditionally, not only
  when the variable was previously unset — so a stale/invalid pre-set
  value never survives past resolution. Every gate subprocess invocation
  in the rest of the script then sees the resolved, working core, and
  all existing test cases run unchanged — same assertions, same
  exit-code expectations, same messages. (A conditional "export only if
  unset" guard was drafted and then dropped after the after-proposal
  warrant hunt reproduced it silently keeping a stale
  `CLAUDE_PLUGIN_ROOT_CORE` value alive even after a working sibling
  core resolved — see
  `docs/reports/2026-08-09-hunt-test-env-resolution.md`.)
- The existing "missing core (CLAUDE_PLUGIN_ROOT_CORE unresolvable)
  fails closed" test case in each script (which deliberately points
  `CLAUDE_PLUGIN_ROOT_CORE` at `/nonexistent-core-$$` and a scratch
  `CLAUDE_PLUGIN_ROOT`) stays unchanged — it exercises the *gate's own*
  fail-closed behavior on a per-invocation basis, which is a different
  concern from the *runner's* upfront environment check, and remains a
  concrete regression guard on the gate scripts' own sourcing guard.

## Out of scope
- Vendoring or importing on-the-record's `gates/test_env_resolve.py`
  module into this repo.
- Any change to the 3 gate scripts themselves (`ga-*-gate.sh`) — their
  existing fail-closed sourcing guard is correct and untouched.
- `growth-analytics/hooks/` and any other plugin tree in this repo —
  none have a test runner today.
- A shared bash lib file across the three plugin trees — no such shared
  location exists today (survey); each script stays self-contained.

## How you'll know it worked
- With `CLAUDE_PLUGIN_ROOT_CORE` unset and no `../core` sibling: each of
  the 3 scripts exits `75` and prints the exact SKIP message to stderr,
  with zero PASS/FAIL lines for individual test cases (confirmed by
  running each script under `env -u CLAUDE_PLUGIN_ROOT_CORE -u
  CLAUDE_PLUGIN_ROOT`).
- With `CLAUDE_PLUGIN_ROOT_CORE` pointed at a real core checkout (as in
  the current spawn env): all existing test cases still run and pass
  exactly as before (confirmed by running each script unchanged in the
  current session, which already has `CLAUDE_PLUGIN_ROOT_CORE` set).
- `grep -rl test-env-resolution ga-funnel ga-trust ga-prereg` returns all
  3 scripts.
