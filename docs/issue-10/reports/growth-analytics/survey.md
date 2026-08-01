# Survey: issue-10 gate audit defects (growth-analytics)

Subject: issue-10. This is a phase-1 research artifact only — no hook
script is modified here.

## 0. Verbatim audit findings from issue #10

Issue #10 body, "2026-08-01 실물 코드 감사 결과 (등급: B)" section, verbatim:

> 매직 문구('experiment trust verdict') 없으면 상태머신 전체 미발동; Twyman
> 교차검증이 listdir 순서의 임의 proposal 참조·단위 무시; README가 미존재
> 게이트 3종 문서화

And the verbatim "요구 — 전 축 A+ 수준으로" requirements:

> 1. 위 결함 전부 수정. 특히 경로 매칭(절대경로 정규화), fail-closed
>    (trap-at-top, malformed-JSON deny, 킬스위치 비인식 값=활성), Edit/
>    MultiEdit/replace_all 완전 재구성, deny 사유 stderr 전달.
> 2. 시맨틱 검사를 부분문자열에서 섹션/인접성/구조 검사로 상향 — 채택
>    방법론의 판단이 '단어 언급'으로 통과되지 않게.
> 3. 테스트에 Edit/MultiEdit/replace_all/malformed-JSON/킬스위치/절대경로
>    케이스 의무 추가, 배송 상태에서 전 스위트 green.
> 4. README를 실물과 정합화(유령 파일 제거, 실제 플러그인·경로·킬스위치
>    문서화).

And the verbatim precondition:

> core issue #72(게이트 하우스 표준: 공유 라이브러리·표준 하네스·준수
> 검출기)가 랜딩된 뒤 그 라이브러리를 참조해 구현(자체 재구현 금지).

## 1. Precondition status — BLOCKING GAP

`gh issue view 72` returns "Could not resolve to an issue or pull
request with the number of 72" in this repository. A repo-wide search
for `gate-lib` / `gate-house` (file names and in-file references) across
`*.sh` and `*.md` returns nothing. `core/hooks/lib/gate-lib.sh` and
`docs/handbooks/gate-house-standard.md` — the two files this task's
instructions assumed exist — do not exist anywhere in this checkout, and
there is no `core/` tree at all in this repo (see `find . -path
"*/core/*"` → empty). Whatever repo issue #72 lives in, it has not
landed here as of this survey.

This means the issue's own precondition ("implement referencing that
library, do not reimplement it") cannot be satisfied yet: there is no
shared library to reference. Any phase-2 implementation plan is
downstream of core issue #72 landing in this or a linked repo. This
survey and the accompanying proposal (`docs/issue-10/proposals/
gate-a-plus.md`) treat this as an open blocker and design around it
rather than inventing a stand-in library.

## 2. Actual gate scripts read

- `ga-prereg/hooks/ga-prereg-gate.sh` — pre-registration-first check on
  `docs/issue-<n>/proposals/*.md`.
- `ga-funnel/hooks/ga-funnel-gate.sh` — funnel-diagnosis structure check
  on `docs/issue-<n>/reports/growth-analytics.md`.
- `ga-trust/hooks/ga-trust-gate.sh` — Kohavi trust-gate order check on
  the same report path's "experiment trust verdict" section.

Each is a bash wrapper (trap, kill-switch, payload read, root
resolution) around an embedded python3 heredoc that does the actual
parsing. `growth-analytics/hooks/` (the role-glue plugin) has only
`directive.sh` and `hooks.json` — no gate script of its own.

## 3. Defect 1 — magic phrase gates the whole state machine

**Where:** `ga-trust/hooks/ga-trust-gate.sh:127-128`

```python
if not has_any("experiment trust verdict", "experiment-trust-verdict"):
    sys.exit(0)  # section not declared in this write; gate does not engage
```

