/* Lattag モック → 動きの コマ割り(motion/*.png)
   使い方: node tools/capture_motion.js [mock の html] [出力フォルダ]
   1つの 動きを 決まった 時刻で 撮って、1枚の 画像に 並べる(左上が 0ms)。 */
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const MOCK = path.resolve(process.argv[2] || 'mock/lattag_v82.html');
const OUT = path.resolve(process.argv[3] || '.');
const ONLY = process.argv[4] || '';
fs.mkdirSync(path.join(OUT, 'motion/_frames'), { recursive: true });
const W = ms => new Promise(r => setTimeout(r, ms));
const ctl = (p, c) => p.evaluate(c => { const b = [...document.querySelectorAll('#ctl button')].find(b => b.dataset.c === c || b.textContent.trim() === c); b && b.click() }, c);
const ev = (p, f, a) => p.evaluate(f, a);
const clean = p => ev(p, () => { const h = document.getElementById('home'); h && h.classList.remove('cm-spot'); try { cmHide() } catch (e) { } });
const home = async p => { await ctl(p, 'home'); await W(2600); await clean(p) };
const fr3 = async p => { await ctl(p, 'fr3'); await W(1300); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await W(500) };
const lensXY = p => ev(p, () => { const r = document.getElementById('lens').getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2] });

/* [ID, 名前, 開く 前の 準備, 動きを 起こす, 撮る 時刻(ms), 切りとり(画面内 y, 高さ)] */
const M = [
  ['M01_opening', 'オープニング(起動〜Home)', null, null, [0, 300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000, 3400, 3800, 4300, 5000], null, { open: 1 }],
  ['M02_onboarding_intro', 'はじめての 設定の 入口(題字が 落ちる → サインイン)', null, p => ctl(p, 'ob'), [0, 400, 800, 1200, 1600, 2000, 2400, 2800, 3200, 3800, 4600, 5600]],
  ['M03_home_enter', 'Home に 入る(カード ・ ボタン ・ 四すみ ・ ピル)', home, p => ev(p, () => __api.homeIn()), [0, 100, 200, 300, 400, 500, 600, 700, 800, 1000, 1200, 1500], [110, 640]],
  ['M04_shutter', 'まんなかを 押す → はなす → 撮影へ', home, async p => { const L = await lensXY(p); await p.mouse.move(L[0], L[1]); await p.mouse.down(); setTimeout(() => p.mouse.up().catch(() => { }), 600) }, [0, 150, 300, 500, 650, 720, 800, 900, 1000, 1200, 1500, 2000]],
  ['M05_page_swipe', '横スライド(Camera → Friends)と 目次の 印', home, p => ev(p, () => __kit.hpGo(1)), [0, 60, 120, 180, 240, 300, 380, 460, 560, 700, 900, 1200], [110, 640]],
  ['M06_after_shot', '撮った あと(チェキ → 預ける → Home)', p => ctl(p, 'cam').then(() => W(1600)), p => ev(p, () => __api.shoot()), [0, 200, 400, 600, 800, 1000, 1300, 1600, 2000, 2500, 3000, 3600]],
  ['M07_return_after_shot', '撮って もどった Home(弧が 抜ける ・ ピル)', home, p => ev(p, () => __api.setShots(1)), [0, 250, 400, 550, 700, 850, 1000, 1150, 1300, 1500], [110, 640]],
  ['M08_morning_develop', '翌朝 9:00 の 現像', async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(800) }, p => ctl(p, 'next'), [0, 400, 800, 1200, 1600, 2000, 2500, 3000, 3600, 4200, 5000, 6000]],
  ['M09_request_accept', '申請を 承認(カードが 落ちて 壁に 貼られる)', async p => { await ctl(p, 'fr3'); await W(1300); await ctl(p, 'req54'); await W(1500) }, p => ev(p, () => { const b = document.querySelector('.frc [data-a="ok"]'); b && b.click() }), [0, 120, 240, 360, 480, 600, 800, 1000, 1300, 1700]],
  ['M10_trip_create', 'Trip を つくる → パス', async p => { await fr3(p); await home(p); await ev(p, () => __kit.openTrip()); await W(1200); await ev(p, () => __kit.fillTrip()); await W(600) }, p => ev(p, () => __kit.tripCreate()), [0, 200, 400, 600, 800, 1000, 1300, 1600, 2000, 2600]],
  ['M11_mondo_globe', 'Mondo の 地球(回る ・ 9:00 の 線)', async p => { await home(p); await ev(p, () => __kit.hpGo(3)); await W(1500) }, p => ev(p, () => { __kit.MN().boost = .03 }), [0, 700, 1400, 2100, 2800, 3500, 4200, 4900], [110, 640]],
  ['M12_friends_card_in', 'Home 下の Friends カード(チェキが 貼られる)', async p => { await fr3(p); await home(p) }, p => ev(p, () => { const hs = document.getElementById('hs'), a = document.getElementById('afc'); a._in = false; hs.scrollTop = hs.scrollTop + a.getBoundingClientRect().top - hs.getBoundingClientRect().top - 150; hs.dispatchEvent(new Event('scroll')) }), [0, 150, 300, 450, 600, 750, 900, 1100, 1400]],
  ['M13_live_panel', '「消灯まで」を 押した パネル', home, p => ev(p, () => document.getElementById('hst').click()), [0, 100, 200, 300, 450, 600, 800, 1100]],
  ['M14_friend_card_sheet', '友だちの カードを ひらく', async p => { await ctl(p, 'fr3'); await W(1600) }, p => ev(p, () => __kit.openFC(0)), [0, 100, 200, 300, 400, 550, 700, 900, 1200]],
  ['M15_shake_connect', 'Shake:ふる → さがす → 見つけた → つながる', async p => { await fr3(p); await ev(p, () => { __kit.openFriend(); __kit.openShake() }); await W(1500) }, async p => { await ev(p, () => __kit.skShake()); setTimeout(() => p.evaluate(() => __kit.skOk()).catch(() => { }), 3300) }, [0, 300, 900, 1500, 1750, 1950, 2200, 2700, 3300, 3700, 4500, 4900, 5600]],
  ['M16_home_focus', 'Home:はじめの ピント合わせ(フルブリード)', home, p => ev(p, () => __api.homeIn()), [0, 150, 300, 450, 600, 800, 1000, 1300]],
  ['M17_home_camera_boot', 'Home:カメラの 起動(HUD が ひらく ・ 四すみが レンズから 出る ・ かぎ)', home, p => ev(p, () => __api.homeIn()), [0, 200, 350, 500, 650, 800, 950, 1100, 1300, 1600]],
  ['M18_iris_shutter', 'まんなかを 押す → しぼり羽根が しまる → はなす → シャッター', home, async p => { const r = await ev(p, () => { const r = document.getElementById('lens').getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2] }); await p.mouse.move(r[0], r[1]); await p.mouse.down(); setTimeout(() => p.mouse.up().catch(() => { }), 700) }, [0, 120, 250, 400, 600, 720, 760, 800, 900, 1100, 1400]],
  ['M19_header_compact', 'Home:下へ スクロール → ヘッダーが 1つの ガラスに まとまる', home, p => ev(p, () => { __kit.hs().scrollTo({ top: 300, behavior: 'smooth' }) }), [0, 120, 240, 360, 480, 640, 800, 1000]],
  ['M24_recap_develop', 'ME:新しい Recap が 現像される(ぼけ ・ 白黒 → くっきり)', home, p => ev(p, () => { __kit.rcSeen(false); __kit.openMe() }), [0, 300, 600, 900, 1200, 1500, 1800, 2100, 2400]],
  ['M25_recap_play', 'Recap:押す → 題 → 写真が 動いて 入れかわる', async p => { await home(p); await ev(p, () => { __kit.rcSeen(true); __kit.openMe() }); await W(1500) }, p => ev(p, () => document.querySelector('#mew .rch').click()), [0, 200, 400, 700, 1100, 1500, 1900, 2300, 2700, 3100, 3500, 4200]],
];

