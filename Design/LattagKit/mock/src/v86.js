/* ===== v86(モック v89 ・ PROMPT v94) =====
   A. 撮影ボタン = Lattag の アイコン(長押しで ライムが 下から たまり、アイコンが 完成すると 撮れる)
   B. ID(@ユーザー名):はじめての 設定で きめる ・ あとで かえる シート ・ ルール と 空き確認
   C. Friends(さがす 画面):名前 か @ID で さがす ・ 自分の ID ・ おすすめ ・ 申請 ・ 友だち
   D. QR を 読む = Lattag の カメラ(レンズの 角 ・ # の ガイド ・ 見つけたら プロフィールの カード)
   E. Friends タブ(はじめての 日):自分の 3こま ・ 9:00 の 流れ ・ 友だちの 投稿の 見本 ・ 友だちを よぶ */
const K9={id:'yui_0612',idAt:0,disc:true,q:'',dis:new Set(),lv:0,raf:0,was:0,st:'ok'};
const K9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const K9I={
  mag:'<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg>',
  x:'<svg viewBox="0 0 24 24"><path d="M7 7l10 10M17 7L7 17"/></svg>',
  copy:'<svg viewBox="0 0 24 24"><rect x="8" y="8" width="11" height="11" rx="2.5"/><path d="M5 15V6.5A1.5 1.5 0 016.5 5H15"/></svg>',
  pen:'<svg viewBox="0 0 24 24"><path d="M5 19l1-4L15.5 5.5a2 2 0 013 3L9 18z"/></svg>',
  ok:'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  plus:'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
  book:'<svg viewBox="0 0 24 24"><path d="M6 4h11a1 1 0 011 1v15H7a2 2 0 01-2-2V5a1 1 0 011-1z"/><circle cx="11.5" cy="10" r="2.4"/><path d="M8 15.5c.7-1.6 2-2.3 3.5-2.3s2.8.7 3.5 2.3"/></svg>',
  chat:'<svg viewBox="0 0 24 24"><path d="M4 12a8 7 0 1 1 3.6 5.8L4 19.5l1.3-3.6A6.8 6.8 0 0 1 4 12z"/></svg>',
  torch:'<svg viewBox="0 0 24 24"><path d="M8 3h8v4l-2 3v10h-4V10L8 7z"/><path d="M12 13v2"/></svg>',
  img:'<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2.5"/><circle cx="9.5" cy="10" r="1.6"/><path d="M5 17l4.5-4 3 2.5 3-3L19 16"/></svg>',
  heart:'<svg viewBox="0 0 24 24"><path d="M12 19s-7-4.4-7-9.2A3.9 3.9 0 0112 7.6a3.9 3.9 0 017 2.2C19 14.6 12 19 12 19z"/></svg>',
  pin:'<svg viewBox="0 0 24 24"><path d="M12 21s6-6.2 6-11a6 6 0 00-12 0c0 4.8 6 11 6 11z"/><circle cx="12" cy="10" r="2.2"/></svg>',
  lock:'<svg viewBox="0 0 24 24"><rect x="6" y="10.5" width="12" height="9" rx="2"/><path d="M8.5 10.5V8a3.5 3.5 0 017 0v2.5"/></svg>',
  note:'<svg viewBox="0 0 24 24"><path d="M9 17V6l10-2v11"/><circle cx="7" cy="17" r="2.2"/><circle cx="17" cy="15" r="2.2"/></svg>'};
