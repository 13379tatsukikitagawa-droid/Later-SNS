const P9M={"meadow95": ["111111100101000001110010101111111", "100000100110011100101110101000001", "101110101111011101010111101011101", "101110101010011000111101101011101", "101110100010011001100101001011101", "100000100100010010001010101000001", "111111101010101010101010101111111", "000000000101001101000011000000000", "000110110011010010101001100001100", "010011001010110101101011010110100", "010001100101001010001101011101111", "111010000100001000110001000111100", "100101111111001011011111101111000", "101001001010101001111111110001110", "101110101000000000110000001011000", "001001001001111001000001010110111", "100001101111010110110001011110010", "110011010001101000101010101011011", "110001111111001101001111000111101", "111101000001101100110011110101100", "100000111100000101011000001001001", "101111011101010100000000101110110", "101111110001101000011111001100111", "100000000100110111110011100110100", "111110110000001001001001111110011", "000000001000011010011100100011010", "111111101001101111011001101011000", "100000100011011011110111100011110", "101110101100011110011111111110010", "101110101101111000101110110101010", "101110100101101101110010000010111", "100000100000111100010100011000111", "111111100110110000111101100011000"], "maple24": ["111111100101101011111010101111111", "100000100111111000101110101000001", "101110101111011111011111101011101", "101110101010011100110101001011101", "101110100010001000111101101011101", "100000100001000011110011001000001", "111111101010101010101010101111111", "000000000101111011001000100000000", "000110110001011110101000000001100", "000111001101110100100111010110100", "011001111010101010100011011101111", "110110010000000001000111100111100", "101001110110011011011101101111000", "100101000110101000111101110110110", "100100111100010000010000001100000", "001010000101101000000001010100101", "110010100101000100011001011110010", "010100011010100110011010101011011", "001110111111001011000111011111111", "101101011001101100111011101101101", "100011101101100011001000110001000", "101100011100100101000100011110110", "101101110010101001100110101100111", "100011000100010101100010000110100", "111111111001111110000000111110011", "000000001110010010110000100011010", "111111101111101100011111101011000", "100000100100101001111001100011110", "101110101110011010111101111110010", "101110101001111001101100110100110", "101110100101111101010010000011111", "100000100110100100110010011000111", "111111100100101010110001100010100"], "cocoa597": ["111111100101000001110010101111111", "100000100110011100101110101000001", "101110101111011101010111101011101", "101110101010011010111101101011101", "101110100010011110100101001011101", "100000100000000000111110101000001", "111111101010101010101010101111111", "000000000101110010010011000000000", "000110110001111111101001100001100", "010011001010111010010011010110100", "010001100000011111101101011101111", "111010000001000011111000000111100", "100101111011000011011110101111000", "001111011010100001011111110001110", "011011110000000000110000001001100", "001010001001111001000001010110111", "101000110111010110110001011110010", "100000001001101000101010101011011", "101101110111001101001111000111111", "100100000001101100110011110101101", "100000101100100111010000001001010", "101110011101110010011100101110110", "101111110111000111110011001100111", "100000000011110010110001100110100", "111110110110110101010001111110011", "000000001101100010100100100011010", "111111101101110111011001101011000", "100000100010001001010111100011110", "101110101110000110101111111110010", "101110101101110000101110010101010", "101110100101101101110011100010111", "100000100000111100010100011000111", "111111100110110000111101100011000"], "sunny42": ["111111100101101011111010101111111", "100000100111111000101110101000001", "101110101111011111011111101011101", "101110101010111100110101001011101", "101110100111011110100001101011101", "100000100001110111101101001000001", "111111101010101010101010101111111", "000000000010110011100000100000000", "000110110100011001001000100001100", "000111001111011110001111010110100", "011001111100100101000011011101111", "110110010101101101001111000111100", "101101111011010111011101101111000", "000011011100101000111101110111110", "010101101100010000010000001100100", "100101011101101000000001010100101", "001111100101000100011001011110010", "001110000010100110011010111011011", "110101111111001011000111011111111", "100101001001101100111011101101101", "110010101101100011001000110001011", "101100011000110010010100011110110", "101101110010100011110010101100111", "100011000101101110110010000110100", "111111111100101011111000111110011", "000000001001010011100011100011010", "111111101101011100000111101011000", "100000100111100010110001100011110", "101110101011010110001101111110010", "101110101011111001001100010101110", "101110100101111101010011100011011", "100000100110100100110010011000111", "111111100100101010110001100010100"]};
/* ===== v88(モック v91 ・ PROMPT v98) =====
   1. Trip パス:枠の 中に おさめる ・ 印刷される 動き ・ オリジナルの QR ・ Save = 写真に 保存
   2. Trip チャット(まだ だれも いない):座席表 + 送ると こう 見える + 招待リンク
   3. メンバーの シート:座席表 + 3つの ボタン(シンプル)
   4. キャプション画面:2枚目は タグ ・ 音楽を リセット + 「さっきと 同じ」 */
