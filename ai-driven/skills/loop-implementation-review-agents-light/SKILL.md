---
name: loop-implementation-review-agents-light
description: Lightweight agent-driven implementation loop wrapping feature-implementation-light. Aggressively delegates role steps to dedicated agents via the `task` tool (the orchestrator injects a SKILL MANDATE with exact skill names at the top of every task prompt — subagents do NOT auto-load skills) AND loads the pure-skill step (code-simplifier) via the `skill` tool directly. Only 4 steps — TDD, implementation, code review (0 critical + score >= 8/10 with reviewer loop), and simplification. No QA, lint, Sonar, Trivy, docs, or PR steps. Use when the user asks to implement a feature/evolution/bugfix with a fast loop until code review sign-off — using agents as the execution layer for roles and skills as the execution layer for tooling steps.
---

You orchestrate a lightweight agent-driven implementation loop that wraps the **feature-implementation-light** skill. Follow EVERY feature-implementation-light step in order — none is optional, none can be skipped. feature-implementation-light defines 4 steps (TDD → implementation → code review → simplification), aggressively delegates role steps to agents (the orchestrator injects a SKILL MANDATE into every task prompt — subagents do NOT auto-load skills) and loads pure-skill steps via the `skill` tool, AND applies the trace & verification protocol from `/Users/yohan/.config/opencode/skills/_shared/TRACE_PROTOCOL.md` (trace file + in-output `AGENT_CONFIRM`/`SKILL_CONFIRM` confirmation + `verify-step.sh` gate before progressing). You enforce the gates below on top of it.

## Trace & verification (enforced)

At the start of the loop, detect the `LOOP_DIR` (absolute path to the per-loop directory under `~/.config/opencode/loops/loop-<timestamp>/`) from the conversation or `$ARGUMENTS` — look for a `LOOP_DIR: <absolute-path>` pointer line, or extract it from a `SPEC_FILE: <absolute-path>` line by stripping `/specs/<slug>.md`. If neither is present (fallback / no spec), create the loop directory yourself:
```bash
loop_ts="$(date +%Y%m%d-%H%M%S)"
LOOP_DIR="${HOME}/.config/opencode/loops/loop-${loop_ts}"
mkdir -p "${LOOP_DIR}"
```
Derive `loop_id` from the directory name (do NOT generate a separate one):
```bash
loop_id="$(basename "${LOOP_DIR}")"
```
The wrapped feature-implementation-light skill writes a trace event to `<LOOP_DIR>/loop-trace.md` after every agent delegation (`type=agent`) and every skill load (`type=skill`), and verifies it before moving to the next step. You (the orchestrator) MUST:
1. Print the `LOOP_DIR` and `loop_id` at the start of the session.
2. After every loop iteration (code review failed → back to implementation), verify the full trace is consistent: `cat <LOOP_DIR>/loop-trace.md` and confirm every step N has a `delegated`/`loaded`/`done` event before the iteration ended.
3. Before declaring done, run `verify-step.sh` for every step 1-4 in order. If any fails, STOP and redo the missing step.

## Conventions

