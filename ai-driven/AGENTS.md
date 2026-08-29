# Global Claude Code Instructions


## Core Principles

- **Never hallucinate.** Never guess UI navigation paths, API endpoints, config values, or tool behaviors. If you don't know, examine the actual code, configs, and logs first. If you can't access something, say so immediately rather than guessing.
- **Never make unsolicited edits.** When asked an analysis, investigation, or diagnosis question, respond with analysis only. Do NOT edit code, add docstrings, refactor, or make any changes unless explicitly asked to implement.
- **Stop when redirected.** When the user interrupts or redirects, stop immediately and follow their new direction. Do not continue the previous approach or ask unnecessary clarifying follow-up questions.
- **Read before reasoning.** Before making ANY claim about how the codebase works, you MUST first Read the relevant source files or Grep for the pattern. Never answer from general knowledge when the answer is in the code.
- **Confirm domain terminology.** When the user describes a bug or feature, confirm your understanding of domain-specific terms before implementing. Do not assume meanings.
- **Never state verifiable facts from memory.** For any claim about a tool, library, framework, API, version, feature, or external behavior, fetch the primary source (official docs, repo, or spec) BEFORE answering. Memory is for reasoning and synthesis only — not for verifiable facts. If a claim is verifiable and you haven't fetched the source this session, check first. No exceptions for "I think I know this." If you can't access the source, say so explicitly. Do not patch confidence with caveats after being challenged — get it right the first time.
- **You MUST follow feature-implementation workflow steps in order**. You must complete each step before moving to the next. If any issues arise in later steps, you may need to iterate back to previous steps to resolve them. Always ensure that requirements are fully clarified before coding, and that quality checks are passed before merging. **ALL STEPS ARE MANDATORY — load each skill directly via the `skill` tool: `test-writer-<stack>`, `hexagonal-<stack>-patterns`, `code-reviewer`, `code-simplifier`, `linter`, `sonarfix`, `trivyfix`, `tester-qa`, `documentation-writer`.** Do not delegate these steps to agents inside the workflow — agents remain available for the user's manual use only. Before creating a PR, you MUST print the full checklist and verify every step is checked. If a step was skipped, GO BACK and complete it before proceeding.

## Architecture & Code Style

- **Business logic belongs in use cases, not routers.** Routers/controllers are thin HTTP layers only. Follow the existing clean architecture pattern: Router -> Use Case -> Repository/Service.
- **Implement generic solutions on the first attempt.** When building abstractions (decorators, utilities, base classes), make them truly generic from the start. Don't require multiple correction cycles to generalize.
- **Follow existing patterns.** Before writing new code, find and follow the conventions already established in the project (naming, structure, error handling, testing style).

## Planning & Exploration

- **Do not exit plan mode prematurely.** Stay in plan mode until the user explicitly confirms the plan is approved or asks to proceed with implementation.
- **Separate exploration from implementation.** When a task requires investigation, complete the investigation phase and present findings before making any code changes.
- **Time-box exploration.** Don't spend excessive time reading files without producing actionable output. If exploring for more than a few minutes, present what you've found so far.

## Testing

- **Always run the full test suite after changes.** Use pytest for Python, npm/yarn test for TypeScript. Confirm ALL tests pass before declaring completion.
- **Iterate until fully green.** If tests fail after fixes, keep fixing until the ENTIRE suite passes with 0 failures. Don't stop after partial fixes.
- **Never modify test assertions** unless the test is clearly wrong or testing behavior that was intentionally changed.

## Infrastructure & DevOps

- When working with Kubernetes/infrastructure: if you cannot reach a remote cluster, immediately say so and provide the diagnostic commands the user should run, rather than attempting commands that will fail.

## Git

- **NEVER use `git reset --hard`.** It destroys uncommitted work irreversibly. To undo uncommitted changes, ask the user first, then prefer `git stash`, `git restore <file>`, or `git checkout -- <file>`. To move a branch, use `git reset --soft` / `git reset --mixed` (never hard). If a destructive git operation seems necessary, STOP and ask the user.

## Language

- The user works in French and English. Match the language of your responses to the language of the user's message. 

## Tools
- **Activate the project in serena**
- **Use Serana mcp to activate the project** and be able to use serena skills to understand and navigate inside the projects
- **Use Serana mcp to navigate inside project** 
- **Use Context7 and websearch to fetch updated documentation**

## Stack detection & mandatory skill loading (before any code)

Before writing or refactoring ANY code in a repo, detect the stack from the repo files and load the matching skill(s) via the `skill` tool BEFORE editing code. This applies to direct user requests, not only to the feature-implementation workflow.

- **Python / FastAPI** (look for `pyproject.toml`, `*.py`, `uv.lock`) → load `hexagonal-python-patterns`. Additionally load `async-python-patterns` if the task touches async/concurrency. For tests, additionally load `test-writer-python`.
- **React / TypeScript** (look for `package.json` with `react`, `*.tsx`, `vite.config.ts`) → load `hexagonal-react-patterns`. Additionally load `async-react-patterns` if async/streaming is involved, `vercel-react-best-practices` for Next.js or performance tasks. For tests, additionally load `test-writer-react`.
- **NestJS / TypeScript** (look for `@nestjs/core` in `package.json`, `*.controller.ts`, `app.module.ts`) → load `hexagonal-nestjs-patterns`. Additionally load `async-nestjs-patterns` if async/queues/microservices/WebSocket are involved. For tests, additionally load `test-writer-nestjs`.

Rules:
- This rule covers code-writing tasks (implement, refactor, fix, scaffold, write tests). Pure read-only analysis ("explain this code") does NOT require loading a skill.
- If the stack is ambiguous or mixed, ask the user which stack to target rather than guessing.
- After loading the skill, follow its workflow and reference files; do not improvise layer structure.