#!/bin/bash
# DEBUG ビルドを 起動引数つきで 開いて、スクショ → 見本と 比べる
# 使い方: scripts/snapto.sh <画面ID> <route> [t秒]   例: scripts/snapto.sh O02_opening_logo opening 2.95
set -euo pipefail
ID="${1:?画面ID}"; ROUTE="${2:?route}"; T="${3:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID="${LATTAG_BID:-com.tatsukikitagawa.laternew2}"
xcrun simctl terminate booted "$BID" 2>/dev/null || true
ARGS=(-debugRoute "$ROUTE"); [ -n "$T" ] && ARGS+=(-debugT "$T")
xcrun simctl launch booted "$BID" "${ARGS[@]}" >/dev/null
sleep "${SNAP_WAIT:-3.5}"
"$ROOT/scripts/snap.sh" "$ID"
