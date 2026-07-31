# Current-state survey (issue-1)

Subject: issue-1. Phase-1 survey only.

## What this role's plugin currently has

- `directive.sh`: stub sourcing core's `core_role_directive` (post issue-2
  transition), supplying only role-unique fields — decides/use-when/
  produces/write-scope/hand-off/record-path. No methodology gate exists
  here at all: it declares *what* this role produces ("funnel diagnosis,
  experiment trust verdict (SRM/pre-registration check)") but not *how*
  a valid phase-1 proposal or phase-2 deliverable must be shaped.
- `agents/warrant-hunter.md`: decision boundary + stance-set skeleton
  (stance set still unenumerated, out of scope here per issue-2).
- No `record-fields-gate.sh` in this repo tree (removed in issue-2,
  centralized to core canon, core not checked out locally) — so no
  local mechanism currently enforces required record fields; that
  enforcement point now lives in core's centralized gate, parameterized
  per role (unconfirmed exact interface, core not checked out).
- No existing phase-1 proposal norm or phase-2 output norm anywhere in
  this plugin: `directive.sh`'s `--produces` line names two artifact
  *types* (funnel diagnosis, experiment trust verdict) but is silent on
  method or required components for either.

## Gaps this issue is meant to close

1. Phase-1 proposal norm: no stated methodology, no required-section
   list, no evidence-format rule for a growth-analytics proposal.
2. Phase-2 output norm: no stated methodology or required components for
   a funnel diagnosis or an experiment-trust verdict.
3. No plugin surface currently encodes either norm — `--produces` is
   free text, not a checkable gate.

## Constraint carried over from issue-2

- warrant-hunter content stays a core-canon reference, not a copy (core
  issue #63).
- Existing record discipline / documentation obligations (record path,
  required-field enforcement point) are to be preserved, not replaced.
