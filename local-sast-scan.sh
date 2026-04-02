#!/bin/bash

# Local SAST Scan Script
# Runs Semgrep + GoSec locally and posts results as a PR comment on GitHub

export PATH="$PATH:$HOME/go/bin"
set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Get current branch and find associated PR
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')

if [ -z "$PR_NUMBER" ]; then
    echo "No open PR found for branch: $BRANCH"
    echo "Make sure you have an open PR before running this script."
    exit 1
fi

echo "Found PR #$PR_NUMBER for branch: $BRANCH"
echo "Running SAST scans..."

# Get changed files compared to main
BASE_BRANCH="main"
CHANGED_GO=$(git diff --name-only --diff-filter=ACM "$BASE_BRANCH"..."$BRANCH" -- '*.go' || true)
CHANGED_PHP=$(git diff --name-only --diff-filter=ACM "$BASE_BRANCH"..."$BRANCH" -- '*.php' | grep -v '/vendor/' | grep -v '/node_modules/' || true)

# Initialize result file
RESULT_FILE=$(mktemp)
echo "# SAST Scan Results" > "$RESULT_FILE"
echo "" >> "$RESULT_FILE"
echo "**Branch:** \`$BRANCH\` | **PR:** #$PR_NUMBER | **Scanned at:** $(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

TOTAL_ISSUES=0

# ============================================================
# 1. SEMGREP (PHP + Go)
# ============================================================
echo ""
echo "========================================="
echo "Running Semgrep..."
echo "========================================="

SEMGREP_OUTPUT=$(mktemp)
semgrep scan \
    --config auto \
    --config p/owasp-top-ten \
    --config p/php \
    --config p/golang \
    --config p/secrets \
    --json \
    --baseline-commit "$BASE_BRANCH" 2>/dev/null > "$SEMGREP_OUTPUT" || true

SEMGREP_COUNT=$(jq '.results | length' "$SEMGREP_OUTPUT" 2>/dev/null || echo "0")
TOTAL_ISSUES=$((TOTAL_ISSUES + SEMGREP_COUNT))

echo "---" >> "$RESULT_FILE"
echo "## Semgrep (PHP + Go) — $SEMGREP_COUNT issue(s)" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

if [ "$SEMGREP_COUNT" -gt 0 ]; then
    echo "| File | Line | Rule | Severity | Message |" >> "$RESULT_FILE"
    echo "|---|---|---|---|---|" >> "$RESULT_FILE"
    jq -r '.results[]? | "| `\(.path)` | \(.start.line) | \(.check_id | split(".") | last) | \(.extra.severity) | \(.extra.message | split("\n") | first | .[0:80]) |"' "$SEMGREP_OUTPUT" >> "$RESULT_FILE"
else
    echo "No issues found." >> "$RESULT_FILE"
fi
echo "" >> "$RESULT_FILE"

echo "Semgrep: $SEMGREP_COUNT issues found"

# ============================================================
# 2. GOSEC (Go specialist)
# ============================================================
echo ""
echo "========================================="
echo "Running GoSec..."
echo "========================================="

if [ -n "$CHANGED_GO" ]; then
    # Find Go module roots
    MODROOTS=""
    for f in $CHANGED_GO; do
        dir=$(dirname "$f")
        while [ "$dir" != "." ]; do
            if [ -f "$dir/go.mod" ]; then
                MODROOTS="$MODROOTS $dir"
                break
            fi
            dir=$(dirname "$dir")
        done
        if [ -f "go.mod" ] && [ "$dir" = "." ]; then
            MODROOTS="$MODROOTS ."
        fi
    done
    MODROOTS=$(echo "$MODROOTS" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    GOSEC_OUTPUT="$REPO_ROOT/gosec-local-results.json"
    GOSEC_COUNT=0

    for modroot in $MODROOTS; do
        cd "$modroot"
        go mod tidy 2>/dev/null
        gosec -fmt json -out "$GOSEC_OUTPUT" ./... 2>/dev/null || true
        cd "$REPO_ROOT"
    done

    GOSEC_COUNT=$(jq '.Issues | length' "$GOSEC_OUTPUT" 2>/dev/null || echo "0")
    TOTAL_ISSUES=$((TOTAL_ISSUES + GOSEC_COUNT))

    echo "---" >> "$RESULT_FILE"
    echo "## GoSec (Go specialist) — $GOSEC_COUNT issue(s)" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    if [ "$GOSEC_COUNT" -gt 0 ]; then
        echo "| File | Line | Rule | Severity | Details |" >> "$RESULT_FILE"
        echo "|---|---|---|---|---|" >> "$RESULT_FILE"
        jq -r '.Issues[]? | "| `\(.file | split("/") | .[-2:] | join("/"))` | \(.line) | \(.rule_id) | \(.severity) | \(.details) |"' "$GOSEC_OUTPUT" >> "$RESULT_FILE"
    else
        echo "No issues found." >> "$RESULT_FILE"
    fi
    echo "" >> "$RESULT_FILE"
    echo "GoSec: $GOSEC_COUNT issues found"
else
    echo "---" >> "$RESULT_FILE"
    echo "## GoSec (Go specialist) — Skipped (no Go files changed)" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"
    echo "GoSec: Skipped (no Go files changed)"
fi

# ============================================================
# POST TO PR
# ============================================================
echo "" >> "$RESULT_FILE"
echo "---" >> "$RESULT_FILE"
echo "**Total issues: $TOTAL_ISSUES** | Scanned using Semgrep + GoSec" >> "$RESULT_FILE"

echo ""
echo "========================================="
echo "SCAN COMPLETE"
echo "========================================="
echo "Total issues found: $TOTAL_ISSUES"
echo ""
echo "Posting results to PR #$PR_NUMBER..."

# Check if a previous SAST comment exists, edit it instead of creating new one
EXISTING_COMMENT=$(gh api "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" --jq '.[] | select(.body | startswith("# SAST Scan Results")) | .id' | tail -1)

if [ -n "$EXISTING_COMMENT" ]; then
    gh api "repos/{owner}/{repo}/issues/comments/$EXISTING_COMMENT" -X PATCH -f body="$(cat "$RESULT_FILE")" > /dev/null
    echo "Updated existing comment on PR #$PR_NUMBER"
else
    gh pr comment "$PR_NUMBER" --body "$(cat "$RESULT_FILE")"
    echo "Posted new comment on PR #$PR_NUMBER"
fi

echo "Results posted to PR #$PR_NUMBER"
echo "View at: $(gh pr view "$PR_NUMBER" --json url --jq '.url')"

# Cleanup
rm -f "$SEMGREP_OUTPUT" "$RESULT_FILE" "$REPO_ROOT/gosec-local-results.json"
