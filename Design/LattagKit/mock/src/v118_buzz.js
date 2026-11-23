/* ===== v119 モック(PROMPT v133 案):バズの 仕かけ 3画面  印 bz9 =====
   __kit.bz('unlock'|'share'|'invite', {v:'a'|'b'|'c', th:'d'|'n', end:true, open:true}) ・ __kit.bzShoot() ・ __kit.bzTheme('auto'|'d'|'n') ・ __kit.bzClose() */
const BZ9={k:null,th:'auto',v:'a',pick:'d',off:{},tm:[]};
const BZ9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const BZ9Y=[{k:'a',t:'09:12'},{k:'d',t:'13:40'},{k:'f',t:'20:43'}];
const BZ9F=[{n:'ゆい',k:'b'},{n:'れな',k:'c'},{n:'かい',k:'e'},{n:'みお',k:'a'}];
const BZ9I={x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  ok:'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  cam:'<svg viewBox="0 0 24 24"><path d="M4 8.5A1.5 1.5 0 015.5 7h2l1.5-2h6l1.5 2h2A1.5 1.5 0 0120 8.5v9a1.5 1.5 0 01-1.5 1.5h-13A1.5 1.5 0 014 17.5z"/><circle cx="12" cy="13" r="3.4"/></svg>',
  up:'<svg viewBox="0 0 24 24"><path d="M12 15V4M7.5 8.5L12 4l4.5 4.5"/><path d="M5 13v5.5A1.5 1.5 0 006.5 20h11a1.5 1.5 0 001.5-1.5V13"/></svg>',
  dl:'<svg viewBox="0 0 24 24"><path d="M12 4v11M7.5 10.5L12 15l4.5-4.5"/><path d="M5 19h14"/></svg>',
  lk:'<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>',
  qr:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/></svg>',
  sh:'<svg viewBox="0 0 24 24"><path d="M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4 6.7 19.4l1.2-6L3.4 9.3l6-.7z"/></svg>'};
function bz9Th(){if(BZ9.th!=='auto')return BZ9.th;const h=new Date().getHours();return h>=9&&h<21?'d':'n'}
function bz9Root(){let R=$('bz9');if(!R){$('phone').insertAdjacentHTML('beforeend','<div id="bz9"><div class="bz9note" id="bz9nt"></div><div id="bz9pg"></div></div>');R=$('bz9')}return R}
function bz9Clear(){BZ9.tm.forEach(clearTimeout);BZ9.tm=[]}
function bz9At(ms,f){BZ9.tm.push(setTimeout(f,BZ9RM()?0:ms))}
function bz9Note(t){const N=$('bz9nt');if(!N)return;N.textContent='ここで 振動:'+t;N.classList.add('on');clearTimeout(N._t);N._t=setTimeout(()=>N.classList.remove('on'),900)}
function bz9Hap(n,why){try{hap(n,why)}catch(e){}bz9Note(n)}
function bz9Close(){bz9Clear();const R=$('bz9');if(R)R.classList.remove('bz9on');BZ9.k=null}
function bz9Open(k,o){o=o||{};if(o.v)BZ9.v=o.v;if(o.th)BZ9.th=o.th;bz9Clear();const R=bz9Root();BZ9.k=k;
  R.classList.add('bz9on');R.classList.toggle('bz9n',k!=='unlock'&&bz9Th()==='n');
  const P=$('bz9pg');P.innerHTML=k==='unlock'?bz9UHTML(o):k==='share'?bz9SHTML():bz9IHTML();
  ({unlock:bz9UBind,share:bz9SBind,invite:bz9IBind})[k](o)}
const bz9Top=(l,r)=>`<div class="bz9top">${l||'<i></i>'}${r||''}</div>`;
const bz9X=()=>`<button class="bz9x" data-bz="close" aria-label="閉じる"><i>${BZ9I.x}</i></button>`;

/* ---------- 1 9:00 解禁「あかりが つく」 ----------
   きまり:9:00 から 見られる。ただし **きのうの 自分の 写真は、今日の 1枚を 撮ると ひらく**(友だちの 写真は のせて いれば 9:00 から 見える)。
   ひらいた あと、のせる 写真を えらぶ(確認の 手順 ・ 不適切な 写真と プライバシーを 守る)。 */
