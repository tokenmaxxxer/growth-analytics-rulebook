#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — ga-funnel plugin (issue-7 phase 2,
# hardened issue-10 phase 2).
#
# Enforces stage/segment localization on docs/issue-<n>/reports/
# growth-analytics.md writes that declare a "funnel diagnosis" section:
# stage/event definitions, quantified per-stage-pair drop-off, segment
# breakdown with a concentration sentence, a causal bottleneck
# hypothesis tracing to the segment evidence, and exactly one
# prioritized recommendation. Fail-closed shape per docs/issue-7/
# proposals/growth-analytics.md section 3.1 (pattern from pricing/hooks/
# methodology-gate.sh, not copied).
#
# issue-10 hardening: trap installed before the kill-switch/python3
# preamble; kill-switch default inverted (unrecognized value fails
# closed); absolute-path containment resolved through symlinks
# (realpath); Edit/MultiEdit reconstruction honors per-edit replace_all;
# the "funnel diagnosis" arm-phrase now requires a markdown heading, and
# every check (stage definitions, stage-pair drop-off, segment/
# concentration, bottleneck hypothesis) runs only inside that heading's
# section span — previously only the recommendation extraction was
# section-scoped. No shared gate-lib.sh exists yet in this repo (core
# issue #72 unlanded) — see docs/issue-10/proposals/gate-a-plus.md
# section 5 — so these fixes are applied inline, not reference-adopted
# from a library.
#
# Kill switch: export GA_FUNNEL_GATE_OFF=1 (or 0/false/no/off to leave it
# on explicitly). Any other value, including an unrecognized one, leaves
# the gate enabled — there is no fail-open default.
. "${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh" \
  || { echo "ga-funnel-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${GA_FUNNEL_GATE_OFF:-}" || { trap - EXIT; exit 0; }

deny() { echo "ga-funnel: refused — $1" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ] || { [ ! -d "$root/.git" ] && [ ! -f "$root/.git" ]; }; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] && { [ -d "$root/.git" ] || [ -f "$root/.git" ]; } || deny "no project root (no CLAUDE_PROJECT_DIR/.git and no resolvable git toplevel)"

GA_PAYLOAD="$payload" GA_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import json, os, re, sys

import importlib.util
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

def deny(m):
    sys.stderr.write("ga-funnel: refused — %s\n" % m)
    sys.exit(2)

raw = os.environ.get("GA_PAYLOAD", "")
root = os.environ.get("GA_ROOT", "")
ev = gate_lib.gate_parse_json_or_deny(raw, deny)

tool = ev.get("tool_name")
ti = ev.get("tool_input")

GUARDED_RE = r'docs/issue-[0-9]+/reports/growth-analytics\.md$'

if tool == "Bash":
    if not isinstance(ti, dict):
        sys.exit(0)
    command = ti.get("command")
    if not isinstance(command, str) or not command:
        sys.exit(0)
    for token in gate_lib.gate_bash_write_targets(command):
        if re.search(GUARDED_RE, token.replace("\\", "/")):
            deny(
                "this Bash command appears to target %s; use Write/Edit/MultiEdit "
                "instead of a shell redirect so the funnel-diagnosis gate can "
                "inspect the resulting content." % token
            )
    sys.exit(0)

if tool not in ("Write", "Edit", "MultiEdit") or not isinstance(ti, dict):
    sys.exit(0)

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    sys.exit(0)

norm = path.replace("\\", "/")
root_real = os.path.realpath(root) if root else root
if root_real:
    tail = gate_lib.gate_normalize_path(root_real, path)
    if tail is None:
        deny("target path resolves outside the project root")
    abspath = os.path.join(root_real, tail) if not os.path.isabs(norm) else os.path.normpath(norm)
    real_abspath = os.path.realpath(abspath)
    if not (real_abspath == root_real or real_abspath.startswith(root_real + "/")):
        deny("target path resolves outside the project root")
else:
    abspath = norm if os.path.isabs(norm) else norm
    abspath = os.path.normpath(abspath)

