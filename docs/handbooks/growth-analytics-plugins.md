# Handbook: growth-analytics methodology plugins (ga-prereg / ga-funnel / ga-trust)

Operational reference for the three methodology-enforcement plugins added
in issue-7 phase 2 (`docs/issue-7/reports/growth-analytics.md`).

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
agent file.

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