const k9Kana=s=>String(s||'').trim().replace(/[\u30A1-\u30F6]/g,c=>String.fromCharCode(c.charCodeAt(0)-0x60));
const k9F=()=>FPOOL.map((f,i)=>({f,i,id:FID(f).slice(1)}));
const k9Esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const k9Bump=e=>{if(!e||K9RM())return;e.animate([{transform:'scale(1)'},{transform:'scale(.9)'},{transform:'scale(1.05)'},{transform:'scale(1)'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'})};

/* ================= A. 撮影ボタン = Lattag の アイコン ================= */
function k9IconSvg(){const B=(p)=>`<rect x="19" y="31" width="62" height="10" rx="5"${p}/><rect x="19" y="59" width="62" height="10" rx="5"${p}/><rect x="31" y="19" width="10" height="62" rx="5"${p}/><rect x="59" y="19" width="10" height="62" rx="5"${p}/>`;
  return `<svg class="k9sv" viewBox="0 0 100 100" aria-hidden="true"><defs><clipPath id="k9cp"><rect width="100" height="100" rx="22.4"/></clipPath><clipPath id="k9fc"><path id="k9wv" d="M-10 110H110V110H-10Z"/></clipPath>
    <linearGradient id="k9lg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#DDFB7E"/><stop offset="1" stop-color="#B9E44C"/></linearGradient></defs>
    <g clip-path="url(#k9cp)"><rect width="100" height="100" fill="#151517"/>
      <g class="k9ol" fill="none" stroke="#C8F25A" stroke-width="1.5">${B('')}<circle cx="50" cy="50" r="15"/></g>
      <g clip-path="url(#k9fc)"><rect width="100" height="100" fill="url(#k9lg)"/><g fill="#0B0C0D">${B('')}</g><circle cx="50" cy="50" r="15" fill="#C8F25A" stroke="#0B0C0D" stroke-width="3.5"/><circle cx="50" cy="50" r="10" fill="#10141c"/><circle cx="47" cy="46" r="3" fill="#fff"/></g>
      </g>
    <rect width="100" height="100" rx="22.4" fill="none" stroke="rgba(255,255,255,.16)" stroke-width="1.2"/>
    <rect class="k9tr" x="-5" y="-5" width="110" height="110" rx="27" fill="none" stroke="rgba(200,242,90,.18)" stroke-width="2.2"/>
    <rect class="k9pr" x="-5" y="-5" width="110" height="110" rx="27" fill="none" stroke="#C8F25A" stroke-width="2.6" stroke-linecap="round" pathLength="100" stroke-dasharray="100" stroke-dashoffset="100"/></svg>
    <i class="k9fl"></i>`}
function k9Wave(lv,ph){const L=100-lv*100,A=lv>0&&lv<1?2.6:0;let d=`M-10 ${L.toFixed(2)}`;for(let x=-10;x<=110;x+=5){const y=L+A*Math.sin(x/100*Math.PI*3+ph);d+=`L${x} ${y.toFixed(2)}`}return d+'L110 110L-10 110Z'}
function k9Sh(){const S=$('sh');if(!S||S.querySelector('.k9ic'))return;S.insertAdjacentHTML('beforeend',`<div class="k9ic" id="k9ic">${k9IconSvg()}</div>`);S.classList.add('k9');
  new MutationObserver(()=>{if(S.classList.contains('hold')){K9.was=1;k9Loop()}else if(K9.was){K9.was=0;if(K9.lv>.8)k9Snap();k9Loop()}}).observe(S,{attributes:true,attributeFilter:['class']})}
function k9Loop(){if(K9.raf)return;const S=$('sh'),P=$('prog'),W=$('k9wv'),PR=document.querySelector('.k9pr');let ph=0;
  const f=()=>{K9.raf=0;if(!S||!P||!W)return;const hold=S.classList.contains('hold'),k=hold?Math.max(0,Math.min(1,1-parseFloat(P.style.strokeDashoffset||307.9)/307.9)):0;
    if(hold)K9.lv=k;else K9.lv+=(0-K9.lv)*.16;if(K9.lv<.004)K9.lv=0;ph+=.18;
    W.setAttribute('d',k9Wave(K9.lv,ph));PR&&PR.setAttribute('stroke-dashoffset',(100-K9.lv*100).toFixed(2));
    const I=$('k9ic');if(I){I.style.setProperty('--k',K9.lv.toFixed(3));I.classList.toggle('on',hold)}
    if(hold&&!$('cam').classList.contains('mv')){const q=Math.min(4,Math.floor(K9.lv*4+.001));$('hint').innerHTML=`<span class="k9hb">${[0,1,2,3].map(i=>`<i class="${i<q?'on':''}"></i>`).join('')}</span>${K9.lv>.97?'いま!':'はなさないで'}`}
    if(hold){const q=Math.floor(K9.lv*4+.001);if(q>K9.qq){K9.qq=q;if(q<4)hap('click',`カチッ(${q} / 4)`,{norip:1})}}else K9.qq=0;
    if(hold||K9.lv>0)K9.raf=requestAnimationFrame(f)};K9.raf=requestAnimationFrame(f)}
function k9Snap(){const I=$('k9ic');if(!I)return;K9.lv=1;$('k9wv')&&$('k9wv').setAttribute('d',k9Wave(1,0));
  if(!K9RM()){I.animate([{transform:'scale(1)'},{transform:'scale(.86)',offset:.25},{transform:'scale(1.08)',offset:.7},{transform:'scale(1)'}],{duration:420,easing:'cubic-bezier(.3,1.3,.5,1)'});
    I.querySelector('.k9fl').animate([{opacity:.9},{opacity:0}],{duration:460,easing:'ease-out'})}
  setTimeout(()=>{K9.lv=.999;k9Loop()},700)}
{const _r=renderCam;renderCam=function(){_r();try{k9Sh()}catch(e){console.error(e)}}}
try{k9Sh()}catch(e){}

/* ================= B. ID ================= */
const K9RES=['lattag','admin','support','official','help','team','null','root','staff','api','www'];
const K9TAKEN=new Set([...FPOOL.map(f=>FID(f).slice(1)),'yui','yui_06','yuina','hana','sora','rena','yui.film']);
const K9KANA={'あ':'a','い':'i','う':'u','え':'e','お':'o','か':'ka','き':'ki','く':'ku','け':'ke','こ':'ko','さ':'sa','し':'shi','す':'su','せ':'se','そ':'so','た':'ta','ち':'chi','つ':'tsu','て':'te','と':'to','な':'na','に':'ni','ぬ':'nu','ね':'ne','の':'no','は':'ha','ひ':'hi','ふ':'fu','へ':'he','ほ':'ho','ま':'ma','み':'mi','む':'mu','め':'me','も':'mo','や':'ya','ゆ':'yu','よ':'yo','ら':'ra','り':'ri','る':'ru','れ':'re','ろ':'ro','わ':'wa','を':'wo','ん':'n','が':'ga','ぎ':'gi','ぐ':'gu','げ':'ge','ご':'go','ざ':'za','じ':'ji','ず':'zu','ぜ':'ze','ぞ':'zo','だ':'da','で':'de','ど':'do','ば':'ba','び':'bi','ぶ':'bu','べ':'be','ぼ':'bo','ぱ':'pa','ぴ':'pi','ぷ':'pu','ぺ':'pe','ぽ':'po'};
function k9Norm(v){return String(v||'').replace(/[Ａ-Ｚａ-ｚ０-９＿．]/g,c=>String.fromCharCode(c.charCodeAt(0)-0xFEE0)).replace(/^[@＠]+/,'').replace(/\s+/g,'').toLowerCase()}
function k9Chk(v,me){v=k9Norm(v);
  if(!v)return{s:'e',m:'3〜20文字 ・ 英小文字 ・ 数字 ・ _ と .'};
  if(!/^[a-z0-9._]+$/.test(v))return{s:'x',m:'つかえるのは 英小文字 ・ 数字 ・ _ と . だけ'};
  if(v.length<3)return{s:'x',m:'3文字 以上'};if(v.length>20)return{s:'x',m:'20文字 まで'};
  if(/^\.|\.$|\.\./.test(v))return{s:'x',m:'. は 先頭 ・ さいご ・ 2つ つづけて は ×'};
  if(/^\d+$/.test(v))return{s:'x',m:'数字 だけ は ×'};
  if(K9RES.some(r=>v===r||v.startsWith(r+'_')))return{s:'x',m:'この ID は つかえません'};
  if(K9TAKEN.has(v)&&v!==me)return{s:'t',m:'もう つかわれて います'};
  return{s:'ok',m:'つかえます'}}
function k9Roma(n){let r='';for(const c of String(n||''))r+=K9KANA[c]||(/[a-z0-9]/i.test(c)?c.toLowerCase():'');return r}
function k9Sug(base){base=k9Norm(base).replace(/[^a-z0-9._]/g,'').slice(0,14)||'lattag.me';const d=new Date(),c=[base+'_'+String(d.getMonth()+1).padStart(2,'0')+String(d.getDate()).padStart(2,'0'),base+'.film',base+String(d.getFullYear()).slice(2),base+'_tag',base+'.'+(100+base.length*37%900)];
  return c.filter(x=>k9Chk(x).s==='ok').slice(0,3)}
/* ID の 入力欄(はじめての 設定 ・ ID シート で 共通)*/
function k9IdField(id,val,me){return `<div class="k9id" data-st="e"><label class="k9idf"><span class="at">@</span><input id="${id}" value="${k9Esc(val||'')}" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false" inputmode="email" maxlength="24" placeholder="your_id" aria-label="ID"><i class="k9st" aria-hidden="true"></i></label><p class="k9msg" aria-live="polite"></p><div class="k9sg"></div></div>`}
function k9IdBind(inp,me,on){const W=inp.closest('.k9id'),M=W.querySelector('.k9msg'),G=W.querySelector('.k9sg');let t=0;
  const run=(quick)=>{const v=k9Norm(inp.value);if(inp.value!==v){const p=inp.selectionStart;inp.value=v;try{inp.setSelectionRange(p,p)}catch(e){}}
    clearTimeout(t);const r0=k9Chk(v,me);if(r0.s==='e'||r0.s==='x'){W.dataset.st=r0.s;M.textContent=r0.m;G.innerHTML='';on&&on(r0.s,v);return}
    W.dataset.st='w';M.textContent='たしかめて います…';on&&on('w',v);
    t=setTimeout(()=>{const r=k9Chk(inp.value,me);W.dataset.st=r.s;M.textContent=r.s==='ok'?(v===me?'いまの ID':'@'+v+' は つかえます'):r.m;
      if(r.s==='ok'&&v!==me)hap('tick','コツッ(つかえる)',{norip:1});if(r.s==='t'){hap('warn','やわらかく2回(つかわれて いる)');G.innerHTML=k9Sug(v.replace(/[._]?\d+$/,'')).map(s=>`<button type="button" data-v="${s}">@${s}</button>`).join('');
        G.querySelectorAll('button').forEach(b=>b.onclick=()=>{inp.value=b.dataset.v;hap('sel','コツッ(えらぶ)');run(true)})}else G.innerHTML='';on&&on(r.s,v)},quick?120:380)};
  inp.addEventListener('input',()=>run());run(true);return run}

/* はじめての 設定:Name の つぎに「ID」の 1ページ(name → id → tag)*/
OBMK.id=.8;OBPG.id=1;
{const _t=obTpl;obTpl=function(st){if(st!=='id')return _t(st);
  if(!OB.id)OB.id=k9Sug(k9Roma(OB.name)||'you')[0]||'';
  return[`<h2 class="obh obnmh k9obh">ID<small>友だちが さがす ときに つかう ・ あとで かえられる</small></h2>${k9IdField('k9obid',OB.id,'')}`,`<button class="ob1" id="obnx" disabled>つぎへ</button>`]}}
{const _b=obBind;obBind=function(){_b();const nx=$('obnx');
  if(OB.st==='name'&&nx){nx.onclick=()=>{if(nx.disabled)return;hap('click','カチッ(つぎへ)');if(!OB.idT)OB.id='';obStep('id')}}
  if(OB.st!=='id')return;const i=$('k9obid');if(!i||!nx)return;let ok=false;
  k9IdBind(i,'',(s,v)=>{ok=s==='ok';OB.id=v;nx.disabled=!ok});i.addEventListener('input',()=>{OB.idT=1});
  i.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();nx.click()}});
  nx.onclick=()=>{if(nx.disabled||!ok)return;K9.id=OB.id;K9TAKEN.add(OB.id);hap('click','カチッ(つぎへ)');obStep('tag')};
  setTimeout(()=>{if(OB.on&&OB.st==='id')i.focus({preventScroll:true})},420)}}
$('obk').onclick=()=>{const b={tag:'id',id:'name',fr:'tag',nt:'fr',mail:'in',sent:'mail'}[OB.st];if(!b)return;hap('tick','ごく軽く1回(もどる)');obStep(b,-1)};
{const _f=fMe;fMe=function(){const r=_f();r.id='@'+K9.id;return r}}

/* ID を かえる シート */
function k9IdOpen(){let S=$('k9is');if(!S){$('phone').insertAdjacentHTML('beforeend','<div class="k9is" id="k9is" aria-hidden="true"><i class="k9isc"></i><div class="k9isp" role="dialog" aria-label="ID を かえる"></div></div>');S=$('k9is');S.querySelector('.k9isc').onclick=()=>k9IdClose()}
  const P=S.querySelector('.k9isp'),left=K9.idAt?Math.max(0,14-Math.floor((Date.now()-K9.idAt)/864e5)):0;
  P.innerHTML=`<i class="grab"></i><div class="k9ish"><b>ID</b><button class="k9isx" aria-label="とじる">${K9I.x}</button></div>
    <p class="k9isnow">いま <b>@${K9.id}</b></p>${k9IdField('k9isin',K9.id,K9.id)}
    <ul class="k9rl"><li>3〜20文字 ・ 英小文字 ・ 数字 ・ <code>_</code> <code>.</code></li><li>かえられるのは <b>14日に 1回</b>${left?`(あと ${left}日)`:''}</li><li>前の ID は 14日間 だれも とれない ・ 古い QR と リンクも 新しい ID へ</li></ul>
    <button class="k9sv2" id="k9issv" disabled>保存</button>`;
  const sv=$('k9issv');k9IdBind($('k9isin'),K9.id,(s,v)=>{sv.disabled=!(s==='ok'&&v!==K9.id)||left>0;sv.textContent=left>0?`あと ${left}日で かえられます`:'保存'});
  P.querySelector('.k9isx').onclick=()=>k9IdClose();
  sv.onclick=()=>{const v=k9Norm($('k9isin').value);if(sv.disabled)return;K9TAKEN.delete(K9.id);K9.id=v;K9TAKEN.add(v);K9.idAt=Date.now();hap('success','トトトン(ID を かえた)');k9IdClose();try{_toast('ID を @'+v+' に しました')}catch(e){}try{renderFriends()}catch(e){}};
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('soft','ふわっ(シート)',{norip:1});setTimeout(()=>{const i=$('k9isin');i&&i.focus({preventScroll:true})},380)}
function k9IdClose(){const S=$('k9is');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true')}

/* ================= C. Friends = さがす 画面 ================= */
function k9St(o){return FR.includes(o.f)?'fr':SENT['@'+o.id]?'sent':REQ.some(r=>r.f===o.f)?'in':'none'}
function k9Btn(o){const s=k9St(o);return `<button class="k9ad ${s}" data-a="add" data-f="${o.i}">${s==='fr'?K9I.chat+'<span>チャット</span>':s==='sent'?'<span>申請中</span>':s==='in'?'<span>承認</span>':K9I.plus+'<span>追加</span>'}</button>`}
function k9Mut(o){const n=(o.f.n.charCodeAt(0)+o.i)%4;return FR.length?Math.min(FR.length,n+1):0}
function k9Why(o){const m=k9Mut(o);if(m)return `<em class="k9why"><span class="k9mav">${FR.slice(0,Math.min(3,m)).map(f=>`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span>共通の 友だち ${m}人</em>`;
  return `<em class="k9why">${['連絡先に います','あなたの リンクを ひらいた','連絡先に います'][o.i%3]}</em>`}
function k9Av(f,big){return `<span class="k9av${big?' big':''}${f.k>0&&FR.includes(f)?' k':''}" style="background:${avBg(f)}">${f.n[0]}</span>`}
function k9Mark(s,q){if(!q)return k9Esc(s);const i=s.toLowerCase().indexOf(q.toLowerCase());if(i<0)return k9Esc(s);return k9Esc(s.slice(0,i))+'<mark>'+k9Esc(s.slice(i,i+q.length))+'</mark>'+k9Esc(s.slice(i+q.length))}
function k9Row(o,q,why){return `<div class="k9rw" data-f="${o.i}">${k9Av(o.f)}<span class="k9tx"><b>${k9Mark(o.f.n,q&&!/^[@a-z0-9._]+$/i.test(q)?q:'')}</b><small>@${k9Mark(o.id,q&&/^[@a-z0-9._]+$/i.test(q)?k9Norm(q):'')}</small>${why?k9Why(o):''}</span>${k9Btn(o)}${why&&k9St(o)==='none'?`<button class="k9dx" data-a="dx" data-f="${o.i}" aria-label="おすすめから はずす">${K9I.x}</button>`:''}</div>`}
function k9Sugs(){return k9F().filter(o=>!FR.includes(o.f)&&!REQ.some(r=>r.f===o.f)&&!K9.dis.has(o.i)).slice(0,5)}
function k9Hub(){const m=fMe(),av=(()=>{try{return avUrl()}catch(e){return 'none'}})(),S=k9Sugs(),V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0).length;
  const me=`<section class="k9me"><span class="k9mph" style="background-image:${av};background-color:${(m.c&&m.c[0])||'#C8F25A'}">${av==='none'?k9Esc(m.n[0]):''}</span>
      <span class="k9mtx"><small>あなたの ID</small><b>@${K9.id}</b><em>${k9Esc(m.n)}</em></span>
      <button class="k9ic2" data-a="copy" aria-label="ID を コピー">${K9I.copy}</button><button class="k9ic2" data-a="edit" aria-label="ID を かえる">${K9I.pen}</button>
      <button class="k9qr" data-a="myqr" aria-label="自分の QR">${tQR('@'+K9.id,30)}<span>QR</span></button></section>`;
  const tl=`<div class="k9tl"><button data-a="scan"><i>${X8I.scan}</i><b>QR を 読む</b><small>会って すぐ</small></button><button data-a="link"><i>${X8I.link}</i><b>リンク</b><small>LINE などで</small></button><button data-a="con"><i>${K9I.book}</i><b>連絡先</b><small>知り合い</small></button></div>`;
  const rq=REQ.length?`<div class="k9h"><b>申請</b><span class="k9n">${REQ.length}</span></div>${REQ.map((r,i)=>`<div class="k9rw k9rq" data-r="${i}">${k9Av(r.f)}<span class="k9tx"><b>${r.f.n}</b><small>${FID(r.f)} ・ ${r.at}</small></span><button class="k9ad in" data-a="ok"><span>承認</span></button><button class="k9dx" data-a="later" aria-label="あとで">${K9I.x}</button></div>`).join('')}`:'';
  const sg=S.length?`<div class="k9h"><b>おすすめ</b><small>知り合い かも</small></div>${S.map(o=>k9Row(o,'',1)).join('')}`:'';
  const ls=FR.length?`<div class="k9h"><b>友だち</b>${took?`<span class="k9lv"><i></i>きょう ${took}人 撮った</span>`:''}</div>${V.map(f=>{const o={f,i:FPOOL.indexOf(f),id:FID(f).slice(1)};return `<div class="k9rw k9fr" data-f="${o.i}">${k9Av(f)}<span class="k9tx"><b>${f.n}</b><small>@${o.id}</small></span><span class="k9k">${[0,1,2].map(j=>`<i class="${j<f.k?'on':''}"></i>`).join('')}</span><button class="k9ch" data-a="chat" aria-label="チャット">${K9I.chat}</button></div>`}).join('')}`:'';
  return `<div class="k9sr"><label class="k9q">${K9I.mag}<input id="k9in" placeholder="名前 か @ID で さがす" value="${k9Esc(K9.q)}" autocomplete="off" autocapitalize="off" spellcheck="false" enterkeyhint="search" aria-label="名前 か ID で さがす"><button class="k9cl" data-a="clr" aria-label="けす"${K9.q?'':' hidden'}>${K9I.x}</button></label></div>
    <div class="k9res" id="k9res"${K9.q?'':' hidden'}></div>
    <div class="k9main" id="k9main"${K9.q?' hidden':''}>${me}${tl}${rq}${sg}${ls}<p class="k9nt">友だちの 数は どこにも 出ません ・ 名前で 見つかるのは「名前で 見つかる」が オンの 人だけ</p></div>`}
function k9Res(){const R=$('k9res'),M=$('k9main');if(!R)return;const raw=K9.q.trim(),q=k9Norm(raw),idq=/^[@＠]?[a-z0-9._]+$/i.test(raw);
  R.hidden=!raw;M.hidden=!!raw;const cl=document.querySelector('.k9cl');cl&&(cl.hidden=!raw);if(!raw){R.innerHTML='';return}
  const P=k9F(),ex=idq?P.find(o=>o.id===q):null,idh=idq&&q.length>=2?P.filter(o=>o!==ex&&o.id.startsWith(q)).slice(0,6):[],kq=k9Kana(raw),nm=P.filter(o=>k9Kana(o.f.n).startsWith(kq)&&o!==ex).slice(0,8);
  let h='';
  if(ex)h+=`<div class="k9h"><b>ID が ぴったり</b></div><div class="k9ex" data-f="${ex.i}"><span class="k9exp" style="background:${avBg(ex.f)}">${ex.f.n[0]}</span><span class="k9tx"><b>${ex.f.n}</b><small>@${k9Mark(ex.id,q)}</small>${k9Why(ex)}</span>${k9Btn(ex)}</div>`;
  if(idh.length)h+=`<div class="k9h"><b>ID</b><small>@${k9Esc(q)} で はじまる</small></div>${idh.map(o=>k9Row(o,raw)).join('')}`;
  if(nm.length)h+=`<div class="k9h"><b>名前</b><small>共通の 友だち が 多い 順</small></div>${nm.sort((a,b)=>k9Mut(b)-k9Mut(a)).map(o=>k9Row(o,raw,1)).join('')}`;
  if(!h)h=`<div class="k9no"><b>見つかりません</b><small>${idq?'ID は 1文字 ちがうと 出ません':'名前で 見つかるのは「名前で 見つかる」が オンの 人だけ'}</small><button data-a="link">${X8I.link}リンクを 送る</button></div>`;
  else h+=`<p class="k9nt">${idq?'@ID の 一部 でも さがせます':'名前の 先頭 から(ひらがな ⇄ カタカナ は 同じ)'}</p>`;
  R.innerHTML=h;k9BindRows(R);
  if(!K9RM())[...R.children].slice(0,8).forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:260,delay:i*28,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'}))}
function k9Add(o,b){const s=k9St(o);
  if(s==='fr'){hap('pop','ぷにっ(チャット)');try{openDM(o.f)}catch(e){}return}
  if(s==='in'){const i=REQ.findIndex(r=>r.f===o.f);hap('click','カチッ(承認)');try{reqAccept(i)}catch(e){}return}
  if(s==='sent'){hap('warn','やわらかく2回(もう 申請した)');return}
  SENT['@'+o.id]=1;hap('pop','ぷにっ(申請した)');if(b){b.className='k9ad sent';b.innerHTML='<span>申請中</span>';k9Bump(b)}
  setTimeout(()=>{if(FR.includes(o.f))return;FR.unshift(o.f);delete SENT['@'+o.id];hap('success','トトトン(承認された)',{norip:1});try{renderFriends(0)}catch(e){}
    try{toastA(o.f.n+' が 承認しました','チャット',()=>{try{openDM(o.f)}catch(e){}})}catch(e){try{_toast(o.f.n+' が 承認しました')}catch(_){}}},3200)}
function k9BindRows(B){B.querySelectorAll('[data-a="add"]').forEach(b=>b.onclick=e=>{e.stopPropagation();const o=k9F()[+b.dataset.f];k9Add(o,b)});
  B.querySelectorAll('[data-a="dx"]').forEach(b=>b.onclick=e=>{e.stopPropagation();const r=b.closest('.k9rw');K9.dis.add(+b.dataset.f);hap('soft','やわらかく1回(はずす)',{norip:1});
    r.animate([{opacity:1,transform:'none'},{opacity:0,transform:'translateX(-30px)'}],{duration:220,fill:'forwards'}).onfinish=()=>{try{renderFriends()}catch(e){}}});
  B.querySelectorAll('[data-a="link"]').forEach(b=>b.onclick=()=>k9Link())}
function k9Link(){hap('pop','ぷにっ(リンク)');try{const m=fMe();openShare({t:`Lattag で つながろう ・ ${m.n}(@${K9.id})\nhttps://lattag.app/u/${K9.id}`,h:m.n})}catch(e){}}
function k9HubBind(B){const I=$('k9in');k9BindRows(B);
  if(I){I.oninput=()=>{K9.q=I.value;k9Res()};I.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();I.blur();hap('sel','コツッ(さがす)',{norip:1})}});
    I.addEventListener('focus',()=>B.classList.add('k9foc'));I.addEventListener('blur',()=>setTimeout(()=>B.classList.remove('k9foc'),120))}
  const A=(s,fn)=>B.querySelectorAll(s).forEach(b=>b.addEventListener('click',e=>{k9Bump(b);fn(b,e)}));
  A('[data-a="clr"]',()=>{K9.q='';I.value='';k9Res();I.focus();hap('tick',null,{norip:1})});
  A('[data-a="copy"]',b=>{hap('success','トトトン(コピー)',{norip:1});try{navigator.clipboard&&navigator.clipboard.writeText('@'+K9.id).catch(()=>{})}catch(e){}try{_toast('@'+K9.id+' を コピーしました')}catch(e){}});
  A('[data-a="edit"]',()=>k9IdOpen());
  A('[data-a="myqr"]',()=>{hap('pop','ぷにっ(QR)');try{q9Open()}catch(e){}});
  A('.k9tl [data-a="scan"]',()=>{try{openScan('fr')}catch(e){}});
  A('.k9tl [data-a="con"]',()=>{hap('click','カチッ(連絡先)');try{_toast('(モック)連絡先から さがしました ・ おすすめに 出ます')}catch(e){}});
  B.querySelectorAll('.k9rq').forEach(r=>{const i=+r.dataset.r;r.querySelector('[data-a="ok"]').onclick=e=>{e.stopPropagation();hap('click','カチッ(承認)',{norip:1});r.animate([{opacity:1},{opacity:0,transform:'translateX(40px)'}],{duration:260,fill:'forwards'});setTimeout(()=>reqAccept(i),240)};
    r.querySelector('[data-a="later"]').onclick=e=>{e.stopPropagation();r.animate([{opacity:1},{opacity:0,transform:'translateX(-40px)'}],{duration:220,fill:'forwards'});setTimeout(()=>reqLater(i),200)}});
  B.querySelectorAll('.k9fr').forEach(r=>{const f=FPOOL[+r.dataset.f];r.onclick=e=>{if(e.target.closest('[data-a="chat"]')){e.stopPropagation();hap('pop','ぷにっ(チャット)');try{openDM(f)}catch(_){}return}try{openFC(f,r)}catch(_){}}})}
