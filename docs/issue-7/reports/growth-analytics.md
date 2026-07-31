---
loop_state: landed
---

# Record: growth-analytics — issue-7 phase 2 (plugin-set enforcement)

Subject: issue-7. Implements `docs/issue-7/proposals/growth-analytics.md`
in full (approved via issue-comment `APPROVE issue-7/growth-analytics` by
`JiwonJung94`, single-account mode, contract v3 s19).

## What was done

Each of the three methodologies adopted in issue-1
(`docs/issue-1/proposals/rulebook-maturation.md` (a)/(b), reflected
`4e50c6f`) is now an independent, self-contained, marketplace-registered
plugin, matching `core`'s `freelunch`/`terse`/`scout`/`warrant` shape:

| Plugin | Methodology | Write surface | Files |
|---|---|---|---|
| `ga-prereg` | Pre-registration-first (phase 1) | `docs/issue-<n>/proposals/*.md` | `.claude-plugin/plugin.json`, `hooks/directive.sh`, `hooks/ga-prereg-gate.sh`, `hooks/hooks.json`, `hooks/tests/run-gate-tests.sh` |
| `ga-funnel` | Stage/segment localization (phase 2) | record's funnel-bottleneck section | same set + `agents/funnel-localizer.md` |
| `ga-trust` | Kohavi trust-gate (phase 2) | record's experiment-trust section | same set + `agents/trust-gate-walker.md` |

All three registered in `.claude-plugin/marketplace.json` alongside the
existing `growth-analytics` entry.

`growth-analytics/hooks/output-components-gate.sh` and
`proposal-preregistration-gate.sh` are deleted; their `hooks.json` wiring
is removed. `growth-analytics/hooks/directive.sh`'s `--produces` line is
rewritten into a composition manifest naming the three plugins and their
responsibilities (proposal section 6), replacing the inline free-text
component list. `growth-analytics` is now the composition root: role-wide
fields only (`--decides`/`--use-when`/`--hand-off`/`--record-path`),
methodology enforcement fully delegated to the three plugins.

Each new gate follows the fail-closed shape from proposal section 3.1
(pattern from `pricing/hooks/methodology-gate.sh`, read not copied):
`trap`-wrapped exit-code normalization, deny on empty payload, resolve
and validate `CLAUDE_PROJECT_DIR`/git-toplevel before trusting a path,
reconstruct post-write content for `Write`/`Edit`/`MultiEdit` rather than
diffing, mechanical (regex/needle) presence checks only, and a per-plugin
kill switch (`GA_PREREG_GATE_OFF`, `GA_FUNNEL_GATE_OFF`,
`GA_TRUST_GATE_OFF`). `ga-trust`'s gate additionally tracks session state
at `.claude/state/growth-analytics/ga-trust-<issue-n>.json`, re-deriving
validated steps from content on every write and using the state file only
to catch a regression (a later edit that removes a previously-validated
step's evidence) — never trusting stale state across a content change.

## Test results

Every case from proposal section 4 was exercised via each plugin's own
`hooks/tests/run-gate-tests.sh` (disposable git repo per case, synthetic
`PreToolUse` JSON payload on stdin, assert exit code + stderr content).
All pass:

- `ga-prereg`: 5/5 (full-pass, no-keyword-pass, missing-decision-rule
  reject, guardrail-equals-primary reject, malformed-JSON fail-closed
  reject).
- `ga-funnel`: 5/5 (full-pass, two-recommendations reject,
  no-concentration-sentence reject, restated-hypothesis reject, Edit-on-
  top-of-complete-Write content-reconstruction pass).
- `ga-trust`: 7/7 (full-verdict pass, effect/CI-before-SRM ordering
  reject, SRM-only-first-write pass, anomalous-effect-no-Twyman-flag
  reject, anomalous-effect-with-flag pass, SRM-removed-after-validation
  regression reject, no-project-root fail-closed reject).

## Why

Issue-1 adopted three methodologies but left them enforced (loosely) by
two role-local gates bundled by write-surface, with no fail-closed
wrapper, no ordering enforcement, and no tests — the gap this issue's
approver comment named directly, and corrected from "one deepened gate"
to "a plugin set," matching `core`'s existing precedent for how a
rulebook packages independently-adopted methodologies.

## Upstream basis

- Issue: #7. Approval: issue-comment `APPROVE issue-7/growth-analytics`
  by `JiwonJung94`.
- Phase-1 basis: `docs/issue-7/proposals/growth-analytics.md` (sections
  1-7, all implemented as written), `docs/issue-7/reports/growth-analytics/
  current-state-survey.md`, `docs/issue-7/reports/growth-analytics/
  scout-brief.md`.
- Normative source (unchanged, not re-litigated): `docs/issue-1/proposals/
  rulebook-maturation.md` (a)/(b)/(c), reflected `4e50c6f` (PR #6).

## Loop state

Closed for this issue: proposal's phase-2 reflection plan (section 7)
items 1-5 done; item 6 (updating issue-1's own record note) could not be
written from this branch — role-handoff contract v3 s10's board-gate
denies cross-issue-tree writes from a non-owning branch
(`docs/issue-1/...` requires branch `issue-1/growth-analytics`). Recorded
here instead: issue-1's "Open findings" first item (core sub-field gap
filled role-locally) is superseded by this issue's plugin split, not
resolved in place — the old combined gate is gone, replaced by
`ga-funnel`/`ga-trust`'s independent gates; the second item (keyword-
heuristic gating) is still applicable, unchanged by this issue since
`ga-prereg`/`ga-funnel` keep the same keyword pre-gate.

## Open findings

- `ga-trust`'s Twyman cross-check locates the linked `ga-prereg` proposal
  by directory listing under `docs/issue-<n>/proposals/`, taking the
  first `.md` file whose text contains an "expected effect" cue — if an
  issue ever has multiple proposal files with different expected
  effects, this picks the first found by filesystem order, not
  necessarily the one that actually authorized the running experiment.
  No stronger cross-reference (e.g. an explicit proposal-file pointer in
  the verdict section) exists yet to key on instead.
- The multi-fragment `SessionStart` composition this issue's directives
  rely on (each plugin's `directive.sh` appending independently,
  matching `core`'s `terse`/`freelunch`/`scout` precedent) is asserted
  consistent with `core`'s actual mechanism, not independently verified
  against `core`'s source in this repo tree (core is not checked out
  here) — same caveat pattern as issue-1 (d)2 and this issue's proposal
  section "Explicitly out of scope."
- Issue-1's own record (`docs/issue-1/reports/growth-analytics.md`) still
  needs its "Open findings" section amended in place to reflect the
  supersession noted above under Loop state; that edit is out of this
  branch's write scope (contract v3 s10) and needs a separate pass on
  the `issue-1/growth-analytics` branch, or a core-level allowance for
  cross-issue-tree annotation, to land.
