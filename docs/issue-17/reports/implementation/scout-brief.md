# Scout brief — issue-17 (align rulebook with growth-analytics.spec.json)

Non-product role (rulebook alignment). Stage 1 sweep: single WebSearch angle
(no parallel fan-out warranted — this task has one decision axis: how
NSM/funnel-stage vocabulary composes, not multiple competing angles), plus
the spec's own cited source.

## Must-bes (from field)
- NSM sits *above* AARRR; AARRR stages ladder up to it — NSM is not itself
  a funnel stage, it's a cross-cutting flag on whichever metric currently
  qualifies. Confirms the spec's design: `is_north_star` is a boolean flag
  alongside `funnel_stage`, not a sixth enum value.
- Exactly one NSM should hold at a time and it changes only when what's
  offered to the customer changes — matches spec's `recomputation` rule
  (exactly one `is_north_star=true` across all records, recomputed each
  new record).
- AARRR is the operational/diagnostic layer (funnel leaks), NSM is the
  alignment/compass layer. This rulebook's `ga-funnel` gate is exactly the
  operational-diagnostic layer already; NSM is a new, separate axis, not a
  rename of anything existing.

## Gap line
Rulebook already has: full AARRR-shaped funnel diagnosis (ga-funnel gate),
experiment trust verdict (ga-trust), pre-registration (ga-prereg). Missing
from current state: (1) no `funnel_stage` enum vocabulary anywhere in
docs — funnel diagnosis prose uses free-text "stage 1/2/3", not the AARRR
label set; (2) no North Star field/flag at all; (3) no `metric_value`
concept — the record has no single machine-checkable value field, only
free-text quantified drop-off; (4) no role-specific `loop_state` vocabulary
declared anywhere — growth-analytics records currently just say
`loop_state: landed` inherited from generic contract kinds, with no
role-specific progress/refusal/error states.

## Adopt / skip
- Adopt: NSM as boolean flag layered onto the *funnel-diagnosis* record,
  not a new document type — keeps "strengthening existing content, never
  deleting methodology" per issue text.
- Skip: implementing `TBD` recomputation *enforcement* (spec itself marks
  this a follow-up, issue-521 out-of-scope) — proposal maps the vocabulary
  and rule statement, not a new enforcement gate for it.

## Stage/mode
1 stage (sweep only; saturation reached — the relationship is well-established
canon, not a contested design space, so no deepening round was needed).

Sources:
- https://gustdebacker.com/north-star-metric/
- https://www.productcompass.pm/p/aarrr-pirate-metrics (spec's own citation)
