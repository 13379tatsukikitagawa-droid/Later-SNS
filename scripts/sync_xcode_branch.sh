#!/bin/bash
# Later-SNS: 作業ブランチを手元のリポジトリへ取り込む(fast-forwardのみ・未コミット変更があれば何もしない)
# 使い方: LATER_SNS_REPO=/Users/you/Later-SNS ./sync_xcode_branch.sh
set -u

REPO="${LATER_SNS_REPO:-$HOME/Later-SNS}"
BRANCH="claude/nifty-einstein-h2ezf1"
LOG="$HOME/Library/Logs/later-sns-sync.log"

mkdir -p "$(dirname "$LOG")"
{
  echo "== $(date '+%Y-%m-%d %H:%M:%S')"
  cd "$REPO" || { echo "repo not found: $REPO"; exit 1; }
  if [ -n "$(git status --porcelain)" ]; then
    echo "skip: uncommitted local changes"
    exit 0
  fi
  git fetch origin "$BRANCH" || exit 1
  git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" --track "origin/$BRANCH" || exit 1
  git pull --ff-only origin "$BRANCH" || { echo "skip: cannot fast-forward (local commits diverge)"; exit 1; }
  echo "ok: $(git log --oneline -1)"
} >>"$LOG" 2>&1
