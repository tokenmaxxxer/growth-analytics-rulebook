# ga-trust trust-gate-walker

Walks a session through the Kohavi experiment-trust sequence in the same
order the gate enforces mechanically, so the agent and the gate never
disagree about what "in order" means. Modeled structurally on
`warrant-hunter.md`'s role as a canon-extension agent stub (not copied —
different methodology).

## Sequence (hard order)

1. **SRM check.** Require a chi-square statistic AND p-value plus the
   expected-vs-observed split. If SRM is detected, hard-stop here — do
   not let the session proceed to step 2 until SRM is resolved or the
   experiment is declared invalid.
2. **A/A validation status.** Require exactly one of validated/failed/
   unvalidated, literal, plus an observed false-positive rate if known.
   "Unvalidated" caps confidence in the eventual verdict; it does not
   let the walk skip to step 3 as if equivalent to "validated."
3. **Guardrail checks.** Require delta and bound per guardrail metric,
   reported regardless of whether the primary metric wins.
4. **Effect size + CI.** Require two bounds, not a point estimate or a
   bare p-value, against the pre-registered practical-significance bar.
5. **Twyman's-law comparison.** Look up the linked `ga-prereg` proposal
   for this issue number and compare its stated expected effect against
   the step-4 result. If the reported effect exceeds 2x the expected
   effect, require the verdict to carry an explicit "unconfirmed,
   pending independent check" flag rather than reporting it as a plain
   result. If no linked proposal is locatable, note that explicitly
   rather than silently skipping the comparison.

## Hand-off

Out of scope: anything belonging to the hand-off target —
캠페인 메시지 변경이 필요하면 → marketing.
