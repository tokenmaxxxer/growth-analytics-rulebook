# Current-state survey — issue-17

Subject: align `growth-analytics.spec.json` required fields
(`funnel_stage`, `metric_value`, `is_north_star`) and loop_state
vocabulary (`analytics-data-unreachable`, `landed`, `measuring`,
`reviewing`, `stage-undeclared`) onto this rulebook's docs/hooks.

## Where growth-analytics vocabulary currently lives

- `README.md` — role summary (`decides`/`use_when`/`produces`/
  `write_scope`/`hand-off`), Korean-language, no field-level vocabulary.
- `docs/handbooks/growth-analytics-plugins.md` — operational handbook for
  the three enforcement plugins (kill switches, test commands, session
  state, section-scoping rules). No field-level vocabulary either.
- `growth-analytics/hooks/directive.sh` — SessionStart directive; names
  the three plugins and what each governs (pre-reg fields, funnel-diagnosis
  section components, trust-verdict order) but no enum/field list.
- `ga-funnel/hooks/ga-funnel-gate.sh` — the only gate that touches funnel
  structure. It checks free-text "stage 1 -> stage 2: N%" patterns and a
  segment/concentration sentence; it has **no `funnel_stage` enum
  concept** — stage numbers are arbitrary integers a writer picks, not
  validated against `acquisition/activation/retention/referral/revenue`.
- `ga-trust/hooks/ga-trust-gate.sh` — Kohavi-order trust gate (SRM -> A/A
  -> guardrails -> effect/CI -> Twyman). Operates on "experiment trust
  verdict" sections; independent of funnel-diagnosis. No `metric_value`
  or `is_north_star` concept.
- `ga-prereg/hooks/ga-prereg-gate.sh` — pre-registration-first gate on
  phase-1 proposals (metric, hypothesis, sample size, guardrails, decision
  rule). Its "primary metric" field is close in spirit to `metric_value`
  but is a proposal-phase field, not a record-phase one, and is free text
  with no resolution-to-source-data requirement.
- No file in this repo declares a `loop_state` vocabulary specific to the
  growth-analytics role. Existing growth-analytics records (`docs/issue-1`,
  `docs/issue-7`, `docs/issue-10`, `docs/issue-13`) all just write
  `loop_state: landed`, inheriting the generic contract terminal state for
  a landed record. Nothing here has ever exercised a progress state
  (`measuring`/`reviewing`) or a refusal/error state
  (`stage-undeclared`/`analytics-data-unreachable`) — this rulebook has no
  home for those five words at all today.
- `docs/specs/` contains only `approvers.md`. No
  `record-fields-terminal-states.json` override exists in this repo — the
  role currently relies entirely on core's generic per-kind terminal
  states referenced in the interaction-protocol reminder, with no
  growth-analytics-specific row.

## Write set this proposal will project (for phase 2)

- `docs/handbooks/growth-analytics-plugins.md` — add a vocabulary section
  documenting `funnel_stage`, `metric_value`, `is_north_star`, and the
  loop_state set, cross-referenced to which gate/doc enforces each.
- `README.md` — mention the required-field vocabulary and loop_state set
  in the role summary, since acceptance is checked via
  `grep -ri <field> docs/ README.md`.
- `ga-funnel/hooks/ga-funnel-gate.sh` (+ its
  `ga-funnel/hooks/tests/run-gate-tests.sh`) — tighten the stage-pair
  check to require one of the five canonical `funnel_stage` enum labels
  (or an explicit numbered-stage mapping to one), and add an
  `is_north_star`/`metric_value` presence check appropriate to the
  funnel-diagnosis section.
- `growth-analytics/hooks/directive.sh` — mention the required fields and
  loop_state vocabulary in the composed SessionStart directive text so a
  session sees them before writing a record.
- Possibly `docs/specs/record-fields-terminal-states.json` (new file) to
  declare the growth-analytics record kind's terminal-state override
  matching the spec's `progress`/`terminal`/`refusal`/`error` buckets
  exactly (`measuring`/`reviewing` progress, `landed` terminal,
  `stage-undeclared` refusal, `analytics-data-unreachable` error) — this
  is the only way to make the vocabulary *exactly match, no stale or
  extra states* per the issue's acceptance check, since core's generic
  terminal-state list does not carry these role-specific words at all.

This list is provisional — phase 1 output is the proposal document
itself; the write set above is what the proposal will freeze.