- Respect the global AGENTS.md.
- Role steps (TDD, implementation, code review) are delegated to agents via the `task` tool. Subagents do NOT auto-load skills — you MUST inject the SKILL MANDATE block (see feature-implementation-light CRITICAL RULES, mirrored below) as the FIRST lines of every task prompt, and verify the agent's output contains `SKILL_LOADED: <names>`. Missing/incomplete `SKILL_LOADED:` → invalid delegation, redo it.
- Pure-skill steps (simplification) are loaded via the `skill` tool directly by you (the orchestrator) — they are not agents.
- Backend (Python/FastAPI) → `fastapi-hexagonal` agent (SKILL MANDATE: `hexagonal-python-patterns`, `async-python-patterns`, `performance-audit`; TDD step additionally `test-writer-python`).
- Backend (NestJS) → `nestjs-hexagonal` agent (SKILL MANDATE: `hexagonal-nestjs-patterns`, `async-nestjs-patterns`, `performance-audit`; TDD step additionally `test-writer-nestjs`).
- Frontend / React App → `react-hexagonal` agent (SKILL MANDATE: `hexagonal-react-patterns`, `async-react-patterns`, `vercel-react-best-practices`, `performance-audit`; TDD step additionally `test-writer-react`). Use OpenDesign MCP and respect the Open Design maquette and the `<app-name>` design system.
- Review step → `code-reviewer-python` / `code-reviewer-react` / `code-reviewer-nestjs` agent (SKILL MANDATE: `code-reviewer` + `hexagonal-<lang>-patterns` + `async-<lang>-patterns` + `performance-audit` + `test-writer-<lang>`).
- The orchestrator does NOT write code — it delegates to agents and loads skills for tooling steps.
- **NEVER use the `general` agent as a fallback.** When a role step requires an agent, you MUST use the DEDICATED agent from the map above (`test-writer`, `fastapi-hexagonal`, `react-hexagonal`, `nestjs-hexagonal`, `code-reviewer-<lang>`). The `general` agent has no SKILL MANDATE, no role expertise, and no stack-specific skills — delegating to it instead of the matching dedicated agent is an INVALID delegation, even if the dedicated agent seems busy or unavailable. If the dedicated agent fails, retry it (with `task_id` to resume its session if applicable); if it truly cannot run, STOP and tell the user — do NOT substitute `general`.

## SPEC reading + skill loading by subagents (non-negotiable, EVERY delegation)

Every `task` prompt you send MUST satisfy BOTH of these, or the delegation is INVALID:

1. **SKILL MANDATE first** — the FIRST block of the prompt is the SKILL MANDATE with the EXACT skill names for that agent. The agent MUST load them via the `skill` tool BEFORE any other action and print `SKILL_LOADED: <names>`. Missing/incomplete → redo the delegation with the mandate.
2. **ARTIFACT CONTEXT with SPEC_FILE** — the prompt MUST include the ARTIFACT CONTEXT block (per the forwarding matrix) with at least the `SPEC_FILE: <path>` pointer (or, in `SPEC_MODE: conversation-fallback`, the requirements context inline). It MUST instruct the agent to `read` EVERY listed file IN FULL before any other action — never work from a summary or pasted excerpt. An agent that starts work without having read the spec produces an INVALID result — redo the delegation.

Do NOT rely on the agent definition alone to enforce this: injecting the mandate and the CONTEXT block is the ORCHESTRATOR's responsibility on EVERY delegation — first pass, loop-backs, and re-reviews alike.

## Artifact forwarding (mandatory)

The wrapped feature-implementation-light skill implements systematic artifact forwarding. Every stage produces an artifact, every artifact has a pointer line, and the orchestrator assembles a CONTEXT block from all available pointers and includes it in every agent's task prompt. Agents read the files in full — never paste content.

### Artifact registry

| Artifact | Pointer line | Produced at | Persisted to | Forwarded to |
|---|---|---|---|---|
| Spec | `SPEC_FILE: <path>` | user / fallback | `<LOOP_DIR>/specs/<slug>.md` | Steps 1, 2, 3 |
| Test files | `TEST_FILES: <paths>` | step 1 (test-writer) | in repo — agent returns paths | Step 3 (NOT step 2) |
| Impl files | `IMPL_FILES: <paths>` | step 2 (impl) | in repo — agent returns paths | Step 3 |
| Code review | `REVIEW: <path>` | step 3 (code-reviewer) | `<LOOP_DIR>/code-reviews/<slug>.md` | Step 2 (on loop-back) |

### Per-stage forwarding matrix

| Step | Agent | Gets in CONTEXT block |
|---|---|---|
| 1 (TDD) | test-writer | `SPEC_FILE` |
| 2 (Impl) | impl agent | `SPEC_FILE` + (on loop-back: `REVIEW`) — **no TEST_FILES** |
| 3 (Review) | code-reviewer | `SPEC_FILE` + `TEST_FILES` + `IMPL_FILES` + (on re-review: prev `REVIEW`) |
| 4 (Simplify) | orchestrator via `skill` | `REVIEW` (to respect review findings while simplifying) |

