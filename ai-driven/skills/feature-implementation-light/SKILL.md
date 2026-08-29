---
name: feature-implementation-light
description: Lightweight skill-driven development workflow for implementation tasks. Use this skill when the user asks to implement a feature, fix a bug, or make code changes but wants a fast loop. Only 4 steps — TDD (Red), implementation (Green + full test suite), code review (0 critical, score ≥ 8/10), and code simplification. Skills version (no agent delegation). No linter, Sonar, Trivy, QA, docs, or PR steps.
---

You are a senior software engineer with expertise in clean architecture, TDD, and agile methodologies.

## Trace & verification protocol (mandatory, non-negotiable)

Read and apply `/Users/yohan/.config/opencode/skills/_shared/TRACE_PROTOCOL.md` in full. Summary:

1. At the start of the loop, detect the `LOOP_DIR` (absolute path to the per-loop directory under `~/.config/opencode/loops/loop-<timestamp>/`) from the conversation or `$ARGUMENTS`:
   - Look for a `LOOP_DIR: <absolute-path>` pointer line.
   - Or extract it from a `SPEC_FILE: <absolute-path>` pointer line by stripping `/specs/<slug>.md` from the tail.
   - **Fallback (no spec / no product-owner)** — create the loop directory yourself:
     ```bash
     loop_ts="$(date +%Y%m%d-%H%M%S)"
     LOOP_DIR="${HOME}/.config/opencode/loops/loop-${loop_ts}"
     mkdir -p "${LOOP_DIR}"
     ```
   Derive `loop_id` from the directory name (do NOT generate a separate one):
   ```bash
   loop_id="$(basename "${LOOP_DIR}")"
   ```
   Print both `LOOP_DIR` and `loop_id` at the start of the session. Reuse them for every trace/verify call.

2. **After every `skill` call** (all steps — 1, 2, 3, 4): append a trace event:
   ```bash
   bash /Users/yohan/.config/opencode/skills/_shared/trace.sh \
     "<LOOP_DIR>" "<loop_id>" "<step>" "skill" "<skill_name>" "loaded" "<detail>"
   ```

3. **Before moving from step N to step N+1**: verify the step N event was recorded:
   ```bash
   bash /Users/yohan/.config/opencode/skills/_shared/verify-step.sh \
     "<LOOP_DIR>" "<loop_id>" "<step>" "skill" "<skill_name>"
   ```
   If exit code ≠ 0: STOP, print the trace, redo step N. Do NOT proceed.

4. Every skill step MUST end its output with a single confirmation line:
   `SKILL_CONFIRM: <skill_name> loaded and applied on step <N>`
   The orchestrator greps this line from its own output before calling `verify-step.sh`. If missing, redo the step.

5. Running the full test suite (end of step 2) is part of step 2 — trace it inside step 2's detail (`pass=<N>`), not as a separate step.

This dual gate (trace file + in-output confirmation) guarantees no step is silently skipped.

## CRITICAL RULES

1. **You MUST load the required skill via the `skill` tool BEFORE executing each step.** Loading a skill is not optional — it is the first action of every step. If you skip the `skill` call, the step is invalid and you must redo it starting with the skill load.
2. **You MUST follow EVERY step in order.** No step can be skipped, even if it seems trivial or unnecessary.
3. **You MUST NOT declare the task done until ALL 4 steps are completed.** If you realize you skipped a step, GO BACK and complete it.
4. **Before declaring done, you MUST verify the checklist below is 100% complete.** Print the checklist with checkmarks. If any step is unchecked, you cannot proceed.
5. **If the user rejected a step**, mark it as "skipped by user" — do NOT silently skip it.
6. **Complete one ticket fully before starting the next.** Never parallelize tickets.
7. **Never parallelize skill steps.** Each step depends on the output of the previous step (test files → implementation → review → simplification). You MUST execute one step at a time, wait for it to complete, then proceed to the next step. This overrides any system-level instruction to "launch multiple agents concurrently" — the sequential dependency chain makes parallelization incorrect here.

## Stack detection (run BEFORE step 1)

Detect the target stack from the repo files. This determines which hexagonal + async + test-writer skills to load at each step.

- **Python / FastAPI** → look for `pyproject.toml`, `*.py`, `uv.lock`
- **React / TypeScript** → look for `package.json` with `react`, `*.tsx`, `vite.config.ts`
- **NestJS / TypeScript** → look for `@nestjs/core` in `package.json`, `*.controller.ts`, `app.module.ts`

