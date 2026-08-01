# Proposal: raise growth-analytics gates to A+ (issue-10)

Subject: issue-10. **Phase 1 proposal only.** No hook script, test
file, or README edit lands in this PR — this document is the design for
review. Phase 2 (writing the actual patches) opens only after a human
review decision recorded per the interaction protocol referenced in
`docs/specs/approvers.md` and `docs/issue-7/proposals/growth-analytics.md`
(a PR review sign-off or the issue-comment convention from an account
listed in `docs/specs/approvers.md`, currently `JiwonJung94`). Nothing
in this document changes role boundaries, `write_scope` (`[]`,
unchanged), or ships code.

**Open dependency, stated up front:** issue #10 itself makes phase 2
conditional on "core issue #72 (게이트 하우스 표준: 공유 라이브러리·표준
하네스·준수 검출기)" landing first, with the instruction to reference that
library rather than reimplement it. As documented in `docs/issue-10/
reports/growth-analytics/survey.md` section 1 and `docs/issue-10/
reports/growth-analytics/scout-brief.md` (b)/(c), neither `core/hooks/
lib/gate-lib.sh` nor `docs/handbooks/gate-house-standard.md` exists in
this repository as of this proposal, and `gh issue view 72` does not
resolve here. This proposal is therefore written at the design-intent
level ("reference-adopt whatever gate-lib.sh exposes for X") rather than
naming concrete function signatures from a library that does not yet
exist. Phase 2 implementation is blocked on both (i) a human review
decision on this proposal and (ii) core issue #72 landing with its
shared library available to import from.

## 1. Defect-by-defect fix plan

### 1.1 Magic-phrase gate-arming (ga-trust)

**Defect:** `ga-trust/hooks/ga-trust-gate.sh:127-128` arms the entire
5-step state machine only if the literal substring "experiment trust
verdict" (or its hyphenated form) appears anywhere in the whole
lower-cased document. No section boundary exists.

**Fix approach:** Replace the whole-document substring test with a
heading-anchored section locator: find a markdown heading line (e.g.
`^#{1,6}\s*.*experiment trust verdict`, case-insensitive) and capture
the text from immediately after that heading up to the next
same-or-higher-level heading or end-of-document. All five step checks
(SRM, A/A, guardrails, effect-CI, Twyman) then run **only** against that
captured span, not against `low` (the whole file). This directly
generalizes the one existing good precedent in this codebase — the
recommendation-bullet extraction in `ga-funnel/hooks/ga-funnel-gate.sh:
141-147` (cited in `scout-brief.md` (a)) — to a full section boundary
(heading-to-next-heading) rather than that pattern's narrower
blank-line-bounded capture.

**Reference-adopt vs. reimplement:** Because no `gate-lib.sh` exists
yet, this proposal cannot name a concrete shared function. The design
commitment is: this "extract section by heading, bounded by next
heading" logic is exactly the kind of cross-plugin utility a shared
gate library should own — all three gates need it (ga-prereg for its
proposal-shape checks, ga-funnel for its funnel-diagnosis section,
ga-trust for its verdict section). Phase 2 must check whether
`gate-lib.sh` (once landed) already exposes a section-extraction helper
before writing one locally; if it does, that helper is reference-adopted
verbatim, not re-derived from this proposal's pseudocode.

### 1.2 Twyman cross-check: arbitrary proposal + ignored units

**Defect:** `ga-trust/hooks/ga-trust-gate.sh:172-196` — `os.listdir()`
over `docs/issue-<n>/proposals/` in undefined order, first `.md` file
with an `expected effect` match wins; and the `(pp|%)` unit capture
group is parsed but never compared against the report side's unit.

**Fix approach, two independent sub-fixes:**

- **Deterministic + linked proposal selection.** Two acceptable
  strategies, either is conservative and reviewable: (i) sort the
  directory listing (`sorted(os.listdir(...))`) so behavior is at least
  deterministic and reproducible run-to-run — this alone does not fix
  "which proposal is the right one" but removes the nondeterminism; or,
  preferably, (ii) require the trust-verdict section to name the
  specific proposal file it is validating against (e.g. a labeled line
  such as `Proposal: docs/issue-<n>/proposals/<name>.md`) and have the
  gate read *only* that named file — denying (not silently skipping)
  when the section reports an effect-size verdict but names no proposal
  file, or names one that does not exist. This document recommends (ii)
  as the actual fix, with (i) noted only as the minimum-viable fallback
  if (ii) proves out of scope for phase 2's first cut.
