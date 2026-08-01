# Proposal — gate A+ final closure (issue-13, phase 1)

Status: PROPOSAL — not yet approved. Phase 2 (implementation) waits for a
PR-review Approve or an `APPROVE issue-13/growth-analytics` comment from a
`docs/specs/approvers.md` account, per contract v3 s19.

## Basis

- Current-state survey: `docs/issue-13/reports/growth-analytics/current-state-survey.md`.
- Upstream, already-landed reference: `tokenmaxxxer/tokenmaxxxer-core`
  issue #75 / PR #77 (`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
  `docs/handbooks/gate-house-standard.md`), and `tokenmaxxxer/on-the-record`
  #182 (`CLAUDE_PLUGIN_ROOT_CORE` injection in `spawn.py`).

## 1. Migrate all three gates to reference core's gate-lib (drop the 3x inline duplication)

Apply core's gate-house-standard migration checklist to
`ga-prereg/hooks/ga-prereg-gate.sh`, `ga-funnel/hooks/ga-funnel-gate.sh`,
`ga-trust/hooks/ga-trust-gate.sh` identically:

**Source line** (top of each script, replacing the current bare
`set -uo pipefail` opener). Precedent for the `CLAUDE_PLUGIN_ROOT_CORE`
default: `docs/handbooks/gate-house-standard.md`'s own `compliance-check.sh`
invocation example uses `"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}"`
— a sibling-plugin-directory fallback, not a same-repo relative path (core
lives in a different repo; there is no `../core` inside
`growth-analytics-rulebook` to fall back to via `BASH_SOURCE`). Each gate
adopts the equivalent form:

```sh
. "${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh" \
  || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${<GATE>_OFF:-}" || { trap - EXIT; exit 0; }
```

This replaces, per gate: the hand-rolled `__fc`/`trap __fc EXIT` pair with
`gate_trap_fail_closed`, and the hand-rolled kill-switch `case` statement
with `gate_kill_switch_active` (same "unrecognized value stays ON"
semantics core's function already encodes — no behavior change, just
de-duplication).

**Python payload**, loaded via `$GATE_LIB_PY` (exported by `gate-lib.sh`):

```python
import importlib.util, os
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
```

Replace:
- the hand-rolled JSON-parse-or-deny preamble with
  `gate_lib.gate_parse_json_or_deny(raw, deny)`.
- the hand-rolled `contained()`/path-normalize block with
  `gate_lib.gate_normalize_path(root, path)` — **wrapped**, not called
  naked: `gate_normalize_path` is documented pure string algebra with no
  symlink resolution, but the issue-10 hardening in all three gates added
  `os.path.realpath`-based symlink-safe containment specifically to close
  a bypass. Migration must keep `root = os.path.realpath(root)` (and
  realpath the resolved absolute candidate before the final containment
  check) around the library call, so this defect stays fixed. This is the
  one place a naive "just call the library function" migration would
  silently regress an already-fixed issue-10 bug — called out here so
  phase 2 doesn't reintroduce it.
- the hand-rolled Write/Edit/MultiEdit reconstruction block with
  `gate_lib.gate_reconstruct_write(tool, tool_input, current)`, but only
  after gating on `tool_name in ("Write", "Edit", "MultiEdit")` first (see
  §2 — do not let the library's `NotebookEdit` branch become a dead path
  these gates never route to).

No new shared library is introduced in this repo — the whole point of
issue-13's "gate-lib 미채택 → 참조 이관" instruction is reference-adoption
of the single core source of truth, not a fourth local abstraction.

## 2. hooks.json matcher / code coverage — close the real gap, keep the non-gap non-gap

Two distinct actions, not one:

