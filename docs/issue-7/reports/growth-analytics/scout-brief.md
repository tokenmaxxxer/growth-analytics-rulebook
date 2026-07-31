# Scout brief: mechanical enforcement patterns for document-norm gates (issue-7)

Subject: issue-7. Lightweight scout pass on how PreToolUse gates
mechanically verify document-norm compliance and enforce workflow
ordering, informing this issue's methodology-gate + state-tracking
design. Search was run **sequentially** (each lookup read in full before
the next was issued, since later lookups were chosen based on what the
earlier ones turned up — e.g. reading `pricing`'s gate before deciding
whether `implementation-rulebook`'s state files were also worth reading),
not in parallel.

## Must-bes (non-negotiable for this issue's gate design)

- **Fail-closed on internal error**, not just on a missing field.
  `pricing/hooks/methodology-gate.sh` wraps its Python body in
  `try/except` that exits 2 on any exception, plus a shell-level
  `trap __fc EXIT` that also exits 2 on any non-{0,2} exit — a gate that
  silently exit-0s on a traceback is a false sense of enforcement.
- **Root-resolve before trusting a path**, not just use `cwd`.
  Both `pricing`'s gate and `implementation-rulebook`'s harness resolve
  `CLAUDE_PROJECT_DIR` (validated as plausible: has `.git` or a known
  repo file) with a `git rev-parse --show-toplevel` fallback, then
  require the target path to resolve *inside* that root before acting.
- **Reconstruct the resulting content, not just the diff.** All gates
  surveyed (this role's own two, plus `pricing`'s) handle `Write`
  (full content), `Edit` (apply one replacement), and `MultiEdit` (apply
  all-or-nothing) to get the *post-write* text before checking it — a
  gate that only checks `new_string` would miss content already present
  from a prior write.
- **Presence checks are done as keyword/needle checks over lowercased
  text**, never as an LLM judgment call inside the gate — this is
  consistent across every gate read (`output-components-gate.sh`,
  `proposal-preregistration-gate.sh`, `pricing/methodology-gate.sh`). A
  mechanical gate must stay mechanical or it isn't actually enforcement.

## Performance / design axes

- **Ordering/state tracking is the one capability none of growth-
  analytics's, pricing's, or performance-engineering's existing gates
  have** — all three are stateless, single-write presence checks.
  `implementation-rulebook/coding/hooks/state.sh` + `hunt-state.sh` are
  the only found examples of session-scoped state files (used for
  hunt-cycle tracking, not methodology ordering) — the pattern (a
  small state file under a scratch/session-scoped path, read-then-write
  by each gate invocation) is reusable in shape, not in content, for
  tracking "has SRM been checked yet" ahead of allowing an effect-size
  claim.
- **Test harness shape**: `implementation-rulebook/tests/run-gate-tests.sh`
  spins up a disposable `git init`'d temp dir per case, feeds a
  synthetic `PreToolUse` JSON payload (`tool_name`/`tool_input`/`cwd`) on
  stdin to the gate script directly, and asserts exit code (0=allow,
  2=deny). This is the adoptable pattern for issue-7's designed test
  suite — no framework dependency, pure bash + the gate under test.

## Adopt / skip

- **Adopt**: fail-closed-on-internal-error wrapper (currently absent
  from this role's two gates — a real gap this issue's design should
  close for the new methodology gate); root-resolution-before-trust;
  content-reconstruction across Write/Edit/MultiEdit; keyword/needle
  presence checks; the disposable-repo-per-test-case harness shape.
- **Skip**: adopting a queueing/lock-file mechanism for concurrent
  writers — no evidence any rulebook plugin needs it (single-session,
  single-writer assumption holds everywhere surveyed); skip inventing a
  new named framework for state tracking — a flat marker file (e.g. one
  line per completed Kohavi step) is sufficient and matches the state.sh
  precedent's simplicity.

## Gap line

No surveyed rulebook (growth-analytics, pricing, performance-engineering,
implementation-rulebook) has a PreToolUse gate that enforces cross-write
*ordering* of a multi-step methodology today — every "ordering" example
found (`hunt-state.sh`) tracks a different kind of session state (hunt
miss-streak), not document-content ordering. This is the concrete gap
issue-7's design proposal is closing for growth-analytics's Kohavi
trust-gate order (SRM → A/A → guardrails → effect/CI → Twyman).

## Sources

- `growth-analytics/hooks/output-components-gate.sh` (this repo, read in full)
- `growth-analytics/hooks/proposal-preregistration-gate.sh` (this repo, read in full)
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh` (read in full)
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/tests/run-gate-tests.sh` (read in full)
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/state.sh` (read in full)
- `/tmp/claude-1000/core-canon2/docs/handbooks/canon-scripts.md` (read in full, reference-not-copy rule)
- `docs/issue-1/proposals/rulebook-maturation.md`, `docs/issue-1/reports/growth-analytics.md` (this repo, normative source, read in full)
