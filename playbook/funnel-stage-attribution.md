---
axis: funnel-stage-attribution
rule_count_floor: 2
---

# Funnel-stage attribution rules

1. **When** a metric is proposed as a `funnel_stage` record and it counts
   raw registrations, installs, or signups with no downstream usage
   check, **treat it as acquisition, not activation**, and require a
   separate activation metric before treating the signup number as
   progress — a registration spike with no "aha moment" measured
   afterward is fool's-gold acquisition volume, not evidence of value
   delivered.
   Source: Amplitude, "The Pirate Metrics Framework (AARRR)" —
   https://amplitude.com/blog/pirate-metrics-framework (stage
   definitions + vanity-metric warning, fetched 2026-08-13).

2. **REMOVAL** — when a dashboard reports one blended "conversion rate"
   spanning acquisition through revenue, **drop the blended figure** and
   report only per-stage-pair rates; a single aggregate number cannot be
   attributed to any one AARRR stage and hides which stage actually
   moved.
   Source: Amplitude, "The Pirate Metrics Framework (AARRR)" —
   https://amplitude.com/blog/pirate-metrics-framework (stage-specific
   metrics section, fetched 2026-08-13).
