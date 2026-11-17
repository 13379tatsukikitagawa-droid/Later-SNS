/* ================= v58 Friend を「友だちの チェキの 壁」に =================
   ・いちばん上:NOW(いま 撮った人が 流れる)
   ・Requests:申請も チェキの 小さな カードで
   ・Today:ストーリーの ように 丸い 写真が 並ぶ(撮った人は 緑の 輪 ・ まだの 人は 👋 で つつける)
   ・Friends:みんなの チェキを 2列で 貼った 壁(写真 ・ 手書きの 名前 ・ タグ ・ 時刻)
   ・チェキを 押すと 友だちの カード(Chat ・ つつく ・ Trip に さそう)
   ・下に「ふやす」と 自分の チェキ */
const FPK='dbfaec';
const fPic=f=>PH[FPK[(f.n.charCodeAt(0)+(f.n.charCodeAt(1)||0))%6]];
const fTag=f=>['#夕焼け','#放課後','#帰り道','#カフェ','#雨の日','#部活','#ねむい','#散歩'][(f.n.charCodeAt(0))%8];
const fTag2=f=>['#音楽','#朝型','#夜型','#犬','#古着','#韓国','#映画','#パン'][(f.n.charCodeAt(0)>>1)%8];
const fTimes=f=>['08:14','12:40','17:05'].slice(0,f.k);
const fIdx=f=>FR.indexOf(f);
const IHAND='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11V5.5a1.5 1.5 0 013 0V10m0-1.5a1.5 1.5 0 013 0V11m0-1a1.5 1.5 0 013 0v4.5A6.5 6.5 0 0111.5 21h-.6a6 6 0 01-4.6-2.2L3.6 15.4a1.6 1.6 0 012.4-2.1L9 15.5"/></svg>';
var FQ2='';

function fNow(){const ev=[];FR.forEach(f=>{fTimes(f).forEach(t=>ev.push({f,t}))});ev.sort((a,b)=>a.t<b.t?1:-1);
  const items=ev.length?ev.slice(0,8).map(e=>`<span><i style="background-image:url(${fPic(e.f)})"></i><b>${e.f.n}</b> が ${e.t} に 撮った</span>`):['<span>まだ だれも 撮って いない ・ さいしょの 1枚に なろう</span>'];
  return `<div class="fnow"><em><i></i>NOW</em><div class="fnr"><div class="fnt">${items.join('')}${items.join('')}</div></div></div>`}
function fReq(){if(!REQ.length&&!REQL.length)return '';
  return `<div class="fsec"><div class="fsh"><b>Requests</b>${REQ.length?'<i class="rd"></i>':''}${REQL.length?`<button class="lt" data-a="later">あとで ${REQL.length} ›</button>`:''}</div>
    <div class="frq">${REQ.map((r,i)=>`<div class="frc" data-i="${i}" style="--r:${i%2?2:-2}deg"><span class="ph" style="background-image:url(${fPic(r.f)})"><em>${r.at}</em></span><b class="nm">${r.f.n}</b><small>${FID(r.f)}</small>
      <div class="bt"><button class="ok" data-a="ok">${IOK}承認</button><button class="no" data-a="no" aria-label="あとで">あとで</button></div></div>`).join('')}</div></div>`}
function fStory(){const V=FR.slice().sort((a,b)=>b.k-a.k);
  return `<div class="fsec"><div class="fsh"><b>Today</b><span class="mono">${V.filter(f=>f.k>0).length?`● ${V.filter(f=>f.k>0).length} shot`:'まだ だれも'}</span></div>
    <div class="fsty"><button class="fsa" data-a="add"><span class="c"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></span><small>Add</small></button>
    ${V.map(f=>{const i=fIdx(f);return `<button class="fso${f.k>0?' k':''}${POKED.has(i)?' pk':''}" data-i="${i}"><span class="c"><svg viewBox="0 0 70 70">${[0,1,2].map(j=>`<path d="${fArc(j)}" class="${j<f.k?'on':''}"/>`).join('')}</svg><i style="background-image:url(${fPic(f)})"></i>${f.k>0?`<em>${fTimes(f)[f.k-1]}</em>`:`<u>${IHAND}</u>`}</span><small>${f.n}</small></button>`}).join('')}</div></div>`}
