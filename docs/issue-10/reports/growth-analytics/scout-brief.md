# Scout brief: issue-10 semantic-check precedent scan

Subject: issue-10, phase 1. Purpose: find internal precedent (good and
bad) for section/adjacency/structural checks before proposing new ones,
per `docs/handbooks/gate-house-standard.md` as canon for "good" here —
see finding (b) below for why that citation could not be completed as
specified.

## (a) grep all gate scripts for structural-check patterns

Searched: `ga-prereg/hooks/ga-prereg-gate.sh`,
`ga-funnel/hooks/ga-funnel-gate.sh`, `ga-trust/hooks/ga-trust-gate.sh`
(the only `*gate*.sh` files in the repo — `find . -iname "*gate*.sh"`
returns exactly these three plus their three `run-gate-tests.sh`
harnesses; no other plugin under this repo root ships a gate script to
compare against).

Good example to replicate:
- `ga-funnel/hooks/ga-funnel-gate.sh:141-147` — the "exactly one
  recommendation" check isolates a sub-section before counting:
  `rec_section = re.search(r'recommendation[s]?\s*[:\-]?\s*\n?(.*?)
  (\n\n|\Z)', low, re.S)` then counts bullets only inside
  `rec_section.group(1)`. This is the one instance in the whole repo of
  genuine section-scoped extraction (find a heading, capture until a
  blank-line/EOF boundary, operate only within that span). It is the
  concrete pattern to generalize into a shared "extract section by
  heading, bounded by next heading or blank-line-run" helper.
- `ga-funnel/hooks/ga-funnel-gate.sh:112-116` — `stage_pair_pattern`
  requires a numeric percentage to appear adjacent (within ~60-80 chars)
  to a stage-pair mention via `[^\n]{0,60}` bounded lookaround-by-regex.
  This is a weak but real adjacency check (proximity within the same
  line/short span) — better than the pure has-both-words-anywhere
  pattern used elsewhere, worth citing as the adjacency precedent to
  strengthen (bound it to the *correct* section span too, which it
  currently is not).

Bad examples (the pattern to retire):
- `ga-trust/hooks/ga-trust-gate.sh:127-128` and
  `ga-funnel/hooks/ga-funnel-gate.sh:88` — both gate-arming checks are
  `has_any(...)`, a whole-document substring test with zero section
  concept. Same shape, two files, both defective the same way (only one
  is named explicitly in the issue body, but the second is the same
  bug).
- `ga-prereg/hooks/ga-prereg-gate.sh:118,132` — `has_any("hypothesis")`
  and `has_any("power analysis", "mde", "80% power", "power basis")`:
  word-presence-anywhere with no adjacency to a value or section, unlike
  the file's own better `primary metric\s*[:\-]\s*\S` pattern two lines
  above it. The file is internally inconsistent about its own bar.

No `awk`/`sed` usage found anywhere in any gate script — all
section/structural logic that exists is done in the embedded Python via
`re`, never in bash. So there is no bash-level section-scoping pattern
to cite; the precedent to generalize is entirely the Python `re.search`
capture-group-with-boundary style from `ga-funnel`.

## (b) gate-house-standard.md best-practice section

**Could not be read: the file does not exist in this repository.**
`docs/handbooks/gate-house-standard.md` was searched for directly
(`find . -iname "gate-house*"` and a repo-wide grep for `gate-house`) and
returns nothing. This matches the survey's section 1 finding: core issue
#72 ("게이트 하우스 표준: 공유 라이브러리·표준 하네스·준수 검출기"), which
issue #10 names as this file's source, has not landed in this repo (`gh
issue view 72` fails to resolve). Stating this plainly rather than
padding: there is no "canon for good" document to cite yet. The closest
existing analog is `docs/handbooks/growth-analytics-plugins.md` (an
operational reference for the three ga-* plugins, not a cross-role
gate-writing standard) and `docs/issue-7/proposals/growth-analytics.md`
section 3.1 (the fail-closed shape each gate's docstring cites as its
source pattern) — neither is a substitute for the still-unlanded
gate-house standard.

## (c) shared section-detection functions beyond gate-lib.sh

`core/hooks/lib/gate-lib.sh` does not exist and there is no `core/` tree
in this repo at all (`find . -path "*/core/*"` → empty). Broadened the
search to any `hooks/lib` or shared-helper directory anywhere in the
repo: `find . -type d -iname "lib"` and `find . -iname "*.sh" -path
"*lib*"` both return nothing. No other role/plugin in this checkout
(`ga-prereg`, `ga-funnel`, `ga-trust`, `growth-analytics`) ships any
shared library file — each of the three gate scripts is fully
self-contained with its logic duplicated three times (cf. survey
section 7). **Plainly: no other role's plugin has solved semantic
section-detection anywhere in this repo; there is nothing to borrow from
outside the `ga-funnel` precedent found in (a).**

## Net takeaway for the proposal

The only genuine internal precedent for section-scoped/adjacency
checking in this codebase is `ga-funnel`'s recommendation-bullet
extraction and its stage-pair proximity check. The proposal should
generalize that one pattern (heading-bounded `re.search` capture) into
the checks named in issue #10, and should not claim to be "adopting
gate-house-standard.md conventions" for anything beyond the fail-closed
shape already cited in each script's docstring — that broader standard
does not exist in this repo yet.