`has_any` (defined at `ga-trust/hooks/ga-trust-gate.sh:117-118`) is a
plain substring test over `low`, the **entire lower-cased file content**,
not a scoped search within a declared section. Two consequences:

- If the exact literal string "experiment trust verdict" (or its hyphen
  variant) is absent anywhere in the whole document — even if a
  differently-worded section clearly reports SRM/A-A/guardrails/effect
  size — the entire 5-step state machine (`step1`..`step5_flag`,
  lines 130-138) never runs. A document that reports trust-relevant
  content under a heading like "Experiment Trustworthiness" or a Korean
  equivalent silently bypasses every check.
- Conversely, because the match is over the whole file and not scoped to
  a section, the phrase could appear anywhere (e.g. in an unrelated
  changelog note, a table of contents, or a quoted issue excerpt) and
  spuriously arm the gate, or a genuine verdict section could be
  detected but its step regexes (see Defect 4 below) then scan the
  *entire* file rather than that section, picking up content from
  unrelated adjacent sections.

There is no section-boundary concept anywhere in this file: nothing
locates where the "experiment trust verdict" section starts and ends.

## 4. Defect 2 — Twyman cross-check: arbitrary proposal reference, units ignored

**Where:** `ga-trust/hooks/ga-trust-gate.sh:172-196`

```python
prop_glob_dir = os.path.join(root, "docs", "issue-%s" % issue_n, "proposals")
expected_effect = None
if os.path.isdir(prop_glob_dir):
    for fn in os.listdir(prop_glob_dir):
        if not fn.endswith(".md"):
            continue
        ...
        em = re.search(r'expected effect[,:]?\s*\+?(-?[\d.]+)\s*(pp|%)?', ptxt)
        if em:
            expected_effect = float(em.group(1))
            break
```

Two independent bugs, both named in the issue:

- **Arbitrary file selection:** `os.listdir()` has no defined order
  guarantee (in practice it reflects directory-entry/inode order, not
  filename order and not any semantic "which proposal is THE proposal
  for this issue" order). If `docs/issue-<n>/proposals/` has more than
  one `.md` file, whichever one `listdir` happens to return first that
  contains an `expected effect` line wins — not necessarily the
  proposal the trust-verdict report is actually validating against.
  There's no linkage (e.g. a proposal-id reference from the report) to
  pick the *correct* proposal.
- **Units ignored:** the regex captures an optional unit group `(pp|%)`
  at `em.group(2)` but that group is **never read or compared**. Only
  `em.group(1)` (the bare number) is used, at line 179:
  `expected_effect = float(em.group(1))`. Similarly the report-side
  match at `ga-trust/hooks/ga-trust-gate.sh:168` (`eff_match = re.search(
  r'effect size\s*[:\-]?\s*\+?(-?[\d.]+)\s*%?', low)`) also drops any
  unit. So a proposal stating "expected effect: 3pp" and a report
  stating "effect size: 3%" (a totally different, much larger, relative
  quantity if the baseline is small) are compared as equal numbers by
  the `ratio = abs(reported_effect) / abs(expected_effect)` check at
  line 194 — silently wrong whenever units differ or are omitted on one
  side.

## 5. Defect 3 — README documents 3 gates that do not exist

**Where:** root `README.md`, "Layout" section, and `growth-analytics/
hooks/`.

`README.md` states:

```
- `growth-analytics/hooks/record-fields-gate.sh` — this role's record required-field gate
- `growth-analytics/hooks/trailer-gate.sh` — commit `Subject: issue-<n>` trailer gate
- `growth-analytics/hooks/handbook-trigger-gate.sh` — s21 handbook-sync gate
```

`ls growth-analytics/hooks/` shows only `directive.sh` and
`hooks.json` — none of these three files exist anywhere in the repo
(confirmed via repo-wide `find . -iname "README*"` → only the one root
`README.md`, and `find growth-analytics -type f` → only
`.claude-plugin/plugin.json`, `hooks/directive.sh`, `hooks/hooks.json`,
`agents/warrant-hunter.md`). The README also does not mention the three
real, currently-shipping gates (`ga-prereg-gate.sh`, `ga-funnel-gate.sh`,
`ga-trust-gate.sh`) or their kill switches at all — those are documented
only in `docs/handbooks/growth-analytics-plugins.md`, a separate file
the root README does not point to.

## 6. Requirement-by-requirement gap check (issue's "요구" list)

### (1) Path matching / fail-closed / Edit-MultiEdit-replace_all / deny-to-stderr

- **Absolute-path normalization:** all three gates do
  `abspath = norm if os.path.isabs(norm) else os.path.join(root, norm)`
  then `os.path.normpath(abspath)`, and check
  `os.path.commonpath([...]) != os.path.normpath(root)` to deny
  out-of-root paths (e.g. `ga-prereg/hooks/ga-prereg-gate.sh:80-84`).
  This resolves `.`/`..` lexically but does **not** resolve symlinks
  (`os.path.realpath` is never called) — a symlink inside the repo
  pointing outside root, or a symlinked `docs/issue-<n>` directory,
  would pass `commonpath` on the lexical path while writing outside the
  intended tree. This is the concrete gap behind "경로 매칭(절대경로
  정규화)" — normalization is partial (lexical) not full (real-path).
