---
name: githubpr
description: Manage the full GitHub PR lifecycle from a Jira ticket create a branch with the format <JIRA-ID>/<simple-description>, push, open a PR for review, poll CI, and merge when green. Use this skill whenever the user mentions creating a PR, opening a pull request, pushing a branch for review, or linking a Jira ticket to a GitHub PR. Also trigger when the user asks to wait for CI, merge a PR or manage the git workflow around a Jira ticket.
---

# GitHub PR Skill

Full lifecycle: branch → push → PR → CI → merge.

## 1. Branch naming convention

```
<JIRA-ID>/<simple-description>
```

Rules:
- `JIRA-ID`: exact ticket ID, uppercase — e.g. `PROJ-123`
- `simple-description`: 2–5 words, kebab-case, lowercase, no articles — e.g. `add-user-auth`
- Separator: `/`

Valid examples:
```
PROJ-123/add-user-auth
PROJ-456/fix-null-pointer-login
PROJ-789/update-dependencies
```

Create and switch to the branch:
```bash
git checkout main && git pull origin main
git checkout -b PROJ-123/add-user-auth
```

## 2. Create the PR

→ Load `references/pr-template.md` for the `gh pr create` command, the PR body template, and the full agent flow script.

> Always open as **draft** by default. Mark as "ready for review" only once CI is green.

## 3. Check CI status

```bash
# Quick overview
gh pr checks <PR_NUMBER>

# JSON output for agent parsing
gh pr checks <PR_NUMBER> --json name,state,conclusion
```

Possible states:
- `SUCCESS` → ✅
- `IN_PROGRESS` / `QUEUED` → ⏳ wait
- `FAILURE` → ❌ stop, investigate

## 4. CI polling (agent script)

→ Load `references/ci-polling-script.md` for `wait-ci.sh` (polls `gh pr checks`, exit codes: 0=green, 1=red, 3=timeout).

## 5. Merge

Two distinct scenarios — **load `references/merge-commands.md` before merging**:
- **A. Feature → `dev`** (or `main` if no `dev`): `gh pr merge --merge`
- **B. `dev` → `main`**: **NEVER use `gh pr merge`**. Use CLI `git merge --ff-only dev` + `git push origin main` (true fast-forward, no hash rewriting).

## 6. Full agent flow

→ Load `references/pr-template.md` for the end-to-end bash script (branch → push → PR → ready → wait-ci → merge).

## Agent rules

- **Never merge** if `wait-ci.sh` exit code != 0
- **Feature → `dev`**: use `gh pr merge --merge`
- **`dev` → `main`**: **never use `gh pr merge`**. Use CLI `git merge --ff-only dev` + `git push origin main` (see `references/merge-commands.md`)
- **Never force-push `dev` or `main`**
- **Never use `git reset --hard`.** It destroys uncommitted work irreversibly. To undo uncommitted changes, ask the user first, then prefer `git stash`, `git restore <file>`, or `git checkout -- <file>`. To move a branch, use `git reset --soft` / `git reset --mixed` (never hard). If a destructive git operation seems necessary, STOP and ask the user.
- On CI failure: log the ticket and **continue** to the next one — do not block the pipeline
- PR title must always start with the ticket ID: `PROJ-123: ...`

## References
- `references/pr-template.md` — `gh pr create` command, PR body template, full agent flow script
- `references/ci-polling-script.md` — `wait-ci.sh` polling script with exit codes
- `references/merge-commands.md` — merge commands for both scenarios (feature→dev merge commit, dev→main fast-forward)