fRender=function(ni){const B=$('frbody'),F=$('fscr');if(!B)return;F.classList.add('v58','v65','k9h9');try{v54Counts()}catch(e){}
  let G=F.querySelector('.f65bg');if(G){G.classList.add('e0');G.innerHTML='<b></b>'}
  const tl=F.querySelector('.ftl em');if(tl)tl.textContent='Friends';
  const ad=$('fcall');if(ad){ad.setAttribute('aria-label','自分の QR');ad.onclick=()=>{hap('pop','ぷにっ(QR)');try{q9Open()}catch(e){}}}
  B.innerHTML=k9Hub();k9HubBind(B);if(K9.q)k9Res()};
openAdd=function(){const op=$('fscr').classList.contains('on');if(!op)openFriend();setTimeout(()=>{const i=$('k9in');if(i){i.focus({preventScroll:true});hap('tick',null,{norip:1})}},op?60:460)};
try{if($('fscr'))fRender()}catch(e){}

/* ================= D. QR を 読む = Lattag の カメラ ================= */
{const _os=openScan;openScan=function(mode){if(mode==='join')return _os(mode);k9Scan()}}
function k9Scan(){const Q=$('qrs');clearTimeout(Q._t);clearTimeout(Q._t2);hap('sel','コツッ(カメラ)');const o=k9F()[3];
  Q.className='qrs k9sc';
  Q.innerHTML=`<i class="k9feed" style="background-image:url(${PH.b})"></i><div class="k9tgt" aria-hidden="true"><div class="k9chk">${tQR('@'+o.id,132)}<small>@${o.id}</small></div></div>
    <div class="k9fd" id="k9fd"><i class="c1"></i><i class="c2"></i><i class="c3"></i><i class="c4"></i><i class="k9hs"></i><i class="k9bm"></i><i class="k9ok">${K9I.ok}</i></div>
    <div class="k9top"><button class="k9b" data-a="x" aria-label="とじる">${K9I.x}</button><b>QR を 読む</b><button class="k9b" data-a="torch" aria-label="ライト">${K9I.torch}</button></div>
    <p class="k9tip" id="k9tip"><i></i>友だちの QR を わくに</p>
    <div class="k9bot"><button data-a="me"><span class="k9mq">${X8I.qr}</span><b>自分の QR</b></button><button data-a="lib"><span>${K9I.img}</span><b>写真から</b></button></div>
    <div class="k9hit" id="k9hit" aria-live="polite"></div>`;
  Q.classList.add('on');Q.setAttribute('aria-hidden','false');
  const end=()=>{clearTimeout(Q._t);clearTimeout(Q._t2);Q.classList.remove('on');Q.setAttribute('aria-hidden','true');setTimeout(()=>{if(!Q.classList.contains('on'))Q.className='qrs'},320)};
  Q.querySelector('[data-a="x"]').onclick=()=>{hap('soft');end()};
  Q.querySelector('[data-a="torch"]').onclick=e=>{const b=e.currentTarget;b.classList.toggle('on');hap('click',b.classList.contains('on')?'カチッ(ライト ON)':'カチッ(ライト OFF)');Q.classList.toggle('lit',b.classList.contains('on'))};
  Q.querySelector('[data-a="me"]').onclick=()=>{hap('pop','ぷにっ(自分の QR)');end();setTimeout(()=>{try{q9Open()}catch(e){}},260)};
  Q.querySelector('[data-a="lib"]').onclick=()=>{hap('click');try{_toast('(モック)写真から QR を 読みます')}catch(e){}};
  if(!K9RM())Q.querySelectorAll('.k9fd i[class^="c"]').forEach((c,i)=>c.animate([{opacity:0,transform:'scale(1.4)'},{opacity:1,transform:'none'}],{duration:420,delay:80+i*40,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}));
  Q._t=setTimeout(()=>{const F=$('k9fd');F.classList.add('lock');$('k9tip').innerHTML='<i></i>見つけた';hap('success','トトトン(よめた)',{norip:1});
    Q._t2=setTimeout(()=>k9Hit(o,end),420)},1900)}