- **fail-closed / trap-at-top:** the bash wrapper puts `trap __fc EXIT`
  *after* the kill-switch check and *after* `command -v python3` /
  `payload="$(cat...)"` calls in all three scripts (e.g.
  `ga-prereg/hooks/ga-prereg-gate.sh:19-31`) — the trap itself is set
  early, but `set -uo pipefail` (no `-e`) means the trap's `$?` check
  only fires on the *last* command's exit code at EXIT, so an
  early non-zero from an intermediate command in the same statement
  (e.g. inside a pipeline before `pipefail` triggers) does not
  necessarily propagate cleanly — this needs the shared harness's
  vetted trap idiom rather than each plugin's own hand-rolled version.
- **malformed-JSON deny:** already present — all three python bodies do
  `try: ev = json.loads(raw) except ValueError: deny(...)` (e.g.
  `ga-trust/hooks/ga-trust-gate.sh:65-68`). This part already meets the
  bar; it should become a reference-adopted helper, not be
  reimplemented per plugin.
  - Also `python3` embeds are launched via
    `command -v python3 >/dev/null 2>&1 || deny "..."` — this is
    correct fail-closed shape but duplicated identically in all three
    scripts (see section 7).
- **kill switch unrecognized value = active (must deny/enable gate, not
  silently disable):** current behavior is the opposite of the
  requirement. All three scripts do:
  ```bash
  case "${GA_PREREG_GATE_OFF:-}" in
    ""|0|false|no|off) ;;
    *) exit 0 ;;
  esac
  ```
  Any *unrecognized* non-falsy value (e.g. `GA_PREREG_GATE_OFF=maybe`,
  or a typo like `GA_PREREG_GATE_OFF=1 ` with trailing space, or any
  string at all) currently falls into the `*)` branch and **disables**
  the gate (`exit 0`). The issue's requirement is the reverse: an
  unrecognized value should be treated as "kill switch not affirmatively
  requesting off" — i.e. gate stays **active** — with only the exact
  documented falsy/enable values or exact documented disable value(s)
  changing gate state. This is a genuine, currently-unmet defect in all
  three gates identically.
- **Edit/MultiEdit/replace_all full reconstruction:** `Edit` handling in
  all three scripts (e.g. `ga-funnel/hooks/ga-funnel-gate.sh` python body)
  reads `old_string`/`new_string` and does
  `current.replace(o, n, 1) if o else (current + n)` — a **single**
  replacement (`, 1` count), matching Claude Code's default Edit
  behavior (`replace_all` unset/false). None of the three scripts ever
  read `tool_input.get("replace_all")`. If `replace_all` is `true`, the
  actual edit replaces every occurrence, but the gate's reconstruction
  still only replaces the first occurrence — so the gate is validating
  against a fabricated post-write string that materially diverges from
  what will actually be written whenever `replace_all: true` is set.
  This is an unambiguous defect: `replace_all` is not read at all in
  any of the three gate scripts.
