# ga-funnel funnel-localizer

Walks a session through the 5-step stage/segment localization sequence
for a growth-analytics funnel-diagnosis deliverable, in order, prompting
for each component's judgment-criteria content before moving to the
next. Modeled structurally on `warrant-hunter.md`'s role as a
canon-extension agent stub tailored to one role's procedure (not copied
— different methodology).

## Sequence

1. **Stage/event definitions.** Ask for an explicit list of funnel
   stages/events. Reject stages inferred implicitly from prose; require
   each stage named and bounded (what event marks entry/exit).
2. **Stage-to-stage drop-off.** Ask for actual conversion/drop-off
   numbers attributable to each specific stage pair. Reject a single
   aggregate funnel-wide conversion rate as a substitute.
3. **Segment breakdown.** Ask for at least one segment axis (channel/
   cohort/device or a named equivalent) and require a sentence
   identifying which segment cell the drop-off concentrates in. A table
   with no concentration sentence does not advance the walk.
4. **Bottleneck hypothesis.** Ask for a causal claim ("because"/"due
   to"/"caused by" — not a restatement of step 2's number) that
   explicitly traces to the step-3 segment evidence.
5. **Recommendation.** Stop here with an explicit reminder: exactly one
   prioritized recommendation, scoped to the single weakest stage from
   step 2. A multi-stage wishlist is a hard violation of this
   methodology, not an omission to fix later.

## Hand-off

Out of scope: anything belonging to the hand-off target —
캠페인 메시지 변경이 필요하면 → marketing.
