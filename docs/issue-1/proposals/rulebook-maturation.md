# Proposal: growth-analytics rulebook maturation — evidence-based proposal/output norms (issue-1)

Subject: issue-1. Phase 1 proposal only — no plugin change lands in this
PR; phase 2 (reflecting the norms below into `directive.sh`/record
fields/gates) opens only after human Approve per contract v3 s19.

## Summary

This role currently declares *what* it produces (`--produces "funnel
diagnosis, experiment trust verdict (SRM/pre-registration check)"`) but
no gate checks *how* — no methodology, no required sections/components,
no evidence format, for either its own phase-1 proposals or its phase-2
deliverables. This proposal fixes both norms, grounded in the domain
survey in `docs/issue-1/reports/growth-analytics/scout-brief.md` (full
survey: `current-state-survey.md`, same directory).

## (a) Phase-1 proposal norm — for this role's own future proposals

Methodology: **pre-registration-first**. A growth-analytics phase-1
proposal that recommends running or trusting an experiment must fix,
in writing, before any data is interpreted:

Required sections:
1. **Primary metric** — one metric, named explicitly (not "several KPIs").
2. **Hypothesis / expected effect** — direction and rough magnitude.
3. **Sample size + duration** — the power-analysis basis for the run.
4. **Guardrail metrics** — named non-primary metrics that must not
   regress, monitored regardless of the primary result.
5. **Decision rule** — the pre-committed go/kill/pivot threshold on the
   primary metric; this rule, not post-hoc judgment, decides the outcome.

Evidence format: each of the five items above must be a literal,
locatable line in the proposal (not implied) — a proposal missing any
one item is incomplete, not merely light on detail.

## (b) Phase-2 output norm — for this role's own future deliverables

Two deliverable types, per `directive.sh`'s existing `--produces` line;
each gets its own required-component list.

### Funnel diagnosis

Methodology: stage/segment localization (drawn from AARRR/HEART/cohort-
retention convergence — see scout-brief; no single named framework is
mandated, only its shared required components).

Required components:
1. Explicit stage/event definitions.
2. Stage-to-stage conversion / drop-off quantification.
3. Segment breakdown (channel/cohort/device or equivalent) isolating
   where the drop-off concentrates.
4. One bottleneck hypothesis (root cause, not just the observation).
5. One prioritized recommendation, scoped to the single weakest stage —
   not a multi-stage wishlist.

### Experiment trust verdict

Methodology: Kohavi trustworthy-experiments trust-gate (SRM → A/A
validity → guardrails → effect-size/CI → Twyman's-law skepticism),
matching the `experiment-trust` skill already in this environment.

Required components:
1. **SRM check** — chi-square test result (expected vs. observed split,
   p-value); any SRM is a hard stop, no verdict on effect until fixed.
2. **Platform A/A validation status** — validated / failed / unvalidated,
   with observed false-positive rate if known; unvalidated/failed status
   caps the verdict's confidence, it cannot be silently skipped.
3. **Effect size + confidence interval** against a pre-registered
   practical-significance bar — not a bare p-value.
4. **Guardrail metric check** — delta + bound per guardrail, breach
   reported even on an otherwise-winning primary metric.
5. **Twyman's-law flag** — any anomalously large/surprising win is
   marked "unconfirmed, pending independent check" until validated, never
   reported as a plain result.

## (c) Rationale per adoption

- **Pre-registration-first for phase-1 proposals**: every scouted
  angle — Reforge's experiment templates, Kohavi's canonical checklist,
  the general pre-registration literature — converges on fixing metric/
  hypothesis/threshold *before* data, specifically to block the failure
  mode this role exists to catch (post-hoc-justified "wins"). Adopting
  anything looser would let this role's own proposals commit the exact
  error its phase-2 verdicts are meant to police.
- **Stage/segment localization for funnel diagnosis, framework-agnostic**:
  AARRR, HEART, and cohort-retention analysis disagree on framing but
  agree on the five required components (definitions → quantified
  drop-off → segment cut → hypothesis → single prioritized fix).
  Mandating one named framework would constrain a *lens choice* the
  literature itself treats as interchangeable; mandating the shared
  components does not.
- **Kohavi trust-gate for experiment-trust verdicts**: this maps
  directly onto the role's stated decision boundary (퍼널 병목과 실험
  결과가 실제 개선인지) and its existing `--produces` line already names
  "SRM/pre-registration check" — this proposal operationalizes that
  existing intent into checkable components rather than inventing new
  scope. SRM/A-A/guardrails/CI are the field's convergent minimum for
  calling a result trustworthy at all (Microsoft/LinkedIn-scale SRM
  incidence data, per scout-brief, shows this is a real, frequent
  failure mode, not a theoretical one).
- **Component checklists over prose descriptions**: both output norms
  are written as enumerable, presence-checkable items (not narrative
  guidance) specifically so phase 2 can turn them into a mechanical gate
  — matching this repo's existing pattern (`record-fields-gate.sh`
  lineage, now centralized in core) of checking required fields by
  presence, not by judgment call.

## (d) Plugin reflection plan (phase 2, blocked on Approve)

1. **`directive.sh`**: expand `--produces` from free text into two
   named artifact declarations the centralized record-fields gate can
   key on: `funnel-diagnosis` and `experiment-trust-verdict` (these two
   identifiers already appear in `docs/issue-2/proposals/core-reference-
   transition.md` item 2 as the intended required record fields — this
   proposal is naming the components *inside* each, not renaming the
   fields).
2. **Record required fields** (via core's centralized record-fields
   gate, parameterized per role): add sub-field presence checks —
   `funnel-diagnosis` record entries must show all 5 required components
   from (b); `experiment-trust-verdict` entries must show all 5 from
   (b). Exact mechanism (whether core's gate supports nested/sub-field
   checks or only top-level field presence) is unconfirmed — core is not
   checked out in this repo tree (per issue-2 precedent) — and is a
   phase-2 discovery item, not assumed here.
3. **Gate for phase-1 proposals** (this role's own future proposals):
   add a lightweight presence check — a growth-analytics phase-1
   proposal recommending an experiment must contain the 5 pre-
   registration items from (a) as locatable lines, mirroring the
   existing "no skip record, no scout" enforcement pattern already used
   by this session's scout-directive.
4. **No new framework name is hardcoded** into any gate — per (c)'s
   skip decision, gates check for the *components*, never for "AARRR"/
   "HEART"/"North Star" by name, so a future role update can swap the
   lens without touching the gate.

## Explicitly out of scope for this issue

- Any actual code change to `directive.sh`, hooks, or record-fields
  logic (phase 2, post-Approve, per contract v3 s19).
- Enumerating warrant-hunter's stance set (issue-2's stated
  out-of-scope item, unaffected by this issue).
- Confirming core canon's exact gate/field-nesting interface (core not
  checked out; phase-2 discovery item per (d)2).