function bz9UHTML(o){const op=!!(o&&o.open);return `<div class="bz9pg bz9u${op?' open':''}" id="bz9u">
  <div class="bz9dark"><div class="bz9lens" id="bz9lens"><b>#</b></div><div class="bz9clk" id="bz9clk">8:59</div></div>
  <i class="bz9light" id="bz9light"></i><i class="bz9fl" id="bz9fl"></i>
  <div class="bz9day">
    <div class="bz9hd"><div><div class="bz9tt">Good morning</div><div class="bz9sm" id="bz9sub">${op?'きのう の 3枚 ・ のせる 写真を えらぶ':'きのう の 3枚 ・ 今日の 1枚で ひらく'}</div></div>
      <div class="bz9date"><b class="bz9ser">11.22</b><span class="bz9sm">sat</span></div></div>
    <div class="bz9pile" id="bz9pile">${BZ9Y.map((p,i)=>`<div class="bz9ck${BZ9.off[p.k]?' off':''}" data-k="${p.k}" style="--r:${[-7,3,-2][i]}deg;left:${[14,112,196][i]}px;top:${[30,6,52][i]}px;z-index:${i+1}">
      <div class="bz9ph" style="background-image:url(${PH[p.k]})"><i></i></div><small>${p.t}</small>
      <button class="bz9pick" data-bz="pick" aria-label="のせる / のせない"><i>${BZ9I.ok}</i></button></div>`).join('')}
      <div class="bz9lkc" id="bz9lkc">${BZ9I.lk}</div></div>
    <p class="bz9rv" id="bz9rv">${op?'のせない 写真は 外す ・ 外した 写真は 自分 だけ':'まだ 見て いない きのうの 自分'}</p>
    <button class="bz9fr" id="bz9fr" data-bz="friends"><div class="bz9fav">${BZ9F.slice(0,3).map(f=>`<i data-n="${f.n}" style="background-image:url(${PH[f.k]})"></i>`).join('')}</div>
      <div class="bz9ft"><b>みんなの きのう</b><small>${BZ9F.slice(0,3).map(f=>f.n).join(' ・ ')} が のせた</small></div>
      <i class="bz9go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg></i></button>
    <div class="bz9act">${op?`<button class="bz9lime" data-bz="post" id="bz9post">${BZ9I.ok}<span>3枚を のせる</span></button><button class="bz9ghost" data-bz="toshare" aria-label="シェア カード">${BZ9I.up}</button>`
      :`<button class="bz9lime bz9one" data-bz="shoot" id="bz9post">${BZ9I.cam}<span>撮って ひらく</span></button>`}</div>
  </div></div>`}
function bz9UCount(){const n=BZ9Y.filter(p=>!BZ9.off[p.k]).length;const b=$('bz9post');if(b&&b.dataset.bz==='post')b.querySelector('span').textContent=n?`${n}枚を のせる`:'のせない で すすむ'}
/* 今日の 1枚を 撮った → きのうの 3枚が ひらく(モックでは 撮った ことに する) */
function bz9UOpen(){const U=$('bz9u');if(!U||U.classList.contains('open'))return;const F=$('bz9fl');
  bz9Hap('shutter','カシャ(今日の 1枚)');if(F&&!BZ9RM())F.animate([{opacity:.95},{opacity:0}],{duration:420,easing:'ease-out'});
  bz9At(500,()=>{U.classList.add('open');$('bz9sub').textContent='きのう の 3枚 ・ のせる 写真を えらぶ';$('bz9rv').textContent='のせない 写真は 外す ・ 外した 写真は 自分 だけ';
    U.querySelector('.bz9act').innerHTML=`<button class="bz9lime" data-bz="post" id="bz9post">${BZ9I.ok}<span>3枚を のせる</span></button><button class="bz9ghost" data-bz="toshare" aria-label="シェア カード">${BZ9I.up}</button>`;bz9UCount()});
  [...U.querySelectorAll('.bz9ck')].forEach((c,i)=>bz9At(700+i*140,()=>{c.classList.add('dev');bz9Hap('soft','ふわ(現像 '+(i+1)+')')}));
  bz9At(2100,()=>bz9Hap('success','ぽん(ぜんぶ ひらいた)'))}
