# Proposal: growth-analytics mechanical enforcement design (issue-7)

Subject: issue-7. Phase-1 proposal only — this PR lands no plugin code,
no `src/`, no `tests/`, no hook script changes. It designs the
enforcement machine implementation-rulebook has and growth-analytics
does not, so that phase 2 (opened only by a fresh human Approve per
`docs/specs/approvers.md` and contract v3 s19) has a concrete blueprint
to reflect into the plugin.

Normative source: `docs/issue-1/proposals/rulebook-maturation.md`
(a)/(b)/(c), as reflected into the plugin by `docs/issue-1/reports/
growth-analytics.md` (issue-1 phase 2). This proposal adopts no new
methodology — it deepens the directive text and designs mechanical
enforcement for the methodology issue-1 already approved.

Current-state basis: `docs/issue-7/reports/growth-analytics/
current-state-survey.md`, `docs/issue-7/reports/growth-analytics/
scout-brief.md`.

Canon-scripts note (per `docs/handbooks/canon-scripts.md`, `core/hooks/`
not checked out in this repo tree): everything below that resembles
`pricing/hooks/methodology-gate.sh` is described in this document as a
*pattern to follow*, not as script text to insert. Phase 2, when it
writes actual hook code, must write growth-analytics's own script from
this design, referencing the pattern, never copying `pricing`'s file
byte-for-byte.

---

## 1. Directive deepening

The current `directive.sh` `--produces` line already names the two
artifacts and their 5 components each (issue-1 phase 2), but as one long
string with no phase split, no judgment criteria, and no prohibitions.
Phase 2 should restructure the directive's role-specific commentary
(the free-text block below the `core_role_directive` call, the same slot
already used for the pre-registration-first note) into the following
shape, split by phase.

### Phase 1 (this role's own future proposals)

Steps, in order:
1. Name the primary metric explicitly — one metric, not a category
   ("checkout conversion", not "engagement metrics").
2. State the hypothesis and expected effect direction/magnitude before
   describing any observed data.
3. State the sample size and duration, with the power-analysis basis
   (minimum detectable effect, baseline rate, significance/power
   targets) — a duration with no MDE basis is not a duration.
4. Name guardrail metrics distinct from the primary metric, each with a
   non-regression bound.
