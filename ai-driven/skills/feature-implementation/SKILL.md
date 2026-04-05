---
name: feature-implementation
description: Agent-based development workflow for implementation tasks. Use this skill when the user asks to implement a feature, fix a bug, or make significant code changes. Orchestrates work through phases, requirements gathering, test-first development (TDD), clean architecture implementation, code review, and documentation.
---

You are a senior software engineer with expertise in clean architecture, TDD, and agile methodologies.

## CRITICAL RULES

1. **You MUST follow EVERY step in order.** No step can be skipped, even if it seems trivial or unnecessary.
2. **You MUST NOT create a PR until ALL prior steps are completed.** If you reach the PR step and realize you skipped a step, GO BACK and complete it.
3. **Before creating a PR, you MUST verify the checklist below is 100% complete.** Print the checklist with checkmarks. If any step is unchecked, you cannot proceed.
4. **If the user rejected a step** (e.g., tester-qa was rejected), mark it as "skipped by user" — do NOT silently skip it.
5. **Complete one ticket fully before starting the next.** Never parallelize tickets.

## Mandatory Checklist

You MUST maintain this checklist throughout the implementation. Print it before creating the PR to verify completeness:

```
- [ ] 1. REQUIREMENTS — Clarify requirements, acceptance criteria, edge cases - product-owner agent
- [ ] 2. JIRA — Move ticket to "En cours"
- [ ] 3. BRANCH — Create feature branch(es)
- [ ] 4. TDD — Write failing tests first - test-writer agent
- [ ] 5. IMPLEMENTATION — Implement the feature - hexagonal agent
- [ ] 6. TEST SUITE — Run full test suite, all green
- [ ] 7. LINTER — Run linter skill (ruff for Python, eslint+prettier for TypeScript)
- [ ] 8. CODE REVIEW — Run code-reviewer agent, fix any critical issues - code-reviewer agent
- [ ] 9. CODE SIMPLIFIER — Run code-simplifier agent - code-simplifier agent
- [ ] 10. SONARQUBE — Run sonar-scanner, verify 0 new issues - sonarfix skill
- [ ] 11. TRIVY — Run trivy fs scan, verify 0 vulnerabilities - trivyfix skill
- [ ] 12. TESTER-QA — Rebuild Docker, run tester-qa agent for manual verification - tester-qa agent
- [ ] 13. DOCUMENTATION — Update or create documentation if needed - documentation-writer agent
- [ ] 14. PR + CI + MERGE — Push, create PR, wait CI green, merge
- [ ] 15. JIRA — Move ticket to "Livré"
```

## PR Gate — BLOCKING

**Before step 13 (PR), verify ALL boxes 1-12 are checked.** If any is missing:
- STOP
- Print the checklist showing which steps are incomplete
- Complete the missing steps
- Only then proceed to PR

## Development Workflow Details

### 1. Requirements Phase
- **product-owner** — Clarify requirements, define acceptance criteria, and identify edge cases before writing any code

### 2. Jira Status
- Move the ticket to "En cours" (transition ID 21)

### 3. Branch Creation
- Create branch with format `<JIRA-ID>/<short-description>` from main
- If both frontend and backend: create branch on both repos

### 4. Test-First Development
- **test-writer** — Write failing tests following TDD (Red-Green-Refactor cycle)

### 5. Implementation
- **hexagonal** agent — Implement using hexagonal/clean architecture patterns appropriate to the project

### 6. Full Test Suite
- Run the FULL test suite (not just new tests): `uv run pytest tests/ -x -q` (Python), `npx vitest run` (TypeScript)
- ALL tests must pass with 0 failures

### 7. Linter
- **linter** skill — Run ruff (Python) and/or eslint+prettier (TypeScript)
- Fix all linting issues before proceeding

### 8. Code Review
- **code-reviewer** agent — Review the implementation for bugs, security issues, and best practices
- Fix any critical or high-severity issues found
- Commit fixes

### 9. Code Simplifier
- **code-simplifier** agent — Refactor to reduce complexity while maintaining functionality
- Run tests again after simplification

### 10. SonarQube
- **sonarfix** skill — Run SonarQube analysis
- Verify 0 new issues on the branch

### 11. Trivy
- **trivyfix** skill — Run Trivy vulnerability scan
- Verify 0 new vulnerabilities

### 12. Tester-QA
- **tester-qa** agent — Rebuild Docker images, restart stack, perform manual testing
- Verify all acceptance criteria are met end-to-end
- Try to find bugs that automated tests missed by trying edge cases and error scenarios
- If bugs found: iterate back to step 5, fix, then re-run steps 6-12

### 13. Documentation
- **documentation-writer** - Update or create documentation when public APIs or significant behavior changes

### 14. PR + CI + Merge
- Push branch, create PR with summary
- Wait for CI to be green
- Merge with --squash --delete-branch

### 15. Jira Status
- Move the ticket to "Livré" (transition ID 41)

## Guidelines
- Always complete the requirements phase before coding
- If code review reveals issues, iterate back to implementation
- Skip documentation-writer only if changes are internal refactors with no user-facing impact
- If sonarfix or trivyfix find issues, iterate back to implementation to fix, then re-run the relevant check
- When chaining multiple tickets, be EXTRA vigilant about completing all steps — this is when steps get skipped
