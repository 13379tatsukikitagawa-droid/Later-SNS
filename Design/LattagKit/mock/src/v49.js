/* ================= v49 ================= */
/* --- Home の FRIENDS:カードの 中に 見出し と ボタン --- */
{const _af=arcFriends;arcFriends=function(ni){_af(ni);const B=$('afc');if(!B)return;const took=FR.filter(f=>f.k>0).length;
  const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';
  const h=document.createElement('div');h.className='afh';
  h.innerHTML=`<b>Friend</b>${FR.length?`<span class="lv"><i></i>${took}</span>`:''}`;
  const f=document.createElement('div');f.className='aff';
  f.innerHTML=`<button class="ad" data-a="add"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Add</button><button class="op" data-a="go">Open<svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg></button>`;
  B.prepend(h);B.appendChild(f);
  f.querySelector('.ad').onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(ともだちを 呼ぶ)');if(FR.length>=999){_toast('デモの 友だちは ここまで');return}openSheet('shf')};
  f.querySelector('.op').onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(Friend へ)');openFriend()};
  h.onclick=e=>{e.stopPropagation();hap('pop');openFriend()}}}
$('fscr').querySelector('.ftl em').textContent='Friend';

/* --- Lattag yesterday の FRIENDS:わかりやすい カードに --- */
function yFriends(){const F=$('yfx');if(!F)return;const took=FR.filter(f=>f.k>0).length;
  const ring=f=>`<svg viewBox="0 0 70 70"><circle cx="35" cy="35" r="32" class="t"/><circle cx="35" cy="35" r="32" class="p" pathLength="3" style="stroke-dasharray:${f.k} 3"/></svg>`;
  const seats=Array.from({length:Math.max(0,5-FR.length)},()=>`<span class="yfe"><i></i></span>`).join('');
  F.innerHTML=`<div class="yfc"><div class="yfh"><b>Friend</b>${FR.length?`<span class="lv"><i></i>${took} today</span>`:''}<button class="go" data-a="go" aria-label="Friend へ"><svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg></button></div>
    <div class="yfs"><button class="yfp ad" data-a="add" aria-label="ともだちを 呼ぶ"><span class="c"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></span><b>Add</b></button>
      ${FR.map((f,i)=>`<button class="yfp${f.k>0?' k':''}" data-i="${i}" aria-label="${f.n}、今日 ${f.k}こま"><span class="c">${ring(f)}<i style="background:${avBg(f)}">${f.n[0]}</i>${f.k>0?`<em>${f.k}</em>`:''}</span><b>${f.n}</b></button>`).join('')}${seats}</div>
    ${FR.length?'':`<div class="yf0">${fCrowd(1)}</div>`}</div>`;
  F.querySelectorAll('[data-a="add"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(ともだちを 呼ぶ)');openSheet('shf')});
  F.querySelector('[data-a="go"]').onclick=()=>{hap('pop');closeY();setTimeout(openFriend,350)};
  F.querySelectorAll('.yfp[data-i]').forEach(b=>b.onclick=()=>{hap('pop');closeY();setTimeout(()=>{openFriend();FSEL=+b.dataset.i;setTimeout(fSoft,500)},350)})}
{const _yo=yOnce;yOnce=function(){_yo();yFriends()};window.yOnce=yOnce}
{const _rf=renderFriends;renderFriends=function(n){_rf(n);try{yFriends()}catch(e){}}}

/* --- Mondo の 見出し:地球の o ・ 1文字ずつ ・ 線が かかれる ・ 世界の 9:00 --- */
const MCT=[['Tokyo',9],['Seoul',9],['Bangkok',7],['Paris',1],['London',0],['New York',-5],['L.A.',-8],['Sydney',11]];
function moHead(){const H=document.querySelector('#ymo .mohd');if(!H)return;const d=new Date(Date.now()-864e5);
  const sp=(s,o)=>[...s].map((c,i)=>`<span class="mlt" style="--i:${i+o}">${c===' '?'&nbsp;':c}</span>`).join('');
  const glb=`<span class="glb" style="--i:6"><svg viewBox="0 0 40 40"><defs><clipPath id="gcl"><circle cx="20" cy="20" r="17"/></clipPath></defs><circle cx="20" cy="20" r="17" class="o"/><g clip-path="url(#gcl)"><g class="mer"><path d="M20 3c-7 5-7 29 0 34M20 3c7 5 7 29 0 34M8 6c-6 8-6 20 0 28M32 6c6 8 6 20 0 28M-4 3c-7 5-7 29 0 34M44 3c7 5 7 29 0 34"/></g><path d="M3 20h34M5 12h30M5 28h30" class="lat"/></g><circle cx="29" cy="11" r="2.6" class="pin"/></svg></span>`;
  const now=new Date(),u=now.getUTCHours()+now.getUTCMinutes()/60;
  const tick=MCT.map(([c,z])=>{const h=((u+z)%24+24)%24,hh=Math.floor(h),mm=Math.floor((h-hh)*60);const op=hh>=9&&hh<21;return `<span class="${op?'on':''}"><i></i>${c} <b>${hh}:${p2(mm)}</b></span>`}).join('');
  H.innerHTML=`<span class="mmk"><i class="dot"></i>MONDO · ${MON[d.getMonth()].toUpperCase()} ${d.getDate()}</span>
    <h2 class="mh"><span class="ml1">${sp('The w',0)}${glb}${sp('rld,',7)}</span><span class="ml2">${sp('yesterday.',12)}<svg class="msw2" viewBox="0 0 300 26" preserveAspectRatio="none"><path d="M4 18C60 6 130 4 200 10s80 8 94 2"/></svg></span></h2>
    <div class="mtk"><div class="mtr">${tick}${tick}</div></div>`;
  H.querySelector('.glb').onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(ちきゅう)');const g=H.querySelector('.mer');g.style.animationDuration='.6s';setTimeout(()=>g.style.animationDuration='',1400)}}
{const _ym=yMondo;yMondo=function(){_ym();moHead()};renderYM=yMondo;window.yMondo=yMondo}
{const _yt=ytab;ytab=function(id,q){_yt(id,q);if(id==='ytm'){const h=document.querySelector('#ymo .mohd');if(h){h.classList.remove('in');void h.offsetWidth;h.classList.add('in');clearTimeout(h._t);h._t=setTimeout(()=>h.classList.remove('in'),2600)}}}}
renderArc();
