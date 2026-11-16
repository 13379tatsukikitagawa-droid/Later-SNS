#!/bin/bash
# 設定フローの 画面を DEBUG ビルドで 直接 出して、スクショ → 見本と 比べる
# 使い方: scripts/snapob.sh <画面ID> <step: intro|in|mail|sent|name|tag|fr|nt|go> [t秒(intro のみ)] [-- 追加の 起動引数…]
#   例: scripts/snapob.sh O03_onboarding_intro intro 3.0 / scripts/snapob.sh O09_onboarding_fr fr -- -debugInvite あや
set -euo pipefail
ID="${1:?画面ID}"; STEP="${2:?step}"; shift 2
T=""; if [ $# -gt 0 ] && [ "$1" != "--" ]; then T="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID="${LATTAG_BID:-com.tatsukikitagawa.laternew2}"
xcrun simctl terminate booted "$BID" 2>/dev/null || true
ARGS=(-debugOnbStep "$STEP"); [ -n "$T" ] && ARGS+=(-debugT "$T")
xcrun simctl launch booted "$BID" "${ARGS[@]}" "$@" >/dev/null
sleep "${SNAP_WAIT:-3}"
"$ROOT/scripts/snap.sh" "$ID" 2>&1 | grep -E "score|→"
