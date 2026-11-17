# Later モック v52 ── 実測スペック(自動計測)

- 計測方法: `mock/later_v52.html` を ブラウザで 開き、画面(**390 × 844 pt**)の 各部品の 位置・大きさ・文字・色を そのまま 読み取った。**CSS は 古い版の 上書きが 重なっているので、迷ったら この表の 値が 正**。
- 単位: **px = pt**。x, y は 画面の 左上からの 位置(Dynamic Island・ステータスバー 込み)。
- 色は 16進数。`/ 0.50` は 不透明度。`(photo)` は 写真。
- 書体の 例: `700 12px/normal Space Mono` = 太さ 700 ・ 12pt ・ 行の高さ ・ 書体名。
- 「変形」の `matrix(a,b,c,d,x,y)` は 計測した 瞬間の 回転・拡大(動いている 部品は 値が ゆれる)。
- 部品名(`div#ypill.lp` など)は モックの HTML の id / class。`mock/src/` を その名前で 検索すると 元の CSS と JS が 見つかる。

## 目次

- A01_home_today ── Home(撮影前・昼)
- A02_home_after_shot ── Home(1枚撮った後)
- A03_live_panel ── 「消灯まで」ピル → ひらいた パネル
- A05_home_scroll2 ── Home 下スクロール(暗室)
- B01_yesterday_groups ── Later yesterday ・ Groups(撮る前=ロック)
- B08_yesterday_groups_open_full ── Later yesterday ・ Groups(撮った後)※y は タブの 中の 位置
- B03_yesterday_mondo ── Later yesterday ・ Mondo(撮る前=ロック)
- B10_mondo_open_full ── Later yesterday ・ Mondo(撮った後・下まで 全部)※y は タブの 中の 位置
- C01_friend ── Friend 画面(友だち3人)
- C02_me ── ME
- C03_recap_play ── Recap 再生
- D01_profile ── Profile
- D03_profile_edit ── Profile ・ Edit モード

## A01_home_today

