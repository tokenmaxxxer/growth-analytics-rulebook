# Survey — issue #20 (test-env resolution adoption)

## Scout skip record
Skipped: pure adoption of an already-landed cross-repo convention
(on-the-record docs/specs/test-env-resolution.md, issue #551) — the spec
leaves no product-shaped design decision open, only an implementation
choice within this repo (bash-inline vs. cross-repo python import),
covered below.

## Convention (on-the-record docs/specs/test-env-resolution.md)
Resolution order: `$CLAUDE_PLUGIN_ROOT_CORE` (must contain non-empty
`hooks/lib/gate-lib.sh`) → first caller-supplied sibling candidate with
the same file → SKIP. SKIP prints
`SKIP: core plugin unreachable — unverifiable outside spawn env` to
stderr and exits `75` (EX_TEMPFAIL), distinct from a gate's own 0/1/2.
Reference implementation is `gates/test_env_resolve.py` in the
on-the-record repo; adoption note for "Bash test runner" shape says
invoke it as `python3 -m gates.test_env_resolve <candidates...>` and
branch on exit code — but that module lives in a separate repo with no
vendoring mechanism into this one, so a cross-repo Python import is not
available to these bash scripts.

## Current state (this repo)
Only 3 test scripts exist, all bash test runners:
- `ga-funnel/hooks/tests/run-gate-tests.sh` (209 lines, 17 cases)
- `ga-trust/hooks/tests/run-gate-tests.sh` (271 lines)
- `ga-prereg/hooks/tests/run-gate-tests.sh` (193 lines)

Each invokes its own gate script (`ga-*-gate.sh`) as a subprocess per
test case. Each gate script sources core's `gate-lib.sh` via:
```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh" \
  || { echo "...: cannot source gate-lib.sh" >&2; exit 2; }
```
i.e. the gate itself already fails closed (exit 2) when core is
unreachable — that is correct/existing behavior and must not change.

The test *runners*, however, assume core is always reachable (spawn env,
`CLAUDE_PLUGIN_ROOT_CORE` set). They have no upfront resolution step.
Confirmed by direct run with `CLAUDE_PLUGIN_ROOT_CORE`/`CLAUDE_PLUGIN_ROOT`
unset and no `../core` sibling present:
```
$ unset CLAUDE_PLUGIN_ROOT_CORE CLAUDE_PLUGIN_ROOT
$ bash ga-funnel/hooks/tests/run-gate-tests.sh
...
ga-funnel: 5 passed, 12 failed
```
12 of 17 cases misreport as FAIL (they expected exit 0 from a
functioning gate, or a specific rejection message that "cannot source
gate-lib.sh" doesn't contain) — exactly the false-signal problem issue
#551/#20 describes. The two case groups that do pass by coincidence are
the ones that already expect exit 2 for unrelated reasons (missing-core
test itself, and Bash-write-denied, which also happens to hit the exit-2
sourcing failure path before reaching its own check).

No script currently references `test-env-resolution` or implements any
SKIP contract. `grep -r test-env-resolution .` over this repo returns
nothing.

## Write set (confirmed, matches proposal)
- `ga-funnel/hooks/tests/run-gate-tests.sh`
- `ga-trust/hooks/tests/run-gate-tests.sh`
- `ga-prereg/hooks/tests/run-gate-tests.sh`

No shared `lib/` directory exists across the three plugin trees
(`ga-funnel`, `ga-trust`, `ga-prereg` are independent `.claude-plugin`
roots with no common hooks lib today) — each script is self-contained,
so a shared bash helper is not an existing pattern to slot into.

## Alternatives considered
1. **Vendor `gates/test_env_resolve.py` into this repo and shell out to
   it via `python3 -m ...`** — matches the doc's literal "Bash test
   runner" adoption recipe most closely. Rejected: the module is
   maintained in on-the-record (issue #551's repo); vendoring a copy
   here creates a second, driftable copy of that logic with no update
   path when on-the-record revises it, and adds a python dependency to
   what are otherwise pure-bash scripts. The doc itself says adoption
   "is separate work per repo" — it doesn't mandate the exact
   Python-CLI mechanism, only the resolution order + SKIP contract.
2. **Inline the same resolution order + SKIP contract directly in bash**
   at the top of each `run-gate-tests.sh`, before any test case runs —
   chosen. Small (~15 lines), no new dependency, same order/message/exit
   code as the convention, and each script already references the
   convention doc path in a comment so `grep -r test-env-resolution`
   finds it (acceptance check 3).