function fArc(j){const r=32,c=35,a0=(-90+j*120+6)*Math.PI/180,a1=(-90+(j+1)*120-6)*Math.PI/180;return `M${(c+r*Math.cos(a0)).toFixed(1)} ${(c+r*Math.sin(a0)).toFixed(1)}A${r} ${r} 0 0 1 ${(c+r*Math.cos(a1)).toFixed(1)} ${(c+r*Math.sin(a1)).toFixed(1)}`}
function fBoard(){if(!FR.length)return `<div class="fsec"><div class="fe0">${fCrowd(1)}<b>まだ だれも いない</b><small>QR か ID で、さいしょの 友だちを よぼう</small><button data-a="add">Add friends</button></div></div>`;
  return `<div class="fsec"><div class="fsh"><b>Friends</b><label class="fq"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg><input id="fq2" placeholder="さがす" value="${FQ2}"></label></div>
    <div class="fwall">${FR.map((f,i)=>`<div class="fck${f.k>0?' k':''}" data-i="${i}" style="--r:${[-2.5,1.8,-1,2.6,-1.8,1.2][i%6]}deg"${FQ2&&!f.n.includes(FQ2)?' hidden':''}>
        <i class="tp"></i><span class="ph" style="background-image:url(${fPic(f)})">${f.k>0?`<em class="tm">${fTimes(f)[f.k-1]}</em>`:''}<span class="tg" style="background:${tgc(fTag(f))[0]};color:${tgc(fTag(f))[1]}">${fTag(f)}</span></span>
        <b class="nm">${f.n}</b><span class="st">${f.k>0?`<i class="on"></i>`.repeat(f.k)+`<i></i>`.repeat(3-f.k):'<small>まだ</small>'}</span>
        <span class="ac"><button class="pk${POKED.has(i)?' dn':''}" data-a="poke" aria-label="つつく">${IHAND}</button><button class="ch" data-a="chat" aria-label="チャット">${ICH}</button></span></div>`).join('')}</div></div>`}
function fMore(){return `<div class="fsec fmo2"><div class="fmh"><span class="cr" id="fcore">${fCrowd(Math.min(5,FR.length+1))}</span><div><b>もっと つながる</b><small>となりで ふる ・ QR ・ リンク</small></div></div>
  <div class="fwy"><button data-a="shake" aria-label="ふる"><svg viewBox="0 0 24 24"><rect x="7.5" y="3" width="9" height="18" rx="2.4"/><path d="M3.5 9v6M20.5 9v6"/></svg><b>Shake</b></button>
  <button data-a="qr" class="pr" aria-label="QR"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg><b>QR</b></button>
  <button data-a="link" aria-label="リンク"><svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg><b>Link</b></button></div></div>`}

fRender=function(ni){const B=$('frbody');if(!B)return;$('fscr').classList.add('v58');try{v54Counts()}catch(e){}
  B.innerHTML=fNow()+fReq()+fStory()+fBoard()+fMore()+`<div class="fsec"><div class="fsh"><b>You</b><span class="mono">@yui_0612</span></div>${fMeCard()}</div>`;
  f58Bind(B);if(ni!=null&&FR[ni]){const c=B.querySelector(`.fck[data-i="${ni}"]`);c&&c.animate([{transform:'translateY(-60px) rotate(-12deg) scale(1.2)',opacity:0},{transform:'none',opacity:1}],{duration:700,easing:'cubic-bezier(.3,1.3,.5,1)'})}};
