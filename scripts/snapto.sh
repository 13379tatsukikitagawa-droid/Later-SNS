#!/bin/bash
# DEBUG ビルドを 起動引数つきで 開いて、スクショ → 見本と 比べる
# 使い方: scripts/snapto.sh <画面ID> <route> [t秒] [-- 追加の 起動引数…]
#   例: scripts/snapto.sh O02_opening_logo opening 2.62
#       scripts/snapto.sh H06_home_3shot home -- -debugShots 3 -debugFriends 3
set -euo pipefail
ID="${1:?画面ID}"; ROUTE="${2:?route}"; shift 2
T=""; if [ $# -gt 0 ] && [ "$1" != "--" ]; then T="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID="${LATTAG_BID:-com.tatsukikitagawa.laternew2}"
UD="${LATTAG_SIM:-815EEF6B-47AA-4F2E-BDAD-1E36BDFB851A}"
xcrun simctl terminate "$UD" "$BID" 2>/dev/null || true
ARGS=(-debugRoute "$ROUTE"); [ -n "$T" ] && ARGS+=(-debugT "$T")
xcrun simctl launch "$UD" "$BID" "${ARGS[@]}" "$@" >/dev/null
sleep "${SNAP_WAIT:-3.5}"
"$ROOT/scripts/snap.sh" "$ID" 2>&1 | grep -E "score|→"
