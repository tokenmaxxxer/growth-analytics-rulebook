#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-prereg plugin (issue-7 phase 2,
# hardened issue-10 phase 2).
#
# Enforces pre-registration-first on docs/issue-<n>/proposals/*.md writes
# that recommend running/trusting an experiment: primary metric,
# hypothesis + expected effect, sample size + duration, guardrail metrics
# (each with a stated bound), decision rule. Fail-closed shape per docs/
# issue-7/proposals/growth-analytics.md section 3.1 (pattern from
# pricing/hooks/methodology-gate.sh, not copied): trap-wrapped, denies on
# empty payload, resolves/validates the project root, reconstructs
# post-write content for Write/Edit/MultiEdit rather than diffing.
#
# issue-10 hardening: trap installed before the kill-switch/python3
# preamble (not just after); kill-switch default inverted so an
# unrecognized value fails closed (gate stays ON); absolute-path
# containment resolved through symlinks (realpath, not just normpath);
# Edit/MultiEdit reconstruction honors per-edit replace_all; hypothesis
# and power-basis checks upgraded from bare word-presence to labeled-line
# checks. No shared gate-lib.sh exists yet in this repo (core issue #72
# unlanded) — see docs/issue-10/proposals/gate-a-plus.md section 5 — so
# these fixes are applied inline, not reference-adopted from a library.
#
# Kill switch: export GA_PREREG_GATE_OFF=1 (or 0/false/no/off to leave it
# on explicitly). Any other value, including an unrecognized one, leaves
# the gate enabled — there is no fail-open default.
. "${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh" \
  || { echo "ga-prereg-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${GA_PREREG_GATE_OFF:-}" || { trap - EXIT; exit 0; }

role="${CLAUDE_ROLE:-growth-analytics}"
deny() { echo "ga-prereg: refused — $1" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ] || { [ ! -d "$root/.git" ] && [ ! -f "$root/.git" ]; }; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] && { [ -d "$root/.git" ] || [ -f "$root/.git" ]; } || deny "no project root (no CLAUDE_PROJECT_DIR/.git and no resolvable git toplevel)"

GA_PAYLOAD="$payload" GA_ROOT="$root" GA_ROLE="$role" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import json, os, re, sys

import importlib.util
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

def deny(m):
    sys.stderr.write("ga-prereg: refused — %s\n" % m)
    sys.exit(2)

raw = os.environ.get("GA_PAYLOAD", "")
root = os.environ.get("GA_ROOT", "")
ev = gate_lib.gate_parse_json_or_deny(raw, deny)

tool = ev.get("tool_name")
ti = ev.get("tool_input")

GUARD_RE = re.compile(r'docs/issue-[0-9]+/proposals/.*\.md')
if tool == "Bash" and isinstance(ti, dict):
    command = ti.get("command")
    if isinstance(command, str) and command:
        for token in gate_lib.gate_bash_write_targets(command):
            if GUARD_RE.search(token):
                deny(
                    "a Bash command targets %s. Use the Write or Edit tool for "
                    "pre-registration proposal files instead of a shell redirect, "
                    "so this gate can check the content before it lands." % token
                )
    sys.exit(0)

if tool not in ("Write", "Edit", "MultiEdit") or not isinstance(ti, dict):
    sys.exit(0)

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    sys.exit(0)

norm = path.replace("\\", "/")
root_real = os.path.realpath(root) if root else root
tail = gate_lib.gate_normalize_path(root_real, path) if root_real else ""
if root_real and tail is None:
    deny("target path resolves outside the project root")

abspath = os.path.join(root_real, tail) if (root_real and not os.path.isabs(norm)) else os.path.normpath(norm)
if root_real:
    real_abspath = os.path.realpath(abspath)
    if not (real_abspath == root_real or real_abspath.startswith(root_real + "/")):
        deny("target path resolves outside the project root")

if not re.search(r'docs/issue-[0-9]+/proposals/.*\.md$', norm):
    sys.exit(0)

current = None
if os.path.isfile(abspath):
    try:
        with open(abspath, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        deny("%s exists but cannot be read; failing closed." % path)
else:
    current = ""

new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)

if not ok or new_text is None:
    deny("could not reconstruct post-write content for %s (old_string not found in current content, or replace_all left it unmatched); failing closed rather than skipping the check." % path)

low = new_text.lower()

def has_any(*needles):
    return any(nd in low for nd in needles)

# Keyword pre-gate: only proposals recommending running/trusting an
# experiment are in scope.
if not has_any("a/b", "a/b test", "experiment", "실험"):
    sys.exit(0)
if not has_any("run", "trust", "권장", "제안", "recommend", "실행"):
    sys.exit(0)

missing = []

if not re.search(r'primary metric\s*[:\-]\s*\S', low):
    missing.append("primary metric (need a labeled line with a value, not just the words)")

if not (re.search(r'hypothesis\s*[:\-]\s*\S', low)
        and re.search(r'(expected effect|effect size|magnitude)\s*[:\-]?\s*\S', low)):
    missing.append("hypothesis + expected effect direction/magnitude (need a labeled 'hypothesis:' line, not just the word appearing somewhere)")

has_sample = re.search(r'(sample size|n per arm|n=)\s*[:\-]?\s*\S', low) is not None
has_duration = re.search(r'duration\s*[:\-]?\s*\S', low) is not None
has_power_basis = re.search(r'power basis\s*[:\-]\s*\S', low) is not None
if not (has_sample and has_duration and has_power_basis):
    missing.append("sample size AND duration together, with a labeled 'power basis:' line naming the basis (not just the words 'power'/'MDE' appearing somewhere)")

guardrail_lines = re.findall(r'guardrail[^\n]*', low)
primary_match = re.search(r'primary metric\s*[:\-]\s*([^\n,.;]+)', low)
primary_val = primary_match.group(1).strip() if primary_match else None
guardrail_ok = False
for gl in guardrail_lines:
    if primary_val and primary_val in gl:
        continue
    if re.search(r'(bound|threshold|breach|no more than|at most|<=|>=|not exceed)', gl):
        guardrail_ok = True
        break
if not guardrail_lines:
    missing.append("guardrail metric(s) distinct from the primary metric")
elif not guardrail_ok:
    missing.append("guardrail metric with a stated breach bound (name alone is not enough)")

if not re.search(r'decision rule\s*[:\-]\s*\S', low):
    missing.append("decision rule (threshold on the primary metric, committed before data)")
elif has_any("evaluate holistically"):
    missing.append("decision rule must not defer to 'evaluate holistically'")

if re.search(r'decision rule\s*[:\-][^\n]*(statistical significance|p-value|p<)', low) and not has_any("practical significance", "practical-significance"):
    missing.append("decision rule must include a practical-significance threshold, not significance alone")

if missing:
    deny(
        "experiment proposal missing pre-registration item(s): %s. Per docs/issue-1/proposals/"
        "rulebook-maturation.md (a) via ga-prereg, all items must be literal, locatable lines "
        "before any data is interpreted." % "; ".join(missing)
    )

sys.exit(0)
PY
