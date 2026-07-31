# Current-state survey: growth-analytics enforcement (issue-7, phase 1)

Subject: issue-7. Phase-1 rigor-floor survey — what this rulebook already
has, what implementation-rulebook and pricing-rulebook have that this one
doesn't, and where the write surfaces a methodology gate would sit. This
version supersedes an earlier single-gate-framed pass in favor of the
plugin-set framing the approver's issue comment requires (see
`../../proposals/growth-analytics.md`); the underlying inventory below is
unchanged, only the design conclusion drawn from it differs.

## What exists today

- `growth-analytics/hooks/directive.sh` — a `core_role_directive` stub.
  Its `--produces` line already spells out two named artifacts,
  `funnel-diagnosis` and `experiment-trust-verdict`, each with a 5-item
  required-component list inline (issue-1 phase 2, commit `4e50c6f`).
  This is deeper than a one-line PRODUCES summary already — but it is
  still one long string on one role-wide directive, not three separable
  methodology units each with its own directive/gate/agent/tests, the
  way `core`'s `freelunch`/`scout` each own one capability as an
  independent plugin.
- `growth-analytics/hooks/output-components-gate.sh` — a role-local
  `PreToolUse` gate on `docs/issue-<n>/reports/growth-analytics.md`
  writes. If the record declares a `funnel diagnosis` or `experiment
  trust verdict` section, it keyword-checks for all 5 required
  components of that artifact and denies (exit 2) if any are missing.
  Presence-only, single file, single write surface (record only). It
  bundles both methodologies' checks into one script.
- `growth-analytics/hooks/proposal-preregistration-gate.sh` — a
  role-local `PreToolUse` gate on `docs/issue-<n>/proposals/*.md` writes.
  Keyword-gated (fires only if the proposal text contains an experiment/
  A-B term plus a run/trust/recommend term), then keyword-checks for the
  5 pre-registration items. Also presence-only, and this is a third,
  distinct methodology (pre-registration-first) already living in its
  own file — closest existing precedent in this repo for "one
  methodology, one script."
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
- This repo's single-plugin marketplace (`.claude-plugin/marketplace.json`)
  registers exactly one plugin, `growth-analytics`, sourced from
  `./growth-analytics`. `core`'s marketplace (read for comparison, not
  copied) registers `core`, `terse`, `freelunch`, `scout`, `warrant` as
  five independent, single-purpose plugins in one repo — the structural
  precedent this issue's approver comment asks growth-analytics to
  follow for its own adopted methodologies.

## What's missing relative to the issue's ask (as corrected by the approver)

1. **Plugin-set structure.** The three adopted methodologies (pre-
   registration-first; funnel stage/segment localization; Kohavi
   experiment-trust gate) currently live as sections of one directive
   string plus two gate scripts bundled by write-surface rather than by
   methodology. There is no independent, self-contained, marketplace-
   registered plugin per methodology.
2. **Directive depth per methodology.** The existing `--produces` string
   names required components but does not, per adopted methodology,
   separate phase-1 obligations from phase-2 obligations, state judgment
   criteria (how to tell a component is satisfied vs. merely mentioned),
   or state prohibitions (what counts as a violation even with keywords
   present, e.g. an SRM check that reports a p-value with no test
   statistic, or a Twyman's-law flag reused as decoration without an
   actual anomalous-win trigger).
3. **Methodology gate design, `pricing-rulebook`-pattern.** Both existing
   gates already resemble the pattern closely (JSON payload parsing,
   Write/Edit/MultiEdit content reconstruction) but differ from
   `pricing/hooks/methodology-gate.sh` in: exiting 0 on an empty payload
   (silently permissive) instead of failing closed; trusting a
   same-process cwd instead of resolving `CLAUDE_PROJECT_DIR` with a
   `git rev-parse` fallback and validating plausibility; and having no
   outer `trap`-based fail-closed wrapper around any internal logic (a
   crash today exits non-zero-non-two, which neither existing gate
   guards against).
4. **Ordering / state tracking.** The Kohavi trust-gate order (SRM → A/A
   validity → guardrails → effect-size/CI → Twyman check) is an implicit
   ordering constraint never enforced — no mechanism tracks "has SRM
   been checked yet this session" the way `implementation-rulebook`'s
   `coding/hooks/state.sh` + `hunt-state.sh` track hunt-cycle state.
5. **Tests.** No `tests/` directory, no gate-test harness anywhere in
   this repo. Compare `implementation-rulebook/tests/run-gate-tests.sh`,
   which spins up a throwaway git repo per case, feeds a synthetic
   `PreToolUse` JSON payload on stdin, and asserts the gate's exit code
   (0=allow, 2=deny) — the *shape* is reusable per methodology-plugin
   without copying the script.
6. **Agents/checklist for repeated procedure.** Every experiment-trust-
   verdict runs the same 5-step Kohavi sequence; every funnel-diagnosis
   runs the same 5-step localization sequence; every pre-registration
   proposal fixes the same 5 items. No agent or checklist currently
   walks a session through any of the three sequences step by step — the
   gates only check the finished artifact.

## Normative source

`docs/issue-1/proposals/rulebook-maturation.md` sections (a)/(b)/(c),
approved by issue-comment `APPROVE issue-1/growth-analytics` and reflected
into the plugin by `docs/issue-1/reports/growth-analytics.md` (issue-1
phase 2, commit `4e50c6f`, merged as PR #6). This document is the
methodology of record — it names three adopted methodologies:
pre-registration-first (phase-1 proposal norm, section (a)),
stage/segment localization for funnel diagnosis (phase-2 norm, section
(b)), and the Kohavi trust-gate for experiment-trust verdicts (phase-2
norm, section (b)). This issue's directive deepening, gate design, and
plugin-set proposal must operationalize these three further — nothing
here proposes a new methodology.

## Write surfaces in scope

- `docs/issue-<n>/proposals/*.md` (phase-1 proposals — pre-registration
  methodology's write surface).
- `docs/issue-<n>/reports/growth-analytics.md` (phase-2 record —
  funnel-diagnosis and experiment-trust-verdict methodologies' shared
  write surface, disambiguated by declared section).

No other write surface exists for this role today (`write_scope: []` in
`directive.sh`/`plugin.json` — unchanged by this issue, per its own
constraint).

## Canon-scripts rule (reference, do not copy)

`docs/handbooks/canon-scripts.md` (core canon, read at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/docs/handbooks/canon-scripts.md`;
not present in this repo's own tree since core is not checked out here):
"Canon scripts are referenced, never copied. Any script that lives under
`core/hooks/` or `core/hooks/tests/` is invoked by a rulebook through a
path resolved against the core plugin's own install root. A rulebook's
own tree never contains a second copy of a core canon file." Every new
hook this proposal designs stays role-local — growth-analytics has no
core script to invoke for methodology gating. `pricing/hooks/
methodology-gate.sh` is itself role-local to `pricing`, not a core
canon script, so it is referenced here only as a *pattern* to imitate in
shape (per the same clause's spirit — read in full, never copied; see
`Sources` in `scout-brief.md`).
