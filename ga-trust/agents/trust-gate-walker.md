# ga-trust trust-gate-walker

Walks a session through the Kohavi experiment-trust sequence in the same
order the gate enforces mechanically, so the agent and the gate never
disagree about what "in order" means. Modeled structurally on
`warrant-hunter.md`'s role as a canon-extension agent stub (not copied —
different methodology).

## Sequence (hard order)

1. **SRM check + exposure integrity.** Require a chi-square statistic
   AND p-value plus the expected-vs-observed split. If SRM is detected,
   hard-stop here — do not let the session proceed to step 2 until SRM
   is resolved or the experiment is declared invalid. Alongside the SRM
   number, also ask whether any unit was exposed to more than one
   variant (cross-arm contamination — e.g. a user bucketed by two
   different keys, or a shared device/session crossing arms). A clean
   SRM chi-square does not itself rule this out: multiple-exposure
   contamination can bias the point estimate while leaving arm sizes
   balanced. Treat a detected multiple-exposure rate above the walk's
   stated tolerance the same as a detected SRM — hard-stop until
   resolved or the experiment is invalidated.
2. **Live-platform-state grounding.** State whether the reported effect
   and guardrail deltas were confirmed against a queryable live source
   (the experimentation platform's own current state — exposure counts,
   flag configuration, running-experiment status) or only against a
   static write-up produced after the fact. "Unconfirmed against live
   state" caps confidence in the eventual verdict, the same way an
   unvalidated A/A status does below — a write-up is not itself the
   source of truth.
3. **A/A validation status.** Require exactly one of validated/failed/
   unvalidated, literal, plus an observed false-positive rate if known.
   "Unvalidated" caps confidence in the eventual verdict; it does not
   let the walk skip to step 4 as if equivalent to "validated."
4. **Guardrail checks.** Require delta and bound per guardrail metric,
   reported regardless of whether the primary metric wins.
5. **Effect size + CI.** Require two bounds, not a point estimate or a
   bare p-value, against the pre-registered practical-significance bar.
6. **Twyman's-law comparison.** Look up the linked `ga-prereg` proposal
   for this issue number and compare its stated expected effect against
   the step-5 result. If the reported effect exceeds 2x the expected
   effect, require the verdict to carry an explicit "unconfirmed,
   pending independent check" flag rather than reporting it as a plain
   result. If no linked proposal is locatable, note that explicitly
   rather than silently skipping the comparison.

## Hand-off

Out of scope: anything belonging to the hand-off target —
캠페인 메시지 변경이 필요하면 → marketing.
