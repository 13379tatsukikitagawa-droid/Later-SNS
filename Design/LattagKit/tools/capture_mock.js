/* Lattag モック → 見本画像(screens/)と 寸法データ(spec/screens/)を 作る
   使い方:  node tools/capture_mock.js [mock の html] [出力フォルダ] [ID の 一部(省略可)]
   例:      node tools/capture_mock.js mock/lattag_v64.html . H0
   必要:    npm i -D playwright && npx playwright install chromium */
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const MOCK = path.resolve(process.argv[2] || 'mock/lattag_v64.html');
const OUT = path.resolve(process.argv[3] || '.');
const ONLY = process.argv[4] || '';
fs.mkdirSync(path.join(OUT, 'screens'), { recursive: true });
fs.mkdirSync(path.join(OUT, 'spec/screens'), { recursive: true });

const W = ms => new Promise(r => setTimeout(r, ms));
const ctl = (p, c) => p.evaluate(c => { const b = [...document.querySelectorAll('#ctl button')].find(b => b.dataset.c === c || b.textContent.trim() === c); b && b.click() }, c);
const ev = (p, f, a) => p.evaluate(f, a);
const clean = p => ev(p, () => { const h = document.getElementById('home'); h && h.classList.remove('cm-spot'); try { cmHide() } catch (e) { } });
const home = async p => { await ctl(p, 'home'); await W(2600); await clean(p) };
const scrollTo = (p, id, off) => ev(p, ([id, off]) => { const hs = document.getElementById('hs'), a = document.getElementById(id); if (hs && a) hs.scrollTop = hs.scrollTop + a.getBoundingClientRect().top - hs.getBoundingClientRect().top - off }, [id, off]);
const fr3 = async p => { await ctl(p, 'fr3'); await W(1300); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await W(500) };

