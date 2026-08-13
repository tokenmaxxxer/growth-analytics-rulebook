#!/usr/bin/env bash
# SessionStart fragment: ga-prereg methodology directive (phase 1 only).
# Appends alongside growth-analytics's own SessionStart fragment (multi-
# fragment composition, same pattern core's terse/freelunch/scout use).
#
# Kill switch: export GA_PREREG_DIRECTIVE_OFF=1
set -uo pipefail

case "${GA_PREREG_DIRECTIVE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
[ga-prereg] Pre-registration-first (phase-1 proposals recommending an
experiment). Write surface: docs/issue-<n>/proposals/*.md.

Steps, in order — each must be a literal, locatable line with a
label-like cue and a substantive value (a heading alone does not count):
  1. Name the single primary metric. Reject "several KPIs" or an
     unnamed composite.
  2. State the hypothesis plus expected effect direction AND rough
     magnitude. Reject "should improve X" with no direction/magnitude.
  3. State sample size AND duration together, with the power-analysis
     basis named (even informally). Either alone does not satisfy this.
     If a pre-experiment baseline value of the primary metric is
     available per unit (e.g. last-30d value before assignment), name
     it and note whether the power basis accounts for the variance
     reduction it buys — a baseline-adjusted analysis can hit the same
     sensitivity at a smaller sample or shorter duration than a raw
     between-arm comparison, so the sample-size line should say
     explicitly whether that adjustment was assumed.
  4. Name guardrail metric(s) distinct from the primary metric, each
     with a stated breach bound — not just a name. Reject reusing the
     primary metric as its own guardrail.
  5. State the decision rule as a threshold on the primary metric,
     committed before data. Reject "we'll evaluate holistically."

Prohibited: (a) skipping pre-registration for "just a quick test" — no
size exemption exists; (b) a decision rule stated as statistical
significance alone with no practical-significance threshold; (c) a
guardrail named with no breach bound stated.

Enforced mechanically by ga-prereg-gate.sh on Write|Edit|MultiEdit to
docs/issue-<n>/proposals/*.md, gated on experiment keywords being
present in the text. Kill switch: GA_PREREG_GATE_OFF=1.
EOF
