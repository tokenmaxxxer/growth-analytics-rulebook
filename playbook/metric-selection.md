---
axis: metric-selection
rule_count_floor: 2
---

# One-metric-that-matters selection rules

1. **When** a team is choosing what to call the North Star / one metric
   that matters for a given business stage, **pick the single metric
   tied to the stage's current bottleneck, not the metric that is
   easiest to move** — OMTM selection is stage-dependent (the right
   metric for an empathy-stage product differs from a growth-stage
   product) and must be revisited as the stage changes, not fixed once.
   Source: Croll & Yoskovitz, *Lean Analytics* (O'Reilly, 2013), ch. 3,
   "The One Metric That Matters" — cited via
   https://www.oreilly.com/library/view/lean-analytics/9781449335670/
   (fetched 2026-08-13; publisher landing page confirming chapter/thesis).

2. **REMOVAL** — when a record proposes more than one metric as
   `is_north_star=true` for the same review window, **cut all but one**;
   the recomputation rule forces exactly one live North Star because a
   set of "several KPIs" prevents anyone from knowing which number the
   org will actually act on.
   Source: Croll & Yoskovitz, *Lean Analytics* (2013), ch. 3 (OMTM
   uniqueness argument), same citation as above.
