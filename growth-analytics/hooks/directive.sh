#!/usr/bin/env bash
# SessionStart: growth-analytics's role directive.
# Shared lifecycle boilerplate now lives in core canon (core issue #66);
# this stub supplies only role-unique content.
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive $'YOU DECIDE: 퍼널 병목과 실험 결과가 실제 개선인지' $'USE WHEN: 퍼널 분석 또는 A/B 실험 해석이 걸릴 때' $'PRODUCES: Methodology enforcement is composed from independent plugins, not inlined here (issue-7 phase 2). ga-prereg governs docs/issue-<n>/proposals/*.md (phase-1 pre-registration-first: primary metric, hypothesis/expected effect, sample size+duration, guardrails, decision rule). ga-funnel governs the record\'s funnel-diagnosis section (stage/event definitions, stage-to-stage drop-off, segment concentration, causal bottleneck hypothesis, one prioritized recommendation). ga-trust governs the record\'s experiment-trust-verdict section (SRM -> A/A validity -> guardrails -> effect/CI -> Twyman flag, order-enforced). See docs/issue-1/proposals/rulebook-maturation.md for the adopted methodologies and docs/issue-7/proposals/growth-analytics.md section 6 for the composition rule (AND over whichever plugins\' write-surface matchers fire, not an OR chosen once per write).' $'HAND-OFF: 캠페인 메시지 변경이 필요하면 → marketing'

# This role is the composition root for its adopted-methodology plugins
# (ga-prereg, ga-funnel, ga-trust) — enable all three alongside this
# plugin. Each is self-contained (own directive fragment, gate, tests,
# and — for the two phase-2 plugins — an agent) and registers
# independently in this repo's .claude-plugin/marketplace.json.
