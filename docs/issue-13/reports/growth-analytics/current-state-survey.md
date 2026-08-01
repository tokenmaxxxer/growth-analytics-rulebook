# Current-state survey — issue-13 (gate A+ final closure)

## Scope

Re-audited the four plugins in this repo (`growth-analytics`, `ga-prereg`,
`ga-funnel`, `ga-trust`) against the two now-landed prerequisites:

- core issue-72/75 (`docs/handbooks/gate-house-standard.md` in
  `tokenmaxxxer/tokenmaxxxer-core`, merged via PR #77): the gate-lib
  standard, its mandatory `||`-guarded source form, `compliance-check.sh`,
  and the 7-group `run-gate-lib-tests.sh` harness.
- on-the-record #182 (closed): `spawn.py` now injects
  `CLAUDE_PLUGIN_ROOT_CORE` into role sessions, so referencing core's
  gate-lib from this repo's gates is safe in production (no longer a
  relative-path-into-nowhere problem).

## Finding 1 — gate-lib not adopted (confirmed, matches issue text)

None of `ga-prereg-gate.sh`, `ga-funnel-gate.sh`, `ga-trust-gate.sh` source
`gate-lib.sh`/`gate-lib.py`. Each hand-rolls, independently:

- its own `trap __fc EXIT` fail-closed wrapper (near-identical across all
  three, differs only in the gate-name string)
- its own kill-switch `case` statement (identical shape and semantics —
  unrecognized value stays ON, per issue-10 hardening — to
  `gate_kill_switch_active` in core's gate-lib.sh)
- its own `contained(root, abspath)` / `os.path.commonpath` path-containment
  check plus a separate `os.path.realpath` symlink-resolution step (issue-10
  hardening), duplicated near-verbatim in all three Python heredocs
- its own Write/Edit/MultiEdit reconstruction block honoring per-edit
  `replace_all` (again near-identical across all three)

`ga-prereg-gate.sh`'s own header comment names the reason: "No shared
gate-lib.sh exists yet in this repo (core issue #72 unlanded) — these fixes
are applied inline, not reference-adopted from a library." That precondition
is now false — issue-72/75 are merged, and the on-the-record #182 env-var
injection removes the last resolution obstacle. This is the "gate-lib
미채택(인라인 3중 복제)" defect the issue names.

**Correctness note for phase 2**: core's `gate_normalize_path` (in
`gate-lib.py`) is explicitly documented as pure string/path algebra with
*no* filesystem/symlink resolution — its own docstring says callers needing
symlink safety must `realpath` their own root before calling it. The three
plugins' issue-10 hardening added `os.path.realpath`-based symlink
resolution specifically to close a containment bypass. Migrating to
`gate_normalize_path` must keep that realpath step around it (call
`os.path.realpath(root)` before passing to `gate_normalize_path`, and
`os.path.realpath` on the resolved absolute path before the containment
comparison) — adopting the library function naively, without preserving
the realpath wrapper, would silently regress the issue-10 symlink fix.

## Finding 2 — hooks.json matcher / code coverage: currently consistent, but a live migration risk

All three `hooks.json` matchers are `"Write|Edit|MultiEdit"`. All three
gate scripts' Python payload branches on `tool in ("Write", "Edit",
"MultiEdit")` only. Matcher and code agree today — no dead/unreachable
branch exists right now, so this is not a currently-live defect.

It becomes one under migration, in two ways the proposal must design for:

1. `gate_reconstruct_write` (core's shared reconstruct function) also
   handles `NotebookEdit`. If a gate's Python payload switches to calling
   `gate_reconstruct_write` wholesale without gating on `tool_name` first,
   it would silently start reconstructing `NotebookEdit` payloads whose
   matcher never fires — dead code, not a bug, but exactly the
   "advertised-but-unreachable" shape issue-13 calls out. These plugins'
   write surface is markdown records/proposals, not notebooks, so the
   correct fix is to keep gating on `tool_name in ("Write","Edit",
   "MultiEdit")` before calling `gate_reconstruct_write`, not to add
   `NotebookEdit` to the matcher.
2. None of the three gates cover `Bash`-redirected writes to their own
   guarded paths (e.g. `echo ... > docs/issue-13/proposals/x.md` bypasses
   all three gates' content checks entirely, since a `Bash` tool call never
   reaches the `Write|Edit|MultiEdit`-matched hook at all). Core's own
   `record-fields-gate.sh` and `approval-gate.sh`/`board-gate.sh` already
   closed the equivalent gap using `gate_bash_write_targets` + a `Bash`
   matcher entry. This repo's three gates never adopted that pattern —
   this is a real, currently-live bypass, not a migration side-effect.

## Finding 3 — missing-core test case: absent (confirmed)

None of the three `run-gate-tests.sh` harnesses exercise a
`CLAUDE_PLUGIN_ROOT_CORE`-pointed-nowhere case. Core's own 7-group
`run-gate-lib-tests.sh` makes that case mandatory since issue-75. Currently
moot (nothing sources core yet), but becomes mandatory the moment
migration adds the guarded source line.

## Finding 4 — README / manifest ghost files or stale role names: not found

Checked `README.md`, `.claude-plugin/marketplace.json`, and all four
`.claude-plugin/plugin.json` files against the actual file tree:

- Every path `README.md`'s "Layout" section names
  (`growth-analytics/.claude-plugin/plugin.json`,
  `growth-analytics/hooks/hooks.json`, `growth-analytics/hooks/directive.sh`,
  `growth-analytics/agents/warrant-hunter.md`,
  `ga-prereg/hooks/ga-prereg-gate.sh`, `ga-funnel/hooks/ga-funnel-gate.sh`,
  `ga-trust/hooks/ga-trust-gate.sh`,
  `docs/handbooks/growth-analytics-plugins.md`, `docs/specs/approvers.md`)
  exists on disk.
- `marketplace.json` lists exactly the four plugins that exist
  (`growth-analytics`, `ga-prereg`, `ga-funnel`, `ga-trust`), each
  `source` path resolving to a real directory.
- All four `plugin.json` `name` fields match their directory name and the
  role name `growth-analytics` used throughout (directive.sh `--role`,
  hand-off text, record path). No alternate/legacy role name found anywhere
  in this repo's tracked files.

This repo does not currently carry the "옛 역할명/유령 파일" defect the
issue names as a blanket requirement across the 43-rulebook batch. Recorded
explicitly so phase 2 does not spend effort hunting a defect that isn't
present here — but phase 2 must re-run this same cross-check *after* the
gate-lib migration edits land, since renaming/removing any gate-internal
file during migration is exactly the kind of change that could introduce a
stale README/manifest reference where none existed before.

## Scout skip record

Skipped. This deliverable is a mechanical reference-adoption of an
already-landed, fully-specified core canon (core issue #75's merged
`gate-lib.sh`/`gate-lib.py` plus `docs/handbooks/gate-house-standard.md`'s
migration checklist) into this repo's three existing gates — a pure
bugfix/compliance closure with no open product-facing design decision to
scout external exemplars for.