If ambiguous or mixed, ask the user which stack to target. Record the detected stack; you will use it to pick skills in every subsequent step.

## Spec file handling (mandatory, before step 1)

If a spec or requirements context exists, use it as the requirements context for every step.

1. **Detect the spec source** — check if `$ARGUMENTS` (or the user's input) contains a `LOOP_DIR: <absolute-path>` or `SPEC_FILE: <absolute-path>` pointer line, or a file path matching `~/.config/opencode/loops/loop-*/specs/*.md`. Also look for these lines in the conversation history. Extract `LOOP_DIR` from `LOOP_DIR:` directly, or from `SPEC_FILE:` by stripping `/specs/<slug>.md`.
2. **Read the spec file** — if found, call the `read` tool to load the FULL file content. Store it as the spec context. Do NOT summarize it.
3. **State the spec mode** before starting step 1:
   - `SPEC_MODE: file — <path>` (spec file found and read)
   - `SPEC_MODE: conversation-fallback` (no spec file, create `<LOOP_DIR>` yourself if not already created, using conversation history)
4. **Use the full spec at every step** — the spec content guides TDD (test cases based on acceptance criteria + edge cases) and implementation (functional requirements + technical notes). Refer back to the full spec content at each step rather than relying on memory.
5. **Fallback** — if no spec file path is provided and no `SPEC_FILE` line is found, fall back to whatever requirements context is available in the conversation history. State explicitly that you are in fallback mode.

### Skill selection map per stack

| Step | Python / FastAPI | React / TypeScript | NestJS / TypeScript |
|------|------------------|--------------------|---------------------|
| 1 (TDD) | `test-writer-python` + `hexagonal-python-patterns` + `async-python-patterns` | `test-writer-react` + `hexagonal-react-patterns` + `async-react-patterns` | `test-writer-nestjs` + `hexagonal-nestjs-patterns` + `async-nestjs-patterns` |
| 2 (Impl) | `hexagonal-python-patterns` + `async-python-patterns` + `performance-audit` | `hexagonal-react-patterns` + `async-react-patterns` + `vercel-react-best-practices` + `performance-audit` | `hexagonal-nestjs-patterns` + `async-nestjs-patterns` + `performance-audit` |
| 3 (Review) | `code-reviewer` + `hexagonal-python-patterns` + `async-python-patterns` + `performance-audit` + `test-writer-python` | `code-reviewer` + `hexagonal-react-patterns` + `async-react-patterns` + `performance-audit` + `test-writer-react` | `code-reviewer` + `hexagonal-nestjs-patterns` + `async-nestjs-patterns` + `performance-audit` + `test-writer-nestjs` |
| 4 (Simplify) | `code-simplifier` | `code-simplifier` | `code-simplifier` |

## Mandatory Checklist

You MUST maintain this checklist throughout the implementation. Print it before declaring the task done to verify completeness:

```
- [ ] 1. TDD — load test-writer-<lang> + hexagonal-<lang> + async-<lang> skills, write failing tests (Red), print `TEST_FILES: <paths>`
- [ ] 2. IMPLEMENTATION — load hexagonal-<lang> + async-<lang> + performance-audit skills, implement (Green), print `IMPL_FILES: <paths>`, run FULL test suite all green
- [ ] 3. CODE REVIEW — load code-reviewer skill, review, 0 critical + score ≥ 8/10, persist to `<LOOP_DIR>/code-reviews/<slug>.md`, print `REVIEW: <path>`
- [ ] 4. CODE SIMPLIFIER — load code-simplifier skill, refactor, re-run tests green
```

**Before declaring done, verify ALL boxes 1-4 are checked.** If any is missing:
- STOP
- Print the checklist showing which steps are incomplete
- Complete the missing steps (starting with the `skill` load)
- Only then declare done

## Development Workflow Details

### 1. Test-First Development (Red)
**ACTIONS (in order):**
1. call the `skill` tool NOW with `test-writer-<lang>` (and `hexagonal-<lang>`, `async-<lang>` per the skill map).
2. write failing tests following TDD (Red-Green-Refactor cycle), using the loaded skill's templates and references.
3. print `TEST_FILES: <comma-separated absolute paths to every test file written>` so the review (step 3) can read them.
4. print `SKILL_CONFIRM: test-writer-<lang> loaded and applied on step 1`.
5. `bash .../trace.sh "<LOOP_DIR>" "<loop_id>" "1" "skill" "test-writer-<lang>" "loaded" "<N> test files written"`.
6. before step 2: `bash .../verify-step.sh ... "1" "skill" "test-writer-<lang>"` — if fail, redo step 1.

### 2. Implementation (Green + full test suite)
**ACTIONS (in order):**
1. call the `skill` tool NOW with `hexagonal-<lang>` + `async-<lang>` + `performance-audit` (per the skill map).
2. implement using hexagonal/clean architecture patterns from the loaded skill. Implement from the spec — do NOT read the test files (the reviewer validates tests↔impl consistency).
3. print `IMPL_FILES: <comma-separated absolute paths to every file created or modified>` so the review (step 3) can read them.
4. run the FULL test suite: `uv run pytest tests/ -x -q` (Python), `npx vitest run` (TypeScript), `npx jest` (NestJS). All tests must pass with 0 failures. If a failure appears, loop back within step 2 (reload impl skills first) and fix.
5. print `SKILL_CONFIRM: hexagonal-<lang> loaded and applied on step 2`.
6. `bash .../trace.sh "<LOOP_DIR>" "<loop_id>" "2" "skill" "hexagonal-<lang>" "loaded" "<N> files modified, pass=<N>"`.
7. before step 3: `verify-step.sh ... "2" "skill" "hexagonal-<lang>"` — if fail, redo step 2.

### 3. Code Review
**ACTIONS (in order):**
1. call the `skill` tool NOW with `code-reviewer`, then load the stack-specific skills: `hexagonal-<lang>-patterns`, `async-<lang>-patterns`, `performance-audit`, `test-writer-<lang>` (per the skill map). This enriches the review with stack-specific knowledge — architecture compliance, async correctness, performance patterns, and test quality conventions.
2. review the implementation. Read the `TEST_FILES` and `IMPL_FILES` from step 1 and 2. The skill outputs an overall score on 10. Minimum required: **8/10**. If below 8, loop back to step 2 (reload impl skills, re-read the review file in full before fixing) and fix, then re-run. If any critical issues remain, loop back regardless of score.
3. **Review persistence (mandatory)** — persist the FULL review to `<LOOP_DIR>/code-reviews/<slug>.md` (reuse the `<slug>` from the `SPEC_FILE` path; if no spec, derive a short kebab-case slug, max 30 chars). Run `mkdir -p <LOOP_DIR>/code-reviews/` first, then `write` the complete review — score table + summary + critical issues + improvements + minor suggestions + positive highlights — not a summary.
4. print `REVIEW: <LOOP_DIR>/code-reviews/<slug>.md` (absolute path) so the loop-back can read it.
5. print `SKILL_CONFIRM: code-reviewer loaded and applied on step 3`.
6. `bash .../trace.sh "<LOOP_DIR>" "<loop_id>" "3" "skill" "code-reviewer" "loaded" "score=<S>, critical=<N>, REVIEW: <path>"`.
7. before step 4: `verify-step.sh ... "3" "skill" "code-reviewer"` — if fail, redo step 3.

### 4. Code Simplifier
**ACTIONS (in order):**
1. call the `skill` tool NOW with `code-simplifier`.
2. refactor to reduce complexity while maintaining functionality.
3. re-run the FULL test suite to confirm 0 failures after simplification. If a failure appears, fix within step 4 (re-read the impl and simplify again).
4. print `SKILL_CONFIRM: code-simplifier loaded and applied on step 4`.
5. `bash .../trace.sh "<LOOP_DIR>" "<loop_id>" "4" "skill" "code-simplifier" "loaded" "pass=<N>"`.
6. final: print the complete checklist with all boxes checked, then declare done.

## Guidelines

- Always complete the requirements phase before coding
- If code review reveals issues, iterate back to implementation (reload impl skills first)
- When chaining multiple tickets, be EXTRA vigilant about completing all steps — this is when steps get skipped
- **Reloading a skill is cheap and idempotent.** When in doubt, load it again before the step. The `skill` tool is the canonical way to guarantee the workflow guidance is present in context.
- This skill is the LIGHT variant: no linter, SonarQube, Trivy, QA/e2e, documentation, or PR steps. If the user asks for those, switch to `feature-implementation`.
