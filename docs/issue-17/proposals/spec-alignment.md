---
status: proposed
files:
  - docs/handbooks/growth-analytics-plugins.md
  - README.md
  - ga-funnel/hooks/ga-funnel-gate.sh
  - ga-funnel/hooks/tests/run-gate-tests.sh
  - growth-analytics/hooks/directive.sh
  - docs/specs/record-fields-terminal-states.json
---

## Request

Layer the realized `growth-analytics.spec.json`'s three required record
fields (`funnel_stage`, `metric_value`, `is_north_star`) and its
`loop_state` vocabulary (`analytics-data-unreachable`, `landed`,
`measuring`, `reviewing`, `stage-undeclared`) onto this rulebook's docs
and hooks, strengthening what already exists rather than deleting any
methodology. Map each spec field onto the closest existing rulebook
concept; where none exists, say so and propose where it lands.

## Constraints

- Never delete existing methodology (pre-registration, funnel-diagnosis
  structure, Kohavi trust-gate order) — only add or tighten.
- `metric_value`'s spec-level rule ("must resolve to an actual computed
  figure ... no fabricated figures", `checked_by:
  on-the-record/hooks/role-spec-reference-guard.sh`) is enforced by a
  hook outside this repo. This rulebook's job is to name the field and
  require its presence/shape in the funnel-diagnosis section, not
  reimplement that guard.
- `recomputation`'s enforcement is explicitly `checked_by: TBD` in the
  spec (follow-up per issue-521) — this proposal states the rule in docs
  but does not build a new enforcement gate for uniqueness-across-records.
- Acceptance requires the loop_state vocabulary to match the spec set
  **exactly** — no stale or extra states — which is a stronger bar than
  "mentioned somewhere"; it requires an actual per-kind terminal-state
  declaration, since core's generic contract states don't carry these
  words.

## Rationale

Two placement questions had real alternatives:

1. **Where do `funnel_stage`/`is_north_star`/`metric_value` live?**
   Considered creating a brand-new plugin (`ga-northstar`) parallel to
   `ga-prereg`/`ga-funnel`/`ga-trust`, each owning one field. Rejected:
   the scout brief's must-be is that NSM sits *above* AARRR as a
   cross-cutting flag on a metric, not an independent methodology step —
   a separate plugin would treat it as a fourth Kohavi-style procedure it
   isn't. Instead, `funnel_stage` and `is_north_star` extend the existing
   `ga-funnel` gate's funnel-diagnosis section (the section that already
   deals in per-stage numbers), and `metric_value` is documented as the
   record-level machine-checkable figure that section's numbers must
   resolve to. This keeps AARRR-stage vocabulary and NSM flagging in the
   one place that already validates funnel structure, instead of
   fragmenting enforcement across a new plugin.

2. **How to satisfy the "vocabulary matches exactly" loop_state
   acceptance check?** Considered leaving loop_state purely as prose in
   the handbook (cheaper, no new file). Rejected: the acceptance check is
   mechanical (`grep` for field names, and a vocabulary-match check) and
   this repo already has the extension point core defines for exactly
   this purpose — `docs/specs/record-fields-terminal-states.json`, a
   `{kind: [states]}` override file the interaction-protocol contract
   explicitly reads per-kind. Declaring a `growth-analytics` kind row
   there — `progress: [measuring, reviewing]`, `terminal: [landed]`,
   `refusal: [stage-undeclared]`, `error: [analytics-data-unreachable]` —
   both satisfies the exact-match requirement and reuses core's designed
   mechanism instead of inventing a parallel one.

## What will be done

1. `docs/handbooks/growth-analytics-plugins.md`: add a "Record field
   vocabulary (issue-17)" section listing `funnel_stage` (enum:
   acquisition/activation/retention/referral/revenue, must appear in the
   funnel-diagnosis section's stage-pair lines), `metric_value` (the
   computed figure a stage-pair or NSM line resolves to — sourced from
   real analytics data, never fabricated), and `is_north_star`
   (true/false flag; at most one `true` across all growth-analytics
   records at a time, recomputed per new record — enforcement of the
   uniqueness rule is a stated follow-up, not built here). Also document
   the five-word `loop_state` vocabulary and which bucket each belongs to.
2. `README.md`: add the three field names and the loop_state set to the
   role summary so `grep -ri <field> docs/ README.md` finds each at the
   repo root, not only inside a handbook.
3. `ga-funnel/hooks/ga-funnel-gate.sh`: extend the existing stage-pair
   check to require the stage-pair line name one of the five canonical
   `funnel_stage` labels (directly, or via an explicit
   "stage N = <label>" mapping declared earlier in the section), and add
   a check that the section states an `is_north_star` flag anchored to a
   specific metric line with an explicit `true`/`false` value (e.g. a
   `is_north_star: true|false` labeled line attached to a named metric),
   not a bare substring match on the phrase "is_north_star" — the gate's
   existing checks (stage/event definitions, bottleneck hypothesis) are
   already anchored to a labeled pattern rather than a loose
   `has_any(...)` substring test, and this new check must follow that
   same anchored shape, not the file's looser substring idiom, to avoid
   being satisfiable by mentioning the field name with no real value
   attached. Update `ga-funnel/hooks/tests/run-gate-tests.sh` with
   passing/failing cases for both additions, including a case that a
   bare mention of "is_north_star" with no value is rejected.
4. `growth-analytics/hooks/directive.sh`: mention the three required
   fields and the loop_state vocabulary in the composed SessionStart
   directive text, so a session sees them before it starts writing a
   record.
5. `docs/specs/record-fields-terminal-states.json`: add a `growth-analytics`
   key with `{"progress": ["measuring", "reviewing"], "terminal":
   ["landed"], "refusal": ["stage-undeclared"], "error":
   ["analytics-data-unreachable"]}`, matching the spec's `loop_state`
   object exactly.

## Out of scope

- Building the `metric_value` reference-resolution guard itself (that
  lives in `on-the-record/hooks/role-spec-reference-guard.sh`, outside
  this repo).
- Building enforcement for the "exactly one `is_north_star=true` across
  all records" recomputation rule — spec marks this `checked_by: TBD`
  and out-of-scope pending real-usage evidence (issue-521 note).
- Any new plugin/methodology step. This proposal only extends
  `ga-funnel` and the shared docs — `ga-prereg` and `ga-trust` are
  untouched, since neither field-set concerns pre-registration ordering
  or trust-verdict ordering.

## How you'll know it worked

- `grep -ri funnel_stage docs/ README.md`, `grep -ri metric_value docs/
  README.md`, `grep -ri is_north_star docs/ README.md` each return at
  least one hit after phase 2.
- `docs/specs/record-fields-terminal-states.json`'s `growth-analytics` row
  is exactly `{measuring, reviewing, landed, stage-undeclared,
  analytics-data-unreachable}` — no stale or extra state.
- `bash ga-funnel/hooks/tests/run-gate-tests.sh` passes, including new
  cases for the `funnel_stage` enum check and the `is_north_star`
  presence check.
- No existing test in `ga-prereg`, `ga-funnel`, or `ga-trust` regresses
  (all three harnesses still exit 0).
