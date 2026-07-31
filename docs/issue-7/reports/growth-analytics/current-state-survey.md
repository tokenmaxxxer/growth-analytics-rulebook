# Current-state survey: growth-analytics enforcement (issue-7, phase 1)

Subject: issue-7. Phase-1 rigor-floor survey — what this rulebook already
has, what implementation-rulebook and pricing-rulebook have that this one
doesn't, and where the write surfaces this issue's gate would sit on
actually are.

## What exists today

- `growth-analytics/hooks/directive.sh` — a `core_role_directive` stub.
  Its `--produces` line already spells out two named artifacts,
  `funnel-diagnosis` and `experiment-trust-verdict`, each with a 5-item
  required-component list inline (issue-1 phase 2, commit `4e50c6f`).
  This is deeper than a "one-line PRODUCES summary" already — but it is
  still one long string, not the step/judgment-criteria/prohibition
  structure a directive needs to be facet-actionable per this issue.
- `growth-analytics/hooks/output-components-gate.sh` — a role-local
  `PreToolUse` gate on `docs/issue-<n>/reports/growth-analytics.md`
  writes. If the record declares a `funnel diagnosis` or `experiment
  trust verdict` section, it keyword-checks for all 5 required
  components of that artifact and denies (exit 2) if any are missing.
  Presence-only, single-file, single-write-surface (record only, not
  proposals).
- `growth-analytics/hooks/proposal-preregistration-gate.sh` — a
  role-local `PreToolUse` gate on `docs/issue-<n>/proposals/*.md` writes.
  Keyword-gated (fires only if the proposal text contains an experiment/
  A-B term plus a run/trust/recommend term), then keyword-checks for the
  5 pre-registration items. Also presence-only.
- `growth-analytics/hooks/hooks.json` — wires both gates as `PreToolUse`
  (matcher `Write|Edit|MultiEdit`), plus the `SessionStart` directive.
- `growth-analytics/agents/warrant-hunter.md` — core canon `warrant/`
  extension stub; stance set still unenumerated (open gap, out of scope
  for this issue per issue-2 precedent).
- No `tests/` directory anywhere in this repo tree. No test harness
  exercises either existing gate; issue-1 phase 2's record says
  verification was manual and not automated (`docs/issue-1/reports/
  growth-analytics.md`, item 5).
- No state-tracking file or ordering enforcement anywhere in this
  plugin. Both existing gates are single-shot presence checks against
  the text of one write; neither remembers anything about a prior write
  in the session.

## What's missing relative to the issue's ask

1. **Directive depth.** The existing `--produces` string names required
   components but does not distinguish phase-1 vs. phase-2 obligations,
   does not state judgment criteria (how to tell a component is
   satisfied vs. merely mentioned), and states no prohibitions
   (what counts as a violation even if keywords are present, e.g. an SRM
   check that reports a p-value with no test statistic).
2. **Methodology gate, `pricing-rulebook`-pattern.** Both existing gates
   already follow closely-related shape (root-resolution, JSON payload
   parsing, Write/Edit/MultiEdit content reconstruction, fail-closed on
   internal error) but `pricing/hooks/methodology-gate.sh` additionally:
   fail-closes on an **empty payload** (this role's gates `exit 0` on
   empty payload — silently permissive, not fail-closed); resolves the
   project root defensively via `CLAUDE_PROJECT_DIR` + a `git rev-parse`
   fallback, rather than trusting a same-process cwd; and wraps its
   Python body in a `try/except` that fails closed on *any* internal
   error (`_fc_e`), not just a JSON parse error. None of this role's
   gates have that outer fail-closed wrapper — a Python traceback today
   would exit non-zero-non-two, which the two existing gates don't
   protect against consistently (`output-components-gate.sh` /
   `proposal-preregistration-gate.sh` only check `set -uo pipefail`, no
   `trap`).
3. **Ordering / state tracking.** The adopted methodology (see below)
   has an implicit ordering constraint this rulebook has never
   enforced: for `experiment-trust-verdict`, the Kohavi trust-gate order
   is SRM → A/A validity → guardrails → effect-size/CI → Twyman check —
   an SRM failure is supposed to be a hard stop before effect size is
   even discussed. No mechanism here tracks "has SRM been checked yet
   this session" the way `implementation-rulebook`'s `coding/hooks/
   state.sh` + `hunt-state.sh` track hunt-cycle state across a session.
4. **Tests.** No `tests/` directory, no gate-test harness. Compare
   `implementation-rulebook/tests/run-gate-tests.sh`, which spins up a
   throwaway git repo per case, feeds a synthetic `PreToolUse` JSON
   payload on stdin, and asserts the gate's exit code (0=allow,
   2=deny) — this pattern is directly reusable by growth-analytics
   without copying the script itself (only the *shape* is portable).
5. **Agents/checklist for repeated procedure.** The methodology this
   role adopted (issue-1) has a genuinely repeated shape (every
   experiment-trust-verdict runs the same 5-step Kohavi sequence; every
   funnel-diagnosis runs the same 5-step localization sequence) but no
   agent or checklist currently walks a session through either sequence
   step by step — the gate only checks the finished artifact, it does
   not guide production of it. `warrant-hunter.md` is the only agent in
   this plugin and it is unrelated (rotating-stance hunt, not
   methodology execution).

## Normative source

`docs/issue-1/proposals/rulebook-maturation.md` sections (a)/(b)/(c),
approved by issue-comment `APPROVE issue-1/growth-analytics` and reflected
into the plugin by `docs/issue-1/reports/growth-analytics.md` (issue-1
phase 2, commit `4e50c6f`, merged as PR #6). This is the methodology of
record this issue's directive deepening and gate design must operationalize
further — nothing here proposes a new methodology, only a stronger
enforcement of the one already adopted.

## Write surfaces in scope for a methodology gate

- `docs/issue-<n>/reports/growth-analytics.md` (phase-2 record — already
  covered by `output-components-gate.sh`, presence-only).
- `docs/issue-<n>/proposals/*.md` (phase-1 proposals — already covered by
  `proposal-preregistration-gate.sh`, presence-only, keyword-gated).

No other write surface exists for this role today (`write_scope: []` in
`directive.sh`/`plugin.json` — unchanged by this issue, per its own
constraint).
