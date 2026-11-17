#!/bin/bash
# 使い方: scripts/anchor_search.sh <ID> <sec-name> <基準y> [追加の 起動引数…]  → 一番 score が 低い y を 出す
cd "$(dirname "$0")/.."
ID=$1; SEC=$2; BASE=$3; shift 3
best=999; by=$BASE
for d in -24 -12 0 12 24 36; do
  y=$((BASE+d))
  sc=$(SNAP_WAIT=8 scripts/snapto.sh $ID home -- -debugBackdrop 1 -debugRequests 1 -debugSection $SEC:$y "$@" | head -1 | sed 's/score \([0-9.]*\).*/\1/')
  if [ -n "$sc" ] && python3 -c "import sys; sys.exit(0 if $sc<$best else 1)"; then best=$sc; by=$y; fi
done
echo "$ID $SEC:$by $best"
