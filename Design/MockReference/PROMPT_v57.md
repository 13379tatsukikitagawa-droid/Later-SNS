# v57 ── Home の まんなかを「横に スライドする 5枚」に する(モック v55)

> v55(まわす ダイヤル と ひらく カード)の **「まわす」「カード」を この v57 で 置きかえ**ます。理由は、横に はらう 操作と ぶつかるためです。
> v55 の うち、次の 3つは そのまま 使います。
> - ボタンの 見た目(白い 丸 62pt ・ 黒の ふち ・ 平らな 影 ・ 札)
> - 登場の 動き(レンズから とびだす)
> - ひまな ときに 光が 1周する 演出
>
> 見本:
> - `later_v55.html`
> - `later_v55_slide_preview.png`
> - `MockReference/screens/S01〜S07`
> - コード: `mock/src/v55.js` と `style.css` の 末尾「v55」
>
> CloudKit / Firebase の 保存 ・ リンク発行 ・ 招待文は さわらない。

## 1. しくみ

- いま カメラが ある 場所(写ルンです の 本体)を、**横に スライドする 5枚**に する。

  | 番号 | ページ |
  |---|---|
  | 0 | Camera(今の カメラ。最初に 出る) |
  | 1 | Friends |
  | 2 | Trip |
  | 3 | Mondo |
  | 4 | Yesterday |

- 行き方は 3つ。
  - **指で 横に はらう**
  - **下の 目次**を 押す
  - **カメラの 四すみの ボタン**を 押す(その ページへ すべって 移る)
- **たてに 動かすと、今までどおり Home 全体が スクロール**し、下の 写真(Today ・ ACTIVE ・ YESTERDAY ・ ALBUMS)へ 行ける。下の「今日を撮る」(地球)も そのまま。

## 2. SwiftUI の 作り方

```swift
ScrollView(.vertical) {                 // 今の Home の たてスクロール
  VStack(spacing: 0) {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(HomePage.allCases) { p in
          page(p)
            .frame(width: screenW, height: 600)
            .visualEffect { c, proxy in   // 少し 立体に
              let d = proxy.frame(in: .scrollView(axis: .horizontal)).minX / screenW
              return c.rotation3DEffect(.degrees(-d * 14), axis: (0, 1, 0), perspective: 0.6)
                      .scaleEffect(1 - 0.08 * min(1, abs(d)))
                      .opacity(1 - 0.45 * min(1, abs(d)))
            }
        }
      }.scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $page)
    .scrollIndicators(.hidden)
    .overlay(alignment: .bottom) { PageIndex(page: $page).padding(.bottom, 58) }
    // ↓ 今の 下の 写真の 区画
  }
}
```

- 横と たての 判定: 最初の 動きが **横 8pt 以上**で、たての **1.2倍 以上**なら 横スライド。それ以外は たてスクロールに ゆずる(SwiftUI の ScrollView の 入れ子で 自然に そうなる)。
- 両はしで 引っぱると **35% の 重さ**で のびて 戻る。
- 指を 離した ときの 速さで、**となり 1枚まで** 進む(2枚 とばさない)。
- 戻り方は ばね(`.spring(response: 0.32, dampingFraction: 0.78)`)。
- Mac の トラックパッドの 横スクロールでも 1枚ずつ 移る。

## 3. 目次(下の ピル)

- カメラ本体の 下の 黒い 部分(本体の 下から 12pt)に、**ガラスの ピル**を 置く。
  - 背景: #121212 78% + ぼかし 14
  - 中の 間隔: 4pt
  - 角丸: 22
- 5つの アイコンを 並べる(各 34pt)。今の ページだけ **黄緑 #C8F25A の カプセル**に なり、名前(`CAMERA` `FRIENDS` `TRIP` `MONDO` `YESTERDAY`、Space Mono 8.5pt・字間 0.14em)が 横に のびて 出る(0.35秒)。
- アイコン:
  - Camera: 二重丸
  - Friends: 2人
  - Trip: スーツケース
  - Mondo: 地球
  - Yesterday: 写真の 束

## 4. 4枚の ページ(カメラ本体と 同じ 大きさ ・ 同じ 世界)

