---
proposal: docs/issue-17/proposals/spec-alignment.md
---

# Hunt record — spec-alignment

## after-proposal — stance 0: assume the gate just touched/proposed is bypassable — find the bypass

Verdict: FINDING — the planned `is_north_star` presence check ("add a check that the section states an `is_north_star` flag for at least one metric line") is specified without any structural anchor to a metric line or value shape, unlike the sibling `funnel_stage` check in the same step, which the proposal explicitly ties to a stage-pair line or an explicit mapping declaration — so it is designed to inherit this file's existing weak `has_any(...)` substring-presence idiom, which is trivially satisfiable by a bare mention with no real content.
Kind: design-error
Seed: docs/issue-17/proposals/spec-alignment.md, item 3 under "What will be done"; current ga-funnel/hooks/ga-funnel-gate.sh
cap_seconds: 60
tier: default
diff_stat_lines: docs-only proposal, no code diff yet (proposal file ~100 lines)
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:10:00Z

### Reproduce
Demonstrated against the current (pre-change) gate, which already contains the exact idiom (has_any(low, "stage definition", ...), has_segment_axis = has_any(...)) the proposal's is_north_star check is designed to reuse, since the proposal gives it no numeric/structural requirement analogous to the stage-pair_pattern regex used for drop-off numbers.

Steps: write a JSON PreToolUse Write payload targeting a fictitious guarded report path under a temp git repo (path pattern the gate matches on: reports directory ending in growth-analytics.md), with content:

  ## Funnel Diagnosis

  stage definition exists.
  stage 1 -> stage 2: 40% drop-off
  channel breakdown mostly in paid
  bottleneck hypothesis: because paid traffic
  recommendation:
  - fix paid

  is_north_star mentioned here.

Pipe that JSON into ga-funnel/hooks/ga-funnel-gate.sh with CLAUDE_PROJECT_DIR set to the temp repo.

### Observed
rc=0 — the gate accepts this content today. "is_north_star mentioned here." is bare prose: no colon, no true/false value, not attached to any specific metric line, and could be pasted verbatim into every future write to pre-satisfy any check implemented the way the proposal describes (a presence check for "the section states an is_north_star flag ... for at least one metric line" with no stated structural test for "attached to a metric line" or "is a boolean"). The funnel_stage check in the same step is specified with an actual structural anchor ("directly, or via an explicit 'stage N = label' mapping declared earlier in the section"); the is_north_star check is not given an equivalent anchor in the proposal text, so as planned it is on track to repeat the file's already-demonstrated bypassable idiom rather than the stronger pattern the proposal itself uses one line above it.

### Expected
The proposal should specify a structural test for is_north_star analogous to funnel_stage's (e.g., require the flag token to appear on the same line as a metric name/value, or via key: value syntax with true/false, checked with a regex tied to a metric line) — otherwise the implementation is free to (and, given this file's existing idiom, likely will) add nothing stronger than a bare substring check, silently failing to enforce the field's actual intent while reporting success.
