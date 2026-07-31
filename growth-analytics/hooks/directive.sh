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
  --produces "funnel diagnosis, experiment trust verdict (SRM/pre-registration check)" \
  --write-scope "" \
  --hand-off "캠페인 메시지 변경이 필요하면 → marketing" \
  --record-path "docs/issue-<n>/reports/growth-analytics.md"