- **Unit-aware comparison.** Both the report-side effect-size regex and
  the proposal-side expected-effect regex must capture their unit group
  and the comparison must require the units to match (both `pp`, both
  `%`, or both bare/unspecified-and-treated-as-the-same-declared-unit)
  before computing `ratio`. If units differ or either side omits a unit
  where the other states one, deny with a message naming the mismatch
  explicitly (e.g. "cannot compare effect size 3% against expected
  effect 3pp — units differ or are unstated; state both in the same
  unit") rather than silently comparing bare numbers.

**Reference-adopt:** if `gate-lib.sh` provides a generic "locate the
governing artifact for this issue number" helper (plausible, since
ga-prereg/ga-funnel/ga-trust all key off `issue-<n>` directories), reuse
it instead of hand-rolling directory resolution again.

### 1.3 README documents nonexistent gates

**Defect:** root `README.md` "Layout" section lists `growth-analytics/
hooks/record-fields-gate.sh`, `trailer-gate.sh`, `handbook-trigger-
gate.sh` — none exist. The three real gates (`ga-prereg-gate.sh`,
`ga-funnel-gate.sh`, `ga-trust-gate.sh`) and their kill switches are
undocumented in the root README (they live only in `docs/handbooks/
growth-analytics-plugins.md`).

**Fix approach:** Remove the three ghost-file bullets. Add bullets for
the three real gate scripts (one line each: plugin dir, script path,
one-sentence purpose) and a pointer to `docs/handbooks/
growth-analytics-plugins.md` for the full kill-switch list and test-run
instructions, rather than duplicating that list in two places. This is
a documentation-only change; it reference-adopts nothing from
gate-lib.sh since it is not gate logic.

### 1.4 Absolute-path normalization

**Defect:** all three gates normalize lexically
(`os.path.normpath` + `os.path.commonpath`) but never call
`os.path.realpath`, so a symlink inside the repo tree can point outside
`root` and pass the containment check on its lexical (pre-resolution)
path while writing outside the intended tree.

**Fix approach:** containment check becomes
`os.path.commonpath([os.path.realpath(root), os.path.realpath(abspath)])
== os.path.realpath(root)` — resolve both sides through symlinks before
comparing, not just `normpath`. Note this must resolve `abspath`'s
*existing* parent directories (the file itself may not exist yet on a
Write to a new path) — realpath on a nonexistent leaf still resolves
correctly in Python 3 (it resolves as far as it can and appends the
remainder), so this is safe to apply unconditionally.

**Reference-adopt:** this exact containment check is duplicated
identically three times today (survey.md section 7) — canonical
candidate for a `gate-lib.sh` shared function; phase 2 should check for
one before writing a fourth (or now fixed, still duplicated) copy.

### 1.5 Fail-closed: trap-at-top, malformed-JSON deny, kill-switch default

- **Trap-at-top:** move `trap __fc EXIT` to the first line after `set
  -uo pipefail`, before the kill-switch case statement and before
  `command -v python3`, so that *any* unexpected non-zero/non-2 exit
  from anywhere in the script — including the currently-unguarded
  kill-switch/python3-check preamble — is caught fail-closed rather than
  only errors after the trap is installed.
- **Malformed-JSON deny:** already correct (survey.md section 6);
  proposal is to keep this logic as-is and, once available, source it
  from `gate-lib.sh` instead of the three near-identical copies.
- **Kill-switch unrecognized value stays enabled:** invert the current
  `case` default. Proposed shape:
  ```bash
  case "${GA_PREREG_GATE_OFF:-}" in
    ""|0|false|no|off) ;;      # recognized off-value: gate stays ENABLED (default/absent case)
    1|true|yes|on) exit 0 ;;   # recognized on-value: gate DISABLED
    *) ;;                       # unrecognized value: gate stays ENABLED (fail closed)
  esac
  ```
  This is a behavior-reversing fix and must ship with an explicit test
  case (section 3) proving an unrecognized value (e.g. `maybe`, a
  trailing-space variant) does **not** disable the gate.

