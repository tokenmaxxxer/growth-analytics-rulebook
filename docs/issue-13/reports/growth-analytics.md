# Record — issue-13 gate A+ final closure (phase 2)

## What was done

Implemented the approved phase-1 proposal (`docs/issue-13/proposals/gate-a-plus-final.md`)
in full:

1. **gate-lib reference-adoption.** All three gates —
   `ga-prereg/hooks/ga-prereg-gate.sh`, `ga-funnel/hooks/ga-funnel-gate.sh`,
   `ga-trust/hooks/ga-trust-gate.sh` — now source
   `tokenmaxxxer-core`'s `core/hooks/lib/gate-lib.sh` /
   `core/hooks/lib/gate-lib.py` (via the `||`-guarded
   `. "${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"`
   line) instead of hand-rolling the fail-closed trap, kill-switch,
   path-containment, and Write/Edit/MultiEdit reconstruction logic each
   independently carried before. `gate_normalize_path` calls are wrapped
   with `os.path.realpath` on both the root and the resolved candidate
   path (double-realpath), preserving the issue-10 symlink-containment
   fix that `gate_normalize_path` itself does not provide. No local
   gate-lib copy was introduced — the library is referenced, not
   vendored, per the issue's explicit instruction.
2. **hooks.json matcher / code coverage.** Each gate's `hooks.json`
   matcher is now `"Write|Edit|MultiEdit|Bash"`. The Python payload
   gates its `Write`/`Edit`/`MultiEdit` reconstruct-and-check path on
   `tool_name in ("Write","Edit","MultiEdit")` exactly as before (so
   `gate_reconstruct_write`'s `NotebookEdit` handling stays unreachable —
   no matcher/code drift introduced by the migration), and adds a new
   `Bash`-tool branch that runs `gate_lib.gate_bash_write_targets` against
   the command string and denies a shell-redirect write into the gate's
   own guarded path. This closes the live bypass the survey found
   (`echo ... > docs/issue-<n>/proposals/x.md` previously reached none of
   the three gates).
3. **Test coverage.** Each `run-gate-tests.sh` gained a `missing-core`
   group (asserts exit 2 when `CLAUDE_PLUGIN_ROOT_CORE`/`../core` is
   unresolvable — the exact issue-75 regression) and a
   `bash-write-coverage` group (asserts the new Bash-redirect bypass
   check denies), plus a trailing assertion that both mandatory groups
   actually ran. All three suites pass clean: `ga-prereg: 14 passed, 0
   failed`; `ga-funnel: 15 passed, 0 failed`; `ga-trust: 21 passed, 0
   failed`.
4. **compliance-check.sh, record clean.** Ran core's
   `core/hooks/tests/compliance-check.sh` against all three `hooks/`
   directories post-migration:
   - `compliance-check: ok — ga-prereg/hooks/ga-prereg-gate.sh`
   - `compliance-check: ok — ga-funnel/hooks/ga-funnel-gate.sh`
   - `compliance-check: ok — ga-trust/hooks/ga-trust-gate.sh`
   No violations (no unguarded `gate-lib.sh` source, no hand-rolled
   kill-switch reading a `*_OFF` var without `gate_kill_switch_active`,
   no hand-rolled `.replace(...)` reconstruction bypassing
   `gate_reconstruct_write`).
5. **README / manifest ghost-name sweep, re-run post-migration.**
   Re-checked `README.md`'s Layout list, `.claude-plugin/marketplace.json`,
   and all four `.claude-plugin/plugin.json` files against the actual
   tree after the gate-lib edits landed: every listed path still exists,
   `marketplace.json` lists exactly the four real plugins, and every
   `plugin.json` `name` matches its directory and the `growth-analytics`
   role name. No stale/legacy role name or ghost file found — confirms
   the survey's finding-4 (none found) held through the migration.
6. **Handbook updated.** `docs/handbooks/growth-analytics-plugins.md`
   gained a "gate-lib reference-adoption (issue-13 phase 2)" section
   describing the new source shape and the Bash-coverage addition, and
   the test-running section now also documents the two new mandatory
   groups and the `compliance-check.sh` invocation.

## Why

Issue #13 required the third and final defect from the growth-analytics
2026-08-01 re-audit — "gate-lib 미채택(인라인 3중 복제)" — to be closed by
reference-adopting core's now-landed `gate-lib.sh`/`gate-lib.py` canon
(`tokenmaxxxer-core` issue #75 / PR #77), rather than continuing to
independently hand-roll the same trap/kill-switch/path-normalize/
reconstruct logic three times in this repo. `on-the-record` #182's
`CLAUDE_PLUGIN_ROOT_CORE` injection removed the last blocker (a
role session previously had no reliable way to resolve core's path).
Bundled in per the approved proposal: the hooks.json matcher/code parity
requirement (issue text item 2) surfaced a real, currently-live Bash-write
bypass that core's own gates already closed with the identical
`gate_bash_write_targets` pattern, so it was closed here too rather than
deferred.

## Upstream basis

- Issue: #13 (this repo).
- Approved proposal: `docs/issue-13/proposals/gate-a-plus-final.md`,
  approved via issue comment `APPROVE issue-13/growth-analytics` (account
  `JiwonJung94`, listed in `docs/specs/approvers.md`).
- Current-state survey:
  `docs/issue-13/reports/growth-analytics/current-state-survey.md`.
- Upstream canon: `tokenmaxxxer/tokenmaxxxer-core` issue #75 / PR #77
  (`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
  `docs/handbooks/gate-house-standard.md`) and
  `tokenmaxxxer/on-the-record` #182.

loop_state: landed

## Open findings

None outstanding. The one item the proposal flagged as an approver
judgment call — adding `Bash` coverage as new surface slightly beyond the
issue's literal matcher/code-parity wording — was included per the
proposal's own recommendation and is reflected in the approved scope
(the approval was unconditional, no scope carve-out was requested back).