- **deny reason to stderr:** already correctly done — `deny()` in all
  three scripts writes to `sys.stderr` (Python) and the bash-level
  `deny()` also writes to `>&2` (e.g. `ga-trust/hooks/ga-trust-gate.sh:20`).
  This part meets the bar already.

### (2) Substring → section/adjacency/structural checks

- **ga-trust:** section-scoping is entirely missing (Defect 1). Ordering
  ("adjacency") is partially present — the SRM-before-effect-size check
  at `ga-trust/hooks/ga-trust-gate.sh:151-154` compares *membership* in
  `current_present`/`prev_validated` sets, not textual position/adjacency
  in the document. It cannot detect "SRM section appears, but physically
  *after* the effect-size section in the rendered document" as an
  ordering violation if both are merely present — it only checks
  presence-based logical order via the state machine, not line-position
  order within a single write. The issue's phase-1 "adjacency" ask reads
  as: also verify physical section ordering within the document text
  itself, not just presence/state.
- **ga-prereg:** structural checks are labeled-line based already for
  most items (`re.search(r'primary metric\s*[:\-]\s*\S', low)` at
  `ga-prereg/hooks/ga-prereg-gate.sh:114`) — this is a real structural
  check (label + non-empty value), not a bare substring/keyword check,
  and is worth preserving. But it is **not section-scoped**: `low` is
  the whole document, so a "primary metric:" line appearing in an
  unrelated appendix or a quoted example elsewhere in the same file
  would satisfy the check. There's no declared-section boundary (e.g.
  "## Experiment Proposal" heading) that these regexes are confined to.
- **ga-funnel:** has the most structure already — `stage_pair_pattern`
  requires a numeric percentage attributable to a stage-pair mention
  (`ga-funnel/hooks/ga-funnel-gate.sh:112-116`), and the "exactly one
  recommendation" check at `ga-funnel/hooks/ga-funnel-gate.sh:141-147`
  does isolate a `recommendation[s]?` sub-section via
  `re.search(...).group(1)` before counting bullets — this is the one
  place in the three gates that already does section-scoped extraction
  and is worth citing as the internal precedent to replicate elsewhere
  (see scout-brief). But the `has_any("funnel diagnosis", ...)` gate-arm
  check at line 88 has the exact same whole-document substring problem
  as ga-trust's Defect 1, just without an issue-cited name.
- **"단어 언급으로 통과되지 않게" (word-mention alone must not pass):**
  `ga-prereg`'s "structural, not just heading" claim needs an explicit
  audit line: `re.search(r'decision rule\s*[:\-]\s*\S', low)` at
  `ga-prereg/hooks/ga-prereg-gate.sh:139` requires a non-whitespace
  character after the colon, which does reject a bare "Decision rule:"
  heading with nothing after it — this one item genuinely enforces
  "labeled line with a substantive value." But several other checks in
  the same file only require the *word* to appear anywhere
  (`has_any("hypothesis")` at line 118, `has_any("power analysis", "mde",
  "80% power", "power basis")` at line 132) with no requirement that the
  word appear attached to a value or even inside the relevant section —
  these are exactly the "word-mention passes" gaps the issue is pointing
  at.

### (3) Mandatory test cases