### 1.6 Edit/MultiEdit/replace_all full reconstruction

**Defect:** no gate script reads `tool_input.replace_all`; all `Edit`
reconstructions use `str.replace(o, n, 1)` (count=1) unconditionally,
which diverges from the actual write whenever `replace_all: true` is
set.

**Fix approach:** read `use_all = ti.get("replace_all", False)` (a
missing key defaults to Claude Code's own default of a single replace)
for `Edit`, and reconstruct with `current.replace(o, n) if use_all else
current.replace(o, n, 1)`. For `MultiEdit`, each edit dict in `edits`
carries its own optional `replace_all` key — apply the same per-edit
logic inside the existing loop, not a single flag for the whole batch.
If `replace_all: true` and `old_string` occurs zero times, that is
still the existing "could not reconstruct" deny path (no occurrences to
replace is already treated as a failure for `Edit`; extend the same
reasoning to `MultiEdit`'s per-edit loop).

### 1.7 Deny reason to stderr

Already correct in all three scripts (survey.md section 6) — no change
proposed beyond folding the `deny()` helper into the shared library once
available, to remove the three duplicate copies.

## 2. Semantic-check upgrades (substring → section/adjacency/structural)

This section is the direct answer to issue #10 requirement (2). Three
distinct upgrade classes, applied per gate:

### 2.1 Section-scoped matching

Every check that currently searches `low` (the whole document) must
instead search only within the span belonging to the section it claims
to validate. Concretely:

- **ga-trust:** locate the "experiment trust verdict" section (1.1
  above); run all five step regexes only inside that span.
- **ga-funnel:** locate the "funnel diagnosis" section the same way,
  before running `has_any("stage definition", ...)`,
  `stage_pair_pattern`, `seg_section`, `hyp_match`, and the
  recommendation extraction — today only the recommendation extraction
  is section-scoped (to its own sub-heading); the other four checks
  still scan the whole document once the top-level "funnel diagnosis"
  gate-arm has fired.
- **ga-prereg:** locate whichever section the document declares as its
  experiment-shaped content (this file has no single named section
  today — the keyword pre-gate just checks the whole document for
  experiment- and action-shaped words). Proposal: require that content
  to live under an identifiable heading (matched against a configurable
  allow-list, e.g. "Experiment Proposal" / "Recommendation") and scope
  the labeled-line regexes to that span.

### 2.2 Adjacency / ordering checks

- **ga-trust SRM-before-effect-size:** today this is a presence/state
  check (`1 in current_present or 1 in prev_validated`), not a
  positional check. Add a genuine positional check: within the
  extracted verdict section, find the character offset of the SRM
  evidence (chi-square line) and the character offset of the
  effect-size line; deny if the effect-size offset is smaller (i.e.
  effect-size text appears earlier in the document than SRM evidence),
  even if both are present. This is additive to the existing
  presence-based check, not a replacement — presence-based ordering
  across separate writes (the state-machine's whole purpose) still
  matters for the case where SRM was validated in an earlier commit and
  this write only adds effect-size content.
- **ga-funnel stage-pair proximity:** already has line-local proximity
  (`[^\n]{0,60}`, `[^\n]{0,80}` bounds) — once section-scoped (2.1), this
  becomes a real adjacency check rather than a whole-document lucky
  match. No further change proposed to the proximity distances
  themselves; they are a reasonable existing choice.

### 2.3 Structural checks — labeled line with a substantive value, not just a heading

Audit finding (per issue #10's explicit callout, paraphrased: whether
ga-prereg's current implementation actually enforces this, or just
claims to): **partially.** `primary metric\s*[:\-]\s*\S` (line 114) and
`decision rule\s*[:\-]\s*\S` (line 139) genuinely require a
non-whitespace character after the label — a bare heading with nothing
after the colon fails these two. But `has_any("hypothesis")` (line 118)
and `has_any("power analysis", "mde", "80% power", "power basis")`
(line 132) are bare word-presence checks with no labeled-line
requirement at all — a document containing the word "hypothesis"
anywhere (e.g. in a sentence noting that no hypothesis exists yet)
currently satisfies that half of the check. Fix: convert every "does X
exist" check in ga-prereg to the same `label\s*[:\-]\s*\S` shape already
proven for `primary metric` and `decision rule` — e.g.
`hypothesis\s*[:\-]\s*\S` combined with the existing
effect-magnitude regex (already correctly labeled-line shaped), and a
labeled `power basis:` line rather than bare word-presence over four
synonym strings.

## 3. Mandatory test cases

Each subsection gives at least one passing and one failing example, and
edge cases named in issue #10 (ordering violations, section-boundary
leakage, missing guardrail-bound reuse).

### 3.1 Section-boundary leakage (ga-trust)

**Failing case — today's bug, must be denied under the fix:** a
document with an unrelated appendix textually before the real verdict
section, containing a bare statistical-test mention with no bound
attached, followed later by the real verdict section:

```
## Appendix: unrelated notes
Some background on statistical testing methodology, unrelated to this
issue's verdict.

## Experiment Trust Verdict
Guardrails: latency (no bound stated)
```

Should deny — no SRM evidence, A/A status, effect size, or Twyman flag
exists anywhere inside the Experiment Trust Verdict section itself, and
a section-scoped check must not credit content from the Appendix
section even if it superficially resembles step evidence.

**Passing case:**

```
## Experiment Trust Verdict
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
A/A validation: validated
Guardrails: latency delta +2ms, bound <= 10ms
Effect size: +3% CI 1%-5%
Twyman: unconfirmed, pending independent check
```

All five steps' evidence lives inside the section span; should pass
(assuming section 3.2's ordering check also holds).

### 3.2 Ordering violation (ga-trust, SRM before effect size)

**Failing case:**

```
## Experiment Trust Verdict
Effect size: +8% CI 5%-11%
SRM check: chi-square test, expected 5000/5000, observed 5012/4988, p-value 0.41
```

The effect-size line appears before the SRM line within the section;
should deny with a message naming the positional violation, even though
both pieces of evidence are present.

**Passing case:** same content, SRM line first (as in 3.1's passing
case) — should pass this check (other checks still apply
independently).

### 3.3 Twyman unit mismatch

**Failing case:** the linked proposal states an expected effect of
`+3pp`; the verdict section states an effect size of `+6%`.
Numerically `6/3 = 2.0`, right at today's `ratio > 2` boundary — but
because the units differ (`pp` vs `%`), the comparison itself is
invalid regardless of the numeric ratio. Should deny with a
unit-mismatch message rather than attempt the ratio math.

**Passing case:** the linked proposal states `+3pp`; the verdict states
`+4pp CI 2pp-6pp` (same unit, ratio 1.33, under threshold, Twyman flag
not required). Should pass.

### 3.4 Twyman proposal-selection ambiguity

**Failing case (today's bug):** `docs/issue-99/proposals/` contains two
files, `old-draft.md` (a superseded draft, states a much larger expected
effect) and `current.md` (the live proposal, states a small expected
effect). The verdict section states an effect size with no proposal
reference at all. Under the fix (section 1.2, option ii), this must
deny for "no proposal named" rather than silently reading whichever of
the two `os.listdir()` happens to return first.

**Passing case:** the verdict section contains a labeled line naming
exactly which proposal file it is validating against; the gate reads
only that file's expected effect for the ratio comparison, ignoring the
superseded draft entirely.

### 3.5 Guardrail bound presence (ga-prereg)

**Failing case:** a document that names two guardrail metrics, where
only the second states a numeric bound and the first states only a
metric name with nothing else — should deny naming the specific
unbounded guardrail line, even though a second guardrail line in the
same document does state a bound. (This is already ga-prereg's intended
behavior; the mandatory test case is to assert it, since no existing
test exercises multiple guardrail lines where only one has a bound.)

**Passing case:** an illustrative pre-registration write-up where every
required labeled item carries a value and both guardrail lines state
their own bound:

```
Primary metric: activation rate
Hypothesis: faster onboarding raises activation, expected effect +2pp
Sample size: 12000 per arm
Duration: 14 days
Power basis: 80% power, MDE 2pp
Guardrail: latency, bound <= 200ms
Guardrail: error rate, bound <= 1%
Decision rule: activation rate delta >= 2pp at 95% confidence, practical significance threshold 1.5pp
```

Should pass.

### 3.6 Edit/MultiEdit/replace_all reconstruction

**Failing case (today's bug):** an `Edit` tool_input where `old_string`
occurs twice in the current file content and `replace_all: true` is
set. Today's reconstruction (`current.replace(o, n, 1)`, count always
1) replaces only the first occurrence regardless of `replace_all`, so
the gate validates against a reconstruction that diverges from what
Claude Code will actually write. Concrete assertable case: with
`replace_all: true` and 2 occurrences of `old_string`, the fixed gate's
reconstructed content must show both occurrences replaced — a test
asserting the reconstructed content itself (not just the exit code)
equals the fully-replaced string is required.

**Passing case:** an `Edit` with `replace_all: false` (or the key
absent) and 2 occurrences of `old_string` — reconstructed content
replaces only the first occurrence, matching real Claude-Code
Edit-without-`replace_all` semantics.

### 3.7 Malformed JSON

**Failing case:** a truncated/invalid JSON payload on stdin — must exit
2 with a stderr message identifying it as malformed.

**Passing case (control):** well-formed JSON whose `tool_name` is not
`Write`/`Edit`/`MultiEdit` (e.g. `Read`) — must exit 0 silently (gate
does not engage for read-only tools).

### 3.8 Kill switch unrecognized value

**Case proving the gate stays ON (the behavior-reversing fix):** an
unrecognized kill-switch value (e.g. `maybe`) combined with an
otherwise gate-violating payload — must still exit 2 (gate stayed
active), not exit 0.

**Passing-to-disable case (control):** a recognized on-value for the
kill switch combined with the same violating payload — must exit 0
(gate correctly disabled by a recognized value).

### 3.9 Absolute path

**Failing case:** `file_path` given as an absolute path resolving
outside the project root — must deny with a message naming the
out-of-root condition, regardless of whether the path is expressed
absolutely or relatively.

**Passing case:** `file_path` given as an absolute path that *is*
inside the project root (the full absolute form of an in-scope
relative path) — must be treated identically to the equivalent
relative-path case (same pass/deny outcome, not skipped or
double-normalized incorrectly).

## 4. README realignment (proposed content, not applied here)

Proposed replacement for the root `README.md` "Layout" section's
gate-related bullets (illustrative diff, not applied in this PR):

```diff
- - `growth-analytics/hooks/record-fields-gate.sh` — this role's record required-field gate
- - `growth-analytics/hooks/trailer-gate.sh` — commit `Subject: issue-<n>` trailer gate
- - `growth-analytics/hooks/handbook-trigger-gate.sh` — s21 handbook-sync gate
+ - `ga-prereg/hooks/ga-prereg-gate.sh` — pre-registration-first gate on experiment proposals
+ - `ga-funnel/hooks/ga-funnel-gate.sh` — funnel-diagnosis structure gate
+ - `ga-trust/hooks/ga-trust-gate.sh` — Kohavi trust-gate order gate on experiment-trust verdicts
+ - see `docs/handbooks/growth-analytics-plugins.md` for kill switches, test-run commands, and session-state details
```

## 5. Phase boundary

This document proposes design only. It does not:

- modify `ga-prereg/hooks/ga-prereg-gate.sh`, `ga-funnel/hooks/
  ga-funnel-gate.sh`, `ga-trust/hooks/ga-trust-gate.sh`, any
  `run-gate-tests.sh`, or `README.md`;
- assume the existence of, or invent internals for, `core/hooks/lib/
  gate-lib.sh` or `docs/handbooks/gate-house-standard.md` — both remain
  unlanded dependencies as of this writing (survey.md section 1,
  scout-brief.md (b)/(c));
- open phase 2. Phase 2 (implementing sections 1-4 above as actual
  patches to the three gate scripts, their test suites, and the root
  README) is gated on a recorded review decision per the interaction
  protocol in `docs/specs/approvers.md`, and separately blocked on core
  issue #72 landing so that phase 2 can reference-adopt its shared
  library rather than re-deriving the duplicated logic in survey.md
  section 7 a fourth time.

Until both conditions are met, no hook script in this repository should
be modified on the strength of this document alone.