(async () => {
  const b = await chromium.launch(); const log = [];
  for (const [id, name, prep, act, T, crop, o] of M) {
    if (ONLY && !id.includes(ONLY)) continue;
    const p = await b.newPage({ viewport: { width: 430, height: 1400 }, deviceScaleFactor: 1 });
    try {
      await p.goto('file://' + MOCK + (o && o.open ? '' : '?noopen')); if (!(o && o.open)) await W(1300);
      if (prep) await prep(p);
      const R = await p.evaluate(() => { const r = document.getElementById('home').getBoundingClientRect(); return [r.x, r.y, r.width, r.height] });
      const clip = crop ? { x: R[0], y: R[1] + crop[0], width: R[2], height: crop[1] } : { x: R[0], y: R[1], width: R[2], height: R[3] };
      const t0 = Date.now(); if (act) act(p); const files = [];
      for (const t of T) { const wait = t - (Date.now() - t0); if (wait > 0) await W(wait); const real = Date.now() - t0; const f = path.join(OUT, 'motion/_frames', `${id}_${String(t).padStart(5, '0')}.png`); await p.screenshot({ path: f, clip }); files.push([f, t, real]) }
      log.push({ id, name, frames: files.map(f => [path.basename(f[0]), f[1], f[2]]) }); process.stdout.write(id + ' ok\n');
    } catch (e) { process.stdout.write(id + ' FAIL ' + String(e).slice(0, 140) + '\n') }
    await p.close();
  }
  fs.writeFileSync(path.join(OUT, 'motion/_frames/log.json'), JSON.stringify(log, null, 1)); await b.close();
})();
