# モックの 元コード ・ 読む 順番

`lattag_v64.html` は、下の ファイルを この 順番で 1つに まとめた もの です(フォント ・ 見本写真は html の 中に 埋めこみ)。

## HTML

- `body.html` … 画面の 骨組み(`#home` `#tag` `#cam` `#dev` `#ob` `#yst` `#fscr` `#room` `#gnw` など)

## CSS(後ろ ほど 優先 ・ 後勝ち)

1. `style.css`(v1 〜 v57 まで 全部 入り。**同じ クラスに 何回も ルールが ある** ので、いちばん 後ろの ルールが 効く)
2. `v58.css`(Friend の チェキの 壁)
3. `v61.css`(Home カード:ぼかした 写真 + ガラス / Home 下の Friends カード)
4. `v62.css`(仕上げ:チップ ・ ガラスの ふち ・ 目次 44pt ・ today / yesterday)
5. `v63.css`(カメラの 絵だけ ・ ヘッダー ・ 月の ガラス ・ はじめての 日)
6. `v64.css`(Mondo ページ)

## JS(後ろ ほど 優先 ・ 前の 関数を 包んで 上書き)

`app.js` の 最後に ある `window.__api={...}` の **直前** に、次の 順で 入って います:

`v46.js` → `v48.js` → `v49.js` → `v50.js` → `v51.js` → `v52.js` → `v53.js` → `v54.js` → `v55.js` → `v56.js` → `v57.js` → `v58.js` → `v61.js` → `v62.js` → `v63.js` → `v64.js`

- 上書きの 書き方:`{const _r=renderOrb;renderOrb=function(){_r(); …足す 処理…}}`。**最後に 定義された もの が 本当の 動き**。
- `v60.*` は `v61.*` に 置きかわった ので 入って いない。
- `v64.js` の 最後の `window.__kit` は 見本づくり用(実機には 入れない)。

## 早く 見つける コツ

- 画面の 部品 → `spec/screens/<ID>.json` の `el`(例 `div#hxb.hxb`)で クラス名を 知る → `mock/src` を その クラス名で 検索 → **いちばん 後ろの ファイル**の ルールを 見る。
- 動き → 関数名で 検索(`hpGo` `homeIn` `openTrip` など)。`hap('名前'` が バイブの 場所。