function k9Hit(o,end){const H=$('k9hit'),s=k9St(o),m=k9Mut(o);
  H.innerHTML=`<div class="k9hc"><span class="k9hp" style="background:${avBg(o.f)}">${o.f.n[0]}</span><b>${o.f.n}</b><small>@${o.id}</small>${m?`<em>${k9Why(o).replace(/<\/?em[^>]*>/g,'')}</em>`:'<em>QR から</em>'}
    <div class="k9hb2"><button class="k9go" data-a="req">${s==='fr'?'もう 友だち ・ チャット':s==='sent'?'申請中':'申請する'}</button><button class="k9no2" data-a="no">とじる</button></div></div>`;
  H.classList.add('on');hap('pop','ぷにっ(カード)');
  H.querySelector('[data-a="no"]').onclick=()=>{hap('soft');end()};
  H.querySelector('[data-a="req"]').onclick=e=>{const b=e.currentTarget;if(s==='fr'){end();setTimeout(()=>{try{openDM(o.f)}catch(_){}},300);return}if(s==='sent'){hap('warn');return}
    k9Add(o,null);b.innerHTML=K9I.ok+'申請しました';b.classList.add('done');k9Bump(b);setTimeout(()=>{end();try{_toast(o.f.n+' に 申請しました')}catch(_){}try{renderFriends()}catch(_){}},900)}}

