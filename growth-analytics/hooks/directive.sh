#!/usr/bin/env bash
# SessionStart: growth-analytics's role directive.
# Shared lifecycle boilerplate now lives in core canon (core issue #66);
# this stub supplies only role-unique content.
source "${CLAUDE_PLUGIN_ROOT}/../core/hooks/lib/role-directive.sh"

core_role_directive \
  --role growth-analytics \
  --kill-switch-var GROWTH_ANALYTICS_CYCLE_OFF \
  --decides "퍼널 병목과 실험 결과가 실제 개선인지" \
  --use-when "퍼널 분석 또는 A/B 실험 해석이 걸릴 때" \
  --produces "funnel-diagnosis (stage/event definitions + stage-to-stage drop-off quantification + segment breakdown isolating the drop-off + one bottleneck hypothesis + one prioritized single-stage recommendation), experiment-trust-verdict (SRM chi-square result + platform A/A validation status + effect size/CI vs. a pre-registered practical-significance bar + guardrail delta/bound per guardrail + Twyman's-law flag on anomalous wins) — components per issue-1 rulebook-maturation proposal, checked by output-components-gate.sh" \
  --write-scope "" \
  --hand-off "캠페인 메시지 변경이 필요하면 → marketing" \
  --record-path "docs/issue-<n>/reports/growth-analytics.md"

# This role's own future phase-1 proposals recommending an experiment run
# or trust call follow pre-registration-first methodology (primary metric,
# hypothesis/expected effect, sample size + duration, guardrail metrics,
# decision rule) — enforced by proposal-preregistration-gate.sh. See
# docs/issue-1/proposals/rulebook-maturation.md.
