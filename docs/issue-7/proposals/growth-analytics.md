# Proposal: growth-analytics enforcement as a plugin set (issue-7)

Subject: issue-7. Phase 1 proposal only — no plugin, hook, agent, or test
file lands in this PR. Phase 2 (writing the scripts/agents/tests
described below) opens only after human Approve per contract v3 s19 —
concretely, either a PR review Approve or the issue-comment form
`APPROVE issue-7/growth-analytics` from an account listed in
`docs/specs/approvers.md` (currently `JiwonJung94`). Nothing here changes
role boundaries or the role's `write_scope` (`[]`, unchanged).

## 0. Framing correction (per approver comment)

The issue body asked for "a methodology gate" (singular) deepening a
single directive. The approver's issue comment corrected this: the
deliverable must be a **set of independent, self-contained plugins**,
one per adopted methodology — the same shape `core`'s marketplace already
uses for `freelunch`/`scout`/`warrant`/`terse` (five single-purpose
plugins registered in one `marketplace.json`, each with its own
`.claude-plugin/plugin.json`, `hooks/`, and where relevant `agents/` and
`hooks/tests/`). This proposal is written to that corrected structure.
The rest of this document is organized as: (1) the plugin inventory,
(2) each plugin's directive deepening, (3) each plugin's gate design,
(4) each plugin's test design, (5) each plugin's agent/checklist, then
(6) how phase-1 and phase-2 *norms* are each a composition of these
plugins, and (7) the phase-2 reflection plan.

## 1. Plugin inventory

Three methodologies were adopted in issue-1 (`docs/issue-1/proposals/
rulebook-maturation.md`, sections (a)/(b), approved and reflected in
issue-1 phase 2, commit `4e50c6f`). Each becomes one plugin:

| Plugin name | Methodology owned | Write surface | Components |
|---|---|---|---|
| `ga-prereg` | Pre-registration-first (phase-1 proposal norm) | `docs/issue-<n>/proposals/*.md` | directive + gate + tests |
| `ga-funnel` | Stage/segment localization for funnel diagnosis (phase-2 norm) | `docs/issue-<n>/reports/growth-analytics.md`, `funnel diagnosis` section | directive + gate + agent + tests |
| `ga-trust` | Kohavi experiment-trust gate (phase-2 norm) | `docs/issue-<n>/reports/growth-analytics.md`, `experiment trust verdict` section | directive + gate + state tracking + agent + tests |

Each plugin is self-contained: its own `.claude-plugin/plugin.json`
(name, description, author — same shape as the existing
`growth-analytics/.claude-plugin/plugin.json`), its own `hooks/`
directory (`directive.sh` contributing a `SessionStart` fragment plus
one `PreToolUse` gate script), its own `hooks/tests/` directory, and —
for the two phase-2 plugins whose methodology is a repeated multi-step
procedure — its own `agents/` directory. All three register in this
repo's `.claude-plugin/marketplace.json` alongside the existing
`growth-analytics` entry (which becomes the thin role-glue plugin: role
directive core fields, hand-off, record path — the parts that are not
methodology-specific).

Proposed marketplace addition (illustrative, not applied this phase):

```json
{
  "name": "ga-prereg",
  "source": "./ga-prereg",
  "description": "Pre-registration-first methodology for growth-analytics phase-1 proposals recommending an experiment: fixes primary metric, hypothesis, sample size/duration, guardrails, and decision rule before any data is interpreted."
},
{
  "name": "ga-funnel",
  "source": "./ga-funnel",
  "description": "Stage/segment localization methodology for growth-analytics funnel-diagnosis deliverables: stage definitions, quantified drop-off, segment isolation, one bottleneck hypothesis, one prioritized single-stage recommendation."
},
{
  "name": "ga-trust",
  "source": "./ga-trust",
  "description": "Kohavi trustworthy-experiments trust-gate for growth-analytics experiment-trust-verdict deliverables: SRM, A/A validity, guardrails, effect-size/CI, Twyman's-law skepticism, enforced in order via session state."
}
```

