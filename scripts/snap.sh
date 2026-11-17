#!/bin/bash
# 使い方: scripts/snap.sh <画面ID>   例: scripts/snap.sh H01_home
# 起動中の シミュレータの スクショ → 見本 と 比べる → /tmp/cmp_<ID>.png(score が 小さい ほど 同じ。目安 8 以下)
set -euo pipefail
ID="${1:?画面ID を 渡して ください(例: H01_home)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/Design/LattagKit"
REF="$KIT/screens/$ID.jpg"
[ -f "$REF" ] || REF="$KIT/screens/$ID.png"
[ -f "$REF" ] || { echo "見本画像が ありません: $ID" >&2; exit 1; }
xcrun simctl io "${LATTAG_SIM:-815EEF6B-47AA-4F2E-BDAD-1E36BDFB851A}" screenshot /tmp/sim.png
python3 "$KIT/tools/compare.py" "$REF" /tmp/sim.png "/tmp/cmp_$ID.png"
echo "→ /tmp/cmp_$ID.png"
