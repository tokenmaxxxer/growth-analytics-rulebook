#!/usr/bin/env bash
# SessionStart fragment: ga-funnel methodology directive (phase 2).
# Appends alongside growth-analytics's own SessionStart fragment.
#
# Kill switch: export GA_FUNNEL_DIRECTIVE_OFF=1
set -uo pipefail

case "${GA_FUNNEL_DIRECTIVE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
[ga-funnel] Stage/segment localization for funnel-diagnosis deliverables.
Write surface: docs/issue-<n>/reports/growth-analytics.md, "funnel
diagnosis" section.

Steps, in order:
  1. Define each funnel stage/event explicitly. Reject implicit stages
     inferred from prose.
  2. Quantify stage-to-stage conversion/drop-off with actual numbers,
     attributable to a specific stage pair — not a single aggregate
     conversion rate for the whole funnel, not qualitative language
     ("many users drop off" does not satisfy this).
  3. Break down by at least one segment axis (channel/cohort/device or
     an explicitly named equivalent) AND state, in a sentence, which
     cell the drop-off concentrates in. A table alone does not satisfy
     this.
  4. State one bottleneck hypothesis as a causal claim tracing to the
     segment evidence — not a restatement of the step-2 observation
     ("stage 3 has the biggest drop" is the observation, not the "why").
  5. Give exactly one prioritized recommendation scoped to the single
     weakest stage.

Prohibited: (a) more than one prioritized recommendation — a hard
violation of this methodology's single-stage scoping, not a style
preference; (b) a bottleneck hypothesis stated as "probably X" with no
reference to the segment breakdown that motivated it.

Enforced mechanically by ga-funnel-gate.sh on Write|Edit|MultiEdit to the
record file, firing only when a funnel-diagnosis section is declared.
Kill switch: GA_FUNNEL_GATE_OFF=1. Repeated procedure: walk it with
agents/funnel-localizer.md.
EOF