/* ================= E. Friends タブ(はじめての 日) ================= */
function k9Cd(){const d=new Date(),t=new Date(d);t.setHours(9,0,0,0);if(t<=d)t.setDate(t.getDate()+1);const s=Math.floor((t-d)/1000),h=Math.floor(s/3600),m=Math.floor(s%3600/60),x=s%60;return `${h}:${String(m).padStart(2,'0')}:${String(x).padStart(2,'0')}`}
setInterval(()=>{const e=$('k9cd');if(e)e.textContent=k9Cd()},1000);
function k9Own(){const n=Math.min(shots,3);return `<section class="k9d1"><div class="k9d1h"><span><small>TODAY</small><b>あなたの 3こま</b></span><em>${n} / 3</em></div>
    <div class="k9sl">${[0,1,2].map(i=>i<n?`<button class="k9s on" data-a="shoot" aria-label="${i+1}こめ"><i style="background-image:url(${PH[['c','a','e'][i]]})"></i><b>DEV</b></button>`:`<button class="k9s${i===n?' nx':''}" data-a="shoot" aria-label="${i+1}こめを 撮る">${i===n?X8I.cam:`<b>${i+1}</b>`}</button>`).join('')}</div>
    <button class="k9go1" data-a="shoot">${X8I.cam}${n?'つづけて 撮る':'最初の 1枚を 撮る'}</button>
    <div class="k9fl2"><div class="k9st2 on"><i></i><b>撮る</b><small>今日 3こま</small></div><u></u><div class="k9st2"><i></i><b>24:00</b><small>消灯</small></div><u></u><div class="k9st2"><i></i><b>9:00</b><small>友だちと ひらく</small></div></div>
    <p class="k9cdl">ひらくまで <b id="k9cd">${k9Cd()}</b></p></section>`}