function bz9UBind(o){const U=$('bz9u'),C=$('bz9clk'),L=$('bz9light');const cks=[...U.querySelectorAll('.bz9ck')];bz9UCount();
  const end=()=>{U.classList.add('lit','fr');if(o.open)cks.forEach(c=>c.classList.add('dev'));C.textContent='9:00';L.style.display='none'};
  if(o.end||o.open||BZ9RM()){end()}
  else{
    cks.forEach(c=>{c.style.opacity=0});
    bz9At(900,()=>{C.textContent='9:00';C.classList.remove('flip');void C.offsetWidth;C.classList.add('flip');bz9Hap('click','カチッ(9:00)')});
    bz9At(1350,()=>{bz9Hap('projector','パッ(あかりが つく)');L.animate([{transform:'scale(0)'},{transform:'scale(24)'}],{duration:650,easing:'cubic-bezier(.6,0,.3,1)',fill:'forwards'})});
    bz9At(1950,()=>{U.classList.add('lit');L.style.display='none'});
    cks.forEach((c,i)=>{bz9At(2150+i*170,()=>{c.style.opacity='';c.animate([{transform:'translateY(-260px) rotate(14deg)',opacity:0},{transform:'translateY(10px)',opacity:1,offset:.7},{transform:'none'}],{duration:620,easing:'cubic-bezier(.3,1.3,.5,1)'});bz9Hap('land','トン(チェキが 落ちる ・ まだ ぼやけた まま)')})});
    bz9At(2900,()=>U.classList.add('fr'))}
  U.onclick=e=>{const b=e.target.closest('[data-bz]');if(!b)return;const a=b.dataset.bz;
    if(a==='pick'){const c=b.closest('.bz9ck');const k=c.dataset.k;BZ9.off[k]=!BZ9.off[k];c.classList.toggle('off',!!BZ9.off[k]);bz9Hap('sel','コツ(えらぶ)');bz9UCount()}
    else if(a==='shoot'){bz9Hap('pop','ぷにっ(撮りに いく)');bz9UOpen()}
    else if(a==='post'){bz9Hap('pop','ぷにっ(のせた)');try{g9Toast('のせました')}catch(e){};setTimeout(()=>bz9Open('share'),350)}
    else if(a==='toshare'){bz9Hap('pop');bz9Open('share')}
    else if(a==='friends'){bz9Hap('pop','ぷにっ(みんなの きのう)');bz9Close();try{g9Open('friends')}catch(e){}}}}

/* ---------- 2 シェア カード ---------- */
function bz9Card(v){const Y=BZ9Y.filter(p=>!BZ9.off[p.k]);const S=Y.length?Y:BZ9Y;
  const wm=`<div class="bz9wm"><i>#</i>Lattag</div>`;
  if(v==='a')return `<div class="bz9card bz9cA" id="bz9card"><div class="bz9strip">${S.map(p=>`<i data-t="${p.t}" style="background-image:url(${PH[p.k]})"></i>`).join('')}<p><b class="bz9ser">11.22</b><small>opened 9:00</small></p></div>${wm}<div class="bz9stp">撮って 見ないで<br>けさ ひらいた</div></div>`;
  if(v==='b')return `<div class="bz9card bz9cB" id="bz9card"><div class="bz9big">Yesterday<small>11.22 ・ ${S.length}枚</small></div>
    ${S.map((p,i)=>`<div class="bz9c" style="--r:${[-8,6,-3][i]}deg;left:${[14,112,48][i]}px;top:${[118,158,262][i]}px"><i style="background-image:url(${PH[p.k]})"></i><small>${p.t}</small></div>`).join('')}
    <div class="bz9stk" style="left:178px;top:96px">9:00<br>OPEN</div>${wm}</div>`;
  const p=S[S.length>1?1:0];const [h,m]=p.t.split(':').map(Number);const mins=(24*60+9*60)-(h*60+m);
  return `<div class="bz9card bz9cC" id="bz9card"><div class="bz9ful" style="background-image:url(${PH[p.k]})"></div><div class="bz9lb">#</div>
    <div class="bz9tl"><div class="bz9ln"><span>shot ${p.t}</span><u></u><span>opened 9:00</span></div><b class="bz9big">${Math.floor(mins/60)}時間 ${mins%60}分</b><small>見ないで 待った 1枚</small></div>${wm}<div class="bz9stp">11.22</div></div>`}
function bz9SHTML(){return `<div class="bz9pg bz9s" id="bz9s">${bz9Top(bz9X(),`<div class="bz9sm" style="align-self:center;margin-bottom:12px">ストーリー ・ 9:16</div><i style="width:44px"></i>`)}
  <div class="bz9stage" id="bz9stage">${bz9Card(BZ9.v)}</div>
  <div class="bz9seg">${[['a','Strip'],['b','Cheki'],['c','19h']].map(([k,l])=>`<button data-bz="v" data-v="${k}" class="${BZ9.v===k?'on':''}">${l}</button>`).join('')}</div>
  <div class="bz9act"><button class="bz9lime" data-bz="send">${BZ9I.up}<span>ストーリーに のせる</span></button><button class="bz9ghost" data-bz="save" aria-label="保存">${BZ9I.dl}</button></div></div>`}
