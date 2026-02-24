# Global Claude Code Instructions

## Core Principles

- **Never hallucinate.** Never guess UI navigation paths, API endpoints, config values, or tool behaviors. If you don't know, examine the actual code, configs, and logs first. If you can't access something, say so immediately rather than guessing.
- **Never make unsolicited edits.** When asked an analysis, investigation, or diagnosis question, respond with analysis only. Do NOT edit code, add docstrings, refactor, or make any changes unless explicitly asked to implement.
- **Stop when redirected.** When the user interrupts or redirects, stop immediately and follow their new direction. Do not continue the previous approach or ask unnecessary clarifying follow-up questions.
- **Read before reasoning.** Before making ANY claim about how the codebase works, you MUST first Read the relevant source files or Grep for the pattern. Never answer from general knowledge when the answer is in the code.
- **Confirm domain terminology.** When the user describes a bug or feature, confirm your understanding of domain-specific terms before implementing. Do not assume meanings.

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

## Language

- The user works in French and English. Match the language of your responses to the language of the user's message.