function k9Sample(){const f=FPOOL[0],g=FPOOL[1];return `<section class="k9pv"><div class="k9pvh"><b>FRIENDS</b><span>見本</span><small>友だちが できると、毎朝 9:00 に ここに ならぶ</small></div>
    <div class="k9po" aria-label="見本:友だちの 投稿">
      <div class="k9poh">${k9Av(f)}<span><b>${f.n}</b><small>@${FID(f).slice(1)} ・ きのう 3こま</small></span><em>9:00 OPEN</em></div>
      <div class="k9pc"><div class="k9pk k1"><i style="background-image:url(${PH.c})"></i><s>16:42</s></div><div class="k9pk k2"><i style="background-image:url(${PH.a})"></i><s>18:05</s></div><div class="k9pk k3"><i style="background-image:url(${PH.e})"></i><s>21:13</s></div>
        <span class="k9tg t1">#放課後</span><span class="k9tg t2">#夕焼け</span><span class="k9pl">${K9I.pin}渋谷区</span><span class="k9mu">${K9I.note}結び</span></div>
      <div class="k9pof"><span>${K9I.heart}</span><span>${K9I.chat}</span><small>${g.n} ・ ほか 2人が 見た</small></div>
      <i class="k9sm" aria-hidden="true">SAMPLE</i></div>
    <div class="k9ghost" aria-hidden="true"><div><i></i><span><u></u><u></u></span></div><div><i></i><span><u></u><u></u></span></div></div></section>`}