**Home(撮影前・昼)**  ・ 見本: `screens/A01_home_today.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.hbg > i.lk1` | 173 | 100 | 389 | 389 |  |  |  | radial-gradient(circle, #59DB73 / 0.22, #59DB73 / 0.00 68%) | 50% | 変形: matrix(1.08065, 0, 0, 1.08065, 17.7428, 24.1948) |
| `div.hbg > i.lk2` | -168 | 427 | 404 | 404 |  |  |  | radial-gradient(circle, #87E59A / 0.16, #87E59A / 0.00 68%) | 50% | 変形: matrix(1.06234, 0, 0, 1.06234, 13.7146, 18.7017) |
| `div#hs.hs > div#orb.orb > span.qsb` | 0 | 198 | 390 | 37 | Later | 900 20px/normal Inter italic | #FFFFFF |  |  | 字間: -0.4px |
| `div#hs.hs > div#orb.orb > i.oau` | -71 | 166 | 532 | 532 |  |  |  | radial-gradient(circle, #25AC40 / 0.55, #70E086 / 0.25 45%, #000000 / 0.00 70%) | 50% | filter: blur(40px); 不透明: 0.505432; 変形: matrix(1.02377, 0, 0, 1.02377, 0, 0) |
| `div#hs.hs > div#orb.orb > i.oau.a2` | 14 | 251 | 363 | 363 |  |  |  | radial-gradient(circle, #C3F1CC / 0.90, #000000 / 0.00 65%) | 50% | filter: blur(50px); 不透明: 0.450603; 変形: matrix(1.06651, 0, 0, 1.06651, 0, 0) |
| `div#orb.orb > div#lens.lens > i.lnb` | 98 | 335 | 193 | 193 |  |  |  | radial-gradient(circle at 50% 40%, #2B2B2D, #0D0D0E 70%) | 50% | 影: #000000 / 0.60 0px 30px 50px -22px, #161616 0px 0px 0px 9px, #FFFFFF / 0.12 0px 0px 0px 11px, rgba(255, 255, 255, 0.1 |
| `div#orb.orb > div#lens.lens > i.lnk` | 98 | 335 | 193 | 193 |  |  |  | repeating-conic-gradient(#2C2C2E 0deg, #2C2C2E 0.9deg, #0C0C0D 0.9deg, #0C0C0D 2.4deg) | 50% |  |
| `div#orb.orb > div#lens.lens > svg.lnsc` | 98 | 335 | 193 | 193 |  |  |  |  |  |  |
| `svg.lnsc > text > textpath` | 140 | 349 | 139 | 167 | LATER · 28mm 1:1.4 · ∞ 10 5 3 2 1.5 1 0. | 700 8.4px/normal Space Mono | #111111 |  |  | 字間: 2.016px |
| `div#orb.orb > div#lens.lens > i.lnr` | 126 | 363 | 139 | 139 |  |  |  | radial-gradient(circle, #050506 60%, #1B1B1D 72%, #070708 74%, #2A2A2C 88%, #0A0A0B 100%) | 50% | 影: #FFFFFF / 0.08 0px 0px 0px 1px inset |
| `div#orb.orb > div#lens.lens > div.lng` | 139 | 376 | 112 | 112 |  |  |  | radial-gradient(circle, #0D1016, #020203 72%) | 50% | 影: #000000 / 0.90 0px 0px 18px 0px inset, #FFFFFF / 0.06 0px 0px 0px 1.5px inset |
| `div#lens.lens > div.lng > svg#lbl.lnbl` | 139 | 376 | 112 | 112 |  |  |  |  |  |  |
| `div#lens.lens > div.lng > i.lnc1` | 139 | 376 | 112 | 112 |  |  |  | radial-gradient(60% 40% at 30% 28%, #8C6EFF / 0.32, #000000 / 0.00 60%), radial-gradient(50% 35% at 72% 74%, #0BFF3C / 0.22, rgba(0, 0, 0, | 50% |  |
| `div#lens.lens > div.lng > i.lnc2` | 148 | 385 | 94 | 94 |  |  |  |  | 50% | 影: #FFFFFF / 0.07 0px 0px 0px 1.5px inset, #FFFFFF / 0.05 0px 10px 22px 0px inset |
| `div#lens.lens > div.lng > i.lnsp1` | 157 | 385 | 42 | 32 |  |  |  | linear-gradient(#FFFFFF / 0.55, #FFFFFF / 0.00) | 50% | filter: blur(1px); 変形: matrix(0.913545, -0.406737, 0.406737, 0.913545, 0, 0) |
| `div#lens.lens > div.lng > i.lnsp2` | 216 | 455 | 8 | 8 |  |  |  | #FFFFFF / 0.70 | 50% | filter: blur(1.5px) |
| `div#orb.orb > div#lens.lens > div.lnfc` | 253 | 350 | 24 | 19 |  |  |  | #0A0A0B | 9px | 影: #000000 / 0.90 0px 1px 3px 0px inset, #FFFFFF 0px 0px 0px 1.5px |
| `div#lens.lens > div.lnfc > span#lfn` | 262 | 352 | 6 | 15 | 3 | 700 16px/normal Space Mono | #FFFFFF |  |  |  |
| `div.lnin > i#lnic > svg` | 186 | 397 | 19 | 19 |  |  |  |  |  |  |
| `div#lens.lens > div.lnin > b#lnt2` | 164 | 417 | 63 | 33 | Shoot | 400 54px/54px Instrument Serif | #FFFFFF |  |  | 字間: -0.81px |
| `div#lens.lens > div.lnin > span#lns2` | 174 | 455 | 41 | 12 | 3 LEFT | 700 13px/normal Space Mono | #FFFFFF |  |  | 字間: 3.12px |
| `div#orb.orb > div#orz.orz > i.oglow` | -18 | 219 | 426 | 426 |  |  |  | radial-gradient(circle, #61DD7A / 0.32, #96E8A7 / 0.18 45%, #FFFFFF / 0.00 70%) | 50% | 不透明: 0.9 |
| `div#orb.orb > div#orz.orz > i.orip` | 3 | 240 | 385 | 385 |  |  |  |  | 50% | 線: 1px solid #24A03C / 0.28; 不透明: 0.0171314; 変形: matrix(1.41201, 0, 0, 1.41201, 0, 0) |
| `div#orb.orb > div#orz.orz > i.orip.o2` | 21 | 258 | 347 | 347 |  |  |  |  | 50% | 線: 1px solid #24A03C / 0.28; 不透明: 0.314385; 変形: matrix(1.27329, 0, 0, 1.27329, 0, 0) |
| `div#orb.orb > div#orz.orz > svg#ring.ring` | -129 | 108 | 648 | 648 |  |  |  |  |  | 変形: matrix(0.988336, 0.15229, -0.15229, 0.988336, 0, 0) |
| `svg#ring.ring > text > textpath#rtx` | -27 | 210 | 444 | 444 | LATER — TODAY — YESTERDAY — 3 SHOTS A DA | 400 8px/normal Space Mono | #111111 |  |  | 字間: 1.6px |
| `div#orb.orb > div#orz.orz > div#og.og` | 64 | 301 | 261 | 261 |  |  |  | radial-gradient(circle at 32% 24%, #FFFFFF 0%, #CCE8D1 35%, #EFE7DA 100%) | 50% | 影: #5A3214 / 0.45 0px 20px 44px -18px, #DCC8AF / 0.45 0px -8px 20px 0px inset |
| `div#orz.orz > div#og.og > canvas#globe` | 64 | 301 | 261 | 261 |  |  |  |  | 50% | filter: grayscale(1) sepia(0.6); 不透明: 0.18 |
| `div#orz.orz > div#og.og > i.ohi` | 113 | 305 | 122 | 72 |  |  |  | linear-gradient(#FFFFFF / 0.95, #FFFFFF / 0.00) | 50% | 変形: matrix(0.961262, -0.275637, 0.275637, 0.961262, 0, 0) |
| `div#orb.orb > div#orz.orz > svg#ofl.ofa` | 35 | 272 | 321 | 321 |  |  |  |  |  |  |
| `div#orz.orz > svg#ofl.ofa > path.on` | 96 | 284 | 229 | 78 |  |  |  |  |  | filter: drop-shadow(#FFFFFF / 0.60 0px 0px 3px) |
| `div#orz.orz > svg#ofl.ofa > path.on` | 190 | 401 | 153 | 178 |  |  |  |  |  | filter: drop-shadow(#FFFFFF / 0.60 0px 0px 3px) |
| `div#orz.orz > svg#ofl.ofa > path.on` | 47 | 354 | 102 | 219 |  |  |  |  |  | filter: drop-shadow(#FFFFFF / 0.60 0px 0px 3px) |
| `div#osat.osat > button.osb.lk > i` | 12 | 241 | 70 | 70 |  |  |  | #3A3A3A | 50% | 線: 2px solid #000000; 影: #000000 0px 3px 0px 0px |
| `button.osb.lk > i > svg` | 32 | 261 | 30 | 30 |  |  |  |  |  |  |
| `div#osat.osat > button.osb.lk > span` | 5 | 314 | 84 | 24 | YESTERDAY | 700 7px/normal Space Mono | #888888 | #2A2A2A | 5px | 字間: 0.98px |
| `div#osat.osat > button.osb > i` | 310 | 246 | 65 | 65 |  |  |  | #121212 | 50% | 線: 2px solid #121212; 影: #121212 0px 3px 0px 0px |
| `button.osb > i > svg` | 329 | 265 | 28 | 28 |  |  |  |  |  |  |
| `button.osb > i > u` | 354 | 246 | 19 | 19 |  |  |  | #D8262C | 50% | 線: 2px solid #FFFFFF |
| `div#osat.osat > button.osb > span` | 301 | 317 | 84 | 24 | NEW GROUP | 700 7px/normal Space Mono | #FFFFFF | #121212 | 5px | 字間: 0.98px |
| `div#osat.osat > button.osb.lk > i` | 15 | 533 | 65 | 65 |  |  |  | #3A3A3A | 50% | 線: 2px solid #000000; 影: #000000 0px 3px 0px 0px |
| `button.osb.lk > i > svg` | 33 | 552 | 28 | 28 |  |  |  |  |  |  |
| `div#osat.osat > button.osb.lk > span` | 20 | 604 | 54 | 24 | MONDO | 700 7px/normal Space Mono | #888888 | #2A2A2A | 5px | 字間: 0.98px |
| `div#osat.osat > button.osb > i` | 308 | 528 | 70 | 70 |  |  |  | #FFFFFF | 50% | 線: 2px solid #121212; 影: #121212 0px 3px 0px 0px |
| `button.osb > i > svg` | 328 | 548 | 30 | 30 |  |  |  |  |  |  |
| `div#osat.osat > button.osb > span` | 308 | 601 | 69 | 24 | FRIENDS | 700 7px/normal Space Mono | #FFFFFF | #121212 | 5px | 字間: 0.98px |
| `div#hs.hs > div#orb.orb > span#oscr.oscr` | 0 | 712 | 390 | 14 | TODAY ↓ | 700 9.5px/normal Space Mono | #8A8A84 |  |  | 字間: 2.85px; 不透明: 0.814496; 変形: matrix(1, 0, 0, 1, 0, 1.85504) |
| `div#hs.hs > div#orb.orb > svg.stk.s1` | 30 | 192 | 40 | 40 |  |  |  |  |  | 変形: matrix(1, 0.000963008, -0.000963008, 1, 0, -0.0386234) |
| `div#hs.hs > div#orb.orb > svg.stk.s2` | 304 | 198 | 57 | 25 |  |  |  |  |  | 変形: matrix(0.99914, -0.041474, 0.041474, 0.99914, 0, 1.48561) |
| `div#hs.hs > div#orb.orb > svg.stk.s3` | 314 | 630 | 40 | 40 |  |  |  |  |  | 変形: matrix(1, 0.000488103, -0.000488103, 1, 0, -0.0195764) |
| `div#hs.hs > div#orb.orb > svg.stk.s4` | 44 | 640 | 27 | 22 |  |  |  |  |  | 変形: matrix(0.999388, -0.0349785, 0.0349785, 0.999388, 0, 1.25283 |
| `div#hs.hs > div#dusk.dusk.d2only` | 0 | 692 | 390 | 434 |  |  |  | linear-gradient(#EFEFEA / 0.00 0%, #E3EEE3 12%, #9ED6A5 26%, #24A03C 40%, #156428 54%, #0B2A13 68%, rgb( |  |  |
| `div#hs.hs > div#dusk.dusk.d2only > i.dsg` | 0 | 692 | 390 | 434 |  |  |  | radial-gradient(260px 120px at 78% 46%, #27B042 / 0.35, #000000 / 0.00 70%) |  |  |
| `div#hs.hs > div#dusk.dusk.d2only > svg.dd.d1` | 325 | 768 | 31 | 31 |  |  |  |  |  | filter: drop-shadow(#000000 / 0.18 0px 4px 8px); 変形: matrix(0.999056, 0.0434465, -0.0434465, 0.999056, 0, -1.7430 |
| `div#hs.hs > div#dusk.dusk.d2only > svg.dd.d2` | 30 | 757 | 31 | 31 |  |  |  |  |  | filter: drop-shadow(#000000 / 0.18 0px 4px 8px); 変形: matrix(0.999692, -0.0248269, 0.0248269, 0.999692, 0, 0.88913 |
| `div#hs.hs > div#dusk.dusk.d2only > div#tdv.tdv` | 14 | 810 | 362 | 276 |  |  |  | #121014 / 0.86 | 30px | 影: #000000 / 0.80 0px 30px 60px -30px, #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div#tdv.tdv > div.tdh > b` | 32 | 828 | 68 | 34 | Today | 400 34px/34px Instrument Serif | #FFFFFF |  |  | 字間: -0.34px |
| `div#tdv.tdv > div.tdh > span` | 332 | 832 | 26 | 30 | 0 | 400 30px/30px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.tdh > span > s` | 345 | 837 | 13 | 26 | /3 | 400 20px/20px Instrument Serif italic | #6E6E75 |  |  |  |
| `div#hhd.hhd` | 0 | 0 | 390 | 150 |  |  |  | linear-gradient(#EFEFEA 74%, #EFEFEA / 0.00) |  |  |
| `div#hhd.hhd > div.hh > div.lg` | 22 | 63 | 73 | 32 | Later | 900 32px/32px Inter | #111111 |  |  | 字間: -2.08px |
| `div.lg > button#dsw.dsw > em.on` | 102 | 54 | 32 | 21 | today | 400 16px/normal Instrument Serif italic | #6E6E73 |  |  |  |
| `div.lg > button#dsw.dsw > em` | 143 | 54 | 54 | 21 | yesterday | 400 16px/normal Instrument Serif italic | #C2C1C7 |  |  |  |
| `div#hhd.hhd > div.hh > div.av` | 322 | 56 | 46 | 46 |  |  |  | radial-gradient(circle at 35% 30%, #D9F0DC, #24A03C 55%, #0D4A1B 95%) | 50% | 影: #EFEFEA 0px 0px 0px 2px, #111111 0px 0px 0px 3.5px |
| `div.hh > div.av > u` | 358 | 54 | 12 | 12 |  |  |  | #D8262C | 50% | 線: 2px solid #F3F2EC |
| `div#hhd.hhd > button#hst.hst.lp` | 16 | 106 | 235 | 36 |  |  |  | linear-gradient(#FFFFFF / 0.80, #F4F4F6 / 0.56) | 18px | 影: #FFFFFF 0px 1px 0px 0px inset, #000000 / 0.04 0px -1px 0px 0px inset, #000000 / 0.08 0px 0px 0px 0.6px inset, rgba(0, 0; 背景ぼかし: blur(16px) saturate(1.8) |
| `button#hst.hst.lp > span.lpr > svg` | 22 | 112 | 24 | 24 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `button#hst.hst.lp > span.lpr > i` | 31 | 121 | 7 | 7 |  |  |  | #24A03C | 50% | 影: #24A03C / 0.41 0px 0px 0px 2.17715px |
| `div#hhd.hhd > button#hst.hst.lp > span.lpl` | 53 | 116 | 47 | 16 | 消灯まで | 600 11.5px/normal Inter | #86868C |  |  | 字間: 0.23px |
| `span.rd > span.rs > i` | 107 | -8 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 8 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 23 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 39 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 54 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 70 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 85 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 101 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 116 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `button#hst.hst.lp > b#hlod.lpd.rl > span.rx` | 116 | 116 | 8 | 16 | h | 700 13.5px/normal Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 85 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 101 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 116 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 132 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 147 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 163 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 178 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 194 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 209 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 225 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 8 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 23 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 39 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 54 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 70 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 85 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 101 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 116 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 132 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 147 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `button#hst.hst.lp > b#hlod.lpd.rl > span.rx` | 145 | 116 | 12 | 16 | m | 700 13.5px/normal Inter | #111111 |  |  | 字間: -0.135px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 174 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 184 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 193 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > b` | 207 | 117 | 8 | 15 | 3 | 700 12.5px/normal Inter | #111111 |  |  | 字間: 0.25px |
| `div#hhd.hhd > button#hst.hst.lp > em.lpc` | 223 | 114 | 20 | 20 |  |  |  | #000000 / 0.05 | 50% |  |
| `button#hst.hst.lp > em.lpc > svg` | 228 | 119 | 10 | 10 |  |  |  |  |  |  |
| `div#hmoon.hmoon` | -105 | 712 | 600 | 600 |  |  |  | radial-gradient(circle at 50% 30%, #1C1C1C 0%, #0D0D0D 60%, #050505 100%) | 50% | 影: #000000 / 0.25 0px -12px 40px 0px, #FFFFFF / 0.18 0px 2px 1px 0px inset |
| `div#hmoon.hmoon > canvas#mgl.mgl` | -105 | 712 | 600 | 600 |  |  |  |  | 50% |  |
| `div#hmoon.hmoon > i.r2` | -91 | 726 | 572 | 572 |  |  |  |  | 50% | 影: #96E8A7 / 0.25 0px 0px 0px 1px inset |
| `div#hmoon.hmoon > i.mat` | -107 | 710 | 604 | 604 |  |  |  |  | 50% | 影: #FFFFFF 0px 10px 0px -6px inset, #D8262C 0px 14px 0px -9px inset, #C8A46A 0px 18px 0px -13px inset |
| `div#hmoon.hmoon > div.mt > b#hmt` | -105 | 734 | 600 | 36 | 今日を撮る | 900 25px/normal Inter | #FFFFFF |  |  | 字間: -0.5px |
| `div#hmoon.hmoon > div.mt > small#hms` | -105 | 775 | 600 | 16 | のこり 3こま | 700 10.5px/normal Space Mono | #9ED6A5 |  |  | 字間: 1.47px |
| `div.mt > small#hms > i` | 142 | 775 | 21 | 16 | ●●● | 700 10.5px/normal Space Mono | #239E3C |  |  | 字間: 0.63px |

## A02_home_after_shot

**Home(1枚撮った後)**  ・ 見本: `screens/A02_home_after_shot.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.hbg > i.lk1` | 174 | 102 | 396 | 396 |  |  |  | radial-gradient(circle, #59DB73 / 0.22, #59DB73 / 0.00 68%) | 50% | 変形: matrix(1.09982, 0, 0, 1.09982, 21.9595, 29.9448) |
| `div.hbg > i.lk2` | -167 | 430 | 415 | 415 |  |  |  | radial-gradient(circle, #87E59A / 0.16, #87E59A / 0.00 68%) | 50% | 変形: matrix(1.09167, 0, 0, 1.09167, 20.1663, 27.4995) |
| `div#hs.hs > div#orb.orb > span.qsb` | 0 | 198 | 390 | 37 | Later | 900 20px/normal Inter italic | #FFFFFF |  |  | 字間: -0.4px |
| `div#hs.hs > div#orb.orb > i.oau` | -68 | 169 | 526 | 526 |  |  |  | radial-gradient(circle, #25AC40 / 0.55, #70E086 / 0.25 45%, #000000 / 0.00 70%) | 50% | filter: blur(40px); 不透明: 0.528839; 変形: matrix(1.01129, 0, 0, 1.01129, 0, 0) |
| `div#hs.hs > div#orb.orb > i.oau.a2` | 12 | 249 | 367 | 367 |  |  |  | radial-gradient(circle, #C3F1CC / 0.90, #000000 / 0.00 65%) | 50% | filter: blur(50px); 不透明: 0.407273; 変形: matrix(1.07806, 0, 0, 1.07806, 0, 0) |
| `div#orb.orb > div#lens.lens > i.lnb` | 98 | 335 | 193 | 193 |  |  |  | radial-gradient(circle at 50% 40%, #2B2B2D, #0D0D0E 70%) | 50% | 影: #000000 / 0.60 0px 30px 50px -22px, #161616 0px 0px 0px 9px, #FFFFFF / 0.12 0px 0px 0px 11px, rgba(255, 255, 255, 0.1 |
| `div#orb.orb > div#lens.lens > i.lnk` | 98 | 335 | 193 | 193 |  |  |  | repeating-conic-gradient(#2C2C2E 0deg, #2C2C2E 0.9deg, #0C0C0D 0.9deg, #0C0C0D 2.4deg) | 50% |  |
| `div#orb.orb > div#lens.lens > svg.lnsc` | 98 | 335 | 193 | 193 |  |  |  |  |  |  |
| `svg.lnsc > text > textpath` | 140 | 349 | 139 | 167 | LATER · 28mm 1:1.4 · ∞ 10 5 3 2 1.5 1 0. | 700 8.4px/normal Space Mono | #111111 |  |  | 字間: 2.016px |
| `div#orb.orb > div#lens.lens > i.lnr` | 126 | 363 | 139 | 139 |  |  |  | radial-gradient(circle, #050506 60%, #1B1B1D 72%, #070708 74%, #2A2A2C 88%, #0A0A0B 100%) | 50% | 影: #FFFFFF / 0.08 0px 0px 0px 1px inset |
| `div#orb.orb > div#lens.lens > div.lng` | 139 | 376 | 112 | 112 |  |  |  | radial-gradient(circle, #0D1016, #020203 72%) | 50% | 影: #000000 / 0.90 0px 0px 18px 0px inset, #FFFFFF / 0.06 0px 0px 0px 1.5px inset |
| `div#lens.lens > div.lng > img#lph.lnph` | 158 | 395 | 74 | 74 |  |  |  |  | 50% | filter: url("#chk") contrast(1.05) |
| `div#lens.lens > div.lng > svg#lbl.lnbl` | 139 | 376 | 112 | 112 |  |  |  |  |  | 不透明: 0.92 |
| `div#lens.lens > div.lng > i.lnc1` | 139 | 376 | 112 | 112 |  |  |  | radial-gradient(60% 40% at 30% 28%, #8C6EFF / 0.32, #000000 / 0.00 60%), radial-gradient(50% 35% at 72% 74%, #0BFF3C / 0.22, rgba(0, 0, 0, | 50% |  |
| `div#lens.lens > div.lng > i.lnc2` | 148 | 385 | 94 | 94 |  |  |  |  | 50% | 影: #FFFFFF / 0.07 0px 0px 0px 1.5px inset, #FFFFFF / 0.05 0px 10px 22px 0px inset |
| `div#lens.lens > div.lng > i.lnsp1` | 157 | 385 | 42 | 32 |  |  |  | linear-gradient(#FFFFFF / 0.55, #FFFFFF / 0.00) | 50% | filter: blur(1px); 変形: matrix(0.913545, -0.406737, 0.406737, 0.913545, 0, 0) |
| `div#lens.lens > div.lng > i.lnsp2` | 216 | 455 | 8 | 8 |  |  |  | #FFFFFF / 0.70 | 50% | filter: blur(1.5px) |
| `div#orb.orb > div#lens.lens > div.lnfc` | 253 | 350 | 24 | 19 |  |  |  | #0A0A0B | 9px | 影: #000000 / 0.90 0px 1px 3px 0px inset, #FFFFFF 0px 0px 0px 1.5px |
| `div#lens.lens > div.lnfc > span#lfn` | 262 | 352 | 6 | 15 | 2 | 700 16px/normal Space Mono | #FFFFFF |  |  |  |
| `div.lnin > i#lnic > svg` | 186 | 400 | 19 | 19 |  |  |  |  |  |  |
| `div#lens.lens > div.lnin > b#lnt2` | 155 | 420 | 81 | 26 | Yesterday | 400 42px/42px Instrument Serif | #FFFFFF |  |  | 字間: -0.63px |
| `div#lens.lens > div.lnin > span#lns2` | 168 | 451 | 55 | 12 | 1 OPENED | 700 13px/normal Space Mono | #FFFFFF |  |  | 字間: 3.12px |
| `div#orb.orb > div#orz.orz > i.oglow` | -18 | 219 | 426 | 426 |  |  |  | radial-gradient(circle, #61DD7A / 0.32, #96E8A7 / 0.18 45%, #FFFFFF / 0.00 70%) | 50% | 不透明: 0.9 |
| `div#orb.orb > div#orz.orz > i.orip` | 48 | 285 | 293 | 293 |  |  |  |  | 50% | 線: 1px solid #24A03C / 0.28; 不透明: 0.737831; 変形: matrix(1.07568, 0, 0, 1.07568, 0, 0) |
| `div#orb.orb > div#orz.orz > i.orip.o2` | 6 | 243 | 378 | 378 |  |  |  |  | 50% | 線: 1px solid #24A03C / 0.28; 不透明: 0.071276; 変形: matrix(1.38674, 0, 0, 1.38674, 0, 0) |
| `div#orb.orb > div#orz.orz > svg#ring.ring` | -143 | 94 | 675 | 675 |  |  |  |  |  | 変形: matrix(0.977381, 0.211485, -0.211485, 0.977381, 0, 0) |
| `svg#ring.ring > text > textpath#rtx` | -37 | 200 | 463 | 463 | LATER — TODAY — YESTERDAY — 3 SHOTS A DA | 400 8px/normal Space Mono | #111111 |  |  | 字間: 1.6px |
| `div#orb.orb > div#orz.orz > div#og.og` | 64 | 301 | 261 | 261 |  |  |  | radial-gradient(circle at 32% 24%, #FFFFFF 0%, #CCE8D1 35%, #EFE7DA 100%) | 50% | 影: #5A3214 / 0.45 0px 20px 44px -18px, #DCC8AF / 0.45 0px -8px 20px 0px inset |
| `div#orz.orz > div#og.og > canvas#globe` | 64 | 301 | 261 | 261 |  |  |  |  | 50% | filter: grayscale(1) sepia(0.6); 不透明: 0.18 |
| `div#orz.orz > div#og.og > i.ohi` | 113 | 305 | 122 | 72 |  |  |  | linear-gradient(#FFFFFF / 0.95, #FFFFFF / 0.00) | 50% | 変形: matrix(0.961262, -0.275637, 0.275637, 0.961262, 0, 0) |
| `div#orb.orb > div#orz.orz > svg#ofl.ofa` | 35 | 272 | 321 | 321 |  |  |  |  |  |  |
| `div#orz.orz > svg#ofl.ofa > path.on` | 190 | 401 | 153 | 178 |  |  |  |  |  | filter: drop-shadow(#FFFFFF / 0.60 0px 0px 3px) |
| `div#orz.orz > svg#ofl.ofa > path.on` | 47 | 354 | 102 | 219 |  |  |  |  |  | filter: drop-shadow(#FFFFFF / 0.60 0px 0px 3px) |
| `div#osat.osat > button.osb > i` | 12 | 239 | 70 | 70 |  |  |  | #FFFFFF | 50% | 線: 2px solid #121212; 影: #121212 0px 3px 0px 0px |
| `button.osb > i > svg` | 32 | 259 | 30 | 30 |  |  |  |  |  |  |
| `div#osat.osat > button.osb > span` | 20 | 312 | 54 | 24 | SHOOT | 700 7px/normal Space Mono | #FFFFFF | #121212 | 5px | 字間: 0.98px |
| `div#osat.osat > button.osb > i` | 310 | 241 | 65 | 65 |  |  |  | #FFFFFF | 50% | 線: 2px solid #121212; 影: #121212 0px 3px 0px 0px |
| `button.osb > i > svg` | 329 | 259 | 28 | 28 |  |  |  |  |  |  |
| `div#osat.osat > button.osb > span` | 308 | 312 | 69 | 24 | DEVELOP | 700 7px/normal Space Mono | #FFFFFF | #121212 | 5px | 字間: 0.98px |
| `div#osat.osat > button.osb > i` | 15 | 534 | 65 | 65 |  |  |  | #121212 | 50% | 線: 2px solid #121212; 影: #121212 0px 3px 0px 0px |
| `button.osb > i > svg` | 33 | 553 | 28 | 28 |  |  |  |  |  |  |
| `button.osb > i > u` | 61 | 536 | 19 | 19 |  |  |  | #D8262C | 50% | 線: 2px solid #FFFFFF |
| `div#osat.osat > button.osb > span` | 5 | 605 | 84 | 24 | NEW GROUP | 700 7px/normal Space Mono | #FFFFFF | #121212 | 5px | 字間: 0.98px |
| `div#osat.osat > button.osb > i` | 308 | 533 | 70 | 70 |  |  |  | #FFFFFF | 50% | 線: 2px solid #121212; 影: #121212 0px 3px 0px 0px |
| `button.osb > i > svg` | 328 | 553 | 30 | 30 |  |  |  |  |  |  |
| `div#osat.osat > button.osb > span` | 315 | 606 | 54 | 24 | MONDO | 700 7px/normal Space Mono | #FFFFFF | #121212 | 5px | 字間: 0.98px |
| `div#hs.hs > div#orb.orb > span#oscr.oscr` | 0 | 710 | 390 | 14 | TODAY ↓ | 700 9.5px/normal Space Mono | #8A8A84 |  |  | 字間: 2.85px; 不透明: 0.972042; 変形: matrix(1, 0, 0, 1, 0, 0.279581) |
| `div#hs.hs > div#orb.orb > svg.stk.s1` | 27 | 184 | 45 | 45 |  |  |  |  |  | 変形: matrix(0.989552, 0.14418, -0.14418, 0.989552, 0, -5.80285) |
| `div#hs.hs > div#orb.orb > svg.stk.s2` | 304 | 198 | 56 | 23 |  |  |  |  |  | 変形: matrix(0.999806, -0.0196959, 0.0196959, 0.999806, 0, 0.70535 |
| `div#hs.hs > div#orb.orb > svg.stk.s3` | 312 | 625 | 43 | 43 |  |  |  |  |  | 変形: matrix(0.995944, 0.0899805, -0.0899805, 0.995944, 0, -3.6137 |
| `div#hs.hs > div#orb.orb > svg.stk.s4` | 43 | 642 | 29 | 24 |  |  |  |  |  | 変形: matrix(0.990755, -0.13566, 0.13566, 0.990755, 0, 4.87299) |
| `div#hs.hs > div#dusk.dusk.d2only` | 0 | 692 | 390 | 434 |  |  |  | linear-gradient(#EFEFEA / 0.00 0%, #E3EEE3 12%, #9ED6A5 26%, #24A03C 40%, #156428 54%, #0B2A13 68%, rgb( |  |  |
| `div#hs.hs > div#dusk.dusk.d2only > i.dsg` | 0 | 692 | 390 | 434 |  |  |  | radial-gradient(260px 120px at 78% 46%, #27B042 / 0.35, #000000 / 0.00 70%) |  |  |
| `div#hs.hs > div#dusk.dusk.d2only > svg.dd.d1` | 325 | 768 | 31 | 31 |  |  |  |  |  | filter: drop-shadow(#000000 / 0.18 0px 4px 8px); 変形: matrix(0.99899, 0.0449296, -0.0449296, 0.99899, 0, -1.8026) |
| `div#hs.hs > div#dusk.dusk.d2only > svg.dd.d2` | 30 | 757 | 31 | 31 |  |  |  |  |  | filter: drop-shadow(#000000 / 0.18 0px 4px 8px); 変形: matrix(0.99967, -0.025693, 0.025693, 0.99967, 0, 0.920163) |
| `div#hs.hs > div#dusk.dusk.d2only > div#tdv.tdv` | 14 | 810 | 362 | 276 |  |  |  | #121014 / 0.86 | 30px | 影: #000000 / 0.80 0px 30px 60px -30px, #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div#tdv.tdv > div.tdh > b` | 32 | 828 | 68 | 34 | Today | 400 34px/34px Instrument Serif | #FFFFFF |  |  | 字間: -0.34px |
| `div#tdv.tdv > div.tdh > span` | 338 | 832 | 20 | 30 | 1 | 400 30px/30px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.tdh > span > s` | 345 | 837 | 13 | 26 | /3 | 400 20px/20px Instrument Serif italic | #6E6E75 |  |  |  |
| `div#hhd.hhd` | 0 | 0 | 390 | 150 |  |  |  | linear-gradient(#EFEFEA 74%, #EFEFEA / 0.00) |  |  |
| `div#hhd.hhd > div.hh > div.lg` | 22 | 63 | 73 | 32 | Later | 900 32px/32px Inter | #111111 |  |  | 字間: -2.08px |
| `div.lg > button#dsw.dsw > em.on` | 102 | 54 | 32 | 21 | today | 400 16px/normal Instrument Serif italic | #6E6E73 |  |  |  |
| `div.lg > button#dsw.dsw > em` | 143 | 54 | 54 | 21 | yesterday | 400 16px/normal Instrument Serif italic | #C2C1C7 |  |  |  |
| `div#hhd.hhd > div.hh > div.av` | 322 | 56 | 46 | 46 |  |  |  | radial-gradient(circle at 35% 30%, #D9F0DC, #24A03C 55%, #0D4A1B 95%) | 50% | 影: #EFEFEA 0px 0px 0px 2px, #111111 0px 0px 0px 3.5px |
| `div.hh > div.av > u` | 358 | 54 | 12 | 12 |  |  |  | #D8262C | 50% | 線: 2px solid #F3F2EC |
| `div#hhd.hhd > button#hst.hst.lp` | 16 | 106 | 235 | 36 |  |  |  | linear-gradient(#FFFFFF / 0.80, #F4F4F6 / 0.56) | 18px | 影: #FFFFFF 0px 1px 0px 0px inset, #000000 / 0.04 0px -1px 0px 0px inset, #000000 / 0.08 0px 0px 0px 0.6px inset, rgba(0, 0; 背景ぼかし: blur(16px) saturate(1.8) |
| `button#hst.hst.lp > span.lpr > svg` | 22 | 112 | 24 | 24 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `button#hst.hst.lp > span.lpr > i` | 31 | 121 | 7 | 7 |  |  |  | #24A03C | 50% | 影: #24A03C / 0.57 0px 0px 0px 0.350095px |
| `div#hhd.hhd > button#hst.hst.lp > span.lpl` | 53 | 116 | 47 | 16 | 消灯まで | 600 11.5px/normal Inter | #86868C |  |  | 字間: 0.23px |
| `span.rd > span.rs > i` | 107 | -8 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 8 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 23 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 39 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 54 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 70 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 85 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 101 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 116 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `button#hst.hst.lp > b#hlod.lpd.rl > span.rx` | 116 | 116 | 8 | 16 | h | 700 13.5px/normal Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 85 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 101 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 116 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 132 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 147 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 163 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 178 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 194 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 209 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 225 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 8 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 23 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 39 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 54 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 70 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 85 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 101 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 116 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 132 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 147 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #111111 |  |  | 字間: -0.135px |
| `button#hst.hst.lp > b#hlod.lpd.rl > span.rx` | 145 | 116 | 12 | 16 | m | 700 13.5px/normal Inter | #111111 |  |  | 字間: -0.135px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 174 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 184 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > i.o.gone` | 193 | 118 | 7 | 12 |  |  |  |  | 2px | 影: #86868C 0px 0px 0px 1.2px inset; 不透明: 0.4 |
| `button#hst.hst.lp > span#hfilm.hfb > b` | 207 | 117 | 8 | 15 | 2 | 700 12.5px/normal Inter | #111111 |  |  | 字間: 0.25px |
| `div#hhd.hhd > button#hst.hst.lp > em.lpc` | 223 | 114 | 20 | 20 |  |  |  | #000000 / 0.05 | 50% |  |
| `button#hst.hst.lp > em.lpc > svg` | 228 | 119 | 10 | 10 |  |  |  |  |  |  |
| `div#hmoon.hmoon` | -105 | 712 | 600 | 600 |  |  |  | radial-gradient(circle at 50% 30%, #1C1C1C 0%, #0D0D0D 60%, #050505 100%) | 50% | 影: #000000 / 0.25 0px -12px 40px 0px, #FFFFFF / 0.18 0px 2px 1px 0px inset |
| `div#hmoon.hmoon > canvas#mgl.mgl` | -105 | 712 | 600 | 600 |  |  |  |  | 50% |  |
| `div#hmoon.hmoon > i.r2` | -91 | 726 | 572 | 572 |  |  |  |  | 50% | 影: #96E8A7 / 0.25 0px 0px 0px 1px inset |
| `div#hmoon.hmoon > i.mat` | -107 | 710 | 604 | 604 |  |  |  |  | 50% | 影: #FFFFFF 0px 10px 0px -6px inset, #D8262C 0px 14px 0px -9px inset, #C8A46A 0px 18px 0px -13px inset |
| `div#hmoon.hmoon > div.mt > b#hmt` | -105 | 734 | 600 | 36 | もう1枚 撮る | 900 25px/normal Inter | #FFFFFF |  |  | 字間: -0.5px |
| `div#hmoon.hmoon > div.mt > small#hms` | -105 | 775 | 600 | 16 | ○  のこり 2こま | 700 10.5px/normal Space Mono | #9ED6A5 |  |  | 字間: 1.47px |
| `div.mt > small#hms > i` | 142 | 775 | 14 | 16 | ●● | 700 10.5px/normal Space Mono | #239E3C |  |  | 字間: 0.63px |

## A03_live_panel

**「消灯まで」ピル → ひらいた パネル**  ・ 見本: `screens/A03_live_panel.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `i#lpsc.lpsc` | 0 | 0 | 390 | 844 |  |  |  | #000000 / 0.30 |  | 背景ぼかし: blur(8px) |
| `div#lpk.lpk` | 12 | 97 | 366 | 305 |  |  |  | #050506 | 36px | 影: #000000 / 0.75 0px 34px 70px -24px, #FFFFFF / 0.07 0px 0px 0px 1px inset |
| `div#lpk.lpk > div.lpin` | 12 | 97 | 366 | 315 |  |  |  |  |  | filter: blur(0px); 変形: matrix(1, 0, 0, 1, 0, 0) |
| `div.lpin > div.lph > span.lv` | 30 | 116 | 59 | 22 | LIVE | 700 9.5px/normal Space Mono | #7EE08F | #24A03C / 0.16 | 11px | 字間: 1.9px |
| `div.lph > span.lv > i` | 37 | 124 | 6 | 6 |  |  |  | #3BD35A | 50% | 影: #000000 / 0.00 0px 0px 0px 7px |
| `div.lpin > div.lph > span#lpclk.lt` | 99 | 119 | 221 | 15 | 14:32:18 | 700 10px/normal Space Mono | #5D5D63 |  |  | 字間: 1.4px |
| `div.lpin > div.lph > button#lpxx.lpxx` | 330 | 112 | 30 | 30 |  |  |  | #1A1A1D | 50% |  |
| `div.lph > button#lpxx.lpxx > svg` | 339 | 121 | 12 | 12 |  |  |  |  |  |  |
| `div.lpin > div.lpm > span.k` | 30 | 155 | 61 | 15 | ひらくまで | 600 12px/normal Inter | #8C8C93 |  |  | 字間: 0.24px |
| `span.rd > span.rs > i` | 30 | 99 | 38 | 74 | 0 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 173 | 38 | 74 | 1 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 246 | 38 | 74 | 2 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 320 | 38 | 74 | 3 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 394 | 38 | 74 | 4 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 467 | 38 | 74 | 5 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 541 | 38 | 74 | 6 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 614 | 38 | 74 | 7 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 688 | 38 | 74 | 8 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 30 | 762 | 38 | 74 | 9 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 68 | -48 | 38 | 74 | 5 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 68 | 26 | 38 | 74 | 6 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 68 | 99 | 38 | 74 | 7 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 68 | 173 | 38 | 74 | 8 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 68 | 246 | 38 | 74 | 9 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `div.lpm > div.big > em` | 107 | 174 | 19 | 64 | : | 800 64px/64px Inter | #FFFFFF |  |  | 字間: -3.2px; 不透明: 0.35; 変形: matrix(1, 0, 0, 1, 0, -3.84) |
| `span.rd > span.rs > i` | 128 | 26 | 38 | 74 | 0 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 99 | 38 | 74 | 1 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 173 | 38 | 74 | 2 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 246 | 38 | 74 | 3 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 320 | 38 | 74 | 4 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 394 | 38 | 74 | 5 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 467 | 38 | 74 | 6 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 541 | 38 | 74 | 7 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 614 | 38 | 74 | 8 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 128 | 688 | 38 | 74 | 9 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 166 | -48 | 38 | 74 | 4 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 166 | 26 | 38 | 74 | 5 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 166 | 99 | 38 | 74 | 6 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 166 | 173 | 38 | 74 | 7 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 166 | 246 | 38 | 74 | 8 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 166 | 320 | 38 | 74 | 9 | 900 64px/73.6px Inter | #FFFFFF |  |  | 字間: -3.2px |
| `span.rd > span.rs > i` | 212 | 112 | 14 | 25 | 0 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 137 | 14 | 25 | 1 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 162 | 14 | 25 | 2 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 187 | 14 | 25 | 3 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 213 | 14 | 25 | 4 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 238 | 14 | 25 | 5 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 263 | 14 | 25 | 6 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 289 | 14 | 25 | 7 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 314 | 14 | 25 | 8 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 212 | 339 | 14 | 25 | 9 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 184 | 14 | 25 | 0 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 209 | 14 | 25 | 1 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 235 | 14 | 25 | 2 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 260 | 14 | 25 | 3 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 285 | 14 | 25 | 4 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 310 | 14 | 25 | 5 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 336 | 14 | 25 | 6 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 361 | 14 | 25 | 7 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 386 | 14 | 25 | 8 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `span.rd > span.rs > i` | 227 | 412 | 14 | 25 | 9 | 700 22px/25.3px Inter | #3BD35A |  |  | 字間: -0.44px |
| `div.lpin > div.lpm > span.k2` | 30 | 252 | 98 | 16 | 消灯まで | 600 11.5px/normal Inter | #6C6C73 |  |  |  |
| `span.rd > span.rs > i` | 82 | 129 | 8 | 14 | 0 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 143 | 8 | 14 | 1 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 157 | 8 | 14 | 2 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 171 | 8 | 14 | 3 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 184 | 8 | 14 | 4 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 198 | 8 | 14 | 5 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 212 | 8 | 14 | 6 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 226 | 8 | 14 | 7 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 240 | 8 | 14 | 8 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 82 | 253 | 8 | 14 | 9 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.k2 > b#lpk2.rl > span.rx` | 90 | 253 | 7 | 15 | h | 700 12px/normal Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 226 | 8 | 14 | 0 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 240 | 8 | 14 | 1 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 253 | 8 | 14 | 2 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 267 | 8 | 14 | 3 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 281 | 8 | 14 | 4 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 295 | 8 | 14 | 5 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 309 | 8 | 14 | 6 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 322 | 8 | 14 | 7 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 336 | 8 | 14 | 8 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 100 | 350 | 8 | 14 | 9 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 157 | 8 | 14 | 0 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 171 | 8 | 14 | 1 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 184 | 8 | 14 | 2 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 198 | 8 | 14 | 3 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 212 | 8 | 14 | 4 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 226 | 8 | 14 | 5 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 240 | 8 | 14 | 6 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 253 | 8 | 14 | 7 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 267 | 8 | 14 | 8 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.rd > span.rs > i` | 109 | 281 | 8 | 14 | 9 | 700 12px/13.8px Inter | #C9C9CF |  |  |  |
| `span.k2 > b#lpk2.rl > span.rx` | 117 | 253 | 11 | 15 | m | 700 12px/normal Inter | #C9C9CF |  |  |  |
| `div.lpin > div#lptr.lptr > div.bar` | 30 | 287 | 330 | 8 |  |  |  | #161618 | 4px |  |
| `div#lptr.lptr > div.bar > i.z1` | 30 | 287 | 240 | 8 |  |  |  | linear-gradient(90deg, #14301B, #1C4A27) | 4px 0px 0px 4px |  |
| `div#lptr.lptr > div.bar > i.z2` | 270 | 287 | 90 | 8 |  |  |  | repeating-linear-gradient(-45deg, #1D1D21 0px, #1D1D21 4px, #121214 4px, #121214 8px) | 0px 4px 4px 0px |  |
| `div#lptr.lptr > div.bar > i.fill` | 30 | 287 | 145 | 8 |  |  |  | linear-gradient(90deg, #3BD35A / 0.25, #3BD35A / 0.75) | 4px | 影: #3BD35A / 0.35 0px 0px 14px 0px |
| `div#lptr.lptr > div.bar > i.sh` | 118 | 274 | 8 | 11 |  |  |  | #3BD35A | 2px | 影: #3BD35A / 0.70 0px 0px 8px 0px |
| `div#lptr.lptr > div.bar > i#lpnow.now` | 168 | 284 | 14 | 14 |  |  |  | #FFFFFF | 50% | 影: #FFFFFF / 0.14 0px 0px 0px 4px, #FFFFFF / 0.70 0px 0px 18px 0px |
| `div#lptr.lptr > div.lbs > span` | 30 | 304 | 25 | 13 | 0:00 | 700 8.5px/normal Space Mono | #55555B |  |  | 字間: 1.02px |
| `div#lptr.lptr > div.lbs > span` | 108 | 304 | 25 | 13 | 9:00 | 700 8.5px/normal Space Mono | #55555B |  |  | 字間: 1.02px; 変形: matrix(1, 0, 0, 1, -12.4453, 0) |
| `div#lptr.lptr > div.lbs > span.r` | 254 | 304 | 31 | 13 | 24:00 | 700 8.5px/normal Space Mono | #D8262C |  |  | 字間: 1.02px; 変形: matrix(1, 0, 0, 1, -15.5625, 0) |
| `div#lptr.lptr > div.lbs > span.e` | 304 | 304 | 56 | 13 | 9:00 OPEN | 700 8.5px/normal Space Mono | #7EE08F |  |  | 字間: 1.02px; 変形: matrix(1, 0, 0, 1, -56, 0) |
| `div#lpfr.lpfr > button.lf.on > i` | 26 | 335 | 48 | 62 |  |  |  | (photo) |  | filter: blur(5px) saturate(0.6) brightness(0.75); 変形: matrix(1.2, 0, 0, 1.2, 0, 0) |
| `div#lpfr.lpfr > button.lf.on > span` | 42 | 361 | 17 | 11 | DEV | 700 7.5px/normal Space Mono | #FFFFFF |  |  | 字間: 1.05px |
| `div.lpbt > div#lpfr.lpfr > button.lf` | 76 | 340 | 40 | 52 |  |  |  |  | 9px | 影: #2A2A2E 0px 0px 0px 1.4px inset |
| `div#lpfr.lpfr > button.lf > svg` | 88 | 358 | 16 | 16 |  |  |  |  |  |  |
| `div.lpbt > div#lpfr.lpfr > button.lf` | 122 | 340 | 40 | 52 |  |  |  |  | 9px | 影: #2A2A2E 0px 0px 0px 1.4px inset |
| `div#lpfr.lpfr > button.lf > svg` | 134 | 358 | 16 | 16 |  |  |  |  |  |  |
| `div.lpin > div.lpbt > button#lpgo.lpgo` | 174 | 339 | 186 | 54 |  |  |  | #FFFFFF | 27px |  |
| `div.lpbt > button#lpgo.lpgo > svg` | 228 | 355 | 22 | 22 |  |  |  |  |  |  |
| `div.lpbt > button#lpgo.lpgo > span` | 260 | 351 | 46 | 31 | shoot | 800 17px/17.85px Inter | #111111 |  |  | 字間: -0.34px |
| `button#lpgo.lpgo > span > small` | 260 | 369 | 42 | 13 | 2 left | 700 9px/normal Space Mono | #8E8E95 |  |  | 字間: 1.44px; 大文字化: uppercase |

## A05_home_scroll2

**Home 下スクロール(暗室)**  ・ 見本: `screens/A05_home_scroll2.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.hbg > i.lk1` | 172 | 95 | 376 | 376 |  |  |  | radial-gradient(circle, #59DB73 / 0.22, #59DB73 / 0.00 68%) | 50% | 変形: matrix(1.04469, 0, 0, 1.04469, 9.83136, 13.4064) |
| `div.hbg > i.lk2` | -167 | 429 | 413 | 413 |  |  |  | radial-gradient(circle, #87E59A / 0.16, #87E59A / 0.00 68%) | 50% | 変形: matrix(1.08592, 0, 0, 1.08592, 18.903, 25.7768) |
| `div#hs.hs > section#arc.arc.d2only` | 0 | -74 | 390 | 3653 |  |  |  | #0A0A0B |  |  |
| `section#arc.arc.d2only > div#aact.aact > button#acnew.acd.nw` | 18 | -20 | 150 | 248 |  |  |  |  | 24px | 影: #2A2A2E 0px 0px 0px 1.5px inset |
| `div#aact.aact > button#acnew.acd.nw > i` | 67 | 57 | 52 | 52 |  |  |  | #FFFFFF | 50% |  |
| `button#acnew.acd.nw > i > svg` | 82 | 72 | 22 | 22 |  |  |  |  |  |  |
| `div#aact.aact > button#acnew.acd.nw > span` | 53 | 121 | 81 | 29 | New group | 400 22px/normal Instrument Serif | #FFFFFF |  |  |  |
| `div#hs.hs > section#arc.arc.d2only > div.axh` | 18 | 262 | 354 | 31 |  |  |  |  |  | 線: 1px solid #1E1E21 |
| `section#arc.arc.d2only > div.axh > span` | 18 | 277 | 81 | 16 | YESTERDAY | 700 10.5px/normal Space Mono | #8C8C93 |  |  | 字間: 2.52px |
| `section#arc.arc.d2only > div.axh > em#aydd` | 348 | 277 | 24 | 16 | THU | 700 10.5px/normal Space Mono | #55555B |  |  | 字間: 1.47px |
| `div#hs.hs > section#arc.arc.d2only > div#ayh.ayh` | 14 | 305 | 362 | 452 |  |  |  | #161618 | 30px |  |
| `section#arc.arc.d2only > div#ayh.ayh > i.bg` | 14 | 305 | 362 | 452 |  |  |  | (photo) |  |  |
| `section#arc.arc.d2only > div#ayh.ayh > span.stk2` | 307 | 323 | 52 | 36 | #朝 | 900 15px/15px Inter | #111111 | #9ED8FF | 12px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `section#arc.arc.d2only > div#ayh.ayh > div.tt` | 14 | 511 | 362 | 78 | Yesterday | 400 54px/54px Instrument Serif | #FFFFFF |  |  | 字間: -0.81px |
| `div#ayh.ayh > div.tt > small` | 14 | 573 | 362 | 16 | NOV 12 | 700 10.5px/normal Space Mono | #FFFFFF / 0.70 |  |  | 字間: 2.52px |
| `div.sts > div > b` | 81 | 607 | 12 | 31 | 6 | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  | 字間: -0.31px |
| `div.sts > div > span` | 58 | 641 | 58 | 16 | Moments | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.sts > div.cir > b` | 185 | 607 | 27 | 31 | 6d | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  | 字間: -0.31px |
| `div.sts > div.cir > span` | 186 | 641 | 24 | 16 | Left | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.sts > div.cir > svg` | 161 | 597 | 74 | 50 |  |  |  |  |  |  |
| `div.sts > div > b` | 300 | 607 | 12 | 31 | 4 | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  | 字間: -0.31px |
| `div.sts > div > span` | 280 | 641 | 51 | 16 | People › | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div#ayh.ayh > div.bt > button.w` | 30 | 687 | 268 | 54 | Mondo | 800 15px/normal Inter | #111111 | #FFFFFF | 27px |  |
| `div.bt > button.w > svg` | 125 | 704 | 19 | 19 |  |  |  |  |  |  |
| `div#ayh.ayh > div.bt > button.s` | 306 | 687 | 54 | 54 |  |  |  | #FFFFFF / 0.12 | 27px | 背景ぼかし: blur(10px) |
| `div.bt > button.s > svg` | 323 | 704 | 20 | 20 |  |  |  |  |  |  |
| `section#arc.arc.d2only > div#ayg.ayg > div.ayc` | 14 | 766 | 177 | 212 |  |  |  | #161618 | 20px |  |
| `div#ayg.ayg > div.ayc > img` | 14 | 766 | 177 | 212 |  |  |  |  |  |  |
| `section#arc.arc.d2only > div#ayg.ayg > div#ayk.ayc.own` | 200 | 766 | 177 | 236 |  |  |  | #161618 | 20px |  |
| `div#ayg.ayg > div#ayk.ayc.own > img` | 200 | 766 | 177 | 236 |  |  |  |  |  |  |
| `div#hhd.hhd` | 0 | 0 | 390 | 150 |  |  |  | linear-gradient(#0A0A0B 74%, #0A0A0B / 0.00) |  |  |
| `div#hhd.hhd > div.hh > div.lg` | 22 | 63 | 73 | 32 | Later | 900 32px/32px Inter | #FFFFFF |  |  | 字間: -2.08px |
| `div.lg > button#dsw.dsw > em.on` | 102 | 54 | 32 | 21 | today | 400 16px/normal Instrument Serif italic | #B9B9C0 |  |  |  |
| `div.lg > button#dsw.dsw > em` | 143 | 54 | 54 | 21 | yesterday | 400 16px/normal Instrument Serif italic | #55555B |  |  |  |
| `div#hhd.hhd > div.hh > div.av` | 322 | 56 | 46 | 46 |  |  |  | radial-gradient(circle at 35% 30%, #D9F0DC, #24A03C 55%, #0D4A1B 95%) | 50% | 影: #0A0A0B 0px 0px 0px 2px, #FFFFFF 0px 0px 0px 3.5px |
| `div.hh > div.av > u` | 358 | 54 | 12 | 12 |  |  |  | #D8262C | 50% | 線: 2px solid #0A0A0B |
| `div#hhd.hhd > button#hst.hst.lp` | 16 | 106 | 235 | 36 |  |  |  | linear-gradient(#3A3A40 / 0.62, #1A1A1E / 0.50) | 18px | 影: #FFFFFF / 0.18 0px 1px 0px 0px inset, #000000 / 0.04 0px -1px 0px 0px inset, #FFFFFF / 0.08 0px 0px 0px 0.6px ins; 背景ぼかし: blur(16px) saturate(1.8) |
| `button#hst.hst.lp > span.lpr > svg` | 22 | 112 | 24 | 24 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `button#hst.hst.lp > span.lpr > i` | 31 | 121 | 7 | 7 |  |  |  | #24A03C | 50% | 影: #000000 / 0.00 0px 0px 0px 7px |
| `div#hhd.hhd > button#hst.hst.lp > span.lpl` | 53 | 116 | 47 | 16 | 消灯まで | 600 11.5px/normal Inter | #9A9AA2 |  |  | 字間: 0.23px |
| `span.rd > span.rs > i` | 107 | -8 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 8 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 23 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 39 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 54 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 70 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 85 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 101 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 107 | 116 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `button#hst.hst.lp > b#hlod.lpd.rl > span.rx` | 116 | 116 | 8 | 16 | h | 700 13.5px/normal Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 85 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 101 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 116 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 132 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 147 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 163 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 178 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 194 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 209 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 127 | 225 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 8 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 23 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 39 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 54 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 70 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 85 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 101 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 116 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 132 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 136 | 147 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #FFFFFF |  |  | 字間: -0.135px |
| `button#hst.hst.lp > b#hlod.lpd.rl > span.rx` | 145 | 116 | 12 | 16 | m | 700 13.5px/normal Inter | #FFFFFF |  |  | 字間: -0.135px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 174 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > i` | 184 | 118 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#hst.hst.lp > span#hfilm.hfb > i.o.gone` | 193 | 118 | 7 | 12 |  |  |  |  | 2px | 影: #9A9AA2 0px 0px 0px 1.2px inset; 不透明: 0.4 |
| `button#hst.hst.lp > span#hfilm.hfb > b` | 207 | 117 | 8 | 15 | 2 | 700 12.5px/normal Inter | #FFFFFF |  |  | 字間: 0.25px |
| `div#hhd.hhd > button#hst.hst.lp > em.lpc` | 223 | 114 | 20 | 20 |  |  |  | #FFFFFF / 0.08 | 50% |  |
| `button#hst.hst.lp > em.lpc > svg` | 228 | 119 | 10 | 10 |  |  |  |  |  |  |
| `div#hfade.hfade.on` | 0 | 640 | 390 | 204 |  |  |  | linear-gradient(#0A0A0B / 0.00, #0A0A0B / 0.92 45%, #0A0A0B) |  |  |
| `div#hmoon.hmoon` | -105 | 712 | 600 | 600 |  |  |  | radial-gradient(circle at 50% 30%, #1C1C1C 0%, #0D0D0D 60%, #050505 100%) | 50% | 影: #000000 / 0.25 0px -12px 40px 0px, #FFFFFF / 0.18 0px 2px 1px 0px inset |
| `div#hmoon.hmoon > canvas#mgl.mgl` | -105 | 712 | 600 | 600 |  |  |  |  | 50% |  |
| `div#hmoon.hmoon > i.r2` | -91 | 726 | 572 | 572 |  |  |  |  | 50% | 影: #96E8A7 / 0.25 0px 0px 0px 1px inset |
| `div#hmoon.hmoon > i.mat` | -107 | 710 | 604 | 604 |  |  |  |  | 50% | 影: #FFFFFF 0px 10px 0px -6px inset, #D8262C 0px 14px 0px -9px inset, #C8A46A 0px 18px 0px -13px inset |
| `div#hmoon.hmoon > div.mt > b#hmt` | -105 | 734 | 600 | 36 | もう1枚 撮る | 900 25px/normal Inter | #FFFFFF |  |  | 字間: -0.5px |
| `div#hmoon.hmoon > div.mt > small#hms` | -105 | 775 | 600 | 16 | ○  のこり 2こま | 700 10.5px/normal Space Mono | #9ED6A5 |  |  | 字間: 1.47px |
| `div.mt > small#hms > i` | 142 | 775 | 14 | 16 | ●● | 700 10.5px/normal Space Mono | #239E3C |  |  | 字間: 0.63px |

## B01_yesterday_groups

**Later yesterday ・ Groups(撮る前=ロック)**  ・ 見本: `screens/B01_yesterday_groups.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.yhd` | 0 | 0 | 390 | 176 |  |  |  | linear-gradient(#FFFFFF 72%, #000000 / 0.00) |  |  |
| `div.yhd > div.yh > div.ylg` | 18 | 58 | 224 | 44 | Later | 900 44px/44px Inter | #111111 |  |  | 字間: -3.08px |
| `div.ylg > button#ydsw.ydsw > em` | 127 | 77 | 38 | 25 | today | 400 19px/normal Instrument Serif italic | #8E8E93 |  |  |  |
| `div.ylg > button#ydsw.ydsw > em.on` | 178 | 77 | 64 | 25 | yesterday | 400 19px/normal Instrument Serif italic | #111111 |  |  |  |
| `div.yhd > div.yh > div.yav` | 320 | 50 | 52 | 52 |  |  |  | radial-gradient(circle at 35% 30%, #AFE5BA, #7CD48E 50%, #B87AC8 100%) | 50% | 影: #FFFFFF 0px 0px 0px 3px, #111111 0px 0px 0px 4.5px |
| `div.yhd > button#ypill.ypill.lp` | 18 | 114 | 255 | 36 |  |  |  | linear-gradient(#FFFFFF / 0.80, #F4F4F6 / 0.56) | 18px | 影: #FFFFFF 0px 1px 0px 0px inset, #000000 / 0.04 0px -1px 0px 0px inset, #000000 / 0.08 0px 0px 0px 0.6px inset, rgba(0, 0; 背景ぼかし: blur(16px) saturate(1.8) |
| `button#ypill.ypill.lp > span.lpr > svg` | 24 | 120 | 24 | 24 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `button#ypill.ypill.lp > span.lpr > i` | 33 | 129 | 7 | 7 |  |  |  | #24A03C | 50% | 影: #24A03C / 0.45 0px 0px 0px 1.76707px |
| `div.yhd > button#ypill.ypill.lp > span#ypt.lpl` | 55 | 124 | 59 | 16 | ひらくまで | 600 11.5px/normal Inter | #86868C |  |  | 字間: 0.23px |
| `span.rd > span.rs > i` | 121 | 109 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 124 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 140 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 155 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 171 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 186 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 202 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 217 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 233 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 248 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 0 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 16 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 31 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 47 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 62 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 78 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 93 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 109 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 124 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 140 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `button#ypill.ypill.lp > b#ypd.lpd.rl > span.rx` | 139 | 124 | 8 | 16 | h | 700 13.5px/normal Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 93 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 109 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 124 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 140 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 155 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 171 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 186 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 202 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 217 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 233 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 16 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 31 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 47 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 62 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 78 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 93 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 109 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 124 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 140 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 155 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `button#ypill.ypill.lp > b#ypd.lpd.rl > span.rx` | 168 | 124 | 12 | 16 | m | 700 13.5px/normal Inter | #8E8E93 |  |  | 字間: -0.135px |
| `button#ypill.ypill.lp > span#ybars.ybars > i` | 197 | 126 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#ypill.ypill.lp > span#ybars.ybars > i` | 207 | 126 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#ypill.ypill.lp > span#ybars.ybars > i.o` | 216 | 126 | 7 | 12 |  |  |  |  | 2px | 影: #86868C 0px 0px 0px 1.2px inset; 不透明: 0.4 |
| `button#ypill.ypill.lp > span#ybars.ybars > b` | 230 | 125 | 8 | 15 | 2 | 700 12.5px/normal Inter | #86868C |  |  |  |
| `div.yhd > button#ypill.ypill.lp > em.lpc` | 245 | 122 | 20 | 20 |  |  |  | #000000 / 0.05 | 50% |  |
| `button#ypill.ypill.lp > em.lpc > svg` | 250 | 127 | 10 | 10 |  |  |  |  |  |  |
| `section#ytg.ytab.on > div#yon.yon > div.yoh` | 18 | 182 | 354 | 470 |  |  |  | #161618 | 32px |  |
| `div.yoh > div.yoc > i` | 12 | 176 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.yoh > div.yoc > i` | 197 | 176 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.yoh > div.yoc > i` | 12 | 419 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.yoh > div.yoc > i` | 197 | 419 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div#yon.yon > div.yoh > span.yok` | 18 | 204 | 354 | 15 | GROUPS · NOV 12 | 700 10px/normal Space Mono | #FFFFFF / 0.75 |  |  | 字間: 2.6px |
| `div#yon.yon > div.yoh > h2` | 34 | 358 | 322 | 94 | Yesterday, together. | 400 46px/46.92px Instrument Serif | #FFFFFF |  |  | 字間: -0.69px |
| `div.yos > div > b` | 75 | 492 | 14 | 31 | 0 | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.yos > div > span` | 60 | 526 | 45 | 16 | Groups | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.yos > div > b` | 176 | 492 | 27 | 31 | 6d | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.yos > div > span` | 178 | 526 | 24 | 16 | Left | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.yos > div > b` | 296 | 492 | 14 | 31 | 0 | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.yos > div > span` | 275 | 526 | 55 | 16 | Friends › | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.yoh > div.yob > button.w` | 32 | 582 | 262 | 56 | Create | 800 16px/normal Inter | #111111 | #FFFFFF | 28px |  |
| `div.yob > button.w > svg` | 124 | 601 | 18 | 18 |  |  |  |  |  |  |
| `div.yoh > div.yob > button.s` | 302 | 582 | 56 | 56 |  |  |  | #FFFFFF / 0.14 | 28px | 影: #FFFFFF / 0.30 0px 1px 0px 0px inset, #FFFFFF / 0.14 0px 0px 0px 1px inset; 背景ぼかし: blur(16px) saturate(1.8) |
| `div.yob > button.s > svg` | 319 | 599 | 22 | 22 |  |  |  |  |  |  |
| `div#ybody.ybody > section#ytg.ytab.on > button#yme.yme` | 18 | 676 | 354 | 206 |  |  |  | #F5F5F7 | 40px |  |
| `section#ytg.ytab.on > button#yme.yme > b` | 46 | 696 | 130 | 92 | ME | 900 92px/92px Inter | #0A0A0C |  |  | 字間: -7.36px |
| `section#ytg.ytab.on > button#yme.yme > i.c1` | 186 | 701 | 100 | 145 |  |  |  | linear-gradient(160deg, #72D786, #EE6A8E 55%, #7A63B0) | 18px | 影: #000000 / 0.35 0px 14px 24px -10px; 変形: matrix(0.992546, -0.121869, 0.121869, 0.992546, 0, 0) |
| `section#ytg.ytab.on > button#yme.yme > i.c2` | 250 | 708 | 91 | 140 |  |  |  | linear-gradient(160deg, #A9D4E6, #E8EEDD 55%, #84D394) | 18px | 影: #000000 / 0.35 0px 14px 24px -10px; 変形: matrix(0.99863, -0.052336, 0.052336, 0.99863, 0, 0) |
| `section#ytg.ytab.on > button#yme.yme > i.c3` | 309 | 683 | 93 | 142 |  |  |  | linear-gradient(160deg, #3A3F73, #D4689B 60%, #7AD78D) | 18px | 影: #000000 / 0.35 0px 14px 24px -10px; 変形: matrix(0.997564, 0.0697565, -0.0697565, 0.997564, 0, 0) |
| `section#ytg.ytab.on > button#yme.yme > span` | 46 | 841 | 202 | 19 | きのうの まい ・ 7日で きえる | 600 13px/normal Inter | #6E6E73 |  |  | 字間: 1.56px |
| `section#ytg.ytab.on > button#yme.yme > svg` | 318 | 832 | 30 | 30 |  |  |  |  |  |  |
| `nav#ynav.ynav` | 58 | 748 | 274 | 66 |  |  |  | #28282E / 0.38 | 33px | 影: #FFFFFF / 0.28 0px 1px 0px 0px inset, #FFFFFF / 0.06 0px -1px 0px 0px inset, #FFFFFF / 0.12 0px 0px 0px 1px; 背景ぼかし: blur(22px) saturate(1.9); 変形: matrix(1.00001, 0, 0, 1.00001, 0, -0.00584349) |
| `nav#ynav.ynav > button > svg` | 118 | 762 | 22 | 22 |  |  |  |  |  |  |
| `nav#ynav.ynav > button > span` | 111 | 786 | 38 | 14 | Mondo | 600 11px/normal Inter | #8E8E93 |  |  |  |
| `nav#ynav.ynav > button.on` | 197 | 753 | 127 | 56 |  |  |  | #000000 / 0.07 | 28px | 影: #FFFFFF / 0.30 0px 1px 0px 0px inset |
| `nav#ynav.ynav > button.on > svg` | 250 | 762 | 22 | 22 |  |  |  |  |  |  |
| `nav#ynav.ynav > button.on > span` | 241 | 786 | 39 | 14 | Groups | 600 11px/normal Inter | #111111 |  |  |  |

## B08_yesterday_groups_open_full

**Later yesterday ・ Groups(撮った後)※y は タブの 中の 位置**  ・ 見本: `screens/B08_yesterday_groups_open.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div#yon.yon > div.yoh` | 18 | 182 | 354 | 470 |  |  |  | #161618 | 32px |  |
| `div.yoh > div.yoc > i` | 12 | 176 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.yoh > div.yoc > i` | 197 | 176 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.yoh > div.yoc > i` | 12 | 419 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.yoh > div.yoc > i` | 197 | 419 | 182 | 240 |  |  |  | (photo) |  | filter: url("#chk") |
| `div#yon.yon > div.yoh > span.yok` | 18 | 204 | 354 | 15 | GROUPS · NOV 12 | 700 10px/normal Space Mono | #FFFFFF / 0.75 |  |  | 字間: 2.6px |
| `div#yon.yon > div.yoh > h2` | 34 | 358 | 322 | 94 | Yesterday, together. | 400 46px/46.92px Instrument Serif | #FFFFFF |  |  | 字間: -0.69px |
| `div.yos > div > b` | 75 | 492 | 14 | 31 | 0 | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.yos > div > span` | 60 | 526 | 45 | 16 | Groups | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.yos > div > b` | 176 | 492 | 27 | 31 | 6d | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.yos > div > span` | 178 | 526 | 24 | 16 | Left | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.yos > div > b` | 296 | 492 | 14 | 31 | 0 | 400 31px/31px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.yos > div > span` | 275 | 526 | 55 | 16 | Friends › | 500 13px/normal Inter | #FFFFFF / 0.62 |  |  |  |
| `div.yoh > div.yob > button.w` | 32 | 582 | 262 | 56 | Create | 800 16px/normal Inter | #111111 | #FFFFFF | 28px |  |
| `div.yob > button.w > svg` | 124 | 601 | 18 | 18 |  |  |  |  |  |  |
| `div.yoh > div.yob > button.s` | 302 | 582 | 56 | 56 |  |  |  | #FFFFFF / 0.14 | 28px | 影: #FFFFFF / 0.30 0px 1px 0px 0px inset, #FFFFFF / 0.14 0px 0px 0px 1px inset; 背景ぼかし: blur(16px) saturate(1.8) |
| `div.yob > button.s > svg` | 319 | 599 | 22 | 22 |  |  |  |  |  |  |
| `button#yme.yme` | 18 | 676 | 354 | 206 |  |  |  | #F5F5F7 | 40px |  |
| `button#yme.yme > b` | 46 | 696 | 130 | 92 | ME | 900 92px/92px Inter | #0A0A0C |  |  | 字間: -7.36px |
| `button#yme.yme > i.c1` | 186 | 701 | 100 | 145 |  |  |  | linear-gradient(160deg, #72D786, #EE6A8E 55%, #7A63B0) | 18px | 影: #000000 / 0.35 0px 14px 24px -10px; 変形: matrix(0.992546, -0.121869, 0.121869, 0.992546, 0, 0) |
| `button#yme.yme > i.c2` | 250 | 708 | 91 | 140 |  |  |  | linear-gradient(160deg, #A9D4E6, #E8EEDD 55%, #84D394) | 18px | 影: #000000 / 0.35 0px 14px 24px -10px; 変形: matrix(0.99863, -0.052336, 0.052336, 0.99863, 0, 0) |
| `button#yme.yme > i.c3` | 309 | 683 | 93 | 142 |  |  |  | linear-gradient(160deg, #3A3F73, #D4689B 60%, #7AD78D) | 18px | 影: #000000 / 0.35 0px 14px 24px -10px; 変形: matrix(0.997564, 0.0697565, -0.0697565, 0.997564, 0, 0) |
| `button#yme.yme > span` | 46 | 841 | 202 | 19 | きのうの まい ・ 7日で きえる | 600 13px/normal Inter | #6E6E73 |  |  | 字間: 1.56px |
| `button#yme.yme > svg` | 318 | 832 | 30 | 30 |  |  |  |  |  |  |
| `div#yfx.yfx > div.yfc` | 18 | 912 | 354 | 174 |  |  |  | #F4F3F7 | 30px | 影: #E3E2E9 0px 0px 0px 1px inset |
| `div.yfc > div.yfh > b` | 38 | 930 | 76 | 34 | Friend | 400 34px/34px Instrument Serif | #111111 |  |  |  |
| `div.yfc > div.yfh > span.ct` | 124 | 938 | 22 | 26 | 0 | 400 20px/normal Instrument Serif | #111111 |  |  |  |
| `div.yfh > span.ct > i` | 133 | 944 | 13 | 18 | /12 | 400 14px/normal Instrument Serif italic | #8E8E93 |  |  |  |
| `div.yfc > div.yfh > button.go` | 320 | 930 | 36 | 36 |  |  |  | #111111 | 50% |  |
| `div.yfh > button.go > svg` | 330 | 940 | 16 | 16 |  |  |  |  |  |  |
| `div.yfs > button.yfp.ad > span.c` | 38 | 982 | 62 | 62 |  |  |  | #24A03C | 50% | 影: #24A03C / 0.80 0px 10px 20px -10px |
| `button.yfp.ad > span.c > svg` | 56 | 1000 | 26 | 26 |  |  |  |  |  |  |
| `div.yfs > button.yfp.ad > b` | 57 | 1051 | 24 | 15 | Add | 700 12px/normal Inter | #24A03C |  |  |  |
| `div.yfc > div.yfs > span.yfe` | 114 | 982 | 62 | 62 |  |  |  |  | 50% | 線: 1px dashed #E3E2E9 |
| `div.yfc > div.yfs > span.yfe` | 190 | 982 | 62 | 62 |  |  |  |  | 50% | 線: 1px dashed #E3E2E9 |
| `div.yfc > div.yfs > span.yfe` | 266 | 982 | 62 | 62 |  |  |  |  | 50% | 線: 1px dashed #E3E2E9 |
| `div.yfc > div.yfs > span.yfe` | 342 | 982 | 62 | 62 |  |  |  |  | 50% | 線: 1px dashed #E3E2E9 |
| `div.yfc > div.yf0 > svg.crowd` | 266 | 902 | 120 | 120 |  |  |  |  |  |  |

## B03_yesterday_mondo

**Later yesterday ・ Mondo(撮る前=ロック)**  ・ 見本: `screens/N02_night_yesterday_mondo.png(夜版。形は 同じ)`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.yhd` | 0 | 0 | 390 | 176 |  |  |  | linear-gradient(#FFFFFF 72%, #000000 / 0.00) |  |  |
| `div.yhd > div.yh > div.ylg` | 18 | 58 | 224 | 44 | Later | 900 44px/44px Inter | #111111 |  |  | 字間: -3.08px |
| `div.ylg > button#ydsw.ydsw > em` | 127 | 77 | 38 | 25 | today | 400 19px/normal Instrument Serif italic | #8E8E93 |  |  |  |
| `div.ylg > button#ydsw.ydsw > em.on` | 178 | 77 | 64 | 25 | yesterday | 400 19px/normal Instrument Serif italic | #111111 |  |  |  |
| `div.yhd > div.yh > div.yav` | 320 | 50 | 52 | 52 |  |  |  | radial-gradient(circle at 35% 30%, #AFE5BA, #7CD48E 50%, #B87AC8 100%) | 50% | 影: #FFFFFF 0px 0px 0px 3px, #111111 0px 0px 0px 4.5px |
| `div.yhd > button#ypill.ypill.lp` | 18 | 114 | 255 | 36 |  |  |  | linear-gradient(#FFFFFF / 0.80, #F4F4F6 / 0.56) | 18px | 影: #FFFFFF 0px 1px 0px 0px inset, #000000 / 0.04 0px -1px 0px 0px inset, #000000 / 0.08 0px 0px 0px 0.6px inset, rgba(0, 0; 背景ぼかし: blur(16px) saturate(1.8) |
| `button#ypill.ypill.lp > span.lpr > svg` | 24 | 120 | 24 | 24 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `button#ypill.ypill.lp > span.lpr > i` | 33 | 129 | 7 | 7 |  |  |  | #24A03C | 50% | 影: #24A03C / 0.33 0px 0px 0px 3.14014px |
| `div.yhd > button#ypill.ypill.lp > span#ypt.lpl` | 55 | 124 | 59 | 16 | ひらくまで | 600 11.5px/normal Inter | #86868C |  |  | 字間: 0.23px |
| `span.rd > span.rs > i` | 121 | 109 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 124 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 140 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 155 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 171 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 186 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 202 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 217 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 233 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 121 | 248 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 0 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 16 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 31 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 47 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 62 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 78 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 93 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 109 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 124 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 130 | 140 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `button#ypill.ypill.lp > b#ypd.lpd.rl > span.rx` | 139 | 124 | 8 | 16 | h | 700 13.5px/normal Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 93 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 109 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 124 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 140 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 155 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 171 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 186 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 202 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 217 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 150 | 233 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 16 | 9 | 16 | 0 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 31 | 9 | 16 | 1 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 47 | 9 | 16 | 2 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 62 | 9 | 16 | 3 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 78 | 9 | 16 | 4 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 93 | 9 | 16 | 5 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 109 | 9 | 16 | 6 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 124 | 9 | 16 | 7 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 140 | 9 | 16 | 8 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `span.rd > span.rs > i` | 159 | 155 | 9 | 16 | 9 | 700 13.5px/15.525px Inter | #8E8E93 |  |  | 字間: -0.135px |
| `button#ypill.ypill.lp > b#ypd.lpd.rl > span.rx` | 168 | 124 | 12 | 16 | m | 700 13.5px/normal Inter | #8E8E93 |  |  | 字間: -0.135px |
| `button#ypill.ypill.lp > span#ybars.ybars > i` | 197 | 126 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#ypill.ypill.lp > span#ybars.ybars > i` | 207 | 126 | 7 | 12 |  |  |  | #24A03C | 2px | 影: #24A03C / 0.45 0px 0px 6px 0px |
| `button#ypill.ypill.lp > span#ybars.ybars > i.o` | 216 | 126 | 7 | 12 |  |  |  |  | 2px | 影: #86868C 0px 0px 0px 1.2px inset; 不透明: 0.4 |
| `button#ypill.ypill.lp > span#ybars.ybars > b` | 230 | 125 | 8 | 15 | 2 | 700 12.5px/normal Inter | #86868C |  |  |  |
| `div.yhd > button#ypill.ypill.lp > em.lpc` | 245 | 122 | 20 | 20 |  |  |  | #000000 / 0.05 | 50% |  |
| `button#ypill.ypill.lp > em.lpc > svg` | 250 | 127 | 10 | 10 |  |  |  |  |  |  |
| `div#ymo.ymo > div.mohd.in > span.mmk` | 20 | 187 | 137 | 15 | MONDO · NOV 12 | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px |
| `div.mohd.in > span.mmk > i.dot` | 20 | 191 | 7 | 7 |  |  |  | #3BD35A | 50% | 影: #24A03C / 0.28 0px 0px 0px 3.74326px |
| `h2.mh > span.ml1 > span.mlt` | 20 | 212 | 25 | 57 | T | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 45 | 212 | 26 | 57 | h | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 71 | 212 | 19 | 57 | e | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 99 | 212 | 33 | 57 | w | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `span.ml1 > span.glb > svg` | 133 | 224 | 36 | 36 |  |  |  |  |  |  |
| `span.glb > svg > g` | 126 | 227 | 53 | 31 |  |  |  |  |  |  |
| `h2.mh > span.ml1 > span.mlt` | 170 | 212 | 17 | 57 | r | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 187 | 212 | 11 | 57 | l | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 198 | 212 | 25 | 57 | d | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 224 | 212 | 11 | 57 | , | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `div.mohd.in > h2.mh > span.ml2` | 20 | 269 | 226 | 64 |  |  |  | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  |  |
| `h2.mh > span.ml2 > span.mlt` | 20 | 269 | 25 | 64 | y | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 45 | 269 | 21 | 64 | e | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 66 | 269 | 18 | 64 | s | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 85 | 269 | 16 | 64 | t | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 101 | 269 | 21 | 64 | e | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 122 | 269 | 22 | 64 | r | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 144 | 269 | 29 | 64 | d | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 173 | 269 | 29 | 64 | a | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 202 | 269 | 25 | 64 | y | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 228 | 269 | 13 | 64 | . | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > svg.msw2` | 20 | 323 | 226 | 16 |  |  |  |  |  |  |
| `div#ymo.ymo > div.mohd.in > div.mtk` | 0 | 355 | 390 | 30 |  |  |  |  |  | 線: 1px solid #E3E2E9 |
| `div.mtk > div.mtr > span` | -91 | 363 | 104 | 15 | Tokyo | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span > b` | -30 | 363 | 44 | 15 | 23:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtk > div.mtr > span` | 36 | 363 | 104 | 15 | Seoul | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span > b` | 96 | 363 | 44 | 15 | 23:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtk > div.mtr > span` | 162 | 363 | 122 | 15 | Bangkok | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span > b` | 240 | 363 | 44 | 15 | 21:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtk > div.mtr > span.on` | 305 | 363 | 104 | 15 | Paris | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span.on > b` | 366 | 363 | 44 | 15 | 15:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div#ymo.ymo > div.mobody > div.moone` | 18 | 395 | 354 | 400 |  |  |  | #161618 | 30px |  |
| `div.mobody > div.moone > i.bg` | 18 | 395 | 354 | 400 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.mobody > div.moone > i.aura` | 48 | 424 | 295 | 295 |  |  |  | radial-gradient(circle, #78E28D / 0.55, #27B042 / 0.00 65%) | 50% | 不透明: 0.703876; 変形: matrix(1.13326, 0, 0, 1.13326, 0, 0) |
| `div.mobody > div.moone > span.k` | 18 | 415 | 354 | 15 | TODAY'S ONE · 9:00 | 700 10px/normal Space Mono | #9ED6A5 |  |  | 字間: 2.6px |
| `div.mobody > div.moone > b` | 18 | 686 | 354 | 51 | 鎌倉市 | 700 34px/normal Later Mincho | #FFFFFF |  |  |  |
| `div.mobody > div.moone > small` | 18 | 750 | 354 | 15 | picked by the world · no numbers | 500 12px/normal Inter | #FFFFFF / 0.60 |  |  |  |
| `div.mobody > div.moone > span.tg` | 277 | 442 | 80 | 41 | #夕焼け | 900 15px/15px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div#ymo.ymo > div.mobody > div.axh.moax` | 20 | 825 | 350 | 31 |  |  |  |  |  | 線: 1px solid #1E1E21 |
| `div.mobody > div.axh.moax > span` | 20 | 840 | 45 | 16 | WORDS | 700 10.5px/normal Space Mono | #8C8C93 |  |  | 字間: 2.52px |
| `div.mobody > div.axh.moax > em` | 331 | 840 | 39 | 16 | TOP 5 | 700 10.5px/normal Space Mono | #55555B |  |  | 字間: 1.47px |
| `nav#ynav.ynav` | 58 | 748 | 274 | 66 |  |  |  | #28282E / 0.38 | 33px | 影: #FFFFFF / 0.28 0px 1px 0px 0px inset, #FFFFFF / 0.06 0px -1px 0px 0px inset, #FFFFFF / 0.12 0px 0px 0px 1px; 背景ぼかし: blur(22px) saturate(1.9) |
| `nav#ynav.ynav > button.on` | 66 | 753 | 127 | 56 |  |  |  | #000000 / 0.07 | 28px | 影: #FFFFFF / 0.30 0px 1px 0px 0px inset |
| `nav#ynav.ynav > button.on > svg` | 119 | 762 | 22 | 22 |  |  |  |  |  |  |
| `nav#ynav.ynav > button.on > span` | 111 | 786 | 38 | 14 | Mondo | 600 11px/normal Inter | #111111 |  |  |  |
| `nav#ynav.ynav > button > svg` | 250 | 762 | 22 | 22 |  |  |  |  |  |  |
| `nav#ynav.ynav > button > span` | 241 | 786 | 39 | 14 | Groups | 600 11px/normal Inter | #8E8E93 |  |  |  |

## B10_mondo_open_full

**Later yesterday ・ Mondo(撮った後・下まで 全部)※y は タブの 中の 位置**  ・ 見本: `screens/B10〜B15_mondo_open_*.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div#ymo.ymo > div.mohd > span.mmk` | 20 | 187 | 137 | 15 | MONDO · NOV 12 | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px |
| `div.mohd > span.mmk > i.dot` | 20 | 191 | 7 | 7 |  |  |  | #3BD35A | 50% | 影: #24A03C / 0.15 0px 0px 0px 5.28044px |
| `h2.mh > span.ml1 > span.mlt` | 20 | 212 | 25 | 57 | T | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 45 | 212 | 26 | 57 | h | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 71 | 212 | 19 | 57 | e | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 99 | 212 | 33 | 57 | w | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `span.ml1 > span.glb > svg` | 133 | 224 | 36 | 36 |  |  |  |  |  |  |
| `span.glb > svg > g` | 128 | 227 | 53 | 31 |  |  |  |  |  |  |
| `h2.mh > span.ml1 > span.mlt` | 170 | 212 | 17 | 57 | r | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 187 | 212 | 11 | 57 | l | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 198 | 212 | 25 | 57 | d | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `h2.mh > span.ml1 > span.mlt` | 224 | 212 | 11 | 57 | , | 400 58px/56.84px Instrument Serif | #111111 |  |  | 字間: -1.45px |
| `div.mohd > h2.mh > span.ml2` | 20 | 269 | 226 | 64 |  |  |  | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  |  |
| `h2.mh > span.ml2 > span.mlt` | 20 | 269 | 25 | 64 | y | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 45 | 269 | 21 | 64 | e | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 66 | 269 | 18 | 64 | s | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 85 | 269 | 16 | 64 | t | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 101 | 269 | 21 | 64 | e | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 122 | 269 | 22 | 64 | r | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 144 | 269 | 29 | 64 | d | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 173 | 269 | 29 | 64 | a | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 202 | 269 | 25 | 64 | y | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > span.mlt` | 228 | 269 | 13 | 64 | . | 400 64px/64px Instrument Serif italic | #28B143 | linear-gradient(100deg, #28B143 0%, #7EE08F 30%, #28B143 45%, #C8F25A 60%, #28B143 80%) |  | 字間: -1.28px |
| `h2.mh > span.ml2 > svg.msw2` | 20 | 323 | 226 | 16 |  |  |  |  |  |  |
| `div#ymo.ymo > div.mohd > div.mtk` | 0 | 355 | 390 | 30 |  |  |  |  |  | 線: 1px solid #E3E2E9 |
| `div.mtk > div.mtr > span` | -101 | 363 | 104 | 15 | Tokyo | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span > b` | -41 | 363 | 44 | 15 | 23:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtk > div.mtr > span` | 25 | 363 | 104 | 15 | Seoul | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span > b` | 86 | 363 | 44 | 15 | 23:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtk > div.mtr > span` | 151 | 363 | 122 | 15 | Bangkok | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span > b` | 229 | 363 | 44 | 15 | 21:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtk > div.mtr > span.on` | 295 | 363 | 104 | 15 | Paris | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div.mtr > span.on > b` | 356 | 363 | 44 | 15 | 15:31 | 700 10px/normal Space Mono | #111111 |  |  | 字間: 2.6px; 大文字化: uppercase |
| `div#ymo.ymo > div.mobody > div.moone` | 18 | 395 | 354 | 400 |  |  |  | #161618 | 30px |  |
| `div.mobody > div.moone > i.bg` | 18 | 395 | 354 | 400 |  |  |  | (photo) |  | filter: url("#chk") |
| `div.mobody > div.moone > i.aura` | 54 | 430 | 283 | 283 |  |  |  | radial-gradient(circle, #78E28D / 0.55, #27B042 / 0.00 65%) | 50% | 不透明: 0.806714; 変形: matrix(1.08698, 0, 0, 1.08698, 0, 0) |
| `div.mobody > div.moone > span.k` | 18 | 415 | 354 | 15 | TODAY'S ONE · 9:00 | 700 10px/normal Space Mono | #9ED6A5 |  |  | 字間: 2.6px |
| `div.mobody > div.moone > b` | 18 | 686 | 354 | 51 | 鎌倉市 | 700 34px/normal Later Mincho | #FFFFFF |  |  |  |
| `div.mobody > div.moone > small` | 18 | 750 | 354 | 15 | picked by the world · no numbers | 500 12px/normal Inter | #FFFFFF / 0.60 |  |  |  |
| `div.mobody > div.moone > span.tg` | 277 | 442 | 80 | 41 | #夕焼け | 900 15px/15px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div#ymo.ymo > div.mobody > div.axh.moax` | 20 | 825 | 350 | 31 |  |  |  |  |  | 線: 1px solid #1E1E21 |
| `div.mobody > div.axh.moax > span` | 20 | 840 | 45 | 16 | WORDS | 700 10.5px/normal Space Mono | #8C8C93 |  |  | 字間: 2.52px |
| `div.mobody > div.axh.moax > em` | 331 | 840 | 39 | 16 | TOP 5 | 700 10.5px/normal Space Mono | #55555B |  |  | 字間: 1.47px |
| `div.mobody > div.mowd > button.mow` | 18 | 868 | 162 | 62 |  |  |  | #161618 | 31px | 影: #232326 0px 0px 0px 1px inset |
| `div.mowd > button.mow > i.n` | 32 | 883 | 17 | 31 | 01 | 400 24px/normal Instrument Serif italic | #8C8C93 |  |  |  |
| `div.mowd > button.mow > b` | 59 | 886 | 44 | 25 | #散歩 | 700 17px/normal Later Mincho | #FFFFFF |  |  |  |
| `button.mow > span.ph > i` | 102 | 879 | 40 | 40 |  |  |  | (photo) | 50% | 線: 2px solid #161618 |
| `button.mow > span.ph > i` | 130 | 879 | 40 | 40 |  |  |  | (photo) | 50% | 線: 2px solid #161618 |
| `div.mobody > div.mowd > button.mow` | 188 | 868 | 182 | 62 |  |  |  | #161618 | 31px | 影: #232326 0px 0px 0px 1px inset |
| `div.mowd > button.mow > i.n` | 202 | 883 | 20 | 31 | 02 | 400 24px/normal Instrument Serif italic | #8C8C93 |  |  |  |
| `div.mowd > button.mow > b` | 232 | 886 | 61 | 25 | #放課後 | 700 17px/normal Later Mincho | #FFFFFF |  |  |  |
| `button.mow > span.ph > i` | 291 | 879 | 40 | 40 |  |  |  | (photo) | 50% | 線: 2px solid #161618 |
| `button.mow > span.ph > i` | 319 | 879 | 40 | 40 |  |  |  | (photo) | 50% | 線: 2px solid #161618 |
| `div.mobody > div.mowd > button.mow` | 377 | 868 | 182 | 62 |  |  |  | #161618 | 31px | 影: #232326 0px 0px 0px 1px inset |
| `div#ymo.ymo > div.mobody > div.axh.moax` | 20 | 964 | 350 | 31 |  |  |  |  |  | 線: 1px solid #1E1E21 |
| `div.mobody > div.axh.moax > span` | 20 | 979 | 98 | 16 | MORNING NOW | 700 10.5px/normal Space Mono | #8C8C93 |  |  | 字間: 2.52px |
| `div.mobody > div.axh.moax > em` | 323 | 979 | 47 | 16 | 9:00 → | 700 10.5px/normal Space Mono | #55555B |  |  | 字間: 1.47px |
| `div#ymo.ymo > div.mobody > div.mo9` | 18 | 1007 | 354 | 112 |  |  |  | #161618 | 22px |  |
| `div.mobody > div.mo9 > div.band` | 34 | 1023 | 322 | 38 |  |  |  | linear-gradient(90deg, #0E0E18, #2A2040 30%, #FF9A62 55%, #FFE7C8 66%, #C9D6F0 100%) | 12px |  |
| `div.mo9 > div.cty > b` | 34 | 1071 | 26 | 34 | NY | 400 26px/normal Instrument Serif | #FFFFFF |  |  |  |
| `div.mo9 > div.cty > span` | 68 | 1085 | 119 | 15 | is opening yesterday | 500 12px/normal Inter | #8C8C93 |  |  |  |
| `div#ymo.ymo > div.mobody > div.axh.moax` | 20 | 1149 | 350 | 31 |  |  |  |  |  | 線: 1px solid #1E1E21 |
| `div.mobody > div.axh.moax > span` | 20 | 1164 | 27 | 16 | MAP | 700 10.5px/normal Space Mono | #8C8C93 |  |  | 字間: 2.52px |
| `div.mobody > div.axh.moax > em` | 299 | 1164 | 71 | 16 | 12 PLACES | 700 10.5px/normal Space Mono | #55555B |  |  | 字間: 1.47px |
| `div#ymo.ymo > div.mobody > div.momap` | 18 | 1192 | 354 | 230 |  |  |  | #111113 | 24px | 影: #1E1E21 0px 0px 0px 1px inset |
| `div.mobody > div.momap > button.pin` | 67 | 1264 | 30 | 30 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.00578, 0, 0, 1.00578, 0, 0) |
| `div.momap > button.pin > i` | 70 | 1267 | 24 | 24 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 84 | 1283 | 30 | 30 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.00367, 0, 0, 1.00367, 0, 0) |
| `div.momap > button.pin > i` | 87 | 1286 | 24 | 24 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 169 | 1245 | 31 | 31 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.04079, 0, 0, 1.04079, 0, 0) |
| `div.momap > button.pin > i` | 172 | 1248 | 25 | 25 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 178 | 1253 | 33 | 33 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.10288, 0, 0, 1.10288, 0, 0) |
| `div.momap > button.pin > i` | 182 | 1257 | 26 | 26 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 188 | 1239 | 34 | 34 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.14422, 0, 0, 1.14422, 0, 0) |
| `div.momap > button.pin > i` | 192 | 1242 | 27 | 27 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 256 | 1267 | 34 | 34 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.14633, 0, 0, 1.14633, 0, 0) |
| `div.momap > button.pin > i` | 259 | 1270 | 28 | 28 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 285 | 1258 | 33 | 33 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.10921, 0, 0, 1.10921, 0, 0) |
| `div.momap > button.pin > i` | 288 | 1261 | 27 | 27 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 296 | 1273 | 31 | 31 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.04712, 0, 0, 1.04712, 0, 0) |
| `div.momap > button.pin > i` | 299 | 1276 | 25 | 25 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 307 | 1296 | 30 | 30 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px; 変形: matrix(1.00578, 0, 0, 1.00578, 0, 0) |
| `div.momap > button.pin > i` | 310 | 1299 | 24 | 24 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 109 | 1310 | 30 | 30 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px |
| `div.momap > button.pin > i` | 112 | 1313 | 24 | 24 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 222 | 1319 | 30 | 30 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px |
| `div.momap > button.pin > i` | 225 | 1322 | 24 | 24 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > button.pin` | 159 | 1338 | 30 | 30 |  |  |  | #239E3C | 50% | 影: #0A0A0B 0px 0px 0px 2px, #239E3C / 0.70 0px 0px 14px 0px |
| `div.momap > button.pin > i` | 162 | 1341 | 24 | 24 |  |  |  | (photo) | 50% |  |
| `div.mobody > div.momap > span.note` | 254 | 1399 | 104 | 13 | city-level only | 700 8.5px/normal Space Mono | #55555B |  |  | 字間: 1.7px |
| `div#ymo.ymo > div.mobody > div.axh.moax` | 20 | 1452 | 350 | 31 |  |  |  |  |  | 線: 1px solid #1E1E21 |
| `div.mobody > div.axh.moax > span` | 20 | 1467 | 72 | 16 | EVERYONE | 700 10.5px/normal Space Mono | #8C8C93 |  |  | 字間: 2.52px |
| `div.mobody > div.axh.moax > em` | 196 | 1467 | 174 | 16 | TAP×2 LIGHT · HOLD ONE | 700 10.5px/normal Space Mono | #55555B |  |  | 字間: 1.47px |
| `div.mobody > div.mofd > div.mof` | 18 | 1495 | 173 | 220 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 18 | 1495 | 173 | 220 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 30 | 1684 | 54 | 20 | 鎌倉市 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 152 | 1689 | 28 | 13 | 17:42 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 27 | 1502 | 67 | 39 | #夕焼け | 900 11.5px/11.5px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 200 | 1495 | 173 | 250 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 200 | 1495 | 173 | 250 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 212 | 1714 | 54 | 20 | 渋谷区 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 333 | 1719 | 28 | 13 | 16:20 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 208 | 1502 | 67 | 39 | #放課後 | 900 11.5px/11.5px Inter | #FFFFFF | #9B8CFF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 18 | 1754 | 173 | 250 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 18 | 1754 | 173 | 250 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 30 | 1973 | 59 | 20 | Brooklyn | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 152 | 1978 | 28 | 13 | 08:05 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 26 | 1761 | 56 | 37 | #散歩 | 900 11.5px/11.5px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 200 | 1754 | 173 | 220 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 200 | 1754 | 173 | 220 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 212 | 1943 | 108 | 20 | 京都市左京区 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 333 | 1948 | 28 | 13 | 15:31 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 208 | 1761 | 67 | 39 | #放課後 | 900 11.5px/11.5px Inter | #FFFFFF | #9B8CFF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 18 | 2013 | 173 | 220 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 18 | 2013 | 173 | 220 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 30 | 2202 | 79 | 20 | Seoul · Mapo | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 152 | 2207 | 28 | 13 | 11:12 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 26 | 2020 | 56 | 37 | #散歩 | 900 11.5px/11.5px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 200 | 2013 | 173 | 250 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 200 | 2013 | 173 | 250 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 212 | 2232 | 108 | 20 | 札幌市中央区 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 333 | 2237 | 28 | 13 | 12:48 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 208 | 2020 | 67 | 39 | #雨の日 | 900 11.5px/11.5px Inter | #FFFFFF | #EE5E9C | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 18 | 2272 | 173 | 250 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 18 | 2272 | 173 | 250 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 30 | 2491 | 52 | 20 | Paris 11e | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 152 | 2496 | 28 | 13 | 19:03 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 26 | 2279 | 56 | 37 | #散歩 | 900 11.5px/11.5px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 200 | 2272 | 173 | 220 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 200 | 2272 | 173 | 220 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 212 | 2461 | 54 | 20 | 那覇市 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 333 | 2466 | 28 | 13 | 18:21 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 208 | 2279 | 67 | 39 | #夕焼け | 900 11.5px/11.5px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 18 | 2531 | 173 | 220 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 18 | 2531 | 173 | 220 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 30 | 2720 | 57 | 20 | Bangkok | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 152 | 2725 | 28 | 13 | 23:40 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 27 | 2538 | 67 | 39 | #ねむい | 900 11.5px/11.5px Inter | #FFFFFF | #9B8CFF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 200 | 2531 | 173 | 250 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 200 | 2531 | 173 | 250 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 212 | 2750 | 108 | 20 | 福岡市中央区 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 333 | 2755 | 28 | 13 | 07:58 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 208 | 2538 | 67 | 39 | #雨の日 | 900 11.5px/11.5px Inter | #FFFFFF | #EE5E9C | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 18 | 2790 | 173 | 250 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 18 | 2790 | 173 | 250 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 30 | 3009 | 43 | 20 | Lisbon | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 152 | 3014 | 28 | 13 | 20:10 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 27 | 2797 | 67 | 39 | #夕焼け | 900 11.5px/11.5px Inter | #111111 | #9ED8FF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div.mobody > div.mofd > div.mof` | 200 | 2790 | 173 | 220 |  |  |  | #161618 | 20px |  |
| `div.mofd > div.mof > img` | 200 | 2790 | 173 | 220 |  |  |  |  |  | filter: url("#chk") |
| `div.mofd > div.mof > span.l` | 212 | 2979 | 90 | 20 | 横浜市中区 | 400 18px/19.8px Instrument Serif italic | #FFFFFF |  |  |  |
| `div.mofd > div.mof > span.tm` | 333 | 2984 | 28 | 13 | 01:12 | 700 9px/normal Space Mono | #FF8A3D |  |  |  |
| `div.mofd > div.mof > span.tg` | 208 | 2797 | 67 | 39 | #ねむい | 900 11.5px/11.5px Inter | #FFFFFF | #9B8CFF | 11px | 影: #000000 / 0.60 0px 8px 16px -8px |
| `div#ymo.ymo > div.mobody > button.mokp` | 18 | 3058 | 354 | 72 |  |  |  | #161618 | 22px |  |
| `button.mokp > span > b` | 36 | 3071 | 298 | 29 | Your one | 400 22px/normal Instrument Serif | #FFFFFF |  |  |  |
| `button.mokp > span > small` | 36 | 3102 | 298 | 15 | hold a photo to choose · until 24:00 | 500 12px/normal Inter | #8C8C93 |  |  |  |
| `div.mobody > button.mokp > em` | 346 | 3081 | 8 | 26 | › | 400 22px/normal Inter | #8C8C93 |  |  |  |

## C01_friend

**Friend 画面(友だち3人)**  ・ 見本: `screens/C01_friend.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.fbg > i.ph` | -98 | -132 | 587 | 1109 |  |  |  | (photo) |  | filter: blur(40px) saturate(1.4) brightness(0.5); 変形: matrix(1.15, 0, 0, 1.15, 0, 0) |
| `div.fbg > i.ck` | -60 | 89 | 210 | 238 |  |  |  | #F4F1EA | 4px | filter: blur(6px) brightness(0.72); 不透明: 0.8; 変形: matrix(1.06733, -0.266114, 0.266114, 1.06733, 0, 0) |
| `div.fbg > i.ck > u` | -48 | 101 | 179 | 188 |  |  |  | (photo) |  |  |
| `div.fbg > i.ck` | 242 | 25 | 167 | 192 |  |  |  | #F4F1EA | 4px | filter: blur(6px) brightness(0.72); 不透明: 0.8; 変形: matrix(0.880333, 0.187121, -0.187121, 0.880333, 0, 0) |
| `div.fbg > i.ck > u` | 256 | 34 | 143 | 151 |  |  |  | (photo) |  |  |
| `div.fbg > i.ck` | 268 | 407 | 174 | 205 |  |  |  | #F4F1EA | 4px | filter: blur(6px) brightness(0.72); 不透明: 0.8; 変形: matrix(0.990268, -0.139173, 0.139173, 0.990268, 0, 0) |
| `div.fbg > i.ck > u` | 278 | 417 | 151 | 160 |  |  |  | (photo) |  |  |
| `div.fbg > i.ck` | -42 | 558 | 153 | 178 |  |  |  | #F4F1EA | 4px | filter: blur(6px) brightness(0.72); 不透明: 0.8; 変形: matrix(0.837087, 0.147601, -0.147601, 0.837087, 0, 0) |
| `div.fbg > i.ck > u` | -29 | 567 | 132 | 139 |  |  |  | (photo) |  |  |
| `div.fbg > i.ck` | 116 | 759 | 157 | 188 |  |  |  | #F4F1EA | 4px | filter: blur(6px) brightness(0.72); 不透明: 0.8; 変形: matrix(0.946385, -0.082798, 0.082798, 0.946385, 0, 0) |
| `div.fbg > i.ck > u` | 126 | 768 | 137 | 146 |  |  |  | (photo) |  |  |
| `div.fbg > i.vg` | 0 | 0 | 390 | 844 |  |  |  | radial-gradient(120% 70% at 50% 30%, #000000 / 0.00 30%, #000000 / 0.75), linear-gradient(#000000 / 0.25, #000000 / 0.65) |  |  |
| `div.fhd` | 0 | 0 | 390 | 124 |  |  |  | linear-gradient(#050505 / 0.85 60%, #050505 / 0.00) |  |  |
| `div.fhd > button#fback.fback` | 18 | 64 | 42 | 42 |  |  |  | #161618 | 50% |  |
| `div.fhd > button#fback.fback > svg` | 30 | 76 | 19 | 19 |  |  |  |  |  |  |
| `div.fhd > div.ftl > em` | 72 | 62 | 96 | 44 | Friend | 400 44px/44px Instrument Serif | #FFFFFF |  |  | 字間: -0.44px |
| `div.fhd > div.ftl > span#fcnt.mono` | 178 | 87 | 50 | 16 | 3 / 12 | 700 11px/normal Space Mono | #3BD35A |  |  | 字間: 1.54px |
| `div.fhd > button#fcall.fcall` | 308 | 68 | 64 | 38 | Add | 800 14px/normal Inter | #111111 | #FFFFFF | 19px |  |
| `div#frbody > div#fr0.fhero > i.rad` | 10 | 119 | 370 | 370 |  |  |  | conic-gradient(from 96.8545deg, #24A03C / 0.26, #24A03C / 0.00 22%, #000000 / 0.00) | 50% | 不透明: 0.7 |
| `div#frbody > div#fr0.fhero > svg.tk` | 25 | 134 | 340 | 340 |  |  |  |  |  |  |
| `div.dial > button.fs.f.k > svg` | 165 | 144 | 60 | 60 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `div.dial > button.fs.f.k > span.av` | 173 | 152 | 44 | 44 | れ | 800 17px/normal Inter | #FFFFFF | radial-gradient(circle at 35% 30%, #D9F2FF, #7FB0FF 45%, #9C86FF 90%) | 50% | 影: #3BD35A / 0.35 0px 0px 24px 0px |
| `div.dial > button.fs.f.k > em` | 207 | 143 | 19 | 19 | 2 | 800 10px/19px Inter | #006622 | #3BD35A | 50% | 影: #000000 0px 0px 0px 2.5px |
| `div.dial > button.fs.f.k > small` | 185 | 206 | 20 | 15 | れな | 700 10px/normal Inter | #E5E5EA |  |  | 変形: matrix(1, 0, 0, 1, -10, 0) |
| `div.dial > button.fs.f.k > svg` | 230 | 161 | 60 | 60 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `div.dial > button.fs.f.k > span.av` | 238 | 169 | 44 | 44 | あ | 800 17px/normal Inter | #FFFFFF | radial-gradient(circle at 35% 30%, #BFF1C9, #61DD7A 45%, #FF5A7A 90%) | 50% | 影: #3BD35A / 0.35 0px 0px 24px 0px |
| `div.dial > button.fs.f.k > em` | 272 | 160 | 19 | 19 | 3 | 800 10px/19px Inter | #006622 | #3BD35A | 50% | 影: #000000 0px 0px 0px 2.5px |
| `div.dial > button.fs.f.k > small` | 250 | 223 | 20 | 15 | あや | 700 10px/normal Inter | #E5E5EA |  |  | 変形: matrix(1, 0, 0, 1, -10, 0) |
| `div.dial > button.fs.f > svg` | 278 | 209 | 60 | 60 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `div.dial > button.fs.f > span.av` | 286 | 217 | 44 | 44 | そ | 800 17px/normal Inter | #FFFFFF | radial-gradient(circle at 35% 30%, #E6FFF4, #6FCB8C 45%, #0BB52D 90%) | 50% | filter: saturate(0.5) brightness(0.66) |
| `div.dial > button.fs.f > small` | 298 | 271 | 20 | 15 | そら | 700 10px/normal Inter | #8C8C93 |  |  | 変形: matrix(1, 0, 0, 1, -10, 0) |
| `div.dial > button.fs.e.nx > i` | 307 | 286 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #24A03C; 影: #24A03C / 0.01 0px 0px 0.269406px 0px; 変形: matrix(1.00253, 0, 0, 1.00253, 0, 0) |
| `div.dial > button.fs.e > i` | 290 | 351 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 242 | 399 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 177 | 416 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 112 | 399 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 64 | 351 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 47 | 286 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 64 | 221 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div.dial > button.fs.e > i` | 112 | 173 | 36 | 36 |  |  |  |  | 50% | 線: 1px dashed #4A4A50 |
| `div#fr0.fhero > div#fcore.fcore > button#fhold.fhold` | 107 | 216 | 176 | 176 |  |  |  | radial-gradient(circle at 50% 30%, #283C2E / 0.90, #080809 / 0.92 70%) | 50% | 影: #2A2A2E 0px 0px 0px 1px inset, #24A03C / 0.55 0px 24px 46px -20px |
| `button#fhold.fhold > span.cw > svg.crowd` | 107 | 216 | 176 | 176 |  |  |  |  |  |  |
| `div#fcore.fcore > button#fhold.fhold > svg.rg` | 107 | 216 | 176 | 176 |  |  |  |  |  | 変形: matrix(0, -1, 1, 0, 0, 0) |
| `button#fhold.fhold > svg.rg > circle#fhp.p` | 111 | 220 | 168 | 168 |  |  |  |  |  | filter: drop-shadow(#3BD35A / 0.80 0px 0px 6px) |
| `div#fme.fme > button#fmc.fmc > span.fa` | 69 | 470 | 251 | 312 |  |  |  | #F4F1EA | 6px | 影: #000000 / 0.95 0px 30px 50px -18px, #000000 / 0.05 0px 0px 0px 1px |
| `button#fmc.fmc > span.fa > i.tape` | 144 | 459 | 86 | 34 |  |  |  | #C8F25A / 0.75 |  | 影: #000000 / 0.15 0px 2px 4px 0px; 変形: matrix(0.997564, -0.0697565, 0.0697565, 0.997564, 0, 0) |
| `button#fmc.fmc > span.fa > span.pic` | 84 | 485 | 219 | 227 |  |  |  | radial-gradient(circle at 32% 28%, #FFFFFF / 0.53, #000000 / 0.00 40%), linear-gradient(150deg, #61D278, #EE5E9C) |  | filter: url("#chk") contrast(1.04) |
| `span.fa > span.pic > b` | 145 | 548 | 97 | 101 | ゆ | 900 96px/96px Inter | #FFFFFF |  |  | 字間: -3.84px |
| `span.fa > span.pic > i.lk` | 84 | 485 | 219 | 227 |  |  |  | radial-gradient(70% 50% at 20% 10%, #FFB45A / 0.35, #000000 / 0.00 60%), radial-gradient(60% 60% at 100% 100%, #000000 / 0.25, #000000 / 0.00 |  |  |
| `span.fa > span.pic > span.st` | 225 | 677 | 67 | 19 | '26 11 13 | 700 11px/normal Space Mono | #FF9A3C |  |  | 字間: 0.66px |
| `button#fmc.fmc > span.fa > em.tg` | 90 | 622 | 82 | 46 | #カフェ | 900 15px/normal Inter | #111111 | #C8F25A | 12px | 字間: -0.3px; 影: #000000 / 0.35 3px 4px 0px 0px; 変形: matrix(0.990268, -0.139173, 0.139173, 0.990268, 0, 0) |
| `button#fmc.fmc > span.fa > em.tg` | 236 | 588 | 65 | 35 | #音楽 | 900 15px/normal Inter | #FFFFFF | #EE5E9C | 12px | 字間: -0.3px; 影: #000000 / 0.35 3px 4px 0px 0px; 変形: matrix(0.994522, 0.104528, -0.104528, 0.994522, 0, 0) |
| `button#fmc.fmc > span.fa > em.tg` | 60 | 499 | 66 | 39 | #夜型 | 900 15px/normal Inter | #111111 | #9ED8FF | 12px | 字間: -0.3px; 影: #000000 / 0.35 3px 4px 0px 0px; 変形: matrix(0.997564, -0.0697565, 0.0697565, 0.997564, 0, 0) |
| `button#fmc.fmc > span.fa > span.nm` | 99 | 714 | 77 | 42 | ゆい | 700 36px/36px Caveat | #1A1A1D |  |  | 変形: matrix(0.999391, -0.0348995, 0.0348995, 0.999391, 0, 0) |
| `button#fmc.fmc > span.fa > span.id` | 104 | 753 | 62 | 17 | @yui_0612 | 700 9.5px/normal Space Mono | #8E8E93 |  |  | 字間: 0.95px |
| `div#fme.fme > button#fmc.fmc > span.fb` | 69 | 470 | 251 | 312 |  |  |  | #F4F1EA | 6px | 影: #000000 / 0.95 0px 30px 50px -18px, #000000 / 0.05 0px 0px 0px 1px; 変形: matrix3d(-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1) |
| `button#fmc.fmc > span.fb > span.qr3` | 105 | 521 | 179 | 179 |  |  |  | #FFFFFF | 8px | 影: #FFFFFF 0px 0px 0px 10px inset, #DDD8CC 0px 0px 0px 1px |
| `button#fmc.fmc > span.fb > span.id` | 161 | 707 | 78 | 21 | @yui_0612 | 700 12px/normal Space Mono | #3A3A40 |  |  | 字間: 1.2px |
| `div#frbody > div#fme.fme > button#fed.fed` | 287 | 468 | 40 | 40 |  |  |  | #FFFFFF | 50% | 影: #000000 / 0.60 0px 8px 18px -6px |
| `div#fme.fme > button#fed.fed > svg` | 298 | 479 | 18 | 18 |  |  |  |  |  |  |
| `div#frbody > div.frl > button.frw.k` | 14 | 810 | 362 | 70 |  |  |  | #121214 / 0.62 | 22px | 影: #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.frl > button.frw.k > span.av` | 26 | 823 | 44 | 44 | れ | 800 16px/normal Inter | #FFFFFF | radial-gradient(circle at 35% 30%, #D9F2FF, #7FB0FF 45%, #9C86FF 90%) | 50% |  |
| `button.frw.k > span.tx > b` | 82 | 833 | 167 | 24 | れな | 400 22px/24.2px Instrument Serif | #FFFFFF |  |  |  |
| `button.frw.k > span.fm > i.on` | 261 | 840 | 7 | 11 |  |  |  | #3BD35A | 2px | 影: #3BD35A / 0.50 0px 0px 6px 0px |
| `button.frw.k > span.fm > i.on` | 271 | 840 | 7 | 11 |  |  |  | #3BD35A | 2px | 影: #3BD35A / 0.50 0px 0px 6px 0px |
| `button.frw.k > span.fm > i` | 281 | 840 | 7 | 11 |  |  |  |  | 2px | 影: #2E2E33 0px 0px 0px 1.2px inset |
| `div.frl > button.frw.k > em.op` | 300 | 830 | 62 | 30 | 12:40 | 700 11px/normal Space Mono | #7EE08F | #161618 | 15px | 字間: 0.88px |

## C02_me

**ME**  ・ 見本: `screens/C02_me.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.mbg` | -60 | -60 | 510 | 964 |  |  |  | (photo) |  | filter: blur(50px) saturate(1.4) brightness(0.38) |
| `div.mhd` | 0 | 0 | 390 | 118 |  |  |  | linear-gradient(#050505 / 0.85 55%, #000000 / 0.00) |  |  |
| `div.mhd > button#meb.fback` | 18 | 60 | 42 | 42 |  |  |  | #FFFFFF / 0.12 | 50% |  |
| `div.mhd > button#meb.fback > svg` | 30 | 72 | 19 | 19 |  |  |  |  |  |  |
| `div.mhd > b.mtt` | 72 | 56 | 67 | 46 | ME | 900 46px/46px Inter | #FFFFFF |  |  | 字間: -2.76px |
| `div.mhd > span.mrg` | 269 | 82 | 103 | 20 | NOV 6 — NOV 12 | 700 9.5px/normal Space Mono | #9A9AA2 |  |  | 字間: 1.52px |
| `div#mbd.mbd > button#mrc.mrc` | 14 | 126 | 362 | 430 |  |  |  |  | 32px | 影: #000000 / 0.90 0px 30px 60px -24px |
| `div#mbd.mbd > button#mrc.mrc > span.cv` | 14 | 126 | 362 | 430 |  |  |  | #000000 |  |  |
| `button#mrc.mrc > span.cv > i` | 14 | 126 | 180 | 214 |  |  |  | (photo) |  | filter: url("#chk") |
| `button#mrc.mrc > span.cv > i` | 197 | 126 | 180 | 214 |  |  |  | (photo) |  | filter: url("#chk") |
| `button#mrc.mrc > span.cv > i` | 14 | 343 | 180 | 214 |  |  |  | (photo) |  | filter: url("#chk") |
| `button#mrc.mrc > span.cv > i` | 197 | 343 | 180 | 214 |  |  |  | (photo) |  | filter: url("#chk") |
| `div#mbd.mbd > button#mrc.mrc > i.sh` | -38 | 126 | 104 | 104 |  |  |  | linear-gradient(#000000 / 0.15, #000000 / 0.05 35%, #000000 / 0.82) |  |  |
| `div#mbd.mbd > button#mrc.mrc > span.mrk` | 36 | 146 | 65 | 26 | RECAP | 700 10px/normal Space Mono | #FFFFFF | #000000 / 0.45 | 13px | 字間: 2.4px |
| `div#mbd.mbd > button#mrc.mrc > b` | 36 | 364 | 132 | 120 | Your | 400 62px/57.04px Instrument Serif | #FFFFFF |  |  | 字間: -1.24px |
| `button#mrc.mrc > b > em` | 36 | 407 | 132 | 91 | week. | 400 70px/63px Instrument Serif italic | #C8F25A |  |  | 字間: -1.24px |
| `div#mbd.mbd > button#mrc.mrc > span.st` | 38 | 502 | 192 | 26 | shots days kept | 700 10px/normal Space Mono | #C9C9CF |  |  | 字間: 1.4px; 大文字化: uppercase |
| `button#mrc.mrc > span.st > i` | 38 | 502 | 17 | 26 | 20 | 400 20px/normal Instrument Serif | #FFFFFF |  |  | 大文字化: uppercase |
| `button#mrc.mrc > span.st > i` | 122 | 502 | 7 | 26 | 7 | 400 20px/normal Instrument Serif | #FFFFFF |  |  | 大文字化: uppercase |
| `button#mrc.mrc > span.st > i` | 188 | 502 | 7 | 26 | 7 | 400 20px/normal Instrument Serif | #FFFFFF |  |  | 大文字化: uppercase |
| `div#mbd.mbd > button#mrc.mrc > span.pl` | 286 | 464 | 68 | 68 |  |  |  | #FFFFFF | 50% | 影: #FFFFFF / 0.00 0px 0px 0px 17.9923px |
| `button#mrc.mrc > span.pl > svg` | 308 | 484 | 28 | 28 |  |  |  |  |  |  |
| `div#mbd.mbd > div#msty.msty` | 14 | 570 | 362 | 46 |  |  |  | #FFFFFF / 0.08 | 22px |  |
| `div#mbd.mbd > div#msty.msty > button.on` | 18 | 574 | 114 | 38 | Film | 400 17px/normal Instrument Serif | #111111 | #FFFFFF | 19px |  |
| `div#mbd.mbd > div#msty.msty > button` | 138 | 574 | 114 | 38 | Cheki | 400 17px/normal Instrument Serif | #9A9AA2 |  | 19px |  |
| `div#mbd.mbd > div#msty.msty > button` | 258 | 574 | 114 | 38 | Beat | 400 17px/normal Instrument Serif | #9A9AA2 |  | 19px |  |
| `div#mbd.mbd > div.mstrip` | 0 | 638 | 390 | 114 |  |  |  | #0D0D0E |  |  |
| `div.mfilm > div.mfd > span.mfl` | 14 | 678 | 13 | 35 | FRI | 700 8.5px/normal Space Mono | #FF9A3C |  |  | 字間: 1.7px; 変形: matrix(-1, 0, 0, -1, 0, 0) |
| `div.mfd > span.mfl > b` | 14 | 678 | 13 | 7 | 6 | 700 8.5px/normal Space Mono | #FFFFFF |  |  | 字間: 1.7px |
| `div.mfilm > div.mfd > button.mfr` | 33 | 654 | 62 | 82 |  |  |  | #000000 | 3px |  |
| `div.mfd > button.mfr > i` | 33 | 654 | 62 | 82 |  |  |  | (photo) |  | filter: url("#chk") sepia(0.15) |
| `div.mfilm > div.mfd > button.mfr` | 99 | 654 | 62 | 82 |  |  |  | #000000 | 3px |  |
| `div.mfd > button.mfr > i` | 99 | 654 | 62 | 82 |  |  |  | (photo) |  | filter: url("#chk") sepia(0.15) |
| `div.mfd > button.mfr > svg.kp` | 145 | 657 | 13 | 13 |  |  |  |  |  |  |
| `div.mfilm > div.mfd > button.mfr` | 165 | 654 | 62 | 82 |  |  |  | #000000 | 3px |  |
| `div.mfd > button.mfr > i` | 165 | 654 | 62 | 82 |  |  |  | (photo) |  | filter: url("#chk") sepia(0.15) |
| `div.mfilm > div.mfd > span.mfl` | 237 | 678 | 13 | 35 | SAT | 700 8.5px/normal Space Mono | #FF9A3C |  |  | 字間: 1.7px; 変形: matrix(-1, 0, 0, -1, 0, 0) |
| `div.mfd > span.mfl > b` | 237 | 678 | 13 | 7 | 7 | 700 8.5px/normal Space Mono | #FFFFFF |  |  | 字間: 1.7px |
| `div.mfilm > div.mfd > button.mfr` | 256 | 654 | 62 | 82 |  |  |  | #000000 | 3px |  |
| `div.mfd > button.mfr > i` | 256 | 654 | 62 | 82 |  |  |  | (photo) |  | filter: url("#chk") sepia(0.15) |
| `div.mfd > button.mfr > svg.kp` | 302 | 657 | 13 | 13 |  |  |  |  |  |  |
| `div.mfilm > div.mfd > button.mfr` | 322 | 654 | 62 | 82 |  |  |  | #000000 | 3px |  |
| `div.mfd > button.mfr > i` | 322 | 654 | 62 | 82 |  |  |  | (photo) |  | filter: url("#chk") sepia(0.15) |
| `div.mfilm > div.mfd > button.mfr` | 388 | 654 | 62 | 82 |  |  |  | #000000 | 3px |  |
| `div.mfd > button.mfr > i` | 388 | 654 | 62 | 82 |  |  |  | (photo) |  | filter: url("#chk") sepia(0.15) |
| `div.mday > div.mdh > b` | 18 | 778 | 39 | 28 | Thu | 400 28px/28px Instrument Serif | #FFFFFF |  |  |  |
| `div.mday > div.mdh > span` | 67 | 790 | 45 | 14 | NOV 12 | 700 9.5px/normal Space Mono | #8C8C93 |  |  | 字間: 1.71px |
| `div.mday > div.mdh > em` | 323 | 790 | 49 | 14 | 6d left | 700 9.5px/normal Space Mono | #7EE08F |  |  | 字間: 1.14px; 大文字化: uppercase |
| `div.mday > div.mdg > button.mdc` | 14 | 816 | 117 | 156 |  |  |  | #111111 | 14px |  |
| `div.mdg > button.mdc > img` | 14 | 816 | 117 | 156 |  |  |  |  |  | filter: url("#chk") |
| `div.mday > div.mdg > button.mdc` | 137 | 816 | 117 | 156 |  |  |  | #111111 | 14px |  |
| `div.mdg > button.mdc > img` | 137 | 816 | 117 | 156 |  |  |  |  |  | filter: url("#chk") |
| `div.mdg > button.mdc > svg.kp` | 230 | 823 | 16 | 16 |  |  |  |  |  |  |
| `div.mday > div.mdg > button.mdc` | 259 | 816 | 117 | 156 |  |  |  | #111111 | 14px |  |
| `div.mdg > button.mdc > img` | 259 | 816 | 117 | 156 |  |  |  |  |  | filter: url("#chk") |

## C03_recap_play

**Recap 再生**  ・ 見本: `screens/C03/C04_recap_play*.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div#mst.mst > div.msl.m-day.out` | 6 | 12 | 378 | 819 |  |  |  | #050505 |  | 不透明: 0.0165337; 変形: matrix(0.970496, 0, 0, 0.970496, 0, 0) |
| `div#mst.mst > div.msl.m-day.out > span.dk` | 33 | 127 | 324 | 16 | FRI | 700 11px/normal Space Mono | #7EE08F |  |  | 字間: 4.4px; 変形: matrix(1, 0, 0, 1, 0, 0) |
| `div#mst.mst > div.msl.m-day.out > b` | 165 | 313 | 60 | 148 | 6 | 400 170px/153px Instrument Serif | #FFFFFF |  |  | 字間: -6.8px; filter: blur(0px); 変形: matrix(1, 0, 0, 1, 0, 0) |
| `div#mst.mst > div.msl.m-day.out > span.dm` | 173 | 456 | 45 | 44 | Nov | 400 34px/normal Instrument Serif italic | #C8F25A |  |  |  |
| `div#mst.mst > div.msl.m-day.out > span.dc` | 167 | 517 | 55 | 14 | 3 shots | 700 9.5px/normal Space Mono | #55555B |  |  | 字間: 2.28px; 大文字化: uppercase |
| `div.msl.m-ph > div.fx > i` | 5 | -47 | 389 | 950 |  |  |  | (photo) |  | filter: url("#chk") contrast(1.06); 変形: matrix(1.12508, 0, 0, 1.12508, 4.73114, 5.77035) |
| `div.msl.m-ph > div.fx > span.ds` | 219 | 702 | 151 | 22 | '26 11 06 08:31 | 700 15px/normal Space Mono | #FF9A3C |  |  | 字間: 0.9px |
| `div.msl.m-ph > div.fx > span.tg` | 14 | 689 | 102 | 42 | #ねむい | 900 17px/normal Inter | #111111 | #C8F25A | 14px | 影: #000000 / 0.40 3px 4px 0px 0px; 変形: matrix(1.10693, -0.0774038, 0.0774038, 1.10693, 0, 0) |
| `div.mtop > span.ap` | 14 | 68 | 34 | 34 | L | 900 17px/34px Inter | #111111 | #FFFFFF | 9px | 字間: -1.02px |
| `div.mtop > span.tx > b` | 58 | 66 | 274 | 17 | Your week | 800 14px/normal Inter | #FFFFFF |  |  |  |
| `div.mtop > span.tx > small` | 58 | 88 | 109 | 14 | ♪ 今日の 1曲 ・ Later | 600 11px/normal Inter | #C9C9CF |  |  |  |
| `div.mtop > button#mpx.x` | 342 | 68 | 34 | 34 | ✕ | 700 12px/normal Inter | #FFFFFF | #FFFFFF / 0.16 | 50% |  |
| `i.mgr` | -31 | -32 | 470 | 924 |  |  |  | radial-gradient(#FFFFFF / 0.06 1px, #000000 / 0.00 1px) |  | 変形: matrix(1, 0, 0, 1, 9, 7.5) |

## D01_profile

**Profile**  ・ 見本: `screens/D01_profile.png / D02_profile_scroll.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.pbg > i.g` | -80 | -88 | 558 | 603 |  |  |  | linear-gradient(160deg, #61D278, #EE5E9C) |  | filter: blur(70px) saturate(1.3); 不透明: 0.55; 変形: matrix(1.00683, 0.0146236, -0.0146236, 1.00683, 3.7862, 2.45 |
| `div.pbg > i.ck` | -58 | 501 | 165 | 189 |  |  |  | #F4F1EA | 4px | 線: 8px solid #F4F1EA; filter: blur(7px) brightness(0.6); 不透明: 0.55 |
| `div.pbg > i.ck` | 281 | 574 | 161 | 185 |  |  |  | #F4F1EA | 4px | 線: 8px solid #F4F1EA; filter: blur(7px) brightness(0.6); 不透明: 0.55 |
| `div.pbg > i.vg` | 0 | 0 | 390 | 844 |  |  |  | radial-gradient(130% 80% at 50% 25%, #000000 / 0.00 35%, #000000 / 0.80), linear-gradient(#000000 / 0.00 40%, #060606 / 0.90) |  |  |
| `div.phd` | 0 | 0 | 390 | 104 |  |  |  | linear-gradient(#060606 / 0.70, #000000 / 0.00) |  |  |
| `div.phd > button#pfx.pbk` | 18 | 50 | 42 | 42 |  |  |  | #FFFFFF / 0.12 | 50% | 影: #FFFFFF / 0.10 0px 0px 0px 1px inset; 背景ぼかし: blur(14px) |
| `div.phd > button#pfx.pbk > svg` | 29 | 61 | 20 | 20 |  |  |  |  |  |  |
| `div.phd > span.pid` | 158 | 64 | 74 | 28 | @yui_0612 | 700 11px/normal Space Mono | #C9C9CF |  |  | 字間: 1.54px |
| `div.phd > button#pfset.pbk` | 330 | 50 | 42 | 42 |  |  |  | #FFFFFF / 0.12 | 50% | 影: #FFFFFF / 0.10 0px 0px 0px 1px inset; 背景ぼかし: blur(14px) |
| `div.phd > button#pfset.pbk > svg` | 341 | 61 | 20 | 20 |  |  |  |  |  |  |
| `div#pbd.pbd > div#phero.phero > button.pst.me` | 23 | 157 | 102 | 54 | #カフェ | 900 17px/normal Inter | #111111 | #C8F25A | 14px | 字間: -0.34px; 影: #000000 / 0.50 3px 4px 0px 0px; 変形: matrix(1.0667, -0.168949, 0.168949, 1.0667, -173.453, -138.5 |
| `div#pbd.pbd > div#phero.phero > button.pst.me` | 277 | 187 | 80 | 53 | #音楽 | 900 17px/normal Inter | #FFFFFF | #EE5E9C | 14px | 字間: -0.34px; 影: #000000 / 0.50 3px 4px 0px 0px; 変形: matrix(0.990268, 0.139173, -0.139173, 0.990268, 80.875, -120 |
| `div#pbd.pbd > div#phero.phero > button.pst.me` | 20 | 326 | 78 | 49 | #夜型 | 900 17px/normal Inter | #111111 | #9ED8FF | 14px | 字間: -0.34px; 影: #000000 / 0.50 3px 4px 0px 0px; 変形: matrix(0.994522, 0.104528, -0.104528, 0.994522, -173.125, 19 |
| `div#pbd.pbd > div#phero.phero > button.pst` | 286 | 348 | 81 | 43 | #夕焼け | 900 14px/normal Inter | #111111 | #FFD60A | 14px | 字間: -0.28px; 影: #000000 / 0.50 3px 4px 0px 0px; 不透明: 0.92; 変形: matrix(1.04217, -0.127963, 0.127963, 1.04217, 94.9219, 42) |
| `div#pbd.pbd > div#phero.phero > button.pst` | 60 | 459 | 69 | 32 | #放課後 | 900 14px/normal Inter | #FFFFFF | #9B8CFF | 14px | 字間: -0.28px; 影: #000000 / 0.50 3px 4px 0px 0px; 不透明: 0.92; 変形: matrix(0.917759, -0.064176, 0.064176, 0.917759, -133.078, 15 |
| `div#pbd.pbd > div#phero.phero > button.pst` | 255 | 471 | 71 | 43 | #帰り道 | 900 14px/normal Inter | #111111 | #61D278 | 14px | 字間: -0.28px; 影: #000000 / 0.50 3px 4px 0px 0px; 不透明: 0.92; 変形: matrix(0.886327, 0.156283, -0.156283, 0.886327, 66.9219, 162 |
| `div#phero.phero > button#pck.pck > span.fa` | 75 | 155 | 241 | 299 |  |  |  | #F4F1EA | 6px | 影: #000000 / 0.95 0px 40px 60px -22px, #000000 / 0.06 0px 0px 0px 1px |
| `button#pck.pck > span.fa > i.tape` | 141 | 142 | 93 | 38 |  |  |  | #C8F25A / 0.78 |  | 変形: matrix(0.996195, -0.0871557, 0.0871557, 0.996195, 0, 0) |
| `button#pck.pck > span.fa > span.pic` | 88 | 169 | 211 | 221 |  |  |  | radial-gradient(circle at 30% 26%, #FFFFFF / 0.60, #000000 / 0.00 42%), linear-gradient(150deg, #61D278, #EE5E9C) |  | filter: url("#chk") contrast(1.04) |
| `span.fa > span.pic > b` | 140 | 220 | 108 | 112 | ゆ | 900 104px/104px Inter | #FFFFFF |  |  | 字間: -4.16px; 変形: matrix(0.999603, -0.0281882, 0.0281882, 0.999603, 0, -3.2305 |
| `span.fa > span.pic > i.lk` | 88 | 169 | 211 | 221 |  |  |  | radial-gradient(70% 50% at 18% 8%, #FFB45A / 0.40, #000000 / 0.00 60%) |  |  |
| `span.fa > span.pic > span.st` | 221 | 356 | 67 | 19 | '26 11 13 | 700 11px/normal Space Mono | #FF9A3C |  |  | 字間: 0.66px |
| `button#pck.pck > span.fa > span.nm` | 105 | 399 | 72 | 40 | ゆい | 700 34px/34px Caveat | #1A1A1D |  |  | 変形: matrix(0.999391, -0.0348995, 0.0348995, 0.999391, 0, 0) |
| `button#pck.pck > span.fa > i.gl` | 75 | 155 | 241 | 299 |  |  |  | linear-gradient(115deg, #000000 / 0.00 25%, #FFFFFF / 0.65 40%, #000000 / 0.00 60%) | 6px |  |
| `div#phero.phero > button#pck.pck > span.fb` | 75 | 155 | 241 | 299 |  |  |  | #F4F1EA | 6px | 影: #000000 / 0.95 0px 40px 60px -22px, #000000 / 0.06 0px 0px 0px 1px; 変形: matrix3d(-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1) |
| `button#pck.pck > span.fb > span.qr3` | 105 | 190 | 177 | 177 |  |  |  | #FFFFFF | 8px | 影: #FFFFFF 0px 0px 0px 10px inset, #DDD8CC 0px 0px 0px 1px |
| `button#pck.pck > span.fb > b` | 158 | 370 | 82 | 24 | @yui_0612 | 700 13px/normal Space Mono | #111111 |  |  | 字間: 1.04px |
| `button#pck.pck > span.fb > small` | 158 | 400 | 86 | 17 | SCAN TO ADD | 700 8.5px/normal Space Mono | #8E8E93 |  |  | 字間: 2.55px |
| `div#pbd.pbd > div.pnm > b` | 142 | 520 | 106 | 54 | ゆい | 400 54px/54px Instrument Serif | #FFFFFF |  |  | 字間: -1.08px |
| `div#pbd.pbd > div.pnm > span.mood` | 146 | 582 | 99 | 22 | since | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 1.8px; 大文字化: uppercase |
| `div.pnm > span.mood > em` | 193 | 582 | 51 | 22 | Oct 2026 | 400 17px/normal Instrument Serif italic | #C8F25A |  |  |  |
| `div#pbd.pbd > div.pstat` | 16 | 628 | 358 | 74 |  |  |  | #121214 / 0.55 | 24px | 影: #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.pstat > button > b` | 54 | 642 | 20 | 30 | 12 | 400 30px/30px Instrument Serif | #FFFFFF |  |  |  |
| `div.pstat > button > span` | 32 | 675 | 64 | 13 | day streak | 700 8.5px/normal Space Mono | #8C8C93 |  |  | 字間: 1.19px; 大文字化: uppercase |
| `div.pstat > button > b` | 140 | 642 | 24 | 30 | 49 | 400 30px/30px Instrument Serif | #FFFFFF |  |  |  |
| `div.pstat > button > span` | 136 | 675 | 32 | 13 | shots | 700 8.5px/normal Space Mono | #8C8C93 |  |  | 字間: 1.19px; 大文字化: uppercase |
| `div.pstat > button > b` | 233 | 642 | 12 | 30 | 9 | 400 30px/30px Instrument Serif | #FFFFFF |  |  |  |
| `div.pstat > button > span` | 226 | 675 | 26 | 13 | kept | 700 8.5px/normal Space Mono | #8C8C93 |  |  | 字間: 1.19px; 大文字化: uppercase |
| `div.pstat > button > b` | 315 | 642 | 24 | 30 | 3 | 400 30px/30px Instrument Serif | #FFFFFF |  |  |  |
| `button > b > s` | 326 | 653 | 13 | 18 | /12 | 400 14px/normal Instrument Serif italic | #6C6C73 |  |  |  |
| `div.pstat > button > span` | 308 | 675 | 38 | 13 | friend | 700 8.5px/normal Space Mono | #8C8C93 |  |  | 字間: 1.19px; 大文字化: uppercase |
| `div#pbd.pbd > div.pact > button.pr` | 16 | 714 | 84 | 82 |  |  |  | #24A03C | 22px | 影: #24A03C / 0.90 0px 14px 26px -14px; 背景ぼかし: blur(18px) |
| `div.pact > button.pr > svg` | 46 | 732 | 24 | 24 |  |  |  |  |  |  |
| `div.pact > button.pr > b` | 49 | 762 | 18 | 17 | QR | 400 17px/17px Instrument Serif | #FFFFFF |  |  |  |
| `div#pbd.pbd > div.pact > button` | 108 | 714 | 84 | 82 |  |  |  | #121214 / 0.55 | 22px | 影: #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.pact > button > svg` | 137 | 732 | 24 | 24 |  |  |  |  |  |  |
| `div.pact > button > b` | 137 | 762 | 24 | 17 | Edit | 400 17px/17px Instrument Serif | #FFFFFF |  |  |  |
| `div#pbd.pbd > div.pact > button` | 199 | 714 | 84 | 82 |  |  |  | #121214 / 0.55 | 22px | 影: #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.pact > button > svg` | 229 | 732 | 24 | 24 |  |  |  |  |  |  |
| `div.pact > button > b` | 224 | 762 | 33 | 17 | Share | 400 17px/17px Instrument Serif | #FFFFFF |  |  |  |
| `div#pbd.pbd > div.pact > button` | 291 | 714 | 84 | 82 |  |  |  | #121214 / 0.55 | 22px | 影: #FFFFFF / 0.07 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.pact > button > svg` | 320 | 732 | 24 | 24 |  |  |  |  |  |  |
| `div.pact > button > b` | 319 | 762 | 27 | 17 | Scan | 400 17px/17px Instrument Serif | #FFFFFF |  |  |  |
| `div#pbd.pbd > button#pme.pme` | 16 | 808 | 358 | 118 |  |  |  | #0D0D0E | 24px | 影: #FFFFFF / 0.07 0px 0px 0px 1px inset |
| `div#pbd.pbd > button#pme.pme > span.pmk` | 32 | 821 | 85 | 14 | ME · 7 DAYS | 700 9.5px/normal Space Mono | #FF9A3C |  |  | 字間: 1.9px |

## D03_profile_edit

**Profile ・ Edit モード**  ・ 見本: `screens/D03_profile_edit.png`

| 部品 | x | y | w | h | 文字 | 書体 | 文字色 | 背景 | 角丸 | 線・影・ぼかし ほか |
|---|---|---|---|---|---|---|---|---|---|---|
| `div.pbg > i.g` | -85 | -95 | 582 | 626 |  |  |  | linear-gradient(160deg, #61D278, #EE5E9C) |  | filter: blur(70px) saturate(1.3); 不透明: 0.55; 変形: matrix(1.01926, 0.0430845, -0.0430845, 1.01926, 11.0132, 7.1 |
| `div.pbg > i.ck` | -58 | 495 | 165 | 189 |  |  |  | #F4F1EA | 4px | 線: 8px solid #F4F1EA; filter: blur(7px) brightness(0.6); 不透明: 0.55 |
| `div.pbg > i.ck` | 281 | 576 | 161 | 185 |  |  |  | #F4F1EA | 4px | 線: 8px solid #F4F1EA; filter: blur(7px) brightness(0.6); 不透明: 0.55 |
| `div.pbg > i.vg` | 0 | 0 | 390 | 844 |  |  |  | radial-gradient(130% 80% at 50% 25%, #000000 / 0.00 35%, #000000 / 0.80), linear-gradient(#000000 / 0.00 40%, #060606 / 0.90) |  |  |
| `div#pbd.pbd > div#phero.phero > button.pst` | 285 | 354 | 80 | 39 | #夕焼け | 900 14px/normal Inter | #111111 | #FFD60A | 14px | 字間: -0.28px; 影: #000000 / 0.50 3px 4px 0px 0px; 不透明: 0.15; 変形: matrix(1.04217, -0.127963, 0.127963, 1.04217, 94.9219, 42) |
| `div#pbd.pbd > div#phero.phero > button.pst` | 58 | 457 | 69 | 31 | #放課後 | 900 14px/normal Inter | #FFFFFF | #9B8CFF | 14px | 字間: -0.28px; 影: #000000 / 0.50 3px 4px 0px 0px; 不透明: 0.15; 変形: matrix(0.917759, -0.064176, 0.064176, 0.917759, -133.078, 15 |
| `div#pbd.pbd > div#phero.phero > button.pst` | 261 | 470 | 71 | 41 | #帰り道 | 900 14px/normal Inter | #111111 | #61D278 | 14px | 字間: -0.28px; 影: #000000 / 0.50 3px 4px 0px 0px; 不透明: 0.15; 変形: matrix(0.886327, 0.156283, -0.156283, 0.886327, 66.9219, 162 |
| `div#phero.phero > button#pck.pck > span.fa` | 75 | 155 | 241 | 299 |  |  |  | #F4F1EA | 6px | 影: #000000 / 0.95 0px 40px 60px -22px, #000000 / 0.06 0px 0px 0px 1px |
| `button#pck.pck > span.fa > i.tape` | 141 | 142 | 93 | 38 |  |  |  | #C8F25A / 0.78 |  | 変形: matrix(0.996195, -0.0871557, 0.0871557, 0.996195, 0, 0) |
| `button#pck.pck > span.fa > span.pic` | 88 | 169 | 211 | 221 |  |  |  | radial-gradient(circle at 30% 26%, #FFFFFF / 0.60, #000000 / 0.00 42%), linear-gradient(150deg, #61D278, #EE5E9C) |  | filter: url("#chk") contrast(1.04) |
| `span.fa > span.pic > b` | 141 | 225 | 105 | 109 | ゆ | 900 104px/104px Inter | #FFFFFF |  |  | 字間: -4.16px; 変形: matrix(0.999996, -0.00273478, 0.00273478, 0.999996, 0, -0.31 |
| `span.fa > span.pic > i.lk` | 88 | 169 | 211 | 221 |  |  |  | radial-gradient(70% 50% at 18% 8%, #FFB45A / 0.40, #000000 / 0.00 60%) |  |  |
| `span.fa > span.pic > span.st` | 221 | 356 | 67 | 19 | '26 11 13 | 700 11px/normal Space Mono | #FF9A3C |  |  | 字間: 0.66px |
| `button#pck.pck > span.fa > span.nm` | 105 | 399 | 72 | 40 | ゆい | 700 34px/34px Caveat | #1A1A1D |  | 4px | 変形: matrix(0.999391, -0.0348995, 0.0348995, 0.999391, 0, 0) |
| `button#pck.pck > span.fa > i.gl` | 75 | 155 | 241 | 299 |  |  |  | linear-gradient(115deg, #000000 / 0.00 25%, #FFFFFF / 0.65 40%, #000000 / 0.00 60%) | 6px |  |
| `button#pck.pck > span.fa > button.pbg1` | 255 | 162 | 42 | 42 |  |  |  | #FFFFFF | 50% | 影: #000000 / 0.45 0px 6px 14px 0px |
| `span.fa > button.pbg1 > svg` | 266 | 173 | 20 | 20 |  |  |  |  |  |  |
| `button#pck.pck > span.fa > button.pbg2` | 269 | 397 | 36 | 36 |  |  |  | #FFFFFF | 50% | 影: #000000 / 0.45 0px 6px 14px 0px |
| `span.fa > button.pbg2 > svg` | 277 | 405 | 20 | 20 |  |  |  |  |  |  |
| `div#phero.phero > button#pck.pck > span.fb` | 75 | 155 | 241 | 299 |  |  |  | #F4F1EA | 6px | 影: #000000 / 0.95 0px 40px 60px -22px, #000000 / 0.06 0px 0px 0px 1px; 変形: matrix3d(-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1) |
| `button#pck.pck > span.fb > span.qr3` | 105 | 190 | 177 | 177 |  |  |  | #FFFFFF | 8px | 影: #FFFFFF 0px 0px 0px 10px inset, #DDD8CC 0px 0px 0px 1px |
| `button#pck.pck > span.fb > b` | 158 | 370 | 82 | 24 | @yui_0612 | 700 13px/normal Space Mono | #111111 |  |  | 字間: 1.04px |
| `button#pck.pck > span.fb > small` | 158 | 400 | 86 | 17 | SCAN TO ADD | 700 8.5px/normal Space Mono | #8E8E93 |  |  | 字間: 2.55px |
| `div#pbd.pbd > div#phero.phero > button.pst.me` | 9 | 169 | 105 | 63 | #カフェ | 900 17px/normal Inter | #111111 | #C8F25A | 14px | 字間: -0.34px; 影: #000000 / 0.50 3px 4px 0px 0px; 変形: matrix(1.0667, -0.168949, 0.168949, 1.0667, -173.453, -138.5 |
| `div#phero.phero > button.pst.me > i.px` | -3 | 176 | 28 | 28 | ✕ | 800 10px/22px Inter | #FFFFFF | #111111 | 50% | 字間: -0.34px; 影: #FFFFFF 0px 0px 0px 2px |
| `div#pbd.pbd > div#phero.phero > button.pst.me` | 274 | 186 | 80 | 52 | #音楽 | 900 17px/normal Inter | #FFFFFF | #EE5E9C | 14px | 字間: -0.34px; 影: #000000 / 0.50 3px 4px 0px 0px; 変形: matrix(0.990268, 0.139173, -0.139173, 0.990268, 80.875, -120 |
| `div#phero.phero > button.pst.me > i.px` | 270 | 176 | 25 | 25 | ✕ | 800 10px/22px Inter | #FFFFFF | #111111 | 50% | 字間: -0.34px; 影: #FFFFFF 0px 0px 0px 2px |
| `div#pbd.pbd > div#phero.phero > button.pst.me` | 22 | 336 | 77 | 46 | #夜型 | 900 17px/normal Inter | #111111 | #9ED8FF | 14px | 字間: -0.34px; 影: #000000 / 0.50 3px 4px 0px 0px; 変形: matrix(0.994522, 0.104528, -0.104528, 0.994522, -173.125, 19 |
| `div#phero.phero > button.pst.me > i.px` | 14 | 326 | 23 | 23 | ✕ | 800 10px/22px Inter | #FFFFFF | #111111 | 50% | 字間: -0.34px; 影: #FFFFFF 0px 0px 0px 2px |
| `div#pbd.pbd > div.pnm > b` | 142 | 520 | 106 | 54 | ゆい | 400 54px/54px Instrument Serif | #FFFFFF |  |  | 字間: -1.08px |
| `div#pbd.pbd > div.pnm > span.mood` | 146 | 582 | 99 | 22 | since | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 1.8px; 大文字化: uppercase |
| `div.pnm > span.mood > em` | 193 | 582 | 51 | 22 | Oct 2026 | 400 17px/normal Instrument Serif italic | #C8F25A |  |  |  |
| `div#pbd.pbd > div#ped.ped > div.pes` | 16 | 624 | 358 | 137 |  |  |  | #121214 / 0.62 | 24px | 影: #FFFFFF / 0.08 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.pes > div.peh > b` | 30 | 638 | 47 | 22 | Photo | 400 22px/22px Instrument Serif | #FFFFFF |  |  | 字間: 0.48px |
| `div.pes > div#pep.pep > button.cam` | 30 | 674 | 54 | 68 |  |  |  | #24A03C | 12px |  |
| `div#pep.pep > button.cam > svg` | 45 | 696 | 24 | 24 |  |  |  |  |  |  |
| `div.pes > div#pep.pep > button.ph` | 92 | 674 | 54 | 68 |  |  |  | (photo) | 12px |  |
| `div.pes > div#pep.pep > button.ph` | 154 | 674 | 54 | 68 |  |  |  | (photo) | 12px |  |
| `div.pes > div#pep.pep > button.ph` | 216 | 674 | 54 | 68 |  |  |  | (photo) | 12px |  |
| `div.pes > div#pep.pep > button.ph` | 278 | 674 | 54 | 68 |  |  |  | (photo) | 12px |  |
| `div.pes > div#pep.pep > button.ph` | 340 | 674 | 54 | 68 |  |  |  | (photo) | 12px |  |
| `div#pbd.pbd > div#ped.ped > div.pes` | 16 | 771 | 358 | 117 |  |  |  | #121214 / 0.62 | 24px | 影: #FFFFFF / 0.08 0px 0px 0px 1px inset; 背景ぼかし: blur(18px) |
| `div.pes > div.peh > b` | 30 | 785 | 45 | 22 | Name | 400 22px/22px Instrument Serif | #FFFFFF |  |  | 字間: 0.48px |
| `div.pes > div.peh > em#pecnt` | 315 | 792 | 45 | 15 | 2 / 12 | 700 10px/normal Space Mono | #8C8C93 |  |  | 字間: 1.4px |
| `div#ped.ped > div.pes > label.pen` | 30 | 818 | 330 | 54 |  |  |  | #FFFFFF / 0.08 | 16px |  |
| `div.pes > label.pen > button#peclr` | 324 | 831 | 28 | 28 | ✕ | 700 11px/normal Inter | #C9C9CF | #FFFFFF / 0.14 | 50% |  |
| `div#phe.phe` | 0 | 0 | 390 | 104 |  |  |  | linear-gradient(#060606 / 0.92 60%, #000000 / 0.00) |  |  |
| `div#phe.phe > button#pecx.cx` | 16 | 52 | 102 | 38 | キャンセル | 700 14px/normal Inter | #C9C9CF | #FFFFFF / 0.10 | 19px |  |
| `div#phe.phe > b` | 197 | 55 | 38 | 35 | Edit | 400 26px/26px Instrument Serif | #FFFFFF |  |  | 字間: 0.48px |
| `div#phe.phe > button#peok.ok` | 314 | 52 | 60 | 38 | 完了 | 700 14px/normal Inter | #6C6C73 | #2A2A2E | 19px |  |