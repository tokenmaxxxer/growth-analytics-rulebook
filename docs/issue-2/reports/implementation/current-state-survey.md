# issue-2 current-state survey (implementation, phase 1)

Subject: issue-2

## Scout skip record

Skipped. Reason: the issue body enumerates the exact 5 work items and the
reference target (core issue #63/#66 canon, `core_role_directive`,
`core/hooks/tests/stub-check.sh`) verbatim — this is a mechanical
copy-removal-and-reference-swap on an internal tooling repo, not a
product-shaped or field-comparable deliverable, so no design decision is
open for external scouting to inform.

## Inventory of role-copy surfaces (as they exist on this branch today)

| File | Role-generic part (candidate for removal) | Role-specific part (must survive) |
|---|---|---|
| `growth-analytics/agents/warrant-hunter.md` | Whole file is a copy of implementation-rulebook's warrant-hunter shape (mandate framing, "one stance per run" contract, "reads only" scope framing) | Decision boundary text (퍼널 병목과 실험 결과가 실제 개선인지), hand-off arrow (→ marketing), stance set (currently unenumerated — still a skeleton in this file) |
| `growth-analytics/hooks/trailer-gate.sh` | Entire script — comment at line 7 says explicitly "role name substituted only (this file's logic is role-agnostic)" | `GROWTH_ANALYTICS_CYCLE_OFF` kill-switch var name and the `growth-analytics:` message prefix — both cosmetic, subsumed by core's `CLAUDE_ROLE`-driven gate |
| `growth-analytics/hooks/record-fields-gate.sh` | Generic PreToolUse gate mechanics (payload parsing, target-path match, missing-field denial) | `REQUIRED_FIELDS = ["funnel-diagnosis", "experiment-trust-verdict"]`, record path suffix `reports/growth-analytics.md`. No loop-state/terminal-state list currently exists in this gate (record-fields-gate.sh has no notion of terminal states as written) — so item 4 (`RECORD_FIELDS_TERMINAL_STATES`) is a preserve-if-needed check, not a preserve-because-found one for this role. |
| `growth-analytics/hooks/handbook-trigger-gate.sh` | Entire script is a placeholder that always exits 0 (line 19: "placeholder verdict — TODO before this repo is treated as load-bearing"); no role-specific logic exists yet | `write_scope: []` is the only role fact that would ever matter once core's heuristic goes live (empty write_scope ⇒ no operational surface ⇒ core's real check should also no-op for this role) |
| `growth-analytics/hooks/hooks.json` | Registers all three gates + directive.sh as this role's own hook wiring | The `SessionStart → directive.sh` entry stays (directive becomes a stub, not removed); the three `PreToolUse` gate registrations are the ones core's own registration (core issue #66) is meant to replace |
| `growth-analytics/hooks/directive.sh` | Boilerplate: trap/kill-switch/CLAUDE_ROLE guard scaffold, heredoc framing | YOU DECIDE / USE_WHEN / PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD body text — all role content, must be preserved verbatim inside the stub |

## What is NOT present locally

No `core/` tree exists in this repo (git-plugin-tree only holds
`growth-analytics/`). Core canon (the `warrant/` plugin, `core/hooks/`
gates, `core/hooks/lib/role-directive.sh`, `core/hooks/tests/stub-check.sh`)
is an external dependency landed in the core repo per core issues #63/#66,
referenced here only by name in the issue body — this survey cannot read
its actual current interface (function signature of `core_role_directive`,
exact plugin path core exposes for `warrant/`, or `stub-check.sh`'s pass
condition) from inside this repo. The proposal in
`docs/issue-2/proposals/core-reference-transition.md` therefore states the
integration shape as a to-be-confirmed reference and flags exactly which
facts phase 2 must pull from core before landing.

## Order constraint noted

Per the issue body, this transition must land before this repo's own
"rulebook maturation" issue's phase 2. No such issue is open or referenced
by number in this repo currently — noted for phase 2 sequencing, no action
needed in phase 1.