function k9Invite(){const S=k9Sugs().slice(0,6);return `<section class="k9iv"><div class="k9ivh"><b>友だちを よぶ</b><small>${FR.length} FRIENDS</small></div>
    <button class="k9fq" data-u9="find">${K9I.mag}<span>名前 か @ID で さがす</span></button>
    <div class="x8ib k9ib"><button data-x8="qr"><i>${X8I.qr}</i><b>QR を 見せる</b></button><button data-x8="scan"><i>${X8I.scan}</i><b>QR を 読む</b></button><button data-x8="link"><i>${X8I.link}</i><b>リンク</b></button></div>
    ${S.length?`<div class="k9ivs"><span class="k9ivsh">おすすめ</span><div class="k9hz">${S.map(o=>`<div class="k9hc2">${k9Av(o.f,1)}<b>${o.f.n}</b><small>@${o.id}</small><button class="k9ad ${k9St(o)}" data-a="add" data-f="${o.i}">${k9St(o)==='sent'?'<span>申請中</span>':K9I.plus+'<span>追加</span>'}</button></div>`).join('')}</div></div>`:''}</section>`}
x8First=function(){const own=X8.first||X8.noown,nf=X8.first||X8.nofr;let h='';if(own)h+=k9Own();if(nf)h+=k9Sample()+k9Invite();return h};
{const _b=y72Bind;y72Bind=function(W){_b(W);try{k9BindRows(W);
  W.querySelectorAll('[data-u9="find"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(さがす)');k9Bump(b);try{openFriend()}catch(e){}setTimeout(()=>{const i=$('k9in');i&&i.focus({preventScroll:true})},460)});
  if(!K9RM()){const P=W.querySelector('.k9po');if(P)P.animate([{opacity:0,transform:'translateY(20px) scale(.97)'},{opacity:1,transform:'none'}],{duration:620,delay:160,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'});
    W.querySelectorAll('.k9pk').forEach((k,i)=>k.animate([{opacity:0,transform:'translateY(30px) rotate(0deg)'},{opacity:1}],{duration:560,delay:260+i*90,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}}catch(e){console.error(e)}}}

window.__kit=Object.assign(window.__kit||{},{k9Id:()=>k9IdOpen(),k9Scan:()=>k9Scan(),k9Find:q=>{try{openFriend()}catch(e){}setTimeout(()=>{const i=$('k9in');if(i){i.value=q||'';K9.q=q||'';k9Res()}},480)},k9Set:o=>Object.assign(K9,o),k9Ob:n=>{OB.name=n||'ゆい';OB.id='';OB.idT=0;obStep('id')}});