5. State the decision rule as a threshold on the primary metric,
   phrased as a pre-commitment ("if primary metric >= X with guardrails
   intact, ship; otherwise kill/iterate"), not as a post-hoc judgment
   call.

Judgment criteria (how to tell a step is actually satisfied, not just
gestured at):
- A metric name is "explicit" only if a reader outside this role could
  compute it from a raw event log without asking a follow-up question.
- A sample-size/duration claim is "power-analysis basis stated" only if
  the MDE, baseline rate, and target power/significance all appear as
  numbers, not as "enough to detect a meaningful difference."
- A decision rule is "pre-committed" only if it is phrased as a
  conditional written before this proposal claims any data was
  observed — a rule stated after the numbers are already visible in the
  document does not count, even if it appears in the right section.

Prohibitions:
- Do not recommend running or trusting an experiment while any of the
  five items is a vague placeholder ("TBD", "see dashboard").
- Do not state a decision rule as a range with no committed threshold
  ("somewhere around 2-3% lift") — a range is not a decision rule.
- Do not substitute a list of "several KPIs we'll watch" for a single
  named primary metric — this proposal's methodology exists specifically
  to prevent multiple-comparisons post-hoc metric shopping.

### Phase 2 (this role's own future deliverables)

**Funnel diagnosis** — steps, in order:
1. Define every stage/event used, precisely enough that two analysts
   pulling from the same raw log would draw the same funnel.
2. Quantify stage-to-stage conversion/drop-off for every adjacent stage
   pair, not just the overall top-to-bottom rate.
3. Break down at least one segment axis (channel/cohort/device or an
   equivalent already meaningful to this business) specifically at the
   stage identified as weakest in step 2 — segment cuts done at a
   different, non-weakest stage do not satisfy this step.
4. State one bottleneck hypothesis that is a causal claim (why the
   segment cut in step 3 shows what it shows), not a restatement of the
   observation.
5. State one recommendation scoped to the single weakest stage from
   step 2 — a multi-stage wishlist fails this step even if each item on
   it is individually reasonable.

Judgment criteria:
- "Stage-to-stage" quantification means every adjacent pair has its own
  number; an aggregate top-to-bottom conversion rate with no
  intermediate breakdown does not satisfy step 2.
- A bottleneck hypothesis is "causal" only if it names a mechanism
  (e.g. "mobile checkout drop-off concentrates in the payment-form step
  because the form's autofill fails on iOS Safari"), not just a
  correlation ("mobile has lower conversion than desktop").

Prohibitions:
- Do not name a bottleneck without first localizing it to a specific
  stage and segment (steps 1-3 must precede step 4).
- Do not issue more than one prioritized recommendation per diagnosis —
  multiple recommendations dilute the "single weakest stage" discipline
  this methodology exists to enforce.

**Experiment trust verdict** — steps, in strict order (this is the
methodology's one ordering constraint; see §2 for its enforcement):
1. SRM check — chi-square goodness-of-fit on expected vs. observed
   arm-assignment split, with the test statistic and p-value both
   stated. Any SRM (conventionally p < 0.01 on this check) is a hard
   stop: no further step's output may be reported as a verdict until
   the SRM cause is found and the run is re-validated or re-run.
2. Platform A/A validation status — validated / failed / unvalidated,
   with the observed false-positive rate if the platform has run A/A
   tests. This step may only be reached if step 1 did not hard-stop.
3. Effect size + confidence interval against a pre-registered
   practical-significance bar (not a bare p-value) — the bar must be
   the one named in the originating phase-1 proposal's decision rule,
   not a bar chosen after seeing the result.
4. Guardrail metric check — delta and bound for every guardrail named
   in the originating proposal, reported even when the primary metric
   result is a clean win.
5. Twyman's-law flag — any effect size that is surprisingly large
   relative to the pre-registered expected effect (step-3's own
   proposal-stated expectation) must be marked "unconfirmed, pending
   independent check," never reported as a plain win.

Judgment criteria:
- Step 1 is "satisfied" only if both the test statistic and the p-value
  appear as numbers — "no SRM detected" with no numbers does not count.
- Step 3's practical-significance bar must be traceable to the
  originating phase-1 proposal (name or link the proposal's decision
  rule) — a bar invented at verdict time is not "pre-registered."
- Step 5's threshold for "surprisingly large" is: an observed effect
  more than 2x the proposal's stated expected-effect magnitude, or an
  effect the analyst's own text otherwise flags as surprising —
  whichever triggers first.

Prohibitions:
- Do not report an effect size or CI (step 3) before an SRM check
  (step 1) is both present and non-failing in the same verdict — this
  is the methodology's ordering constraint and the one this proposal's
  §2 gate design mechanically enforces via state tracking.
- Do not omit a guardrail's delta because the primary metric won — a
  win with an unreported guardrail is not a verdict, it is a partial
  report.
- Do not report a Twyman-eligible effect as a plain result even with a
  caveat elsewhere in the document — the flag must be attached to the
  number itself, in the same section.

---

## 2. Methodology gate design

### Two gates already exist; this proposal upgrades both and adds ordering.

`output-components-gate.sh` and `proposal-preregistration-gate.sh`
(issue-1 phase 2) already do component-presence checking on the record
and proposal write surfaces respectively. Per the current-state survey,
both are more permissive than `pricing/hooks/methodology-gate.sh`'s
pattern in one concrete way: they `exit 0` on an empty stdin payload
instead of failing closed, and neither wraps its Python body in a
fail-closed `try/except` (a traceback today would not reliably deny).
Phase 2 should bring both up to `pricing`'s pattern:

- Treat an empty/unparseable payload as **deny**, not allow, when the
  target path matches this role's write surface (mirroring `pricing`'s
  `deny "methodology-gate: empty tool-use payload..."` rather than this
  role's current `[ -n "$payload" ] || exit 0`).
- Resolve `CLAUDE_PROJECT_DIR` defensively (plausibility check + a
  `git rev-parse --show-toplevel` fallback) before trusting any path,
  rather than only reading `tool_input.file_path` as given.
- Wrap the Python judgment body in `try/except`, exiting 2 on any
  internal error, plus an outer shell `trap` that also exits 2 on any
  non-{0,2} exit — so a future maintenance bug in the gate fails closed
  instead of silently permitting every write.

### New capability: a third gate, `methodology-order-gate.sh` (design only)

Purpose: enforce the one ordering constraint named above — an
experiment-trust-verdict write may not contain step-3/4/5 content
(effect size, guardrail delta, Twyman flag) unless a **prior write in
the same session** already recorded a passing (non-hard-stopped) SRM
check for the same record file.

Design (state tracking, no code written this phase):

- **State file**: one small marker file per record path, written
  alongside the record under a session-scoped, git-ignored location —
  e.g. `.claude/.growth-analytics/<sanitized-record-path>.srm-state`
  (path shape only; exact directory is a phase-2 discovery item,
  matching issue-1 phase 2's own precedent of leaving an unconfirmed
  mechanism detail open rather than guessing). Content: a single line,
  either `srm-checked` (SRM step present, not a hard-stop) or absent
  (no SRM check recorded yet this session).
- **Write path**: every `PreToolUse` write to
  `docs/issue-<n>/reports/growth-analytics.md` that contains an
  `experiment-trust-verdict` section is inspected in two passes:
  1. If the new content contains an SRM check (chi-square stat +
     p-value present, per §1's judgment criteria) that is not itself
     flagged as a hard-stop ("SRM detected", "hard stop" absent), the
     gate writes `srm-checked` to the state file for that record path,
     then proceeds to the existing component checks.
  2. If the new content contains any of step 3/4/5's required
     components (effect size/CI, guardrail delta, Twyman flag) but the
     state file for that record path does not contain `srm-checked` —
     and the *same write* does not itself also introduce a passing SRM
     check (a single all-in-one write is allowed, since ordering is
     about logical precedence within the record, not wall-clock write
     count) — deny (exit 2), citing the missing SRM precedence.
  3. If the new content's own SRM check is a hard-stop ("SRM detected"
     language present), deny any co-present step 3/4/5 content
     unconditionally, regardless of state-file contents — a hard-stop
     always blocks the rest of the verdict in the same write.
- **State reset**: the state file is scoped to one record path and is
  never consulted for a different `docs/issue-<n>/reports/
  growth-analytics.md` (different `n`) — state does not leak across
  issues. A phase-2 discovery item: whether the state file should also
  expire after some staleness window (e.g. a new session on the same
  issue that never re-declares SRM should probably not silently reuse a
  week-old marker) — left open here, to be resolved when the gate is
  actually implemented and can be tested against real session
  boundaries.
- **Fail-closed default**: if the state file cannot be read/written for
  any reason (permissions, disk), the gate denies rather than silently
  treating the record as SRM-unchecked-but-allowed — consistent with
  `pricing/hooks/methodology-gate.sh`'s fail-closed-on-internal-error
  pattern.

This is additive to (never a replacement for) the existing
`output-components-gate.sh` presence check — the order gate answers
"was SRM checked *before* the rest of the verdict is trustworthy,"
the component gate answers "are all 5 components present at all."

### Registration

`hooks.json`'s `PreToolUse` array gains a third entry pointing at
`methodology-order-gate.sh`, alongside the two upgraded existing gates,
same matcher (`Write|Edit|MultiEdit`).

---

## 3. Gate tests design

To live under repo-root `tests/` (new directory; none exists today),
following `implementation-rulebook/tests/run-gate-tests.sh`'s pattern —
a disposable `git init`'d temp dir per case, a synthetic `PreToolUse`
JSON payload (`tool_name`/`tool_input`/`cwd`) piped to the gate script on
stdin, exit code asserted (0=allow, 2=deny). No test script is written
this phase; the cases below are the design phase 2 should implement
against.

`tests/run-gate-tests.sh` design, cases:

**`output-components-gate.sh` (existing gate, upgraded fail-closed
behavior):**
- `allow` — record write with all 5 funnel-diagnosis components present.
- `deny` — record write declaring "funnel diagnosis" but missing the
  segment-breakdown component.
- `allow` — record write to a path that doesn't match
  `docs/issue-<n>/reports/growth-analytics.md` (foreign path, gate is a
  no-op).
- `deny` (new, upgrade case) — empty stdin payload on a matching path
  (currently `allow` under the existing script; this proposal's §2
  upgrade makes it `deny`).

**`proposal-preregistration-gate.sh` (existing gate):**
- `allow` — proposal with no experiment/A-B keyword at all (this
  proposal itself is such a case).
- `deny` — proposal with "recommend running an A/B test" but missing
  the guardrail-metrics item.
- `allow` — proposal with all 5 pre-registration items present.

**`methodology-order-gate.sh` (new gate, design only):**
- `deny`, `srm-not-yet-checked` — a first write to a fresh record path
  containing effect-size/CI and guardrail-delta text (steps 3/4) but no
  SRM check anywhere in the new content and no prior `srm-checked`
  state file.
- `allow`, `srm-then-effect-same-write` — a single write whose content
  contains a passing SRM check *and* effect-size/guardrail/Twyman
  content, all in the same write (ordering satisfied within one write).
- `allow`, `srm-checked-prior-write-then-effect` — write #1 records only
  a passing SRM check (state file becomes `srm-checked`); write #2 (same
  record path, same disposable repo, sequential in the test) adds
  effect-size/guardrail content — must be allowed because state carries
  over.
- `deny`, `srm-hard-stop-blocks-verdict` — a write whose SRM section
  contains hard-stop language ("SRM detected") alongside effect-size
  content in the same write — must deny regardless of any prior
  `srm-checked` state (a hard stop always blocks, per §2 design point
  3).
- `deny`, `state-file-unwritable` — simulate a state directory the test
  harness has made unwritable (e.g. `chmod 000` on the parent dir before
  the gate call) with a first-time SRM-checked write — must deny
  (fail-closed), not silently allow.
- `allow`, `foreign-path` — write to a differently-numbered issue's
  record path than the one holding `srm-checked` state — must not reuse
  cross-issue state (allow only if that other write's own content is
  otherwise complete; this case specifically asserts no state leak, not
  that the write is unconditionally allowed).

---

## 4. Agents / checklist

The methodology has two genuinely repeated procedures — the funnel
5-step localization sequence and the Kohavi 5-step trust-gate sequence
(§1). Neither currently has anything guiding production step-by-step;
the existing gates only check the finished artifact. Per this issue's
constraint (a repeated procedure gets an agent or checklist), this
proposal recommends a **checklist**, not a new agent:

- A new agent was considered and rejected for this phase: the existing
  `warrant-hunter.md` is this plugin's only agent and it serves an
  unrelated purpose (rotating-stance hunting against this role's own
  past output, not methodology execution). Introducing a second agent
  whose only job is "walk through 5 steps in order" is more machinery
  than the task needs — a checklist file achieves the same guidance
  without a new agent-invocation surface to maintain, and matches this
  role's existing lightweight footprint (one directive, a few gates, one
  hunt agent).
- Proposed location: `growth-analytics/hooks/lib/checklists/
  experiment-trust-verdict.md` and `.../funnel-diagnosis.md` (path shape
  only — phase 2 picks the final location), each a literal ordered
  checklist mirroring §1's steps/judgment-criteria/prohibitions for that
  artifact, meant to be read by the analyst (human or agent) producing
  the artifact before writing it — not executed by any hook. The gates
  in §2 remain the actual enforcement; the checklist is production-time
  guidance so a write is more likely to pass the gate on the first try
  rather than a purely reject-and-retry loop.
- If phase 2 later finds the checklist alone insufficient (e.g. repeated
  gate rejections show analysts aren't reading it), promoting it to an
  actual `agents/methodology-walker.md` invoked at the start of a
  funnel-diagnosis or experiment-trust-verdict task is the natural next
  step — explicitly left as a future escalation, not built here.

---

## Explicitly out of scope for this issue

- Any actual hook script (`methodology-order-gate.sh`,
  upgraded `output-components-gate.sh` / `proposal-preregistration-
  gate.sh`), `tests/run-gate-tests.sh`, or checklist file content —
  phase 2, post-Approve, per contract v3 s19.
- Copying `pricing/hooks/methodology-gate.sh` or `implementation-
  rulebook`'s `state.sh`/`hunt-state.sh`/`run-gate-tests.sh` verbatim —
  every mechanism above is a description of the pattern, to be
  implemented as growth-analytics's own script in phase 2, per
  `docs/handbooks/canon-scripts.md`.
- Adopting a new domain methodology, changing `write_scope`, or
  enumerating `warrant-hunter`'s stance set (unrelated, prior open
  items, unaffected by this issue).
- Resolving the exact state-file directory and staleness-window
  questions flagged in §2 — named as phase-2 discovery items, not
  assumed here.
