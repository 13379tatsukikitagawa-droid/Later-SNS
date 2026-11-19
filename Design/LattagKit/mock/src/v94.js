/* ===== v94(モック v94 ・ PROMPT v105) =====
   1. 友だちの カード:チェキが シートの 上に はみ出して 切れる ・ うしろが すける バグを 直す + 作りなおし
   2. (オープニングは 別ファイル mock/opening_v94.html の S)
   3. 設定 > サポート:「はじめての 説明を もう1回」「ウィジェット」の 行を 消す → 「使いかた」を 新しく(v99 の 動く 説明 + ウィジェット)
   名前:d9 */
const D9={log:[]};
const D9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const D9I={x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  lock:'<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>',
  trip:'<svg viewBox="0 0 24 24"><rect x="4" y="7.5" width="16" height="12" rx="2.5"/><path d="M9 7.5V5.5h6v2"/></svg>',
  more:'<svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="18" cy="12" r="1.8"/></svg>',
  play:'<svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.5z"/></svg>',
  go:'<svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg>'};

/* ================= 1. 友だちの カード ================= */
function d9Mut(f){const o=FR.filter(x=>x!==f);const n=o.length?Math.min(o.length,(f.n.charCodeAt(0)%3)+1):0;return o.slice(0,n)}
openFC=function(f,from){let S=$('fcv');if(!S){S=document.createElement('section');S.className='fcv';S.id='fcv';$('phone').appendChild(S)}
  S.classList.add('d9');const i=fIdx(f),T=fTimes(f),k=f.k||0,M=d9Mut(f),d=new Date();
  const st=k?`<em class="d9st on"><i></i>今日 ${k}枚</em>`:`<em class="d9st">まだ 撮って いない</em>`;
  const frames=[0,1,2].map(j=>j<k?`<i class="on"><b style="background-image:url(${fPic(f)})"></b><s>${T[j]}</s>${shots?'':`<u>${D9I.lock}</u>`}</i>`:`<i></i>`).join('');
  const cap=k?(shots?'あした 9:00 に ひらく':'今日 1枚 撮ると、あした 見られる'):'まだ 撮って いない ・ つついて 合図しよう';
  const poke=!k;
  S.innerHTML=`<i class="sc" data-a="x"></i><div class="pn" role="dialog" aria-label="${f.n}"><i class="gb"></i>
    <div class="d9hd"><span class="d9k">FRIEND</span>${st}<button class="d9x" data-a="x" aria-label="とじる">${D9I.x}</button></div>
    <div class="d9hero">
      <div class="d9ck"><i class="tp"></i><span class="ph" style="background-image:url(${fPic(f)})"><em class="dt">'${String(d.getFullYear()).slice(2)} ${p2(d.getMonth()+1)} ${p2(d.getDate())}</em></span><b class="nm">${f.n}</b></div>
      <div class="d9tx"><b class="d9n">${f.n}</b><span class="d9id">${FID(f)}</span><span class="d9sn">since ${fSince(f)}</span>
        <div class="d9tg"><span style="background:${tgc(fTag(f))[0]};color:${tgc(fTag(f))[1]}">${fTag(f)}</span><span style="background:${tgc(fTag2(f))[0]};color:${tgc(fTag2(f))[1]}">${fTag2(f)}</span></div>
        ${M.length?`<div class="d9mu"><span>${M.map(m=>`<i style="background:${avBg(m)}">${m.n[0]}</i>`).join('')}</span>共通の 友だち ${M.length}人</div>`:''}</div></div>
    <div class="d9td"><div class="d9th"><span>TODAY</span><em>${k} / 3</em></div><div class="d9fr">${frames}</div><small>${cap}</small></div>
    <div class="d9bt${poke?' p4':''}"><button class="p" data-a="chat">${ICH}<span>Chat</span></button>${poke?`<button class="pk${POKED.has(i)?' dn':''}" data-a="poke">${IHAND}<span>${POKED.has(i)?'つついた':'つつく'}</span></button>`:''}<button data-a="trip">${D9I.trip}<span>Trip</span></button><button data-a="more" aria-label="ほかの 操作">${D9I.more}<span>more</span></button></div></div>`;
  requestAnimationFrame(()=>S.classList.add('on'));hap('pop','ぷにっ('+f.n+')');D9.log.push('fc:'+f.n);
  if(!D9RM()){const C=S.querySelector('.d9ck');C.animate([{transform:'translateY(40px) rotate(10deg) scale(.7)',opacity:0},{transform:'translateY(-4px) rotate(-6deg) scale(1.04)',opacity:1,offset:.7},{transform:'rotate(-4deg)'}],{duration:620,delay:120,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'});
    S.querySelectorAll('.d9tg span').forEach((s,j)=>s.animate([{transform:'scale(0)'},{transform:'scale(1.2)'},{transform:'scale(1)'}],{duration:420,delay:420+j*110,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'}));setTimeout(()=>hap('tick',null,{norip:1}),440);setTimeout(()=>hap('tick',null,{norip:1}),550);
    S.querySelectorAll('.d9tx>*:not(.d9tg),.d9td,.d9bt button').forEach((e,j)=>e.animate([{opacity:0,transform:'translateY(12px)'},{opacity:1,transform:'none'}],{duration:420,delay:200+j*40,easing:'cubic-bezier(.3,1.35,.5,1)',fill:'backwards'}))}
  const close=()=>{S.classList.remove('on');hap('soft')};
  S.querySelectorAll('[data-a="x"]').forEach(b=>b.onclick=close);
  S.querySelector('[data-a="chat"]').onclick=()=>{close();setTimeout(()=>openDM(f),250)};
  const P=S.querySelector('[data-a="poke"]');if(P)P.onclick=e=>{const b=e.currentTarget;fPoke2(i,b);b.classList.add('dn');b.querySelector('span').textContent='つついた'};
  S.querySelector('[data-a="trip"]').onclick=()=>{close();setTimeout(()=>{openTrip();if(TW.g&&!TW.g.m.includes(f)){TW.g.m.push(f);const b=document.querySelector(`#trw .twf button[data-i="${i}"]`);b&&b.classList.add('on');twDraw()}},300)};
  S.querySelector('[data-a="more"]').onclick=()=>{close();setTimeout(()=>fMenu(i),250)}};

/* ================= 3. 使いかた(設定 > サポート)================= */
const D9H=[
  {k:'friends',t:'Friends',s:'友だちと 1日 3枚 ・ 9:00 に ひらく',n:4},
  {k:'trip',t:'Trip',s:'旅の あいだ みんなで 23枚',n:4},
  {k:'mondo',t:'Mondo',s:'世界の きのうの お題',n:4},
  {k:'widget',t:'ウィジェット',s:'ホーム画面に 置く',n:5}];
const d9Mini=k=>({
  friends:'<i class="d9m mf"><b></b><b></b><b></b><em></em></i>',
  trip:'<i class="d9m mt"><b>23</b><small>LEFT</small></i>',
  mondo:'<i class="d9m mm"><b></b></i>',
  widget:'<i class="d9m mw"><b>#</b></i>'}[k]);
function d9HowOpen(){let S=$('d9h');if(!S){$('phone').insertAdjacentHTML('beforeend','<div class="d9h" id="d9h" aria-hidden="true"><i class="d9hc"></i><div class="d9hp" role="dialog" aria-label="使いかた"></div></div>');S=$('d9h');S.querySelector('.d9hc').onclick=()=>d9HowClose()}
  const P=S.querySelector('.d9hp');
  P.innerHTML=`<i class="grab"></i><div class="d9hh"><b>使いかた</b><button class="d9x" data-a="x" aria-label="とじる">${D9I.x}</button></div>
    <p class="d9hs">見たい ところを えらぶと、動く 説明が はじまります</p>
    <button class="d9all" data-a="all"><span class="d9pl">${D9I.play}</span><span><b>ぜんぶ 見る</b><small>Friends → Trip → Mondo ・ 約 45秒</small></span></button>
    <div class="d9hl">${D9H.map(c=>`<button class="d9hr" data-k="${c.k}">${d9Mini(c.k)}<span><b>${c.t}</b><small>${c.s}</small></span><em>${c.n} 場面</em>${D9I.go}</button>`).join('')}</div>`;
  P.querySelector('[data-a="x"]').onclick=()=>d9HowClose();
  P.querySelector('[data-a="all"]').onclick=()=>{hap('click','カチッ(ぜんぶ)');D9.log.push('how:all');d9HowClose();setTimeout(()=>z9Open('friends',{then:()=>setTimeout(()=>z9Open('trip',{then:()=>setTimeout(()=>z9Open('mondo',{}),250)}),250)}),300)};
  P.querySelectorAll('.d9hr').forEach(b=>b.onclick=()=>{const k=b.dataset.k;hap('sel','コツッ('+k+')',{norip:1});D9.log.push('how:'+k);d9HowClose();
    setTimeout(()=>{if(k==='widget'){try{c9wOpen('settings')}catch(e){}}else z9Open(k,{})},300)});
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('soft','ふわっ(シート)',{norip:1})}
function d9HowClose(){const S=$('d9h');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true')}
{const _s=x8Set;x8Set=function(){const r=_s.apply(this,arguments);
  try{document.querySelectorAll('.x8rw[data-a="how"]').forEach(b=>{b.onclick=ev=>{ev.stopPropagation();hap('tick',null,{norip:1});d9HowOpen()}})}catch(e){}
  return r}}

/* ================= デモ ================= */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-d9]'))return;
  C.insertAdjacentHTML('beforeend',['fc:友だちの カード(撮った)','fc0:友だちの カード(まだ)','how:使いかた','op:オープニング(強い 版)'].map(s=>{const[k,l]=s.split(':');return `<button data-d9="${k}">${l}</button>`}).join(''));
  C.querySelectorAll('[data-d9]').forEach(b=>b.onclick=()=>d9Demo(b.dataset.d9))})();
function d9Demo(k){
  if(k==='op'){window.open('opening_v94.html','_blank');return}
  if(k==='how'){d9HowOpen();return}
  if(!FR.length){try{[...document.querySelectorAll('#ctl button')].find(b=>b.dataset.c==='fr3').click()}catch(e){}}
  setTimeout(()=>{try{z9Close()}catch(e){}const f=k==='fc0'?(FR.find(x=>!x.k)||FR[0]):(FR.find(x=>x.k)||FR[0]);openFC(f,document.body)},FR.length?0:700)}
window.__kit=Object.assign(window.__kit||{},{d9:k=>d9Demo(k),d9How:()=>d9HowOpen(),D9:()=>({log:D9.log.slice()})});