if not re.search(GUARDED_RE, norm):
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

whole_low = new_text.lower()

def has_any_in(text, *needles):
    return any(nd in text for nd in needles)

if not has_any_in(whole_low, "funnel diagnosis", "funnel-diagnosis"):
    sys.exit(0)  # arm-phrase not present anywhere; gate does not engage


def extract_section(text, heading_pattern):
    """Text spanning a heading matching heading_pattern (case-insensitive)
    up to the next same-or-higher-level heading or EOF. None if no such
    heading exists."""
    lines = text.split("\n")
    start = None
    level = None
    for i, line in enumerate(lines):
        hm = re.match(r'^(#{1,6})\s*(.*)$', line)
        if hm and re.search(heading_pattern, hm.group(2), re.IGNORECASE):
            start = i + 1
            level = len(hm.group(1))
            break
    if start is None:
        return None
    end = len(lines)
    for j in range(start, len(lines)):
        hm = re.match(r'^(#{1,6})\s+', lines[j])
        if hm and len(hm.group(1)) <= level:
            end = j
            break
    return "\n".join(lines[start:end])


section = extract_section(new_text, r'funnel[\s-]+diagnosis')
if section is None:
    deny(
        "the phrase 'funnel diagnosis' appears in this write but not as a markdown heading "
        "(e.g. '## Funnel Diagnosis') — the funnel-diagnosis section must be structurally "
        "identifiable, not just mentioned in prose."
    )

low = section.lower()

def has_any(*needles):
    return has_any_in(low, *needles)

missing = []

if not has_any("stage definition", "event definition", "stage/event"):
    missing.append("stage/event definitions")

# step 2: numbers attributable to a specific stage pair, e.g. "stage 1 -> stage 2: 40%"
stage_pair_pattern = re.search(
    r'(stage\s*\d+[^\n]{0,40}(->|→|to)[^\n]{0,40}stage\s*\d+)[^\n]{0,60}\d+(\.\d+)?\s*%',
    low,
) or re.search(r'(drop-off|dropoff|conversion)[^\n]{0,80}stage\s*\d+[^\n]{0,80}\d+(\.\d+)?\s*%', low)
if not stage_pair_pattern:
    missing.append("stage-to-stage drop-off quantified with numbers attributable to a specific stage pair")

# step 3: segment axis + concentration sentence
has_segment_axis = has_any("channel", "cohort", "device", "segment")
concentration = re.search(r'(concentrat|mostly in|driven by|primarily (from|in))', low)
if not has_segment_axis:
    missing.append("segment breakdown (channel/cohort/device or named equivalent)")
elif not concentration:
    missing.append("segment breakdown does not identify concentration")

# step 4: causal hypothesis, must not be a bare restatement
hyp_match = re.search(r'bottleneck hypothesis\s*[:\-]\s*([^\n]+)', low)
if not hyp_match:
    missing.append("bottleneck hypothesis")
else:
    hyp_text = hyp_match.group(1)
    if not re.search(r'(because|due to|caused by|driven by)', hyp_text):
        missing.append("bottleneck hypothesis is a verbatim restatement of the drop-off number (no causal cue like 'because'/'due to'/'caused by')")

# step 5: exactly one recommendation
rec_section = re.search(r'recommendation[s]?\s*[:\-]?\s*\n?(.*?)(\n\n|\Z)', low, re.S)
rec_bullets = 0
if rec_section:
    rec_bullets = len(re.findall(r'^\s*[-*\d]', rec_section.group(1), re.M))
if rec_bullets == 0:
    missing.append("prioritized single-stage recommendation")
elif rec_bullets > 1:
    missing.append("exactly one recommendation required (found %d recommendation-shaped bullets)" % rec_bullets)

if missing:
    deny(
        "funnel-diagnosis section is missing/violates required component(s): %s. Per docs/"
        "issue-1/proposals/rulebook-maturation.md (b) via ga-funnel." % "; ".join(missing)
    )

sys.exit(0)
PY