- **Keep matchers at `Write|Edit|MultiEdit`** for the reconstruct path
  (no `NotebookEdit`): these gates guard markdown records/proposals, never
  notebooks. Keep the Python payload's explicit `tool_name in ("Write",
  "Edit", "MultiEdit")` gate in front of the `gate_reconstruct_write` call
  so migrating to the shared function (which also handles `NotebookEdit`)
  never becomes an advertised-but-unreachable branch — this satisfies
  issue-13's matcher/code parity requirement by *not* widening what's
  advertised, since nothing calls it.
- **Add `Bash` to the matcher, and a `gate_bash_write_targets` check to
  the code**, for all three gates. This closes a real, currently-live
  bypass (survey finding 2): a `Bash` tool call like
  `echo x > docs/issue-13/proposals/foo.md` reaches none of the three
  gates today, because `Bash` was never in any matcher. Core's own
  `record-fields-gate.sh`/`approval-gate.sh`/`board-gate.sh` already
  closed the identical gap using exactly this pattern. Design for each
  gate:
  - `hooks.json` matcher becomes `"Write|Edit|MultiEdit|Bash"`.
  - the sh side calls `gate_bash_write_targets "$command"` (from the
    `Bash` tool_input) and applies the gate's own path pattern to each
    token (e.g. `docs/issue-[0-9]+/proposals/.*\.md` for ga-prereg); a
    match denies with a message directing the agent to use `Write`/`Edit`
    instead of a shell redirect, since a gate cannot content-inspect an
    arbitrary shell pipeline — this mirrors `record-fields-gate.sh`'s
    posture (deny-on-target-match, not attempt-to-parse-content).
  - this is new coverage, not present pre- or post- the inline
    implementation, and goes slightly beyond issue-13's literal text (which
    names matcher/code *parity*, not new surface). Flagging it explicitly
    for the approver: recommended because it closes a real bypass using an
    already-established core pattern, but it is an addition an approver
    may choose to defer to a separate issue instead of bundling into this
    A+ closure.

## 3. missing-core test case + Bash-coverage test case, added to all three harnesses

Each `run-gate-tests.sh` gains two mandatory groups, matching core's own
`run-gate-lib-tests.sh` groups 6-7:

- **missing-core**: run the gate with `CLAUDE_PLUGIN_ROOT_CORE` pointed at
  a nonexistent path and no valid `../core` fallback present; assert deny
  (exit 2), not silent-allow. This is the exact regression core's issue-75
  fix targets, and none of these three plugins have it today because none
  of them source core yet.
- **bash-write-coverage**: a `Bash` command writing to the same
  guarded-path target a `Write` call would hit; assert equivalent deny.

Add a trailing "mandatory groups exercised" assertion to each harness
(core's own pattern) so a future edit that silently drops one of these
cases fails the harness itself, not just a downstream gate.

After migration, run `compliance-check.sh` from core against this repo's
gates directory as a verification step
(`"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/compliance-check.sh" <hooks-dir>`
for each of `ga-prereg/hooks`, `ga-funnel/hooks`, `ga-trust/hooks`) and
record it passing clean in the phase-2 record, per issue-13's requirement
3 ("compliance-check 통과 record 기록").

## 4. README / manifest ghost-name sweep

Survey finding 4: none found currently. Phase 2 re-runs the same
cross-check (README "Layout" list vs. actual tree, `marketplace.json`
plugin list vs. actual plugin directories, `plugin.json` `name` fields vs.
directory names and the `growth-analytics` role name) *after* the
gate-lib migration edits land, specifically because migration touches
every gate file's structure — the check is cheap and the risk window is
real even though the current audit is clean. No file renames are proposed
by §1-§3 above (all edits are in-place to existing files), so this is
expected to stay clean, but it is re-verified rather than assumed.

## Delivery order for phase 2

1. Migrate `ga-prereg-gate.sh` (source guard, kill-switch, path-normalize
   with realpath wrapper, reconstruct-write gated on tool_name).
2. Migrate `ga-funnel-gate.sh`, `ga-trust-gate.sh` identically (ga-trust
   additionally keeps its heading-scoped session-state logic untouched —
   that logic is domain-specific, not part of gate-lib's scope).
3. Add `Bash` matcher + `gate_bash_write_targets` check to all three
   (§2, pending approver sign-off on scope).
4. Extend all three `run-gate-tests.sh` with missing-core + bash-write
   groups and the mandatory-groups-exercised assertion (§3).
5. Run `compliance-check.sh` against all three `hooks/` directories;
   record clean.
6. Re-run the README/manifest ghost-name sweep (§4); record clean.
7. Update `docs/handbooks/growth-analytics-plugins.md` to describe the
   gate-lib-referencing shape (currently documents the plugins as if they
   are freestanding; add a line noting they now source core's gate-lib
   per this migration) — same pattern core's own handbook uses to
   document its migration.

## Rejected alternative

A local `growth-analytics`-repo shared helper (a 4th file duplicated once
instead of three times) was considered and rejected: it does not satisfy
issue-13's explicit instruction to reference-adopt core's canon, and it
would create a second source of truth for exactly the logic core issue-72/
75 exists to centralize.

## Scout skip record

See `docs/issue-13/reports/growth-analytics/current-state-survey.md`'s
"Scout skip record" section — pure mechanical reference-adoption of an
already-landed, fully-specified core canon; no open design decision to
scout exemplars for.
