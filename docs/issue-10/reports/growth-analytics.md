# Record: issue-10 gate A+ delivery (growth-analytics, phase 2)

loop_state: landed

Subject: issue-10. Phase 2 delivery against `docs/issue-10/proposals/
gate-a-plus.md` (approved via the issue-10 comment `APPROVE issue-10/
growth-analytics` from `JiwonJung94`, an account listed in `docs/specs/
approvers.md`).

## What was done

Implemented, in this branch, every defect-fix and semantic-check upgrade
that `docs/issue-10/proposals/gate-a-plus.md` sections 1-4 designed, added
the mandatory test cases from its section 3, and realigned `README.md`'s
Layout section — see "Changes" below for the itemized list. All three
plugins' `hooks/tests/run-gate-tests.sh` suites pass (0 failures) as of
this write.

## Why

Issue #10's audit found the growth-analytics gate house at grade B: the
ga-trust state machine could be bypassed by never using its exact magic
phrase in a heading, its Twyman cross-check read an arbitrary proposal
file in undefined directory-listing order and ignored unit mismatches,
and the README documented three gate files that do not exist while
leaving the three real ones undocumented. Issue #10 asked for these
fixed to an A+ bar across all axes, with the fixes described at
design-intent level in the already-approved `gate-a-plus.md` proposal.
This record is that proposal's phase-2 implementation.

## Upstream basis

- `docs/issue-10/proposals/gate-a-plus.md` (this delivery's design basis,
  approved by the issue-10 `APPROVE` comment).
- `docs/issue-10/reports/growth-analytics/survey.md` and `scout-brief.md`
  (phase-1 current-state survey/scout that the proposal was built on).
- Issue #10 itself (2026-08-01 audit comment).

## Precondition deviation, stated up front

The proposal's phase boundary (section 5) made phase 2 conditional on
core issue #72 ("게이트 하우스 표준: 공유 라이브러리·표준 하네스·준수
검출기") landing first, so the fixes could reference-adopt its shared
library instead of re-deriving duplicated logic a fourth time. As of this
delivery: `gh issue view 72` does not resolve in this repository, no
`core/` directory exists, and neither `core/hooks/lib/gate-lib.sh` nor
`docs/handbooks/gate-house-standard.md` exists anywhere in `origin/main`
— the dependency issue #72 does not exist in this repository at all, not
merely "not yet landed." Continuing to block phase 2 on a dependency that
was never filed here would leave issue #10 permanently undeliverable.
Given the explicit phase-2 delivery instruction for this session, the
fixes below are implemented **inline**, duplicated across the three gate
scripts exactly as they were before (same shape as the pre-existing
duplication the proposal itself catalogued), not reference-adopted from
any shared library. If/when a real `gate-lib.sh` lands, folding these
three now-fixed, still-duplicated copies into it remains open follow-up
work — noted, not done here.

There is likewise no `core/*/compliance-check.sh` in this repository to
run. In its place, the check performed and recorded below is: all three
plugins' own `hooks/tests/run-gate-tests.sh` suites, run from a clean
checkout, exit 0.

## Changes (per `gate-a-plus.md` section 1-4)

- **1.1 magic-phrase gate-arming (ga-trust):** the "experiment trust
  verdict" arm-phrase now requires a markdown heading; every step check
  runs only inside that heading's section span. A write where the phrase
  appears outside any heading is denied (structurally unidentifiable),
  not silently skipped.
- **1.2 Twyman cross-check:** the verdict section must name its governing
  proposal via a labeled `Proposal: docs/issue-<n>/proposals/<file>.md`
  line — no more `os.listdir()` order dependence. The comparison also now
  requires both sides' effect-size unit (`pp`/`%`/unstated) to match
  before computing the ratio.
- **1.3 README ghost files:** removed (see below).
- **1.4 absolute-path normalization:** containment checks in all three
  gates now resolve both `root` and the target path through
  `os.path.realpath` before comparing, not just `os.path.normpath`.
- **1.5 fail-closed:** `trap __fc EXIT` moved to the first statement after
  `set -uo pipefail` in all three gates, ahead of the kill-switch case and
  the `python3` presence check. Kill-switch default inverted: only a
  recognized on-value (`1`/`true`/`yes`/`on`) disables a gate; any other
  value, including an unrecognized one, leaves it enabled.
