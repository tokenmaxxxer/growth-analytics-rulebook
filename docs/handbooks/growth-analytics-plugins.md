# Handbook: growth-analytics methodology plugins (ga-prereg / ga-funnel / ga-trust)

Operational reference for the three methodology-enforcement plugins added
in issue-7 phase 2 (`docs/issue-7/reports/growth-analytics.md`).

## gate-lib reference-adoption (issue-13 phase 2)

All three gates (`ga-prereg-gate.sh`, `ga-funnel-gate.sh`,
`ga-trust-gate.sh`) now source core's `core/hooks/lib/gate-lib.sh` /
`core/hooks/lib/gate-lib.py` (per
`tokenmaxxxer-core`'s `docs/handbooks/gate-house-standard.md`) instead of
each hand-rolling its own fail-closed trap, kill-switch, path-containment,
and Write/Edit/MultiEdit-reconstruction logic. The source line is
`||`-guarded (`. "${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh" || { exit 2; }`)
so an unreachable core fails the gate closed rather than silently
defining no `gate_*` functions. Domain-specific checks (pre-registration
fields, funnel-diagnosis section content, the Kohavi trust-gate state
machine) are unchanged — only the shared plumbing moved to the library.
No local copy of gate-lib exists in this repo; it is referenced, never
vendored.

Each gate's `hooks.json` matcher also now includes `Bash`
(`"Write|Edit|MultiEdit|Bash"`), and the gate's Python payload calls
`gate_lib.gate_bash_write_targets` against a `Bash` tool call's command
string to deny a shell-redirect write into the gate's own guarded path
(e.g. `echo x > docs/issue-9/proposals/x.md`) — closing a bypass that
existed before this migration, since a `Bash` tool call never reached the
`Write|Edit|MultiEdit`-only matcher. This is coverage in addition to the
existing Write/Edit/MultiEdit content checks, not a replacement for them;
`NotebookEdit` is deliberately still not in any matcher or code path,
since none of these gates guard notebooks.

## Running the gate tests

Each plugin owns its own test harness; run them individually:

```
bash ga-prereg/hooks/tests/run-gate-tests.sh
bash ga-funnel/hooks/tests/run-gate-tests.sh
bash ga-trust/hooks/tests/run-gate-tests.sh
```

Each script exits 0 only if every case in it passes; it prints a
`PASS`/`FAIL` line per case plus a final tally. Run all three before
landing any change to a gate script, a plugin's directive text, or an
agent file. Since issue-13 phase 2 each harness also carries a mandatory
`missing-core` group (denies when `CLAUDE_PLUGIN_ROOT_CORE`/`../core` is
unresolvable) and a `bash-write-coverage` group (denies a `Bash`-redirect
write to the gate's own guarded path); a harness that silently drops
either group fails itself via a trailing assertion.

Since issue-20 phase 2, each `run-gate-tests.sh` resolves core *before*
any test case runs, per the on-the-record test-env-resolution convention
(`docs/specs/test-env-resolution.md`, issue #551): it checks
`$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh` first, then the sibling
`../../../core/hooks/lib/gate-lib.sh` relative to the test script; if
neither resolves to a non-empty file, it prints
`SKIP: core plugin unreachable — unverifiable outside spawn env` to
stderr and exits `75` before running any test case, instead of
misreporting every case as FAIL. This is a runner-level upfront check,
distinct from each gate script's own per-invocation fail-closed sourcing
guard (`missing-core` test group above), which is unchanged. When core
resolves, `CLAUDE_PLUGIN_ROOT_CORE` is unconditionally exported to the
resolved path so no stale pre-set value survives into the test cases.

Also verify gate-lib compliance against core's detector:

```
"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/compliance-check.sh" ga-prereg/hooks
"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/compliance-check.sh" ga-funnel/hooks
"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/compliance-check.sh" ga-trust/hooks
```

## Kill switches (fail-open escape hatches, per plugin)

- `GA_PREREG_GATE_OFF=1` — disables `ga-prereg-gate.sh`.
- `GA_FUNNEL_GATE_OFF=1` — disables `ga-funnel-gate.sh`.
- `GA_TRUST_GATE_OFF=1` — disables `ga-trust-gate.sh`.
- `GA_PREREG_DIRECTIVE_OFF=1` / `GA_FUNNEL_DIRECTIVE_OFF=1` /
  `GA_TRUST_DIRECTIVE_OFF=1` — suppress the corresponding `directive.sh`
  `SessionStart` fragment.

Only a recognized on-value (`1`/`true`/`yes`/`on`) disables a gate;
unset/`0`/`false`/`no`/`off` leave it enabled, and — since issue-10 phase
2 — so does any other unrecognized value. There is no fail-open default:
a typo in the kill-switch value keeps the gate active.

## ga-trust Twyman cross-check requires a named proposal

Since issue-10 phase 2, an "experiment trust verdict" section that
reports an effect size must also name the specific proposal file it is
validating against, via a labeled line:

```
Proposal: docs/issue-<n>/proposals/<name>.md
```

`ga-trust-gate.sh` reads only that file's `expected effect` for the
Twyman ratio check (no more picking an arbitrary file from
`docs/issue-<n>/proposals/` in directory-listing order), and denies if
the reported and expected effect sizes are stated in different units
(`pp` vs `%`) rather than silently comparing bare numbers.

## Section scoping

`ga-trust-gate.sh` and `ga-funnel-gate.sh` now require their trigger
phrase ("experiment trust verdict" / "funnel diagnosis") to appear as a
markdown heading; every per-step/per-component check runs only inside
that heading's section (to the next same-or-higher-level heading or
EOF), not the whole document. `ga-prereg-gate.sh` does not require a
heading — it has no established heading convention — and keeps its
whole-document keyword pre-gate and labeled-line scan.

## ga-trust session state

`ga-trust-gate.sh` persists which of its 5 Kohavi steps have been
validated per issue at
`<project-root>/.claude/state/growth-analytics/ga-trust-<issue-n>.json`.
This file is re-derived from the record's actual content on every write —
it is disposable: deleting it only means the gate re-verifies from
scratch on the next write to that issue's record, it never causes a false
allow. Do not hand-edit it.

## Record field vocabulary (issue-17)

Layered onto the existing plugins from `growth-analytics.spec.json`'s
required record fields and `loop_state` vocabulary — extending, not
replacing, the funnel-diagnosis structure above.

- `funnel_stage` — one of the five canonical AARRR labels
  (`acquisition`/`activation`/`retention`/`referral`/`revenue`). Every
  stage-pair line in a record's funnel-diagnosis section must name one of
  these five labels directly, or via an explicit "stage N = `<label>`"
  mapping declared earlier in the section. Enforced by
  `ga-funnel-gate.sh`.
- `metric_value` — the computed figure a stage-pair or north-star-metric
  line resolves to. Must be a real number sourced from actual analytics
  data — never a fabricated figure. This rulebook names the field and
  requires its presence/shape in the funnel-diagnosis section;
  `metric_value`'s no-fabrication rule itself is enforced by
  `on-the-record/hooks/role-spec-reference-guard.sh`, outside this repo.
- `is_north_star` — a `true`/`false` flag anchored to a specific named
  metric line (e.g. `is_north_star: true|false`), not a bare mention of
  the phrase. NSM sits above AARRR as a cross-cutting flag on a metric,
  not a separate methodology step, so it is checked inside the same
  funnel-diagnosis section rather than a new plugin. At most one record
  should carry `is_north_star: true` at a time; enforcing that
  uniqueness across records is a stated follow-up (`checked_by: TBD` in
  the spec, per issue-521), not built here.

`loop_state` vocabulary — the exact five-word set from
`growth-analytics.spec.json`, no stale or extra states:

- progress: `measuring`, `reviewing`
- terminal: `landed`
- refusal: `stage-undeclared`
- error: `analytics-data-unreachable`

This is declared here as prose, not via
`docs/specs/record-fields-terminal-states.json`: that override file's
`kind ->` mapping (`core/hooks/record-fields-gate.sh`) accepts only
contract §2's fixed nine record kinds (`coding-record`, `qa-record`,
etc.) as keys — it lets an unmapped role's own record *borrow* one of
those nine terminal-state sets via a self-declared `kind:` frontmatter
field, it does not let a role register a brand-new kind or vocabulary.
`growth-analytics` is not one of the nine and this five-word set is not
a subset of any of them, so the override file cannot carry it; a
`growth-analytics` key in that file is refused at write time
("unrecognized kind"). See `docs/issue-17/reports/implementation.md`'s
Rationale for deviations for the discovery detail.

## Adding a new methodology plugin

Follow the shape of the three existing plugins:
`.claude-plugin/plugin.json`, `hooks/directive.sh` (SessionStart
fragment), `hooks/<name>-gate.sh` (fail-closed PreToolUse gate, per
`docs/issue-7/proposals/growth-analytics.md` section 3.1), `hooks/
hooks.json`, `hooks/tests/run-gate-tests.sh`, and — only if the
methodology is a genuinely repeated multi-step procedure —
`agents/<name>.md`. Register the new plugin in
`.claude-plugin/marketplace.json` and note the composition in
`growth-analytics/hooks/directive.sh`'s `--produces` manifest.
