---
name: githubpr
description: Manage the full GitHub PR lifecycle from a Jira ticket create a branch with the format <JIRA-ID>/<simple-description>, push, open a PR for review, poll CI, and merge when green. Use this skill whenever the user mentions creating a PR, opening a pull request, pushing a branch for review, or linking a Jira ticket to a GitHub PR. Also trigger when the user asks to wait for CI, merge a PR or manage the git workflow around a Jira ticket.
---

# GitHub PR Skill

Full lifecycle: branch → push → PR → CI → merge.

---

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

---

## 2. Create the PR

```bash
gh pr create \
  --title "PROJ-123: <short ticket summary>" \
  --body "$(cat <<'EOF'
## Jira
[PROJ-123](https://your-instance.atlassian.net/browse/PROJ-123)

## Changes
- <point 1>
- <point 2>

## Tests
- [ ] Unit tests
- [ ] Integration tests
EOF
)" \
  --base main \
  --draft
```

> Always open as **draft** by default. Mark as "ready for review" only once the CI is green and the code is finalized.

Mark as ready for review:
```bash
gh pr ready <PR_NUMBER>
```

---

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

---

## 4. CI polling (agent script)

Use this script to wait for CI in an automated workflow:

```bash
#!/bin/bash
# wait-ci.sh <PR_NUMBER> [TIMEOUT_SECONDS]
PR=$1
TIMEOUT=${2:-1800}   # 30 min default
INTERVAL=60

echo "Polling CI for PR #$PR..."
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
  CHECKS=$(gh pr checks $PR --json name,state,conclusion 2>/dev/null)

  IN_PROGRESS=$(echo $CHECKS | jq '[.[] | select(.state == "IN_PROGRESS" or .state == "QUEUED")] | length')
  FAILURES=$(echo $CHECKS | jq '[.[] | select(.conclusion == "FAILURE")] | length')

  echo "[$(date '+%H:%M:%S')] in_progress=$IN_PROGRESS failures=$FAILURES"

  if [ "$FAILURES" -gt 0 ]; then
    echo "❌ CI FAILED"
    exit 1
  fi

  if [ "$IN_PROGRESS" -eq 0 ]; then
    echo "✅ CI PASSED"
    exit 0
  fi

  sleep $INTERVAL
done

echo "⏱ TIMEOUT"
exit 3
```

Exit codes:
| Code | Meaning |
|------|---------|
| `0` | CI green → safe to merge |
| `1` | CI red → stop, investigate |
| `3` | Timeout → check manually |

---

## 5. Merge

```bash
# Squash merge (recommended — clean history)
gh pr merge <PR_NUMBER> --squash --delete-branch

# Merge commit (if project convention requires it)
gh pr merge <PR_NUMBER> --merge --delete-branch
```

After merge, switch back to main:
```bash
git checkout main && git pull origin main
git remote prune origin  # clean up deleted remote branches
```

---

## 6. Full agent flow

```bash
TICKET="PROJ-123"
DESC="add-user-auth"
BRANCH="${TICKET}/${DESC}"

# 1. Branch
git checkout main && git pull origin main
git checkout -b $BRANCH

# 2. [Dev / Tests / Sonar / Trivy here]

# 3. Push + PR
git push origin $BRANCH
PR_URL=$(gh pr create --title "$TICKET: ..." --body "..." --base main --draft)
PR_NUMBER=$(gh pr view --json number -q .number)

# 4. Ready for review
gh pr ready $PR_NUMBER

# 5. Wait for CI
bash wait-ci.sh $PR_NUMBER
CI_EXIT=$?

# 6. Merge if green
if [ $CI_EXIT -eq 0 ]; then
  gh pr merge $PR_NUMBER --squash --delete-branch
  git checkout main && git pull origin main
else
  echo "CI failed on $TICKET — skipping"
fi
```

---

## Agent rules

- **Never merge** if `wait-ci.sh` exit code != 0
- **Always squash merge** unless the project explicitly requires otherwise
- **Always `--delete-branch`** to keep the repo clean
- On CI failure: log the ticket and **continue** to the next one — do not block the pipeline
- PR title must always start with the ticket ID: `PROJ-123: ...`