/* ---- 画面の 一覧(ID ・ 段階 ・ 名前 ・ 開き方) ---- */
const S = [
  // P1 オープニング ・ はじめての 設定
  ['O01_opening_print', 1, 'オープニング:チェキが 出てくる', { open: 1 }, async p => { await W(1700) }],
  ['O02_opening_logo', 1, 'オープニング:Lattag の 文字', { open: 1 }, async p => { await W(2450) }],
  ['O03_onboarding_intro', 1, 'はじめての 設定:入口(落ちてくる 題字)', {}, async p => { await ctl(p, 'ob'); await W(3300) }],
  ['O04_onboarding_signin', 1, 'はじめての 設定:サインイン(Apple / Google / メール)', {}, async p => { await ctl(p, 'ob'); await W(6200) }],
  ...['mail', 'sent', 'name', 'tag', 'fr', 'nt', 'go'].map((st, i) => [`O${String(5 + i).padStart(2, '0')}_onboarding_${st}`, 1, `はじめての 設定:${{ mail: 'メールアドレス', sent: 'メール送信済み', name: '名前と 色', tag: 'タグを 3つ', fr: '友だち', nt: '通知の 許可', go: 'できた' }[st]}`, {}, async p => { await ctl(p, 'ob'); await W(6200); await ev(p, st => __api.obStep(st), st); await W(1500) }]),
  // P2 Home の 上 ・ カメラカード ・ 横スライド
  ['H01_home', 2, 'Home:0枚(いつも)', {}, home],
  ['H02_home_hint', 2, 'Home:はじめの 合図(スポットライト)', {}, async p => { await ctl(p, 'home'); await W(2600) }],
  ['H03_home_press', 2, 'Home:まんなかを 押している 間', {}, async p => { await home(p); const L = await ev(p, () => { const r = document.getElementById('lens').getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2] }); await p.mouse.move(L[0], L[1]); await p.mouse.down(); await W(650) }],
  ['H04_home_1shot', 2, 'Home:1枚 撮った あと', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(1900); await clean(p) }],
  ['H05_home_2shot', 2, 'Home:2枚 撮った あと', {}, async p => { await home(p); await ev(p, () => __api.setShots(2)); await W(1900); await clean(p) }],
  ['H06_home_3shot', 2, 'Home:3枚 撮りおわり(まんなか = Yesterday)', {}, async p => { await home(p); await ev(p, () => __api.setShots(3)); await W(1900); await clean(p) }],
  ['H07_home_friends', 2, 'Home:友だち 3人 + 申請あり(上の チップ)', {}, async p => { await fr3(p); await ctl(p, 'req54'); await W(1200); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await home(p) }],
  ['H08_home_firstday', 2, 'Home:はじめての 日(上)', {}, async p => { await home(p); await ctl(p, 'day'); await W(2200); await clean(p) }],
  ['H09_home_night', 2, 'Home:夜', {}, async p => { await home(p); await ctl(p, '昼夜 きりかえ'); await W(1600); await clean(p) }],
  ['H10_live_panel', 2, 'Home:「消灯まで」を 押した パネル', {}, async p => { await home(p); await ev(p, () => document.getElementById('hst').click()); await W(1400) }],
  ['H11_page_friends', 2, '横スライド 1:Friends', {}, async p => { await home(p); await ev(p, () => __kit.hpGo(1)); await W(1600) }],
  ['H12_page_friends_filled', 2, '横スライド 1:Friends(3人 + 申請)', {}, async p => { await fr3(p); await ctl(p, 'req54'); await W(1200); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await home(p); await ev(p, () => __kit.hpGo(1)); await W(1600) }],
  ['H13_page_trip', 2, '横スライド 2:Trip(まだ ない)', {}, async p => { await home(p); await ev(p, () => __kit.hpGo(2)); await W(1600) }],
  ['H14_page_mondo_locked', 2, '横スライド 3:Mondo(撮る まえ)', {}, async p => { await home(p); await ev(p, () => { __kit.hpGo(3); __kit.MN().rot = 1.2 }); await W(1800) }],
  ['H15_page_mondo_open', 2, '横スライド 3:Mondo(撮った あと)', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(900); await ev(p, () => { __kit.hpGo(3); __kit.MN().rot = 2.6 }); await W(1800); await clean(p) }],
  ['H16_page_yesterday', 2, '横スライド 4:Yesterday(撮る まえ)', {}, async p => { await home(p); await ev(p, () => __kit.hpGo(4)); await W(1600) }],
  ['H17_page_yesterday_open', 2, '横スライド 4:Yesterday(撮った あと)', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(900); await ev(p, () => __kit.hpGo(4)); await W(1600); await clean(p) }],
  ['H18_page_yesterday_firstday', 2, '横スライド 4:Yesterday(はじめての 日)', {}, async p => { await home(p); await ctl(p, 'day'); await W(1500); await ev(p, () => __kit.hpGo(4)); await W(1600); await clean(p) }],
  // P3 Home の 下(スクロール)
  ['L01_today', 3, 'Home 下:Today(今日の フィルム)', {}, async p => { await home(p); await scrollTo(p, 'arc', 150); await W(1500) }],
  ['L02_active', 3, 'Home 下:Active(Trip)', {}, async p => { await home(p); await scrollTo(p, 'aact', 220); await W(1500) }],
  ['L03_yesterday', 3, 'Home 下:Yesterday(撮る まえ ・ ロック)', {}, async p => { await home(p); await scrollTo(p, 'ayh', 150); await W(1500) }],
  ['L04_yesterday_open', 3, 'Home 下:Yesterday(撮った あと)', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(1500); await scrollTo(p, 'ayh', 150); await W(1500); await clean(p) }],
  ['L05_mondo_row', 3, 'Home 下:Mondo の 列', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(1500); await scrollTo(p, 'amd', 200); await W(1500); await clean(p) }],
  ['L06_albums', 3, 'Home 下:Albums(7日)', {}, async p => { await home(p); await scrollTo(p, 'aal', 180); await W(1500) }],
  ['L07_onthisday', 3, 'Home 下:On this day', {}, async p => { await home(p); await scrollTo(p, 'otd', 200); await W(1500) }],
  ['L08_friends_card_empty', 3, 'Home 下:Friends カード(だれも いない)', {}, async p => { await home(p); await scrollTo(p, 'afc', 150); await W(1700) }],
  ['L09_friends_card', 3, 'Home 下:Friends カード(友だち あり)', {}, async p => { await fr3(p); await ctl(p, 'req54'); await W(1200); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await home(p); await scrollTo(p, 'afc', 150); await W(1700) }],
  ['L10_firstday_yesterday', 3, 'Home 下:はじめての 日の Yesterday', {}, async p => { await home(p); await ctl(p, 'day'); await W(1500); await scrollTo(p, 'anew', 260); await W(1600) }],
  ['L11_develop_view', 3, 'Home:今日の フィルム(現像中)を ひらく', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(1200); await ev(p, () => __api.openDvx(0)); await W(1800) }],
  // P4 撮る
  ['C01_tag', 4, 'タグ画面(撮る まえ)', {}, async p => { await ctl(p, 'tag'); await W(2000) }],
  ['C02_camera_photo', 4, '撮影画面(写真)', {}, async p => { await ctl(p, 'cam'); await W(1800) }],
  ['C03_camera_video', 4, '撮影画面(動画)', {}, async p => { await ctl(p, 'cam-m'); await W(2600) }],
  ['C04_volume_button', 4, '音量ボタン 長押しの 合図', {}, async p => { await ctl(p, 'cam'); await W(1500); await ctl(p, 'vol'); await W(900) }],
  ['C05_after_shot_1', 4, '撮った 直後 0.6秒', {}, async p => { await ctl(p, 'cam'); await W(1500); await ev(p, () => __api.shoot()); await W(600) }],
  ['C06_after_shot_2', 4, '撮った あと 1.6秒', {}, async p => { await ctl(p, 'cam'); await W(1500); await ev(p, () => __api.shoot()); await W(1600) }],
  ['C07_after_shot_3', 4, '撮った あと 3.2秒', {}, async p => { await ctl(p, 'cam'); await W(1500); await ev(p, () => __api.shoot()); await W(3200) }],
  ['C08_morning_develop_1', 4, '翌朝 9:00 の 現像 1秒', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(800); await ctl(p, 'next'); await W(1000) }],
  ['C09_morning_develop_2', 4, '翌朝 9:00 の 現像 3秒', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(800); await ctl(p, 'next'); await W(3000) }],
  ['C10_rare_film', 4, '現像(レアフィルム)', {}, async p => { await ctl(p, 'rare'); await W(2600) }],
  ['C11_cheki_develop', 4, '現像(チェキ)', {}, async p => { await ctl(p, '現像(チェキ)'); await W(2600) }],
  // P5 Yesterday ・ Mondo
  ['Y01_yesterday_locked', 5, 'Lattag yesterday(撮る まえ)', {}, async p => { await home(p); await ev(p, () => __api.openY()); await W(1800) }],
  ['Y02_yesterday_open', 5, 'Lattag yesterday(撮った あと)', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(800); await ev(p, () => __api.openY()); await W(1800) }],
  ['Y03_yesterday_mondo_tab', 5, 'Lattag yesterday:Mondo タブ', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(800); await ev(p, () => __api.openY()); await W(1500); await ev(p, () => __api.ytab('ytm')); await W(1500) }],
  ['Y04_yesterday_friends_tab', 5, 'Lattag yesterday:Friends タブ(友だち あり)', {}, async p => { await fr3(p); await home(p); await ev(p, () => __api.setShots(1)); await W(800); await ev(p, () => __api.openY()); await W(1800) }],
  ['Y05_yesterday_scroll', 5, 'Lattag yesterday:下へ', {}, async p => { await home(p); await ev(p, () => __api.setShots(1)); await W(800); await ev(p, () => __api.openY()); await W(1500); await ev(p, () => { const b = document.getElementById('ybody'); b && (b.scrollTop = 700) }); await W(1300) }],
  ['Y06_photo_viewer', 5, '写真を ひらいた ところ', {}, async p => { await home(p); await ev(p, () => __api.openAv({ p: 'a', n: '鎌倉市', s: "today's one · picked by the world", t: '#夕焼け' })); await W(1500) }],
  // P6 Friends ・ Profile
  ['F01_friend_empty', 6, 'Friend 画面(だれも いない)', {}, async p => { await home(p); await ev(p, () => __api.openFriend()); await W(1600) }],
  ['F02_friend_wall', 6, 'Friend 画面(チェキの 壁)', {}, async p => { await ctl(p, 'fr3'); await W(1800) }],
  ['F03_friend_requests', 6, 'Friend 画面:申請が とどいた', {}, async p => { await ctl(p, 'fr3'); await W(1300); await ctl(p, 'req54'); await W(1600) }],
  ['F04_friend_scroll', 6, 'Friend 画面:下へ', {}, async p => { await ctl(p, 'fr3'); await W(1600); await ev(p, () => { const b = document.getElementById('frbody'); const s = b && (b.closest('.fbd') || b.parentElement); [b, s].forEach(e => e && (e.scrollTop = 700)) }); await W(1200) }],
  ['F05_friend_card', 6, '友だちの カード(シート)', {}, async p => { await ctl(p, 'fr3'); await W(1600); await ev(p, () => __kit.openFC(0)); await W(1500) }],
  ['F06_add_friends', 6, 'Add friends(ID ・ QR)', {}, async p => { await home(p); await ev(p, () => __kit.openAdd()); await W(1400) }],
  ['F07_dm_chat', 6, '友だちと チャット', {}, async p => { await fr3(p); await home(p); await ev(p, () => __kit.openDM(0)); await W(1600) }],
  ['F08_profile', 6, 'Profile', {}, async p => { await home(p); await ev(p, () => document.querySelector('#home .hh .av').click()); await W(1800) }],
  ['F09_me_calendar', 6, 'ME(1年 のこす)', {}, async p => { await home(p); await ev(p, () => __kit.openMe()); await W(1800) }],
  ['F10_qr_scan', 6, 'QR を 読む', {}, async p => { await home(p); await ev(p, () => __api.openScan('friend')); await W(1500) }],
  // P7 Trip(グループ)
  ['T01_new_trip', 7, 'New trip(つくる 画面)', {}, async p => { await home(p); await ev(p, () => __kit.openTrip()); await W(1600) }],
  ['T02_new_trip_filled', 7, 'New trip(入力 した あと)', {}, async p => { await fr3(p); await home(p); await ev(p, () => { __kit.openTrip() }); await W(1200); await ev(p, () => __kit.fillTrip()); await W(1200) }],
  ['T03_trip_pass_new', 7, 'Trip パス(できた ・ QR + KEY)', {}, async p => { await fr3(p); await home(p); await ev(p, () => { __kit.openTrip() }); await W(1200); await ev(p, () => { __kit.fillTrip(); __kit.tripCreate() }); await W(2200) }],
  ['T04_trip_page_active', 7, '横スライド 2:進行中の Trip', {}, async p => { await home(p); await ctl(p, 'trip54'); await W(1200); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await home(p); await ev(p, () => __kit.hpGo(2)); await W(1600) }],
  ['T05_trip_pass', 7, 'Trip パス(あとから ひらく)', {}, async p => { await home(p); await ctl(p, 'trip54'); await W(1200); await ev(p, () => __kit.openPass()); await W(1600) }],
  ['T06_trip_settings', 7, 'Trip の 設定', {}, async p => { await home(p); await ctl(p, 'trip54'); await W(1200); await ev(p, () => __kit.tripSet()); await W(1200) }],
  ['T07_trip_chat', 7, 'Trip の 部屋(チャット)', {}, async p => { await home(p); await ctl(p, 'room'); await W(1800) }],
  ['T08_invite', 7, '招待が とどいた', {}, async p => { await home(p); await ctl(p, 'inv'); await W(1600) }],
  ['T09_active_card', 7, 'Home 下:Active に Trip', {}, async p => { await home(p); await ctl(p, 'trip54'); await W(1200); await ev(p, () => { try { __api.closeFriend() } catch (e) { } }); await home(p); await scrollTo(p, 'aact', 220); await W(1600) }],
];

