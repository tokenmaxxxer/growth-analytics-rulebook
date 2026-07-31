#!/usr/bin/env bash
# SessionStart fragment: ga-trust methodology directive (phase 2).
# Appends alongside growth-analytics's own SessionStart fragment.
#
# Kill switch: export GA_TRUST_DIRECTIVE_OFF=1
set -uo pipefail

case "${GA_TRUST_DIRECTIVE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
[ga-trust] Kohavi trust-gate for experiment-trust-verdict deliverables.
Write surface: docs/issue-<n>/reports/growth-analytics.md, "experiment
trust verdict" section. Steps are ORDER-ENFORCED by session state, not
just checked for presence.

Steps, in this order:
  1. SRM check — chi-square statistic AND p-value, expected-vs-observed
     split. A detected SRM is a hard stop: nothing downstream may be
     reported as a verdict until SRM is resolved or the experiment is
     invalidated.
  2. Platform A/A validation status — one of validated/failed/
     unvalidated, literally, not paraphrased, with observed
     false-positive rate if known.
  3. Guardrail metric checks — delta and bound per guardrail, reported
     even when the primary metric wins.
  4. Effect size AND confidence interval (two bounds, not a point
     estimate) against the pre-registered practical-significance bar.
     A bare p-value never satisfies this step.
  5. Twyman's-law flag — any result whose effect size exceeds 2x the
     ga-prereg-stated expected effect is marked "unconfirmed, pending
     independent check," never reported as a plain result.

Prohibited: (a) reporting effect size/CI (step 4) before SRM (step 1)
has cleared — mechanically enforced by state tracking, not just style;
(b) treating "unvalidated" A/A status as equivalent to "validated" —
unvalidated caps confidence, it is never skipped; (c) omitting the
Twyman flag when the reported effect exceeds 2x the linked ga-prereg
expected effect.

Enforced mechanically by ga-trust-gate.sh, stateful across writes to the
record file at .claude/state/growth-analytics/ga-trust-<issue-n>.json
(re-derived from content every time, never trusting stale state across
a content regression). Kill switch: GA_TRUST_GATE_OFF=1. Repeated
procedure: walk it with agents/trust-gate-walker.md.
EOF