function f58Bind(B){
  B.querySelectorAll('.frc').forEach(c=>{const i=+c.dataset.i;c.querySelector('[data-a="ok"]').onclick=e=>{e.stopPropagation();c.animate([{transform:`rotate(var(--r))`},{transform:'translateY(-10px) rotate(6deg) scale(1.06)',offset:.35},{transform:'translateY(160px) rotate(-10deg) scale(.5)',opacity:0}],{duration:520,easing:'cubic-bezier(.5,0,.3,1)',fill:'forwards'});setTimeout(()=>reqAccept(i),460)};
    c.querySelector('[data-a="no"]').onclick=e=>{e.stopPropagation();c.animate([{opacity:1},{opacity:0,transform:'translateX(-40px) rotate(-8deg)'}],{duration:260,fill:'forwards'});setTimeout(()=>reqLater(i),240)}});
  const lt=B.querySelector('.fsh [data-a="later"]');if(lt)lt.onclick=()=>{hap('sel');REQ.push(...REQL);REQL=[];renderFriends()};
  B.querySelectorAll('[data-a="add"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(Add)');openAdd()});
  B.querySelectorAll('.fso').forEach(b=>b.onclick=()=>{const f=FR[+b.dataset.i];if(f.k===0&&!POKED.has(+b.dataset.i)){fPoke2(+b.dataset.i,b);return}openFC(f,b)});
  B.querySelectorAll('.fck').forEach(c=>{const i=+c.dataset.i,f=FR[i];
    c.onclick=e=>{const a=e.target.closest('[data-a]');if(a&&a.dataset.a==='chat'){e.stopPropagation();hap('pop');openDM(f);return}if(a&&a.dataset.a==='poke'){e.stopPropagation();fPoke2(i,c);return}openFC(f,c)};
    c.addEventListener('pointerdown',()=>c.classList.add('dn'));['pointerup','pointerleave','pointercancel'].forEach(t=>c.addEventListener(t,()=>c.classList.remove('dn')))});
  const q=$('fq2');if(q){q.oninput=()=>{FQ2=q.value.trim();B.querySelectorAll('.fck').forEach(c=>c.hidden=!!FQ2&&!FR[+c.dataset.i].n.includes(FQ2))};q.onclick=e=>e.stopPropagation()}
  B.querySelectorAll('.fwy button').forEach(b=>b.onclick=()=>{const a=b.dataset.a;b.animate([{scale:'1'},{scale:'.9'},{scale:'1.04'},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'});
    if(a==='shake'){hap('buzz','ブルブル(ふる)',{norip:1});const c=$('fcore');c.classList.add('sh');setTimeout(()=>{c.classList.remove('sh');bumpBurst(c,()=>askBump())},700)}
    else if(a==='qr'){hap('pop');openAdd()}else{hap('pop');openShare({t:'Lattag で つながろう ・ ゆい(@yui_0612)\nhttps://lattag.app/u/yui_0612',h:'ゆい'})}});
  try{fMeBind()}catch(e){}}
function fPoke2(i,el){if(POKED.has(i)){hap('warn','やわらかく2回(きょうは もう つついた)');shake(el);return}POKED.add(i);hap('heart','ドクン(つついた)',{norip:1});
  const h=el.querySelector('.pk svg,u svg')||el;h.animate([{rotate:'0deg'},{rotate:'-24deg'},{rotate:'18deg'},{rotate:'-8deg'},{rotate:'0deg'}],{duration:560});
  const r=el.getBoundingClientRect(),P=$('phone').getBoundingClientRect();for(let k=0;k<5;k++){const s=document.createElement('i');s.className='fpk';s.textContent='♥';s.style.left=((r.left+r.width/2-P.left)/SC)+'px';s.style.top=((r.top+r.height/2-P.top)/SC)+'px';$('phone').appendChild(s);
    s.animate([{transform:'translate(-50%,-50%) scale(.4)',opacity:1},{transform:`translate(${-50+(k-2)*40}%,${-160-k%2*60}%) scale(1.2) rotate(${(k-2)*12}deg)`,opacity:0}],{duration:900,delay:k*50,easing:'cubic-bezier(.2,.8,.3,1)',fill:'backwards'}).onfinish=()=>s.remove()}
  setTimeout(()=>{_toast(FR[i].n+' を つついた ・ 撮ってね の 合図');renderFriends()},700)}

/* ---------- 友だちの カード(チェキを 押すと)---------- */
function openFC(f,from){let S=$('fcv');if(!S){S=document.createElement('section');S.className='fcv';S.id='fcv';$('phone').appendChild(S)}const i=fIdx(f),T=fTimes(f);
  S.innerHTML=`<i class="sc" data-a="x"></i><div class="pn"><i class="gb"></i>
    <div class="ck"><i class="tp"></i><span class="ph" style="background-image:url(${fPic(f)})"><em class="dt">'26 ${p2(new Date().getMonth()+1)} ${p2(new Date().getDate())}</em></span><b class="nm">${f.n}</b>
      <span class="sk s1" style="background:${tgc(fTag(f))[0]};color:${tgc(fTag(f))[1]}">${fTag(f)}</span><span class="sk s2" style="background:${tgc(fTag2(f))[0]};color:${tgc(fTag2(f))[1]}">${fTag2(f)}</span></div>
    <div class="id"><span>${FID(f)} ・ since ${fSince(f)}</span></div>
    <div class="ftd"><span class="mono">TODAY</span><div class="fcf">${[0,1,2].map(j=>j<f.k?`<i class="on"><b style="background-image:url(${fPic(f)})"></b><s>${T[j]}</s>${shots?'':`<u>${ICO.lock}</u>`}</i>`:`<i></i>`).join('')}</div><small>${f.k?(shots?'あした 9:00 に ひらく':'今日 1枚 撮ると、あした 見られる'):'まだ 撮って いない ・ つついて 合図しよう'}</small></div>
    <div class="bt"><button class="p" data-a="chat">${ICH}<span>Chat</span></button><button data-a="poke" class="${POKED.has(i)?'dn':''}">${IHAND}<span>${POKED.has(i)?'つついた':'つつく'}</span></button><button data-a="trip"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="7.5" width="16" height="12" rx="2.5"/><path d="M9 7.5V5.5a1.5 1.5 0 011.5-1.5h3A1.5 1.5 0 0115 5.5v2"/></svg><span>Trip</span></button><button data-a="more" aria-label="そのほか"><svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18" cy="12" r="1.6"/></svg><span>more</span></button></div></div>`;
  S.classList.add('on');hap('pop','ぷにっ('+f.n+')');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches){const C=S.querySelector('.ck');C.animate([{transform:'translateY(120px) rotate(14deg) scale(.6)',opacity:0},{transform:'translateY(-8px) rotate(-5deg) scale(1.03)',opacity:1,offset:.7},{transform:'rotate(-3deg)'}],{duration:620,easing:'cubic-bezier(.3,1.2,.4,1)'});
    S.querySelectorAll('.sk').forEach((s,k)=>s.animate([{scale:'0'},{scale:'1.25'},{scale:'1'}],{duration:420,delay:420+k*110,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'}));setTimeout(()=>hap('tick',null,{norip:1}),420);setTimeout(()=>hap('tick',null,{norip:1}),530);
    S.querySelectorAll('.id,.ftd,.bt button').forEach((e,k)=>e.animate([{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'none'}],{duration:440,delay:240+k*45,easing:'cubic-bezier(.3,1.35,.5,1)',fill:'backwards'}))}
  const close=()=>{S.classList.remove('on');hap('soft')};
  S.querySelectorAll('[data-a="x"]').forEach(b=>b.onclick=close);
  S.querySelector('[data-a="chat"]').onclick=()=>{close();setTimeout(()=>openDM(f),250)};
  S.querySelector('[data-a="poke"]').onclick=e=>{const b=e.currentTarget;fPoke2(i,b);b.classList.add('dn');b.querySelector('span').textContent='つついた'};
  S.querySelector('[data-a="trip"]').onclick=()=>{close();setTimeout(()=>{openTrip();if(TW.g&&!TW.g.m.includes(f)){TW.g.m.push(f);const b=document.querySelector(`#trw .twf button[data-i="${i}"]`);b&&b.classList.add('on');twDraw()}},300)};
  S.querySelector('[data-a="more"]').onclick=()=>{close();setTimeout(()=>fMenu(i),250)};
  S.querySelector('.ck').onclick=e=>{const c=e.currentTarget;c.classList.toggle('fl');hap('sel')}}

/* ---------- 開いた ときの 動き ---------- */
{const _of=openFriend;openFriend=function(){_of();const F=$('fscr');if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  F.querySelectorAll('.fnow,.fsec .fsh').forEach((x,i)=>x.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:440,delay:120+i*40,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
  F.querySelectorAll('.fso,.fsa').forEach((x,i)=>x.animate([{opacity:0,transform:'scale(.4)'},{opacity:1,transform:'none'}],{duration:480,delay:220+i*50,easing:'cubic-bezier(.3,1.6,.5,1)',fill:'backwards'}));
  F.querySelectorAll('.fck').forEach((x,i)=>{x.animate([{opacity:0,transform:'translateY(-40px) rotate(-10deg) scale(1.08)'},{opacity:1,transform:'rotate(var(--r))'}],{duration:620,delay:380+i*70,easing:'cubic-bezier(.3,1.25,.5,1)',fill:'backwards'});if(i<6)setTimeout(()=>hap('tick',null,{norip:1}),380+i*70+420)})}}
{const _ca=closeAll;closeAll=function(){const s=$('fcv');if(s)s.classList.remove('on');return _ca.apply(this,arguments)}}

/* ---------- ほかの 画面の 友だちの 丸も 写真に ---------- */
{const _h=hpRender;hpRender=function(only){_h(only);if(only&&only!==1)return;const G=document.querySelector('#hpc1 .hpfr');if(!G)return;
  const bs=[...G.querySelectorAll('button[data-n]')];bs.forEach(b=>{const f=FR.find(x=>x.n===b.dataset.n);const i=b.querySelector('i');if(f&&i){i.style.background=`center/cover url(${fPic(f)})`;i.innerHTML=''}});
  if(bs.length>3){bs.slice(2).forEach(b=>b.remove());const m=document.createElement('button');m.className='more';m.innerHTML=`<span class="r"><i>+${FR.length-2}</i></span><small>みんな</small>`;m.onclick=()=>{hap('pop');openFriend()};G.appendChild(m)}}}
{const _yf=yFriends;yFriends=function(){_yf();document.querySelectorAll('#yfx .yfp[data-i] .c i').forEach(i=>{const f=FR[+i.closest('.yfp').dataset.i];if(f){i.style.background=`center/cover url(${fPic(f)})`;i.textContent=''}})}}
try{renderFriends()}catch(e){}try{renderOrb()}catch(e){}
window.openFC=openFC;