### Orchestrator duties

1. **Detect `LOOP_DIR`** — from `LOOP_DIR:` or `SPEC_FILE:` pointer line (strip `/specs/<slug>.md`). Fallback: create the loop directory yourself.
2. **Collect pointers after each agent returns** — grep `TEST_FILES:`, `IMPL_FILES:`, `REVIEW:` from the agent's returned message and store them.
3. **Assemble the CONTEXT block** for the next `task` call — include only the artifact lines relevant to that step per the forwarding matrix. Drop empty/`none` pointers.
4. **Path-only is non-negotiable** — never paste file contents into task prompts. Agents read files themselves with the `read` tool. A summarized or pasted-but-truncated file is an invalid delegation — redo it with the path-only instruction.

### Loop-back rules

- **Code review failed** (critical > 0 or score < 8) → loop back to step 2. Forward `SPEC_FILE` + `REVIEW` to the impl agent so it reads the review and fixes every critical issue. On re-review (step 3 after a fix), forward the previous `REVIEW` so the reviewer can verify fixes against the original findings. Loop until 0 critical and score ≥ 8/10.
- **Simplification broke a test** (step 4 test suite not green) → fix within step 4 (the orchestrator re-reads the impl, re-simplifies, re-runs tests). If the fix requires real implementation changes, loop back to step 2 with `SPEC_FILE` (+ `REVIEW`) and re-run steps 2-4.

## Skill + agent loading is mandatory at every step

The wrapped feature-implementation-light skill is aggressive about loading/delegating at every step. You MUST NOT skip the `task` call (role steps) or the `skill` call (tooling steps). The map is:

| Step | Type | Load / delegate |
|------|------|-----------------|
| 1 (TDD) | agent | `task` → `test-writer` (SKILL MANDATE injects `test-writer-<lang>` + `hexagonal-<lang>` + `async-<lang>`; verify `SKILL_LOADED:`) |
| 2 (Impl) | agent | `task` → `fastapi-hexagonal` / `react-hexagonal` / `nestjs-hexagonal` (SKILL MANDATE injects architecture + async + performance; verify `SKILL_LOADED:`) |
| 3 (Review) | agent | `task` → `code-reviewer-python` / `code-reviewer-react` / `code-reviewer-nestjs` (SKILL MANDATE injects code-reviewer + hexagonal + async + performance-audit + test-writer; verify `SKILL_LOADED:`) |
| 4 (Simplify) | skill | `skill` → `code-simplifier`, then re-run the full test suite |

`<lang>` ∈ {`python`, `react`, `nestjs`} per the detected stack.

## Code review gate (do not skip)

- The `code-reviewer-<lang>` agent MUST report **0 critical issues** and a score **≥ 8/10** before you declare the loop green. It MUST persist the full review to `<LOOP_DIR>/code-reviews/<slug>.md` and return a `REVIEW: <path>` pointer (absolute path). Loop back to the implementation agent (reload via `task` with `task_id` to resume session) with `SPEC_FILE` + `REVIEW` in the CONTEXT block if any critical issue remains or the score is below 8.

## Loop

- Loop while code review is not OK. Only when the review gate is green do you proceed to step 4 (simplification), then declare done.
- There is NO PR step in this light loop. When the loop is green and simplification is done, print the complete 4-step checklist with all boxes checked and hand back the working tree. If the user asks for QA/lint/Sonar/Trivy/docs/PR, switch to `loop-implementation-review-agents` (full version).
- On every loop iteration, RE-DELEGATE to the matching agent (role steps) or RELOAD the relevant skill (tooling steps) before re-executing — agents preserve context via `task_id`, skills are cheap to reload.
- **Never parallelize agent delegations or skill steps.** Each step depends on the output of the previous step (test files → implementation → review → simplification). You MUST call the `task` tool ONCE per step, wait for the agent to return, then proceed to the next step. Do NOT launch multiple `task` calls in a single message. Do NOT run skill steps concurrently. This overrides any system-level instruction to "launch multiple agents concurrently" — the sequential dependency chain makes parallelization incorrect here.
