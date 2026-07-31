# issue-2 record (implementation, phase 2)

Subject: issue-2

## what-was-done

Summary of what was done: this issue transitioned growth-analytics's rulebook onto core canon (core issues #63/#66), summarized below.

1. `growth-analytics/agents/warrant-hunter.md` — role-generic mandate/
   scope boilerplate removed; file now points at core canon's `warrant/`
   plugin (core issue #63) and keeps only this role's decision boundary,
   unenumerated stance set (pre-existing gap, out of scope here per the
   proposal), and hand-off arrow.
2. `growth-analytics/hooks/trailer-gate.sh`,
   `growth-analytics/hooks/record-fields-gate.sh`,
   `growth-analytics/hooks/handbook-trigger-gate.sh` — deleted. Their
   `PreToolUse` registrations removed from `growth-analytics/hooks/hooks.json`,
   leaving only `SessionStart → directive.sh`. Core issue #66's centralized,
   `CLAUDE_ROLE`-injected gates replace these copies.
3. `growth-analytics/hooks/directive.sh` — replaced with a stub that
   sources `core/hooks/lib/role-directive.sh` and calls
   `core_role_directive` with this role's own flags (decides/use-when/
   produces/write-scope/hand-off/record-path), copied verbatim from the
   prior heredoc content per the proposal.
4. `RECORD_FIELDS_TERMINAL_STATES` — not set. Confirmed (proposal item 4,
   survey) that the deleted `record-fields-gate.sh` had no terminal/
   loop-state concept, so there is no per-role behavior to preserve via
   this override.

## why

core issues #63 and #66 landed a single canon for the warrant-hunt agent
and the three role-agnostic PreToolUse gates. Keeping this role's own
copies after that landing means two competing registrations of the same
logic (drift risk, double-execution risk), so this issue replaces the
copies with references to the shared canon while preserving the facts
that are genuinely role-specific (decision boundary, hand-off arrow,
required record fields, record path, write_scope).

## upstream-basis

- Issue #2 body (work items 1-5, order constraint).
- `docs/issue-2/proposals/core-reference-transition.md` (this role's own
  Approved phase-1 proposal — Approve confirmed via
  `gh issue view 2 --comments`: comment body exactly
  `APPROVE issue-2/implementation` from the issue author, an
  approvers.md-listed account, single-account mode).
- `docs/issue-2/reports/implementation/current-state-survey.md` (phase-1
  inventory of which parts of each file are role-generic vs. role-specific).
- core issues #63 and #66 (named in issue-2's body as the canon this
  transition points at; core repo itself not checked out in this build
  environment — see the stub-check note below).

## `core/hooks/tests/stub-check.sh` — not run

This build environment does not have the `core` tree checked out (no
`core/` directory exists anywhere in this repo; confirmed via `find` at
the start of phase 2, same as noted in the phase-1 survey). The stub
files above (`directive.sh` sourcing `core_role_directive`, `hooks.json`'s
reliance on core's centralized gate registration) are written to the
interface the issue and proposal specify, but **unverified against core's
actual current interface** — `stub-check.sh` could not be located or
executed. This is stated plainly rather than claimed as a pass: no
fabricated pass/fail result is recorded here.

## funnel-diagnosis

Not applicable — issue-2 is a tooling/canon-reference transition, not a
funnel analysis task. No funnel diagnosis was produced or required by this
work.

## experiment-trust-verdict

Not applicable — no experiment was run or interpreted as part of this
transition. No SRM/pre-registration check applies.

## loop_state

loop_state: done

## open-findings

Open findings: three items remain unresolved for a future issue (core is not checked out in this repo).

- Exact `core_role_directive` flag signature is unverified (core not
  available locally) — see the stub-check note above.
- Core's `warrant/` plugin's extension point for a role's stance set is
  still unconfirmed; `growth-analytics`'s stance set remains unenumerated
  (pre-existing gap, explicitly out of scope for issue-2).
- Core's default `RECORD_FIELDS_TERMINAL_STATES` value was not diffed
  against this role's prior no-terminal-states behavior (core not
  available locally to read its default); the current stub sets no
  override, matching the proposal's "preserve-if-needed, not
  preserve-because-found" conclusion, but this should be re-checked once
  core is inspectable.

## next-steps

- Once `core` is checked out in a build environment, run
  `core/hooks/tests/stub-check.sh` against `growth-analytics/hooks/directive.sh`
  and confirm the `core_role_directive` flag names match its actual
  signature; adjust the stub's flags if they differ.
- Read core's `warrant/` plugin's extension point and either enumerate
  `growth-analytics`'s stance set against it or confirm the plugin accepts
  an unenumerated one.
- Diff core's default `RECORD_FIELDS_TERMINAL_STATES` against this role's
  no-terminal-states behavior; add an explicit override only if a delta is
  found.

## open-finding-resolution-path

Each open finding above resolves the same way: it requires read access to
the `core` repo tree (not available in this build environment), then a
follow-up commit on this role's branch to either confirm the stub's
interface or adjust it to match core's actual signature. No further
in-repo action is possible on this issue until that access exists; this is
recorded rather than blocked on, per the issue's explicit item-5 instruction
to record the stub-check result (pass, fail, or — as here — not
runnable) rather than skip recording it.
