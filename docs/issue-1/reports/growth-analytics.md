---
loop_state: landed
---

# Record: growth-analytics — issue-1 phase 2 (rulebook maturation reflection)

## What was done

Reflected the human-approved `docs/issue-1/proposals/rulebook-maturation.md`
into this rulebook's plugin, per its (d) plugin reflection plan:

1. `growth-analytics/hooks/directive.sh` — expanded `--produces` from free
   text into two named artifact declarations, `funnel-diagnosis` and
   `experiment-trust-verdict`, each spelling out its 5 required components
   inline; added a comment pointing this role's own future phase-1
   proposals at the pre-registration-first norm.
2. `growth-analytics/hooks/output-components-gate.sh` (new, role-local
   `PreToolUse` hook) — on a write to this role's own record
   (`docs/issue-<n>/reports/growth-analytics.md`), if the record declares a
   `funnel diagnosis` or `experiment trust verdict` section, requires all 5
   of that artifact's required components (proposal (b)) to be present as
   locatable text; denies (fail-closed, exit 2) otherwise. This is
   additive to core's centralized generic `record-fields-gate.sh` (§20
   what/why/upstream/loop_state/open-findings), not a replacement — core's
   gate does not do sub-component checks, per the proposal's (d)2 note
   that the exact core mechanism for nested checks was unconfirmed and
   left as a phase-2 discovery item. Since core is not checked out in this
   repo tree, adding the sub-component check as a role-local gate (rather
   than attempting to modify core canon out-of-scope for this issue) was
   the deliverable available here.
3. `growth-analytics/hooks/proposal-preregistration-gate.sh` (new,
   role-local `PreToolUse` hook) — on a write to this role's own phase-1
   proposal under `docs/issue-<n>/proposals/`, if the text signals an
   experiment run/trust recommendation (keyword gate: an experiment/A-B
   term plus a run/trust/recommend term), requires all 5 pre-registration
   items from proposal (a) (primary metric, hypothesis/expected effect,
   sample size + duration, guardrail metrics, decision rule) as locatable
   lines; denies otherwise. Proposals that don't recommend an experiment
   (e.g. this issue's own rulebook-maturation proposal) are unaffected.
4. `growth-analytics/hooks/hooks.json` — registered both new gates as
   `PreToolUse` hooks (matcher `Write|Edit|MultiEdit`) alongside the
   existing `SessionStart` directive hook.
5. Manually exercised both new gates against sample payloads (missing
   components → deny/exit 2; complete components → allow/exit 0;
   non-experiment proposal → allow; experiment proposal missing items →
   deny) before committing. No automated test harness exists in this repo
   tree to add to; manual verification is recorded here as the check that
   ran.

No framework name (AARRR/HEART/Kohavi) is hardcoded into either gate —
both check only the enumerated components/items, per proposal (c)(4)/(d)4.

## Why

Per issue-1: this role declared *what* it produces but no gate checked
*how* — no methodology, no required components, no evidence format, for
either its phase-1 proposals or phase-2 deliverables. The approved
proposal fixes both norms from a domain survey (Kohavi trust-gate for
experiments; AARRR/HEART/cohort-retention convergence for funnel
diagnosis; pre-registration literature for this role's own proposals),
and phase 2 is that norm's mechanical enforcement, so the role cannot
silently regress to the loose free-text state the survey found.

## Upstream basis

- Issue: #1.
- Approval: issue-level comment `APPROVE issue-1/growth-analytics` by
  `JiwonJung94` (an `docs/specs/approvers.md` account), single-account
  mode per contract v3 s19.
- Phase-1 basis: `docs/issue-1/proposals/rulebook-maturation.md` (this
  proposal's (a)/(b)/(c)/(d) sections are what this record implements),
  `docs/issue-1/reports/growth-analytics/current-state-survey.md`,
  `docs/issue-1/reports/growth-analytics/scout-brief.md`.
- Commit basis: `9a74abd` (phase-1 survey/proposal, merged to main as
  PR #5 / `4fe811c`).

## Open findings

- Core's centralized `record-fields-gate.sh` does not yet support
  per-role sub-component (nested) field checks; this record's
  `output-components-gate.sh` fills that gap role-locally per proposal
  (d)2, but if core later grows a native per-role sub-field mechanism, the
  role-local gate here should be reconciled with (likely retired in favor
  of) that core mechanism to avoid two enforcement paths diverging over
  time.
- The proposal-preregistration keyword gate is a heuristic (experiment/
  A-B term + run/trust/recommend term); a proposal that recommends an
  experiment without those specific words would not trigger it. No
  stronger signal (e.g. structured proposal front-matter) exists yet in
  this rulebook to key on instead.