const DUMP = () => {
  const P = document.getElementById('home').getBoundingClientRect(); const out = [];
  const cs = (e) => getComputedStyle(e);
  const vis = e => { const r = e.getBoundingClientRect(); return r.width > 1 && r.height > 1 && r.right > P.left && r.left < P.right && r.bottom > P.top && r.top < P.bottom };
  const walk = (e, d) => { for (const c of e.children) { if (c.id === 'ctl') continue; const s = cs(c); if (s.display === 'none' || s.visibility === 'hidden' || +s.opacity < .02) continue;
      const tag = c.tagName.toLowerCase(); const r = c.getBoundingClientRect();
      const txt = [...c.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join(' ').slice(0, 40);
      const bg = s.backgroundImage !== 'none' ? s.backgroundImage.replace(/url\("data:[^)]*\)/g, 'url(data…)').slice(0, 160) : (s.backgroundColor !== 'rgba(0, 0, 0, 0)' ? s.backgroundColor : '');
      const visual = txt || bg || s.boxShadow !== 'none' || s.borderTopWidth !== '0px' || ['img', 'svg', 'canvas', 'video', 'input', 'button'].includes(tag) || s.backdropFilter !== 'none';
      if (visual && vis(c)) out.push({ el: tag + (c.id ? '#' + c.id : '') + (typeof c.className === 'string' && c.className ? '.' + c.className.trim().split(/\s+/).slice(0, 3).join('.') : ''), x: +(r.left - P.left).toFixed(1), y: +(r.top - P.top).toFixed(1), w: +r.width.toFixed(1), h: +r.height.toFixed(1),
        ...(txt ? { text: txt, font: `${s.fontStyle === 'italic' ? 'italic ' : ''}${s.fontWeight} ${s.fontSize}/${s.lineHeight} ${s.fontFamily.split(',')[0].replace(/"/g, '')}`, ls: s.letterSpacing, color: s.color } : {}),
        ...(bg ? { bg } : {}), ...(s.borderRadius !== '0px' ? { radius: s.borderRadius } : {}), ...(s.boxShadow !== 'none' ? { shadow: s.boxShadow.slice(0, 160) } : {}),
        ...(s.borderTopWidth !== '0px' ? { border: `${s.borderTopWidth} ${s.borderTopStyle} ${s.borderTopColor}` } : {}), ...(s.backdropFilter !== 'none' ? { backdrop: s.backdropFilter } : {}), ...(s.filter !== 'none' ? { filter: s.filter.replace(/url\([^)]*\)/g, 'url(…)') } : {}),
        ...(+s.opacity < 1 ? { opacity: +(+s.opacity).toFixed(2) } : {}), ...(s.transform !== 'none' ? { transform: s.transform.slice(0, 70) } : {}) });
      if (tag !== 'svg' && d < 14 && out.length < 600) walk(c, d + 1) } };
  walk(document.getElementById('phone') || document.body, 0); return out };

(async () => {
  const b = await chromium.launch(); const idx = [];
  for (const [id, ph, name, o, act] of S) {
    if (ONLY && !id.includes(ONLY)) continue;
    const p = await b.newPage({ viewport: { width: 430, height: 1400 }, deviceScaleFactor: 2 });
    const errs = []; p.on('pageerror', e => errs.push(e.message));
    try {
      await p.goto('file://' + MOCK + (o.open ? '' : '?noopen')); await W(o.open ? 0 : 1300);
      await act(p);
      const R = await p.evaluate(() => { const r = document.getElementById('home').getBoundingClientRect(); return [r.x, r.y, r.width, r.height] });
      await p.screenshot({ path: path.join(OUT, 'screens', id + '.jpg'), type: 'jpeg', quality: 90, clip: { x: R[0], y: R[1], width: R[2], height: R[3] } });
      const d = await p.evaluate(DUMP); fs.writeFileSync(path.join(OUT, 'spec/screens', id + '.json'), JSON.stringify({ id, name, phase: ph, size: '390x844pt', elements: d }, null, 0));
      idx.push({ id, ph, name, n: d.length, errs }); process.stdout.write(id + ' ok ' + d.length + (errs.length ? ' ERR ' + errs[0] : '') + '\n');
    } catch (e) { idx.push({ id, ph, name, fail: String(e).slice(0, 120) }); process.stdout.write(id + ' FAIL ' + String(e).slice(0, 120) + '\n') }
    await p.close();
  }
  fs.writeFileSync(path.join(OUT, 'screens/_capture_log.json'), JSON.stringify(idx, null, 1)); await b.close();
})();