function bz9SBind(){const S=$('bz9s');const c=$('bz9card');if(c&&!BZ9RM())c.classList.add('pop');
  S.onclick=e=>{const b=e.target.closest('[data-bz]');if(!b)return;const a=b.dataset.bz;
    if(a==='close'){bz9Hap('tick');bz9Close()}
    else if(a==='v'){BZ9.v=b.dataset.v;bz9Hap('sel','コツ(案)');$('bz9stage').innerHTML=bz9Card(BZ9.v);S.querySelectorAll('.bz9seg button').forEach(x=>x.classList.toggle('on',x.dataset.v===BZ9.v));const c=$('bz9card');if(c&&!BZ9RM())c.classList.add('pop')}
    else if(a==='send'){bz9Hap('pop','ぷにっ(共有)');try{__api.openShare()}catch(e){try{g9Toast('共有シート(モック)')}catch(_){}}}
    else if(a==='save'){bz9Hap('success','ぽん(保存)');try{g9Toast('写真に 保存しました(モック)')}catch(e){}}}}

/* ---------- 3 チラ見せ 招待 ---------- */
const BZ9OP=[{k:'d',t:'11.22'},{k:'a',t:'11.22'},{k:'f',t:'11.21'},{k:'e',t:'11.20'}];
function bz9IHTML(){const p=BZ9OP.find(x=>x.k===BZ9.pick)||BZ9OP[0];return `<div class="bz9pg bz9i" id="bz9i">${bz9Top(bz9X())}
  <div class="bz9ih"><div class="bz9tt">Invite</div><div class="bz9sm">見せる 1枚を えらぶ ・ ぼかした まま 届く</div></div>
  <div class="bz9pk">${BZ9OP.map(x=>`<button data-bz="pk" data-k="${x.k}" class="${x.k===p.k?'on':''}" style="background-image:url(${PH[x.k]})" aria-label="${x.t} の 写真"><small>${x.t}</small></button>`).join('')}</div>
  <div class="bz9chat"><small>届くと こう 見える</small>
    <div class="bz9bub"><div class="bz9og"><i style="background-image:url(${PH[p.k]})"></i><div class="bz9lk">${BZ9I.lk}</div><div class="bz9ot">Lattag で ひらく</div><div class="bz9fx"></div></div>
      <div class="bz9bt"><b class="bz9ser">たつき の きのう</b><small>あなたも 撮ると、あしたの 9:00 に いっしょに ひらく</small></div></div>
    <span class="bz9me">たつき</span></div>
  <div class="bz9safe">${BZ9I.lk}<span>ひらいた 写真 だけ ・ ぼかして 送る ・ 相手が つながる まで 中身は 見えない</span></div>
  <div class="bz9act"><button class="bz9lime" data-bz="send">${BZ9I.up}<span>リンクを 送る</span></button><button class="bz9ghost" data-bz="qr">${BZ9I.qr}<span>QR</span></button></div></div>`}
function bz9IBind(){const I=$('bz9i');I.onclick=e=>{const b=e.target.closest('[data-bz]');if(!b)return;const a=b.dataset.bz;
  if(a==='close'){bz9Hap('tick');bz9Close()}
  else if(a==='pk'){BZ9.pick=b.dataset.k;bz9Hap('sel','コツ(えらぶ)');bz9Open('invite')}
  else if(a==='send'){bz9Hap('pop','ぷにっ(送る)');try{__api.openShare()}catch(e){}}
  else if(a==='qr'){bz9Hap('pop');try{clickQR()}catch(e){try{g9Toast('自分の QR(モック)')}catch(_){}}}}}

/* ---------- デモ ---------- */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-bz9]'))return;
  C.insertAdjacentHTML('beforeend',['unlock:★ v119 バズ:9:00 解禁(はじめから)','uend:★ v119 バズ:解禁(9:00 すぎ ・ まだ 撮って いない)','uopen:★ v119 バズ:解禁(今日の 1枚を 撮った あと)','share:★ v119 バズ:シェア カード','invite:★ v119 バズ:チラ見せ 招待','d:★ v119 昼(白)','n:★ v119 夜(黒)','auto:★ v119 昼夜 = 時刻'].map(s=>{const i=s.indexOf(':');return `<button data-bz9="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-bz9]').forEach(b=>b.onclick=()=>{const k=b.dataset.bz9;
    if(['d','n','auto'].includes(k)){BZ9.th=k;if(BZ9.k&&BZ9.k!=='unlock')bz9Open(BZ9.k);return}
    if(k==='uend')bz9Open('unlock',{end:1});else if(k==='uopen')bz9Open('unlock',{open:1});else bz9Open(k)})})();
window.__kit=Object.assign(window.__kit||{},{bz:(k,o)=>bz9Open(k,o),bzTheme:t=>{BZ9.th=t;if(BZ9.k&&BZ9.k!=='unlock')bz9Open(BZ9.k)},bzClose:()=>bz9Close(),bzShoot:()=>bz9UOpen(),BZ9:()=>({k:BZ9.k,v:BZ9.v,th:bz9Th(),off:{...BZ9.off}})});