- 大きさと 位置は カメラ本体と 同じ: 左右 10pt・上下 46pt・角丸 40。
- 黒い 本体(#1B1B1B → #101010 → #0B0B0C)。左に カメラと 同じ **白 / 赤 / 金の 3本線**(幅 7)。
- 上の 列:
  - 左に 丸 40pt の アイコン(ページの 色・黒の ふち 2.2・平らな 影 3)
  - `01 / 04`(Space Mono 9pt)
  - 右に 状態(`● 2 shot today` / `11.20 – 11.22` / `TOP 5` / `1 OPENED` / `LOCKED`、#7EE08F)
- 見出し: Instrument Serif 44pt(`Friends` `Trip` `Mondo` `Yesterday`)。
- いちばん 下に **大きな GO**(高さ 56・白・右に 緑 #3BD35A の 丸と →)。目次の 上に 置く。
  - ロック中は 灰色で `Shoot first`(黄緑の 丸に カメラ)。押すと 撮影へ。
- ページに 入った とき: 中身が 60ms ずつ 下から 18pt 上がって 出る(480ms・`cubic-bezier(.3,1.35,.5,1)`)。

| ページ | アイコンの 色 | 中身 | GO |
|---|---|---|---|
| **Friends** | 黄緑 | ① 申請が あれば `Requests` の 帯(丸 3つ + `承認 ›`)<br>② 友だちの 丸(54pt、今日の こま数で 緑の 輪)。左に 黄緑の `+ Add`。3人まで 1列、4人 以上で 2列(最大 7人)<br>③ `YESTERDAY` 友だちの きのうの 写真 4枚(撮る前は ぼかし + 🔒) | `Open friends` → Friend 画面 |
| **Trip** | 緑 #24A03C | Trip が ある とき:<br>・名前(Instrument Serif 34pt 黄緑)<br>・**23マス**(6列・撮った 人の 色で うまる。自分は 黄緑)+ `7/23`<br>・メンバーの 丸<br>・`あした 9:00 に みんなで ひらく`<br>ない とき: スーツケースの 絵 + `旅行 ・ イベント ・ 合宿` / `1日 23枚を、みんなで 分けあって 撮る` | ある とき: 黄緑の `📷 Shoot`(Trip に 撮る)+ 丸い チャット(未読 数)<br>ない とき: `New trip` |
| **Mondo** | 白 | 右上に 大きな 緑の 地球(線で 描き、経線が 7秒で 回る)。`The world, yesterday.`(yesterday. は 緑 Italic)。人気タグ 3つ(1位は 黄緑。ロック中は ぼかし + 🔒)。Tokyo / Paris / New York の 時刻 | `Explore` / `Shoot first` |
| **Yesterday** | 金 #C8A46A | きのうの 3枚を **チェキの 扇**に(−10° / 0 / 10°、白い ふち 7pt・下 26pt・時刻の 印字)。下に タグ 3つ。ロック中は ぼかし + 🔒 | `Open` / `Shoot first` |

## 5. カメラ(0枚目)の 四すみの ボタン

- 位置は 固定(左上・右上・左下・右下)。**大きさは 4つとも 同じ**(右下を 大きくする READY は やめる)。札の 下の 数字も 出さない。
- 押すと 沈んで(`click`)、ぽよんと はねて(0.84 → 1.1 → 1)、**その ページへ すべって 移る**。
- ページが ない ボタン(SHOOT ・ DEVELOP ・ CHAT)は、今までどおり その 画面を ひらく。
- レールの 点線は うすく(白 18%)残す。回す 操作は **なし**。`TURN` の 札も 消す。

## 6. たてスクロールとの つながり

- たてに スクロールした ときの 視差(本体が 少し 上に ずれて 小さくなる)は、**5枚 全体**に かける(今は カメラだけに かかっている)。
- どの ページを 見ていても、下に スクロールすれば 同じ 写真の 区画へ 行く。上に 戻ると、見ていた ページの まま。
- Home に 戻ってきた ときは、**前に 見ていた ページ**を 出す(アプリを 開き直したら Camera から)。

## 7. バイブ

- ページが 変わった とき: `sel`
- 中身が 出そろった とき: `tick`
- 両はしで 引っぱって 戻る とき: `soft`
- 四すみの ボタンを 押した とき: `click`
- Trip の Shoot: `shutter` → `tick`
- ロック中の GO(Shoot first): `pop` → 撮影へ

## 8. 完了の 条件

- 横に はらうと、Camera → Friends → Trip → Mondo → Yesterday と 1枚ずつ 移り、目次が ついてくる。
- たてに 動かすと、どの ページからでも 下の 写真へ スクロールできる(横に 動いて しまわない)。
- 四すみの ボタン・目次の どちらからでも、その ページへ 移れる。
- 4枚とも、中身の 数字(今日 撮った 人・23マス・ロック)が、今の 状態と 合っている。
- 「視差効果を 減らす」が オンの とき: 立体の 回転と 中身の せり上がりを やめ、フェードだけに する。
