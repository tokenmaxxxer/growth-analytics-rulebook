---
code_under_review: same-commit
type: feature
breaking: false
verdict: pass
loop_state: landed
---

# Implementation record — issue-17

## What was done

Applied the approved phase-1 proposal
(`docs/issue-17/proposals/spec-alignment.md`) to align this rulebook with
`growth-analytics.spec.json`'s required record fields (`funnel_stage`,
`metric_value`, `is_north_star`) and `loop_state` vocabulary
(`analytics-data-unreachable`, `landed`, `measuring`, `reviewing`,
`stage-undeclared`).

- [x] `docs/handbooks/growth-analytics-plugins.md` — added "Record field
  vocabulary (issue-17)" section documenting `funnel_stage`,
  `metric_value`, `is_north_star`, and the loop_state bucket mapping (as
  prose — see deviation below).
- [x] `README.md` — added the three field names and the loop_state set to
  the role summary.
- [x] `ga-funnel/hooks/ga-funnel-gate.sh` — added an anchored
  `funnel_stage` check (a stage-pair line must name one of the five
  canonical labels, directly or via a declared `stage N = <label>`
  mapping) and an anchored `is_north_star: true|false` check (rejects a
  bare mention of the phrase with no value — closing the exact gap
  `docs/reports/2026-08-09-hunt-spec-alignment.md`'s phase-1 hunt flagged).
- [x] `ga-funnel/hooks/tests/run-gate-tests.sh` — updated the `FULL`/
  `TWO_RECS` fixtures to include both new required elements (existing
  PASS cases stay PASS), and added two REJECT cases: no canonical
  `funnel_stage` label, and a bare `is_north_star` mention with no
  anchored value.
- [x] `growth-analytics/hooks/directive.sh` — the composed SessionStart
  directive text now names the three required fields and the loop_state
  vocabulary.
- [ ] `docs/specs/record-fields-terminal-states.json` — NOT created; see
  `## Rationale for deviations`. The loop_state vocabulary instead landed
  as prose in the handbook and README.

Ran `bash ga-funnel/hooks/tests/run-gate-tests.sh` (17/17 pass, including
the 2 new cases), plus regression runs of
`ga-prereg/hooks/tests/run-gate-tests.sh` (14/14 pass) and
`ga-trust/hooks/tests/run-gate-tests.sh` (21/21 pass) — no repo-level
pytest/tests directory exists; this repo's actual test suite is these
three shell gate-test harnesses, and all three were run and pass.

## Why

Basis: `docs/issue-17/proposals/spec-alignment.md` (approved via issue
comment `APPROVE issue-17/implementation`, single-account mode, account
`JiwonJung94` listed in `docs/specs/approvers.md`).

## Upstream

Basis: docs/issue-17/proposals/spec-alignment.md

## What did not work

- Wrote `docs/specs/record-fields-terminal-states.json` with a
  `growth-analytics` key per the proposal's item 5, then reverted it: the
  edit tripped `core/hooks/record-fields-gate.sh`'s own validation
  ("names unrecognized kind 'growth-analytics'"). Reading that gate's
  source showed the override file's `kind ->` map only accepts contract
  §2's fixed nine record kinds (`coding-record`, `qa-record`,
  `feasibility-record`, …) as keys — it lets an unmapped role's record
  *borrow* one of those nine terminal-state sets via a self-declared
  `kind:` frontmatter field, it does not let a role register an entirely
  new kind or vocabulary. `growth-analytics` is not one of the nine and
  this five-word loop_state set is not a subset of any of them, so this
  mechanism cannot carry it. Removed the file; documented the vocabulary
  as prose in the handbook and README instead (see Rationale for
  deviations).

## Rationale for deviations

Proposal item 5 (`## What will be done`) planned to satisfy the
"loop_state vocabulary matches the spec set exactly" acceptance check by
declaring a `growth-analytics` key in
`docs/specs/record-fields-terminal-states.json`. That file is real and is
core's designed extension point — but, discovered only by attempting the
write, its schema is narrower than the proposal assumed: `core/hooks/
record-fields-gate.sh` restricts override keys to contract §2's nine
fixed record kinds, refusing any other key at write time. Modifying that
gate to accept new kinds lives in `tokenmaxxxer-core`, outside this
repo's frozen write set and outside this issue's scope. Deviation: the
five-word loop_state vocabulary is instead declared as prose in
`docs/handbooks/growth-analytics-plugins.md` and `README.md` (both
already in the frozen write set), satisfying the acceptance check's grep-
observable form ("rulebook loop_state vocabulary matches the spec set
exactly") without the machine-enforced override file. No other proposal
item changed.

## Open findings

None. Phase-1 hunt finding in
`docs/reports/2026-08-09-hunt-spec-alignment.md` (bare `is_north_star`
substring bypass) is resolved by the anchored
`is_north_star: true|false` regex check added to `ga-funnel-gate.sh`,
covered by the new REJECT test case.
