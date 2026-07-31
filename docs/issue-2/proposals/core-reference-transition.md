# Proposal: transition growth-analytics rulebook onto core canon (issue-2)

Subject: issue-2. Phase 1 proposal only — no execution in this PR.

## Summary

Replace this role's three standalone copies (warrant-hunter agent, three
role-agnostic PreToolUse gates) with references to core canon landed by
core issues #63 and #66, and collapse `directive.sh` into a stub that
sources core's shared `core_role_directive` function and supplies only
this role's own decision content. Role-specific facts are preserved
explicitly, never re-derived from another role's copy.

## Per work-item plan

### 1. Remove `agents/warrant-hunter.md` copy → core canon reference

- Delete `growth-analytics/agents/warrant-hunter.md`'s generic mandate/
  scope boilerplate (shared with implementation-rulebook's copy).
- Keep, moved into a short role file (or plugin.json field, TBC in phase 2
  once core's warrant plugin's own extension point is confirmed):
  - decision boundary: 퍼널 병목과 실험 결과가 실제 개선인지
  - hand-off arrow: 캠페인 메시지 변경이 필요하면 → marketing
  - stance set: currently unenumerated in the existing copy (still a
    skeleton, "enumerate this role's own stance set before shipping") —
    phase 2 must either enumerate it before cutover or confirm core's
    warrant plugin accepts a role that has not yet declared stances.
- Phase 2 precondition: confirm core's `warrant/` plugin's actual
  extension mechanism (how a role supplies its own decision boundary +
  stance set to a shared plugin) — this repo does not have core checked
  out locally, so the exact interface is unread as of this survey.

### 2. Remove trailer-gate.sh / record-fields-gate.sh / handbook-trigger-gate.sh copies + their hook registrations

- Delete all three scripts from `growth-analytics/hooks/`.
- Remove their three `PreToolUse` entries from `growth-analytics/hooks/hooks.json`,
  leaving only the `SessionStart → directive.sh` entry.
- Rationale: core issue #66 registers these role-agnostic gates centrally
  (CLAUDE_ROLE-injected), so a per-role copy is now a duplicate registration,
  not a fallback.
- Preserve the two role facts these gates encoded, so core's centralized
  gates can apply them (see item 4 below):
  - required record fields: `funnel-diagnosis`, `experiment-trust-verdict`
  - record path: `docs/issue-<n>/reports/growth-analytics.md`
  - `write_scope: []` (relevant to handbook-trigger-gate's operational-surface
    heuristic — an empty write_scope should make this role a permanent no-op
    for that gate)

### 3. Replace `directive.sh` with a stub sourcing `core_role_directive`

Proposed shape (illustrative; exact `core_role_directive` call signature
to be confirmed against `core/hooks/lib/role-directive.sh` in phase 2,
since core is not checked out in this repo):

```bash
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
```

All bracketed content above is copied verbatim from the current
`directive.sh` heredoc — no rewording, so the role-unique text an operator
already relies on does not silently drift during the canon swap.

### 4. Preserve real per-role differences via `RECORD_FIELDS_TERMINAL_STATES`

- Surveyed: the current `record-fields-gate.sh` has no terminal/loop-state
  concept at all (confirmed by reading the script — it only checks
  required-field presence in the record file's content, nothing about
  loop_state). This role therefore has **no existing terminal-state
  behavior to migrate**.
- Proposed action: do not set `RECORD_FIELDS_TERMINAL_STATES` unless core's
  centralized gate's default terminal-state set would otherwise change
  this role's observed behavior. Phase 2 must diff core's default set
  against "no explicit terminal states" before deciding whether an
  explicit override is actually needed — setting one preemptively without
  a confirmed behavior delta would be an unrequested addition.

### 5. Confirm `core/hooks/tests/stub-check.sh` passes, record it

- Phase 2 (post-Approve) action: run `core/hooks/tests/stub-check.sh`
  against this role's transitioned files once cut over, and record the
  pass/fail result in `docs/issue-2/reports/implementation.md`'s
  produces fields.
- Not run in phase 1: no code change has landed yet, and core is not
  checked out in this repo tree.

## Open questions for phase 2 (blocking full execution, not blocking this proposal)

1. Exact `core_role_directive` call signature (flag names, required vs.
   optional) — read from `core/hooks/lib/role-directive.sh` once
   available in the build environment.
2. Core's `warrant/` plugin's extension point for a role's decision
   boundary + stance set, and whether an unenumerated stance set blocks
   registration.
3. Core's default `RECORD_FIELDS_TERMINAL_STATES` value, to confirm no
   override is needed for this role (see item 4).

## Explicitly out of scope for this issue

- Enumerating growth-analytics's warrant-hunter stance set (a pre-existing
  skeleton gap, not something issue-2 asks to fill).
- Hardening `handbook-trigger-gate.sh`'s placeholder heuristic (it is being
  deleted, not hardened, per item 2).
- Any change to this repo's separate "rulebook maturation" issue; issue-2
  only needs to land before that issue's phase 2 per the stated order
  constraint.