- **1.6 Edit/MultiEdit/replace_all:** all three gates now read
  `tool_input.replace_all` for `Edit` and each edit's own `replace_all`
  key for `MultiEdit`, reconstructing with `str.replace(o, n)` when true
  and `str.replace(o, n, 1)` otherwise.
- **1.7 deny-to-stderr:** already correct; unchanged.
- **2.1/2.2 section-scoped + adjacency checks:** ga-trust and ga-funnel
  both gained heading-anchored section extraction; every check that used
  to scan the whole document (`low`) now scans only the declared
  section's span. ga-trust additionally gained a positional check (SRM
  evidence must appear before the effect-size label within the section),
  additive to the existing state-based ordering check.
  **Scope note on ga-prereg:** section-heading scoping was **not** added
  to ga-prereg — this repository has no existing heading convention for
  `docs/issue-<n>/proposals/*.md` files (the existing passing fixture has
  no heading at all), and forcing one would be a breaking format change
  beyond what issue #10 or the proposal's mandatory test cases (section
  3) require. ga-prereg keeps its whole-document keyword pre-gate and
  labeled-line regex scan; only the 2.3 labeled-line upgrade below was
  applied.
- **2.3 structural (labeled-line) checks:** ga-prereg's `hypothesis` and
  `power basis` checks converted from bare word-presence to
  `label\s*[:\-]\s*\S` labeled-line requirements, matching the shape
  already used by `primary metric` and `decision rule`.

## README realignment (issue-10 requirement 4)

`README.md` "Layout" no longer lists the three nonexistent
`growth-analytics/hooks/{record-fields-gate.sh,trailer-gate.sh,
handbook-trigger-gate.sh}`. It now lists the three real gate scripts
(`ga-prereg-gate.sh`, `ga-funnel-gate.sh`, `ga-trust-gate.sh`) with a
pointer to `docs/handbooks/growth-analytics-plugins.md` for kill
switches and test-run commands.

## Mandatory test cases added (issue-10 requirement 3)

Added to the three plugins' `hooks/tests/run-gate-tests.sh`:

- ga-trust: section-boundary leakage (3.1), SRM/effect-size ordering
  violation (3.2), Twyman unit mismatch and matching-unit pass (3.3),
  Twyman proposal-selection ambiguity (3.4), Edit/MultiEdit
  `replace_all` reconstruction, malformed JSON, kill-switch
  unrecognized-value-stays-enabled, absolute-path-outside-root denial.
- ga-prereg: bare-word hypothesis/power-basis rejection (2.3 upgrade),
  kill-switch, absolute-path in/out of root, `Edit` `replace_all`
  reconstruction (malformed-JSON case pre-existed).
- ga-funnel: section-scoping leakage (appendix content outside the
  heading must not satisfy the check), arm-phrase-without-heading
  denial, malformed JSON, kill-switch, absolute-path outside root, Edit
  and MultiEdit `replace_all` reconstruction.

## Compliance-check result

No `core/*/compliance-check.sh` exists in this repository to run (see
precondition deviation above). Ran, in place of it, all three plugins'
own gate-test suites from a clean working tree at delivery time:

```
bash ga-prereg/hooks/tests/run-gate-tests.sh   # ga-prereg: 12 passed, 0 failed
bash ga-funnel/hooks/tests/run-gate-tests.sh   # ga-funnel: 13 passed, 0 failed
bash ga-trust/hooks/tests/run-gate-tests.sh    # ga-trust: 18 passed, 0 failed
```

All three exit 0. This is the full-suite-green state required by issue
#10 requirement 3.

## Open findings

- Core issue #72's shared `gate-lib.sh` still does not exist in this
  repository; the fixes above remain inline duplicates across the three
  gate scripts rather than reference-adopted from a shared library, per
  the precondition deviation above. Follow-up: fold the duplicated
  containment/kill-switch/reconstruction/section-extraction logic into a
  shared library once one lands.
- ga-prereg's semantic checks remain whole-document (not section-scoped),
  by deliberate scope decision (see "Scope note on ga-prereg" above), not
  an oversight.
- No `core/*/compliance-check.sh` exists to run; the record above
  substitutes the three plugins' own test suites as the compliance
  evidence.

loop_state: landed
