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

Any non-empty, non-`0`/`false`/`no`/`off` value disables the gate/
directive; unset or falsy values leave it enabled.

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