const P9={cur:null,prev:null};const P9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const P9I={share:'<svg viewBox="0 0 24 24"><path d="M12 3v12M7 8l5-5 5 5"/><path d="M5 13v5a2 2 0 002 2h10a2 2 0 002-2v-5"/></svg>',
  save:'<svg viewBox="0 0 24 24"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>',copy:'<svg viewBox="0 0 24 24"><rect x="8" y="8" width="11" height="11" rx="2.5"/><path d="M5 15V6.5A1.5 1.5 0 016.5 5H15"/></svg>',
  qr:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg>',
  ok:'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',gear:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/></svg>',
  x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',redo:'<svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 1 0 2.4-5.7"/><path d="M4 4v4.5h4.5"/></svg>'};
/* ---- オリジナルの Trip QR(v92 と 同じ 形:点 ・ # の 緑 ・ レンズの 目 ・ まんなかに 表紙)---- */
const P9K=Object.keys(P9M);let p9ki=0;
function p9Qr(key,cover){const M=P9M[String(key||'').replace(/^#/,'')]||P9M.maple24,N=M.length,c=N/2,ic=7.6;let d='',g='';
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){if(M[y][x]!=='1'||q9Fin(x,y,N))continue;if(Math.abs(x+.5-c)<ic/2+.4&&Math.abs(y+.5-c)<ic/2+.4)continue;
    const k=Math.hypot(x+.5-c,y+.5-c)/c;const s=`<circle cx="${x+.5}" cy="${y+.5}" r=".43" style="--k:${k.toFixed(3)}"/>`;q9InHash(x+.5,y+.5,N)?g+=s:d+=s}
  const F=(x,y)=>`<g transform="translate(${x} ${y})"><rect width="7" height="7" rx="1" fill="#0B0C0D"/><rect x="1" y="1" width="5" height="5" rx=".15" fill="#FBFAF6"/><circle cx="3.5" cy="3.5" r="1.62" fill="#0B0C0D"/><circle cx="2.95" cy="2.9" r=".38" fill="#C8F25A"/></g>`,I=c-ic/2,id='p9c'+Math.random().toString(36).slice(2,7);
  return `<svg class="q9q p9q" viewBox="-1 -1 ${N+2} ${N+2}" aria-label="Trip の QR"><defs><clipPath id="${id}"><rect x="${I}" y="${I}" width="${ic}" height="${ic}" rx="${(ic*.224).toFixed(2)}"/></clipPath></defs><g class="dk">${d}</g><g class="gr">${g}</g>${F(0,0)}${F(N-7,0)}${F(0,N-7)}
    <g class="ic"><rect x="${I-.35}" y="${I-.35}" width="${ic+.7}" height="${ic+.7}" rx="${(ic*.26).toFixed(2)}" fill="#C8F25A"/><image href="${PH[cover||'a']}" x="${I}" y="${I}" width="${ic}" height="${ic}" preserveAspectRatio="xMidYMid slice" clip-path="url(#${id})"/></g></svg>`}
/* ---- 1. パス ---- */
function p9Pass(t){const days=tDays(t),mem=[{me:1},...(t.m||[])];
  return `<div class="p9ps" id="p9ps"><div class="p9pt"><i class="cv" style="background-image:url(${PH[t.cover||'a']})"></i><i class="sh"></i>
      <div class="hd"><span>LATTAG</span><span>TRIP PASS ・ No.${String(4000+(t.key||'').length*13).slice(0,4)}</span></div>
      <b class="ti">${rmEsc(t.n||'Trip')}</b><small class="en">${rmEsc(t.en||tEn(t.n||''))}</small>
      <div class="rt"><div><span>FROM</span><b>${tMD(t.from)}</b></div><i>→</i><div><span>TO</span><b>${tMD(t.to)}</b></div><div class="r"><span>DAYS</span><b>${days}</b></div></div>
      <div class="mm"><span class="avs">${mem.slice(0,6).map(f=>f.me?`<i class="me" style="background-image:url(${PH.f})"></i>`:`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span><span>${mem.length} / 8 ・ 1日 23枚</span></div></div>
    <div class="p9pp"><i></i></div>
    <div class="p9pb"><div class="qw">${p9Qr(t.key,t.cover)}</div><div class="ky"><span>KEY</span>${tKeyHtml(t.key)}<small>SCAN TO JOIN<br>あした 9:00 に 現像</small></div><i class="stub"></i></div>
    <i class="p9stamp">ISSUED<b>${tMD(new Date())}</b></i></div>`}
openPass=function(t,fresh){let S=$('tpv');if(!S){S=document.createElement('section');S.className='tpv';S.id='tpv';$('phone').appendChild(S)}
  S.className='tpv p9pv';if(!P9M[String(t.key||'').replace(/^#/,'')])t.key='#'+P9K[p9ki++%P9K.length];
  S.innerHTML=`<i class="tpvs" data-a="x"></i><div class="p9in"><span class="hd2">${fresh?'<i></i>YOUR TRIP IS READY':'TRIP PASS'}</span>
    <div class="p9slot"><i class="lt"></i><span>${fresh?'PRINTING':'LATTAG'}</span></div><div class="p9win">${p9Pass(t)}</div>
    <div class="p9acts"><button data-a="share">${P9I.share}<span>送る</span></button><button data-a="save">${P9I.save}<span>写真に 保存</span></button><button data-a="copy">${P9I.copy}<span>KEY を コピー</span></button></div>
    <button class="p9go" data-a="x">${fresh?'Trip を はじめる':'閉じる'}</button></div><i class="p9flash"></i>`;
  S.classList.add('on');const P=S.querySelector('.p9ps');
  if(!P9RM()){
    if(fresh){P.animate([{transform:'translateY(-102%)'},{transform:'translateY(-70%)',offset:.2},{transform:'translateY(-48%)',offset:.4},{transform:'translateY(-26%)',offset:.6},{transform:'translateY(-8%)',offset:.8},{transform:'translateY(2%)',offset:.92},{transform:'none'}],{duration:1300,easing:'linear',fill:'backwards'});
      [0,220,440,660,880,1060].forEach(ms=>setTimeout(()=>hap('tick',null,{norip:1}),ms));setTimeout(()=>hap('projector','ジジジ(印刷)',{norip:1}),60);}
    else P.animate([{transform:'translateY(40px) scale(.96)',opacity:0},{transform:'none',opacity:1}],{duration:520,easing:'cubic-bezier(.3,1.3,.5,1)'});
    const D=fresh?1250:200;P.querySelectorAll('.p9q circle[style]').forEach(c=>c.animate([{opacity:0,transform:'scale(0)'},{opacity:1,transform:'scale(1)'}],{duration:260,delay:D+parseFloat(c.style.getPropertyValue('--k'))*520,easing:'cubic-bezier(.3,1.6,.5,1)',fill:'backwards'}));
    const st=P.querySelector('.p9stamp');st.animate([{opacity:0,transform:'rotate(-14deg) scale(2.2)'},{opacity:1,transform:'rotate(-14deg) scale(.92)',offset:.7},{opacity:1,transform:'rotate(-14deg) scale(1)'}],{duration:380,delay:D+700,easing:'cubic-bezier(.5,0,.3,1)',fill:'backwards'});
    setTimeout(()=>hap('thud','ドン(ISSUED)',{norip:1}),D+640);
    S.querySelectorAll('.p9acts button,.p9go').forEach((b,i)=>b.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,delay:D+800+i*60,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}))
    if(fresh)setTimeout(()=>{const s=S.querySelector('.p9slot span');if(s)s.textContent='LATTAG';S.querySelector('.p9slot').classList.add('dn');hap('success','トトトン(できた)',{norip:1})},D+900)}
  S.querySelectorAll('[data-a="x"]').forEach(b=>b.onclick=()=>{S.classList.remove('on');hap('soft')});
  S.querySelector('[data-a="share"]').onclick=()=>{hap('pop');openShare({t:`Lattag の Trip「${t.n}」に 乗ろう\nKEY ${t.key}\nhttps://lattag.app/t/${t.key.slice(1)}`,h:t.n})};
  S.querySelector('[data-a="save"]').onclick=e=>{const b=e.currentTarget;hap('shutter','カシャッ(保存)');const f=S.querySelector('.p9flash');f.animate([{opacity:.85},{opacity:0}],{duration:420});
    P.animate([{transform:'none'},{transform:'scale(.95) translateY(8px)',offset:.35},{transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.3,.5,1)'});
    b.classList.add('ok');b.innerHTML=P9I.ok+'<span>保存しました</span>';setTimeout(()=>{try{_toast('パスを 写真に 保存しました')}catch(_){}},300)};
  S.querySelector('[data-a="copy"]').onclick=e=>{const b=e.currentTarget;hap('click');try{navigator.clipboard&&navigator.clipboard.writeText(t.key).catch(()=>{})}catch(_){}b.classList.add('ok');b.innerHTML=P9I.ok+'<span>コピー</span>'}};
window.openPass=openPass;

/* ---- 座席表(8席)---- */
function p9Seats(t,sm){const mem=[{me:1},...(t.m||[])];return `<div class="p9seat${sm?' sm':''}"><div class="nose"><span>FRONT</span></div>${[0,1,2,3,4,5,6,7].map(i=>{const f=mem[i],lab=String.fromCharCode(65+(i%4))+(Math.floor(i/4)+1);
    return `<span class="st${f?' on':''}">${f?(f.me?`<i style="background-image:url(${PH.f})"></i><b>YOU</b>`:`<i style="background:${avBg(f)}">${f.n[0]}</i><b>${f.n}</b>`):`<i>+</i><b>${lab}</b>`}</span>${i%4===1?'<em class="ai"></em>':''}`}).join('')}</div>`}
/* ---- 2. チャット(まだ だれも いない)---- */
{const _r=rmRender;rmRender=function(pop){const g=RM.g;if(!(g.pend||g.m.length<1))return _r(pop);const L=$('rml');$('rmc').style.display='none';const t=g;t.key=t.key||'#maple24';
  L.innerHTML=`<div class="p9ce"><small class="k">BOARDING ・ ${(t.m||[]).length+1} / 8</small><b class="h">なかまを のせよう</b><p>入ると、ここで 話せる ・ 1日 23枚を みんなで</p>
    ${p9Seats(t)}
    <div class="p9pre"><small>送ると、こう 見える</small><div class="p9bb"><div class="p9og"><i style="background-image:url(${PH[t.cover||'a']})"></i><span><em>TRIP PASS</em><b>${rmEsc(t.n)}</b><u>${tMD(t.from)} → ${tMD(t.to)} ・ KEY ${t.key}</u></span></div><div class="p9ft">lattag.app/t/${t.key.slice(1)}</div></div><span class="p9me">ゆい から Trip の 招待 ✈︎</span></div>
    <button class="p9inv" data-a="link">${P9I.share}<span><b>招待リンクを 送る</b><small>LINE ・ メッセージ ・ AirDrop</small></span></button>
    <div class="p9two"><button data-a="qr">${P9I.qr}QR を 見せる</button><button data-a="key">${P9I.copy}${t.key}</button></div>
    <p class="nt">アプリが ない 人も、リンクで パスが 見えて そのまま 入れる</p></div>`;
  const A=(s,f)=>L.querySelectorAll(s).forEach(b=>b.onclick=e=>{const x=e.currentTarget;!P9RM()&&x.animate([{transform:'scale(1)'},{transform:'scale(.94)'},{transform:'scale(1)'}],{duration:260});f(x)});
  A('[data-a="link"]',()=>{hap('pop','ぷにっ(共有)');openShare({t:`Lattag の Trip「${t.n}」に 乗ろう\nhttps://lattag.app/t/${t.key.slice(1)}`,h:t.n})});
  A('[data-a="qr"]',()=>{hap('pop');openPass(t)});
  A('[data-a="key"]',x=>{hap('click');x.innerHTML=P9I.ok+'コピーしました'});
  if(!P9RM())L.querySelectorAll('.p9seat .st').forEach((s,i)=>s.animate([{opacity:0,transform:'translateY(10px) scale(.9)'},{opacity:1,transform:'none'}],{duration:380,delay:120+i*45,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}))}}

/* ---- 3. メンバーの シート ---- */
function p9Members(t){let S=$('p9ms');if(!S){$('phone').insertAdjacentHTML('beforeend','<div class="p9ms" id="p9ms" aria-hidden="true"><i class="sc"></i><div class="pn" role="dialog" aria-label="Trip の メンバー"></div></div>');S=$('p9ms');S.querySelector('.sc').onclick=()=>p9MemClose()}
  const P=S.querySelector('.pn'),n=(t.m||[]).length+1;t.key=t.key||'#maple24';
  P.innerHTML=`<i class="grab"></i><div class="hd"><i class="cv" style="background-image:url(${PH[t.cover||'a']})"></i><span><b>${rmEsc(t.n)}</b><small>DAY ${tDayNo(t)} / ${tDays(t)} ・ ${n} / 8人</small></span><button data-a="set" aria-label="設定">${P9I.gear}</button></div>
    ${p9Seats(t,1)}
    <button class="p9inv" data-a="link">${P9I.share}<span><b>招待リンクを 送る</b><small>あと ${8-n}席</small></span></button>
    <div class="p9two"><button data-a="qr">${P9I.qr}QR を 見せる</button><button data-a="key">${P9I.copy}${t.key}</button></div>
    <p class="nt">${shots?'きのうの Trip の 写真は ひらいて います':'今日 1枚 撮ると、きのうの Trip が ひらく'}</p>`;
  const A=(s,f)=>P.querySelectorAll(s).forEach(b=>b.onclick=e=>f(e.currentTarget));
  A('[data-a="link"]',()=>{hap('pop');openShare({t:`Lattag の Trip「${t.n}」に 乗ろう\nhttps://lattag.app/t/${t.key.slice(1)}`,h:t.n})});
  A('[data-a="qr"]',()=>{hap('pop');p9MemClose();setTimeout(()=>openPass(t),260)});
  A('[data-a="key"]',x=>{hap('click');x.innerHTML=P9I.ok+'コピーしました'});
  A('[data-a="set"]',()=>{p9MemClose();setTimeout(()=>{try{openTrip(t)}catch(_){}},260)});
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('soft','ふわっ(シート)',{norip:1})}
function p9MemClose(){const S=$('p9ms');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true')}
tripSet=function(t){p9Members(t)};

/* ---- 4. キャプション画面:2枚目は リセット + さっきと 同じ ---- */
{const _c=toCam;toCam=function(){if(cur==='tag')P9.cur={tags:tags.slice(),ms:MSEL?{...MSEL}:null};return _c.apply(this,arguments)}}
{const _g=goShoot;goShoot=function(){const had=shots;_g();setTimeout(()=>{if(had>0&&P9.cur)P9.prev=P9.cur;MSEL=null;try{MU8.pick=null;mu8Stop()}catch(e){}try{setMus();mu8Chip()}catch(e){}p9Same()},200)}}
function p9Same(){const old=$('p9same');old&&old.remove();const pv=P9.prev;if(!pv||(!pv.tags.length&&!pv.ms))return;const c=document.querySelector('#tag .mql');if(!c)return;
  const mu=pv.ms&&MUS[pv.ms.s]&&MUS[pv.ms.s][pv.ms.i];
  c.insertAdjacentHTML('beforeend',`<button class="p9same" id="p9same">${P9I.redo}<span>さっきと 同じ</span><em>${pv.tags.slice(0,2).join(' ')}${mu?' ・ ♪ '+mu[0]:''}</em></button>`);
  $('p9same').onclick=e=>{hap('pop','ぷにっ(さっきと 同じ)');tags=pv.tags.slice();MSEL=pv.ms;renderTags();try{setMus();mu8Chip()}catch(_){}e.currentTarget.remove()}}
window.__kit=Object.assign(window.__kit||{},{p9Pass:(fresh)=>{const t=GRP.find(g=>g.trip)||{n:'いつメン旅',en:'Itsumen',cover:'c',from:new Date(),to:new Date(Date.now()+2*864e5),m:[],key:'#meadow95'};t.key=fresh?'#meadow95':t.key;openPass(t,!!fresh)},
  p9Mem:()=>{const t=GRP.find(g=>g.trip);t&&p9Members(t)},p9Room:()=>{const t={n:'いつメン旅',en:'Itsumen',cover:'c',from:new Date(),to:new Date(Date.now()+2*864e5),m:[],key:'#meadow95',trip:false,pend:false,cnt:0,by:[]};openRoom(t)},
  p9Same:(tg)=>{P9.prev={tags:tg||['#放課後','#夕焼け'],ms:{s:'am',i:0}};p9Same()}});