Why plugins, not gate scripts inside the existing `growth-analytics`
tree: (a) it matches the `core` precedent the approver named directly;
(b) each methodology already has an independently statable adoption
rationale (issue-1 proposal (c)) and independently testable pass/reject
behavior — bundling them defeats the point of being able to reason about
one methodology's enforcement without reading the other two; (c) it
makes composition (section 6) an explicit, inspectable fact (which
plugins are enabled) instead of an implicit fact buried inside one
script's branching logic — the current `output-components-gate.sh`
already exhibits this problem, silently bundling the funnel and
trust-verdict checks in one file (current-state-survey.md, "What exists
today," second bullet).

## 2. Directive deepening per plugin

Each plugin's `directive.sh` fragment states phase (1 or 2, as
applicable), the ordered steps, judgment criteria distinguishing
"satisfied" from "mentioned," and explicit prohibitions — not a one-line
summary. This section specifies the *content* each fragment must carry;
phase 2 turns it into an actual `--produces`/comment block, composed via
`role-directive.sh`'s existing multi-fragment support pattern (each
plugin's `SessionStart` hook appends to the same session, as `core`'s
`terse`/`freelunch`/`scout` already do alongside `core`'s own directive).

### `ga-prereg` (phase 1 only)

Steps (in order): (1) name the single primary metric — reject "several
KPIs" or an unnamed composite; (2) state hypothesis + expected effect
direction and rough magnitude — reject "should improve X" with no
direction/magnitude; (3) state sample size **and** duration together,
with the power-analysis basis named (even informally, e.g. "N per arm
from a 5%→6% MDE at 80% power") — a duration alone or a sample size
alone does not satisfy this step; (4) name guardrail metrics distinct
from the primary metric — reject reusing the primary metric as its own
guardrail; (5) state the decision rule as a threshold on the primary
metric, committed before data — reject "we'll evaluate holistically."

Judgment criteria: each of the 5 items must be a literal, locatable line
containing both a label-like cue (e.g. "primary metric:", "guardrail:")
and a substantive value — a section heading with no content under it
does not count as present.

Prohibitions: (a) proposing to skip pre-registration because "this is
just a quick test" — the methodology has no size exemption; (b) stating
a decision rule in terms of statistical significance alone with no
practical-significance threshold (a large-N false positive is not a
license to declare a win); (c) naming a guardrail metric without stating
what breach means (a bound, not just a name).

### `ga-funnel` (phase 2)

Steps: (1) define each funnel stage/event explicitly — reject implicit
stages inferred from prose; (2) quantify stage-to-stage conversion/
drop-off with actual numbers, not qualitative language ("many users
drop off" does not satisfy this); (3) break down by at least one
segment axis (channel/cohort/device or an explicitly named equivalent)
and show where the drop-off concentrates in that segment — reject a
segment table with no concentration claim drawn from it; (4) state one
bottleneck hypothesis that is a causal claim, not a restatement of the
observation (e.g. not "stage 3 has the biggest drop" — that's the
observation from step 2, not a hypothesis about *why*); (5) give exactly
one prioritized recommendation scoped to the single weakest stage —
reject a multi-stage wishlist, which this methodology explicitly treats
as a prohibition, not just an omission.

Judgment criteria: step 2's numbers must be attributable to a specific
stage pair (not a single aggregate conversion rate for the whole
funnel); step 3's segment breakdown must name the concentration
explicitly (a table alone, with no sentence pointing at which cell is
the problem, does not satisfy this).

Prohibitions: (a) more than one "prioritized recommendation" — this is a
hard violation per the adopted methodology's explicit single-stage
scoping, not a style preference; (b) a bottleneck hypothesis stated as
"probably X" with no reference to the segment breakdown that motivated
it — the hypothesis must trace to the segment evidence, not be
freestanding domain intuition.

### `ga-trust` (phase 2)

Steps, **in this order, enforced by state tracking** (section 3.4 for
mechanism): (1) SRM check — chi-square test statistic and p-value,
expected-vs-observed split; a detected SRM is a hard stop, nothing
downstream may be reported as a verdict until SRM is resolved or the
experiment is invalidated; (2) platform A/A validation status
(validated/failed/unvalidated) with observed false-positive rate if
known; (3) guardrail metric checks — delta and bound per guardrail,
reported even when the primary metric wins; (4) effect size and
confidence interval against a pre-registered practical-significance bar
— a bare p-value never satisfies this step; (5) Twyman's-law flag — any
result whose effect size is anomalously large relative to the
pre-registered expected effect (from the `ga-prereg` proposal that
authorized this experiment, when traceable) is marked "unconfirmed,
pending independent check," never reported as a plain result.

Judgment criteria: step 1 must show both a statistic and a p-value, not
either alone; step 2's status must be one of the three named values
literally, not paraphrased; step 4's CI must have two bounds, not a
point estimate with "roughly ±X%" prose.

Prohibitions: (a) reporting effect size/CI (step 4) before SRM (step 1)
has cleared — this is the ordering constraint state tracking exists to
enforce mechanically, not just stylistically; (b) an "unvalidated" A/A
status silently treated as equivalent to "validated" — unvalidated caps
confidence, it does not get skipped; (c) omitting the Twyman flag on a
verdict whose reported effect exceeds 2x the `ga-prereg`-stated expected
effect (a concrete, checkable numeric trigger rather than "if it looks
surprising").

## 3. Methodology gate design (per plugin, pricing-pattern-informed)

Reference: `pricing/hooks/methodology-gate.sh` (read in full at
`/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/
methodology-gate.sh`; **not copied** — see canon-scripts note in
current-state-survey.md). Its pattern, described (not reproduced) for
each of the three new gates:

### 3.1 Shared shape across all three gates

1. **Fail-closed wrapper.** `trap __fc EXIT` at the top, where `__fc`
   exits 2 on any exit code other than 0 or 2 — an unhandled internal
   error becomes a denial, not a silent pass. This closes the concrete
   gap current-state-survey.md item 3 identifies: neither existing
   `growth-analytics` gate has this wrapper today.
2. **Fail-closed on empty payload.** An empty stdin payload is a denial
   (`deny "empty tool-use payload"`), not `exit 0` — the existing two
   gates do the opposite (`exit 0` on nothing to check); this proposal's
   gates invert that default.
3. **Root resolution before trusting a path.** Resolve
   `CLAUDE_PROJECT_DIR` and validate it is plausible (has `.git` or a
   known repo marker file) before trusting it; fall back to `git -C <dir>
   rev-parse --show-toplevel`; deny if no root can be determined. The
   target file path must resolve *inside* that root.
4. **Content reconstruction, not diff-only.** Handle `Write` (use content
   verbatim), `Edit` (apply the one replacement to prior content — where
   prior content is read from disk if the file exists, empty otherwise),
   and `MultiEdit` (apply all edits in order, all-or-nothing) to obtain
   the actual post-write text before running any check. A gate that only
   inspects `new_string` would miss content already present from an
   earlier write in the same file.
5. **Presence checks are mechanical needle checks over lowercased text**
   — never an LLM judgment call inside the gate itself. Judgment criteria
   from section 2 above (e.g. "two bounds, not a point estimate") are
   expressed as regex/pattern checks (e.g. a CI needs two numbers
   separated by a dash/comma/"to" near a "CI"/"confidence interval"
   cue), not as a delegated free-text evaluation.
6. **Kill switch env var per plugin** (`GA_PREREG_GATE_OFF`,
   `GA_FUNNEL_GATE_OFF`, `GA_TRUST_GATE_OFF`), matching the existing
   `GROWTH_ANALYTICS_CYCLE_OFF` naming convention in `directive.sh`.

### 3.2 `ga-prereg`'s gate

Targets `docs/issue-<n>/proposals/*.md`. Keeps the existing keyword
pre-gate (experiment/A-B term + run/trust/recommend term) so proposals
not about experiments are unaffected — this is inherited behavior, not a
new design point. On a match, checks all 5 items from section 2's
judgment criteria; denies naming the first missing item by name (not
just "missing items," to make the denial actionable).

### 3.3 `ga-funnel`'s gate

Targets `docs/issue-<n>/reports/growth-analytics.md`, fires only when a
`funnel diagnosis` (or equivalent declared) section is present in the
reconstructed content. Checks the 5 components with the judgment
criteria from section 2, including the "exactly one recommendation"
prohibition (a count check: more than one recommendation-shaped bullet
under the recommendation heading is itself a denial reason, distinct
from a missing-component denial).

### 3.4 `ga-trust`'s gate + state tracking

Targets the same record file, fires on an `experiment trust verdict`
section. This is the one gate with an **ordering constraint**, per
section 2's prohibition (a): step 4 (effect/CI) may not be reported
before step 1 (SRM) has cleared. Design:

- A small state file, session-scoped, at a path resolved the same way
  `implementation-rulebook/coding/hooks/state.sh` resolves its state
  path (pattern only, not copied) — e.g.
  `<project-root>/.claude/state/growth-analytics/ga-trust-<issue-n>.json`
  — recording which of the 5 steps have been *written and validated* so
  far for this issue's verdict (not "attempted": the gate itself, having
  checked step 1's presence and correctness on an earlier write to this
  same file, marks it done).
- On each `PreToolUse` write to the record file's experiment-trust-
  verdict section, the gate: (a) re-derives which of the 5 steps are
  present in the reconstructed content (this is idempotent — it does not
  trust the state file blindly, it recomputes from content each time,
  using the state file only to catch a **regression**: a later edit that
  removes/blanks an earlier step's content after it had been validated);
  (b) if step 4 or 5 content is present in this write but step 1 is not
  present (in this write or state-file-recorded as previously
  validated), deny with "SRM must be checked before effect size is
  reported (Kohavi trust-gate order)"; (c) on allow, update the state
  file with the now-validated step set.
- This makes the gate stateful but still fail-closed and re-derivable —
  losing the state file only means the gate re-checks from the full
  current content on the next write (safe default: re-verify everything,
  never silently trust a stale "already passed" state across content
  changes).
- Twyman's-law numeric trigger (section 2, prohibition (c)) is checked
  by comparing the verdict's stated effect size against the expected
  effect stated in the `docs/issue-<n>/proposals/*.md` file that
  `ga-prereg`'s gate validated for the same issue number, when that file
  exists and is locatable by issue-n path convention; if it cannot be
  found, the check is skipped with a warning (fail-open only on this one
  cross-file lookup, since the file may legitimately not exist for
  every historical issue — this is the one deliberate exception to
  "fail closed," stated explicitly rather than silently).

## 4. Gate tests design (per plugin, for a later phase)

Test harness shape (pattern from `implementation-rulebook/tests/
run-gate-tests.sh`, read in full, not copied): each plugin's
`hooks/tests/` directory gets a `run-gate-tests.sh` that, per case,
`git init`s a disposable temp dir, writes any needed pre-existing file
content, constructs a synthetic `PreToolUse` JSON payload
(`tool_name`, `tool_input.file_path`, `tool_input.content` or
`old_string`/`new_string`, `cwd`) on stdin, invokes the gate script
directly, and asserts the exit code (0 = allow, 2 = deny) plus, for deny
cases, that stderr names the specific missing/violated item.

Concrete cases (described in prose this phase; not created as files):

### `ga-prereg`
- PASS: proposal with all 5 items present and labeled, experiment
  keywords present → exit 0.
- PASS: proposal with no experiment keywords at all (e.g. a pure design
  proposal) → exit 0, gate does not even engage.
- REJECT: experiment proposal missing the decision rule only → exit 2,
  stderr names "decision rule."
- REJECT: experiment proposal with guardrail metric = primary metric
  restated → exit 2 (prohibition (c) check).
- REJECT (fail-closed): malformed/truncated JSON payload → exit 2, not a
  crash.

### `ga-funnel`
- PASS: all 5 components present, one recommendation.
- REJECT: two recommendations under the recommendation heading → exit 2,
  "exactly one recommendation" reason.
- REJECT: segment table present but no concentration sentence → exit 2,
  "segment breakdown does not identify concentration."
- REJECT: bottleneck hypothesis is a verbatim restatement of the
  drop-off number (regex: hypothesis sentence contains no causal-cue
  word like "because"/"due to"/"caused by") → exit 2.
- PASS: an `Edit` payload that only changes the recommendation section
  of a file whose funnel-diagnosis section was already complete from a
  prior `Write` → exit 0 (validates content reconstruction, not
  diff-only checking).

### `ga-trust`
- PASS: verdict written in full with all 5 steps, SRM clean, in one
  `Write` → exit 0, state file records all 5 validated.
- REJECT: verdict `Write` containing only effect-size/CI content, no SRM
  section at all → exit 2, ordering violation named.
- REJECT: two-step sequence — first `Edit` adds SRM (passes, state file
  updated), second `Edit` adds effect/CI referencing an anomalous
  4x-expected effect with no Twyman flag present → exit 2 on the second
  write, "Twyman's-law flag required."
- PASS: same two-step sequence but the second edit includes the Twyman
  flag language → exit 0.
- REJECT (regression case): a third edit that removes the SRM section
  after it was previously validated, while effect/CI content remains →
  exit 2 (validates the gate re-derives from content every time rather
  than trusting stale state).
- REJECT (fail-closed): gate invoked with `CLAUDE_PROJECT_DIR` unset and
  no `.git` in any resolvable ancestor → exit 2, "no project root."

## 5. Agents / checklist per plugin

Both phase-2 plugins own a genuinely repeated multi-step procedure, so
each proposes one agent (as a doc-only proposal this phase — no agent
file is created):

- **`ga-funnel/agents/funnel-localizer.md`** — walks a session through
  the 5-step stage/segment localization sequence in order, prompting for
  each component's judgment-criteria content (section 2) before moving
  to the next, and stops the walk at step 5 with an explicit reminder of
  the single-recommendation prohibition. Modeled structurally on
  `warrant-hunter.md`'s role as a canon-extension agent stub tailored to
  one role's procedure, not copied from it (different methodology
  entirely).
- **`ga-trust/agents/trust-gate-walker.md`** — walks the Kohavi sequence
  in the enforced order (mirrors the gate's own ordering constraint, so
  the agent and the gate never disagree about what "in order" means),
  hard-stopping at step 1 if SRM is detected before letting the session
  proceed to step 2, and prompting explicitly for the Twyman comparison
  against the linked `ga-prereg` proposal's expected effect at step 5.

`ga-prereg`'s methodology (5 items, one proposal, no multi-artifact
sequencing) does not have a comparable repeated-procedure shape distinct
from just writing the proposal correctly the first time — no agent is
proposed for it; the gate alone is proportionate, consistent with this
issue's own instruction that an agent is only warranted "if the
methodology requires a repeated procedure."

## 6. Norms as plugin composition

This is the structural core the approver's comment asked for made
explicit, not left implicit in a single role directive:

- **Phase-1 proposal norm** (issue-1 proposal (a)) = `ga-prereg` alone.
  A growth-analytics phase-1 proposal that does not recommend an
  experiment is governed by no methodology plugin beyond the generic
  core canon record/proposal gates (§20 fields etc.) — `ga-prereg`'s own
  keyword pre-gate is what makes this composition conditional rather
  than blanket.
- **Phase-2 output norm** (issue-1 proposal (b)) = `ga-funnel` **or**
  `ga-trust`, selected by which section the record declares — not both
  simultaneously on every write, since a single record write typically
  targets one deliverable type. A record that declares *both* a funnel-
  diagnosis and an experiment-trust-verdict section in the same write
  (permitted — nothing prohibits combining both in one issue's record)
  is checked by both gates independently (each `PreToolUse` hook fires
  on its own matcher regardless of the other) — composition here is
  "both apply, independently, when both sections are present," an AND
  over whichever plugins' trigger conditions match, not an OR chosen
  once per write.
- **Cross-plugin composition**: `ga-trust`'s Twyman check (section 3.4)
  is the one place a plugin's gate reads *another* plugin's write-
  surface artifact (the linked `ga-prereg`-validated proposal) — this is
  the concrete instance of "how methodology plugins compose," not a
  hypothetical: `ga-trust` depends on `ga-prereg` having run first for
  the same issue number when that dependency is checkable, and degrades
  gracefully (warns, does not deny) when it isn't.
- The existing `growth-analytics` plugin becomes the **composition
  root**: its `directive.sh` keeps the role-wide fields (`--decides`,
  `--use-when`, `--hand-off`, `--record-path`) and, in place of the
  current inline `--produces` free text, states which methodology
  plugins are expected enabled for this role (`ga-prereg`, `ga-funnel`,
  `ga-trust`) and what artifact each is responsible for — the directive
  becomes a manifest of composed plugins, not a monolith.

## 7. Phase-2 reflection plan (blocked on Approve)

1. Create `ga-prereg/`, `ga-funnel/`, `ga-trust/` as siblings of
   `growth-analytics/` in this repo, each with `.claude-plugin/
   plugin.json`, `hooks/directive.sh`, `hooks/<name>-gate.sh`,
   `hooks/hooks.json`, `hooks/tests/run-gate-tests.sh` (+ `agents/` for
   the two phase-2 plugins), per sections 2–5 above.
2. Register all three in `.claude-plugin/marketplace.json` alongside the
   existing `growth-analytics` entry, per section 1's illustrative JSON.
3. Retire `growth-analytics/hooks/output-components-gate.sh` and
   `proposal-preregistration-gate.sh` in favor of the three new
   plugin-owned gates — remove their `hooks.json` wiring from
   `growth-analytics/hooks/hooks.json` once the replacements are wired
   in the new plugins' own `hooks.json` files. (Deletion of the two
   existing files is itself a phase-2 action; nothing is deleted this
   phase.)
4. Rewrite `growth-analytics/hooks/directive.sh`'s `--produces` line
   into the composition-manifest form described in section 6's last
   bullet.
5. Exercise every test case from section 4 before landing (or, if a real
   automated harness is wired, run it and record pass/fail per case in
   the phase-2 record — this proposal explicitly designs for automated
   verification, closing the "manual only" gap issue-1 phase 2 left
   open).
6. Update `docs/issue-1/reports/growth-analytics.md`'s "Open findings"
   note about `output-components-gate.sh` filling a core-canon gap: once
   split into `ga-funnel`/`ga-trust`, note in the phase-2 record whether
   that open finding is resolved, superseded, or still applicable.

## Explicitly out of scope for this issue

- Writing any actual `hooks/*.sh`, `agents/*.md`, `plugin.json`,
  `marketplace.json` edit, or `tests/*.sh` file (phase 2, post-Approve).
- Any change to `growth-analytics`'s `write_scope` or role hand-off
  boundary (`캠페인 메시지 변경이 필요하면 → marketing`, unchanged).
- Enumerating `warrant-hunter.md`'s stance set (issue-2's stated
  out-of-scope item, unaffected by this issue).
- Modifying core canon (`core/hooks/lib/role-directive.sh` or any core
  script) — core is not checked out in this repo tree; the multi-
  fragment `SessionStart` composition this proposal assumes (section 2's
  intro) is asserted as consistent with `core`'s own `terse`/`freelunch`/
  `scout` precedent, not independently verified against core's source
  here (a phase-2 discovery item, same caveat pattern issue-1 (d)2 used).