- `ga-prereg/hooks/tests/run-gate-tests.sh`,
  `ga-funnel/hooks/tests/run-gate-tests.sh`,
  `ga-trust/hooks/tests/run-gate-tests.sh` all use a `mkjson()` helper
  that only ever builds a `Write` tool-input payload
  (`{"tool_name": tool, "tool_input": {"file_path": path, "content":
  content}}`) — grep across all three test files confirms no test
  constructs an `Edit`, `MultiEdit`, or `replace_all` payload, no test
  sends malformed JSON, no test exercises a kill-switch value, and no
  test exercises an absolute file_path. This matches the issue's list
  exactly: all six categories (Edit, MultiEdit, replace_all,
  malformed-JSON, kill-switch, absolute-path) are absent from every
  existing test suite.

### (4) README

Already covered in section 5 — ghost files listed, real gates/kill
switches undocumented in the root README.

## 7. What gate-lib.sh / gate-house-standard.md *should* provide (reference-adopt, not reimplement)

Because neither file exists yet in this repo (section 1), this section
lists what the *issue's own framing* implies such a shared library must
own, based on what is currently duplicated verbatim (or near-verbatim)
across all three gate scripts — i.e. the concrete reimplementation smell
the precondition is trying to prevent:

- Payload read + empty-payload deny (`payload="$(cat 2>/dev/null ||
  true)"; [ -n "$payload" ] || deny "empty tool-use payload"`) —
  identical in all three scripts.
- Project-root resolution (`CLAUDE_PROJECT_DIR` fallback to `git
  rev-parse --show-toplevel`) — identical in all three scripts.
- The bash-level `trap __fc EXIT` / `__fc()` fail-closed wrapper —
  identical in all three scripts.
- `command -v python3 ... || deny "requires python3..."` — identical in
  all three scripts.
- JSON parse + malformed-JSON deny, tool/tool_input type-narrowing — near
  identical in all three python bodies.
- Path normalization + root-containment check (`os.path.commonpath`) —
  near identical in all three python bodies (and all three share the
  same partial-normalization gap from section 6).
- The `Write`/`Edit`/`MultiEdit` post-write content reconstruction block
  — near-identical in all three python bodies (and all three share the
  same missing-`replace_all` gap).
- Kill-switch parsing (`case "${VAR:-}" in ""|0|false|no|off) ;; *) exit
  0 ;; esac`) — identical pattern, all three scripts, and all three
  share the same inverted-default gap from section 6.

Every one of these is currently hand-duplicated three times with zero
divergence in intent. This is precisely the kind of shared,
security-relevant logic a `gate-lib.sh` is meant to centralize — the
phase-2 implementation (once core issue #72 lands) should source these
from the library rather than re-authoring them a fourth time inside a
patched `ga-trust-gate.sh` etc. Until that library exists, this survey
does not invent one; the proposal in `docs/issue-10/proposals/
gate-a-plus.md` treats "reference-adopt gate-lib.sh's equivalent of the
above" as an explicit open dependency per fix item, not as something
this phase specifies the internals of.

## 8. Gaps with no existing mitigating logic at all

- **replace_all handling:** zero logic anywhere reads `replace_all`;
  this is a pure gap, not a partial implementation.
- **Symlink-aware real-path containment:** zero logic anywhere calls
  `os.path.realpath`; only lexical `normpath` exists.
- **Section-scoped regex matching:** zero shared concept of "find the
  span of text belonging to declared section X" exists in any of the
  three scripts (ga-funnel's recommendation-bullet extraction is the
  closest partial exception, scoped to one sub-check only).
- **Document-position-based adjacency/ordering check:** zero logic
  compares physical line/character position of one section's evidence
  against another's; ga-trust's ordering check is state/presence-based
  only.
- **Correct-proposal linkage for Twyman cross-check:** zero logic links
  a trust-verdict report to a *specific* proposal file (by id, filename
  convention, or in-document reference) — only "some .md file in the
  issue's proposals dir, in listdir order."
- **README-to-reality consistency check:** nothing in the repo
  automatically verifies the root README's Layout section against the
  actual filesystem; this is presently a fully manual, currently-stale
  document.
