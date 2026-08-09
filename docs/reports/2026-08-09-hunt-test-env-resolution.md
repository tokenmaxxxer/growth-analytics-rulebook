---
proposal: docs/issue-20/proposals/2026-08-09-test-env-resolution.md
---

# Hunt record — test-env-resolution

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the proposed export guard "export CLAUDE_PLUGIN_ROOT_CORE to the resolved path (if not already set)" checks whether the var is *set*, not whether it's *valid*, so when CLAUDE_PLUGIN_ROOT_CORE is pre-set to a stale/invalid path, resolve_core() correctly finds a working sibling core but never overwrites the env var — every subsequent gate subprocess in the script still sees the broken original value.
Kind: design-error
Seed: docs/issue-20/proposals/2026-08-09-test-env-resolution.md — "What will be done" section, the `export CLAUDE_PLUGIN_ROOT_CORE ... (if not already set)` clause
cap_seconds: 60
tier: default
diff_stat_lines: 0 (proposal not yet built; logic taken verbatim from proposal text)
started_at: 2026-08-09T09:40:00+09:00
ended_at: 2026-08-09T09:47:00+09:00

### Reproduce
Minimal bash transcription of the proposal's literal resolve_core() logic (order: check `$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh` non-empty -> check `$CLAUDE_PLUGIN_ROOT/../core/hooks/lib/gate-lib.sh` -> else SKIP/exit 75; then `if [ -z "$CLAUDE_PLUGIN_ROOT_CORE" ]; then export CLAUDE_PLUGIN_ROOT_CORE="$resolved"; fi`), run with:

```
mkdir -p demo_core/plugin demo_core/core/hooks/lib
echo shim > demo_core/core/hooks/lib/gate-lib.sh
export CLAUDE_PLUGIN_ROOT=$PWD/demo_core/plugin
export CLAUDE_PLUGIN_ROOT_CORE=/nonexistent-core-stale   # pre-set to a stale/broken path
resolve_core
```

### Observed
```
resolve_core: resolved=.../demo_core/plugin/../core  final CLAUDE_PLUGIN_ROOT_CORE=/nonexistent-core-stale
```
resolve_core successfully locates the working sibling core (`resolved=...`) but the exported `CLAUDE_PLUGIN_ROOT_CORE` remains the invalid pre-set value, because the guard only tests `-z "$CLAUDE_PLUGIN_ROOT_CORE"` (empty), which is false since the var is non-empty, just wrong. Every gate subprocess launched later in the script (which the proposal says reads `CLAUDE_PLUGIN_ROOT_CORE` from the environment) would then fail closed against `/nonexistent-core-stale` instead of the resolved sibling.

### Expected
The export guard should re-export whenever the *resolution path actually used* differs from the current `CLAUDE_PLUGIN_ROOT_CORE` (or simply always export the resolved value unconditionally), not merely when the variable happens to be unset. "Already set" is not maintained anywhere in the proposal or the caller's environment to mean "already set to a value that resolve_core() itself validated."
