/* わかりやすく:四すみは いつも 同じ 4つ(Yesterday / Trip / Mondo / Friends)。
   まんなかは フィルムが ある 間は ずっと Shoot、3枚 撮りおわったら Yesterday。 */
{const _oa=orbActs;orbActs=function(){const R=_oa();R.main=R.A.shoot?'shoot':'yday';R.sat=['yday','group','mondo','friends'];return R}}

try{$('home').classList.remove('safe')}catch(e){}

/* ================= Home の Friends カード ================= */
const AFG='M-18 34V2a18 18 0 0136 0v32z';
function afEmpty(){return `<div class="afe"><svg class="sc" viewBox="0 0 300 178">
    <g transform="translate(62 96) scale(1.5) rotate(-6)"><path class="gh" d="${AFG}"/><text class="q" x="-5" y="20">?</text></g>
    <g transform="translate(238 96) scale(1.5) rotate(6)"><path class="gh g2" d="${AFG}"/><text class="q" x="-5" y="20">?</text></g>
    <g class="me"><g transform="translate(150 84) scale(1.9)"><path class="ar wv" d="M-14 6 Q-25 -3 -23 -15"/><path class="ar" d="M14 6 Q24 -4 22 -14"/>
      <rect x="16" y="-28" width="11" height="17" rx="3" fill="#111"/><rect x="18" y="-26" width="7" height="11" rx="1.5" fill="#9ED8FF"/>
      <path d="${AFG}" fill="#61D278" stroke="#111" stroke-width="2.4" stroke-linejoin="round"/>
      <circle cx="-6.5" cy="0" r="2.4" fill="#111"/><circle cx="6.5" cy="0" r="2.4" fill="#111"/><path d="M-5 6.5q5 5 10 0" fill="none" stroke="#111" stroke-width="2.1" stroke-linecap="round"/>
      <ellipse cx="-11.5" cy="6" rx="3" ry="2" fill="#FF7FAE" opacity=".75"/><ellipse cx="11.5" cy="6" rx="3" ry="2" fill="#FF7FAE" opacity=".75"/></g></g>
    <text class="hi" x="82" y="30" transform="rotate(-8 82 30)">hi!</text></svg></div>
    <div class="aft"><b>まだ ひとり。</b><small>さいしょの 友だちを よぼう ・ 人数の 上限は ありません</small></div>
    <div class="afy"><button data-a="shake"><svg viewBox="0 0 24 24"><rect x="7.5" y="3" width="9" height="18" rx="2.4"/><path d="M3.5 9v6M20.5 9v6"/></svg>Shake</button>
      <button data-a="qr" class="pr"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg>QR ・ ID</button>
      <button data-a="link"><svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg>Link</button></div>`}
function afRow(){const V=FR.slice().sort((a,b)=>b.k-a.k).slice(0,6),more=FR.length-V.length;
  return `<div class="afw" id="afw">${V.map((f,j)=>{const i=FR.indexOf(f),T=fTimes(f);return `<button class="afk${f.k>0?' k':''}" data-i="${i}" style="--r:${[-3,2.2,-1.4,2.8,-2.2,1.6][j%6]}deg;--d:${-j*.7}s" aria-label="${f.n}">
      <i class="tp"></i><span class="ph" style="background-image:url(${fPic(f)})">${f.k>0?`<em class="tm">${T[f.k-1]}</em>`:''}</span><b class="nm">${f.n}</b>
      <span class="st">${f.k>0?'<i class="on"></i>'.repeat(f.k)+'<i></i>'.repeat(3-f.k):'<small>NOT YET</small>'}</span>
      ${f.k>0?'':`<span class="pk${POKED.has(i)?' dn':''}" data-a="poke" role="button" aria-label="${f.n} を つつく">${IHAND}</span>`}</button>`}).join('')}
    <button class="afk al" data-a="all"><svg class="mm" viewBox="-27 -22 54 46"><g transform="translate(-9 4) rotate(-8) scale(.62)"><path d="${AFG}" fill="#EE5E9C" stroke="#111" stroke-width="3" stroke-linejoin="round"/><circle cx="-6.5" cy="0" r="2.6" fill="#111"/><circle cx="6.5" cy="0" r="2.6" fill="#111"/></g><g transform="translate(9 2) rotate(8) scale(.7)"><path d="${AFG}" fill="#61D278" stroke="#111" stroke-width="3" stroke-linejoin="round"/><circle cx="-6.5" cy="0" r="2.6" fill="#111"/><circle cx="6.5" cy="0" r="2.6" fill="#111"/><path d="M-5 6.5q5 5 10 0" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round"/></g></svg>
      <b>${more>0?'+'+more:'All'}</b><small>みんな ›</small></button></div>`}
arcFriends=function(ni){const B=$('afc');if(!B)return;B.className='afc v60';const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';
  const took=FR.filter(f=>f.k>0).length,RQ=(typeof REQ!=='undefined'&&REQ)||[];
  B.innerHTML=`<div class="afh" data-a="go"><b>Friends</b>${took?`<span class="lv"><i></i>${took} shot today</span>`:''}<button class="go" aria-label="Friends を ひらく"><svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg></button></div>`+
    (RQ.length?`<button class="afq" data-a="req"><span class="avs">${RQ.slice(0,3).map(r=>`<i style="background-image:url(${fPic(r.f)})"></i>`).join('')}</span><b>${RQ[0].f.n}${RQ.length>1?' ほか':''} から 申請</b><em>承認 ›</em></button>`:'')+
    (FR.length?afRow()+`<div class="aff"><button class="ad" data-a="add"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Add</button><button class="op" data-a="go">Open friends<i><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg></i></button></div>`
      :afEmpty());
  const go=e=>{e.stopPropagation();hap('pop','ぷにっ(Friends へ)');openFriend()};
  B.querySelectorAll('[data-a="go"],[data-a="all"],[data-a="req"]').forEach(b=>b.onclick=go);
  B.querySelectorAll('[data-a="add"],[data-a="qr"]').forEach(b=>b.onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(Add)');openAdd()});
  const sh=B.querySelector('[data-a="shake"]');if(sh)sh.onclick=e=>{e.stopPropagation();hap('buzz','ブルブル(ふる)',{norip:1});const m=B.querySelector('.afe');m.animate([{transform:'translateX(0)'},{transform:'translateX(-7px) rotate(-2deg)'},{transform:'translateX(7px) rotate(2deg)'},{transform:'translateX(-4px)'},{transform:'none'}],{duration:520});setTimeout(()=>bumpBurst(m,()=>askBump()),620)};
  const lk=B.querySelector('[data-a="link"]');if(lk)lk.onclick=e=>{e.stopPropagation();hap('pop');openShare({t:'Lattag で つながろう ・ ゆい(@yui_0612)\nhttps://lattag.app/u/yui_0612',h:'ゆい'})};
  B.querySelectorAll('.afk[data-i]').forEach(c=>{const i=+c.dataset.i,f=FR[i];c.onclick=e=>{e.stopPropagation();const pk=e.target.closest('[data-a="poke"]');
    if(pk){if(!POKED.has(i))pk.classList.add('dn');fPoke2(i,c);return}hap('sel','コツッ('+f.n+')');openFC(f,c)}});
  if(ni!=null&&FR[ni]){const c=B.querySelector(`.afk[data-i="${ni}"]`);c&&c.animate([{transform:'translateY(-70px) rotate(-14deg) scale(1.2)',opacity:0},{transform:'none',opacity:1}],{duration:700,easing:'cubic-bezier(.3,1.3,.5,1)'})}
  B._in=false;afIn()};
/* 画面に 入って きたら、チェキが 上から 1枚ずつ 貼られる */
function afIn(){const B=$('afc'),hs=$('hs');if(!B||B._in||!B.offsetParent)return;const r=B.getBoundingClientRect(),h=hs.getBoundingClientRect();if(r.top>h.bottom-90*SC||r.bottom<h.top)return;B._in=true;
  if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  B.querySelectorAll('.afk').forEach((c,j)=>{c.animate([{transform:'translateY(-46px) rotate(-10deg) scale(1.12)',opacity:0},{transform:'translateY(3px) rotate(2deg) scale(1)',opacity:1,offset:.7},{transform:'none'}],{duration:560,delay:80+j*90,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'});
    if(j<4)setTimeout(()=>hap('tick','ペタ(貼る)',{norip:1}),80+j*90+380)});
  B.querySelectorAll('.afy button').forEach((c,j)=>c.animate([{transform:'translateY(20px)',opacity:0},{transform:'none',opacity:1}],{duration:420,delay:260+j*70,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}))}
$('hs').addEventListener('scroll',afIn,{passive:true});
try{renderOrb();renderArc()}catch(e){console.error(e)}/* ================= v61 ・ Home の カード = 「ぼかした みんなの 今日 + ガラスの ボタン」 =================
   ・うしろ:友だちが 今日 撮った 写真(まだ ひらかない)を ぼかして 敷き、7秒ごとに ゆっくり 入れかえる
   ・ボタンを 押している 間だけ、ぼかしが 少し 弱まる(見えそうで 見えない)
   ・はなすと カードが 白く 光って、線が はじけて、撮影へ */
var H61={built:false,shots:-1,i:0,tm:0};
const H61P=['d','b','e'];               /* まだ ひらかない「みんなの 今日」(モックでは 写真 d b e)*/
const H61Y=()=>YD.map(d=>d.p);           /* 3枚 撮りおわった あと = ひらいた きのう */
const H61D=()=>{const d=new Date();return WD[d.getDay()]+' ・ '+MON[d.getMonth()].toUpperCase()+' '+d.getDate()};
function hxArc(j,r){const a0=(-90+j*120+14)*Math.PI/180,a1=(-90+(j+1)*120-14)*Math.PI/180;return `M${(r*Math.cos(a0)).toFixed(1)} ${(r*Math.sin(a0)).toFixed(1)}A${r} ${r} 0 0 1 ${(r*Math.cos(a1)).toFixed(1)} ${(r*Math.sin(a1)).toFixed(1)}`}
function hxBuild(){const O=$('orb'),L=$('lens');if(!O||!L||H61.built)return;H61.built=true;
  const q=O.querySelector('.qsb');if(q)q.dataset.d=H61D();
  O.insertAdjacentHTML('afterbegin',`<i class="hxa" id="hxa" style="background-image:url(${PH[H61P[0]]})"></i>
    <div class="hxb" id="hxb">${H61P.map((k,i)=>`<i class="ph${i?'':' on'}" style="background-image:url(${PH[k]})"></i>`).join('')}<i class="lk"></i><i class="vg"></i><i class="gr"></i><i class="fl" id="hxfl"></i></div>`);
  L.querySelector('.lnb').insertAdjacentHTML('afterend',`<svg class="hxs" viewBox="-156 -156 312 312">
    <g class="tk">${Array.from({length:60},(_,i)=>{const a=i*6*Math.PI/180,c=Math.cos(a),s=Math.sin(a),M=i%5===0,r0=M?124:128;return `<line${M?' class="M"':''} x1="${(r0*c).toFixed(1)}" y1="${(r0*s).toFixed(1)}" x2="${(135*c).toFixed(1)}" y2="${(135*s).toFixed(1)}"/>`}).join('')}</g>
    ${[0,1,2].map(j=>`<path class="s" data-j="${j}" d="${hxArc(j,145)}"/>`).join('')}
    <g id="lry">${Array.from({length:12},(_,i)=>{const a=(i*30+15)*Math.PI/180,c=Math.cos(a),s=Math.sin(a);return `<path class="ry" d="M${(176*c).toFixed(1)} ${(176*s).toFixed(1)}L${(206*c).toFixed(1)} ${(206*s).toFixed(1)}"/>`}).join('')}</g></svg>`);
  L.insertAdjacentHTML('afterend',`<button class="hxp" id="hxp" aria-label="今日の フィルムへ"><i></i><b id="hxpt"></b><em id="hxpe"></em><svg viewBox="0 0 24 24"><path d="M12 5v14M6 13l6 6 6-6"/></svg></button>`);
  /* 押す:ピントが 合いそうに なる / はなす:白く 光って 撮影へ */
  const B=$('hxb');let dn=false;const rm=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
  L.addEventListener('pointerdown',()=>{dn=true;B.classList.add('fx')});
  const up=()=>{if(!dn)return;dn=false;B.classList.remove('fx')};['pointerleave','pointercancel'].forEach(e=>L.addEventListener(e,up));
  L.addEventListener('pointerup',()=>{if(!dn)return;up();if(rm()||!ORB||ORB.main!=='shoot')return;
    $('hxfl').animate([{opacity:0},{opacity:.85,offset:.18},{opacity:0}],{duration:420,easing:'cubic-bezier(.2,.8,.3,1)'});
    $('lry').querySelectorAll('.ry').forEach((r,i)=>r.animate([{opacity:0,transform:'scale(.84)'},{opacity:1,transform:'scale(1)',offset:.35},{opacity:0,transform:'scale(1.16)'}],{duration:440,delay:i%2*40,easing:'cubic-bezier(.2,.8,.3,1)'}))});
  /* 下の ピル */
  $('hxp').onclick=e=>{e.stopPropagation();if(shots>0){hap('pop','ぷにっ(現像を 見る)');openDvx(Math.max(0,Math.min(3,shots)-1));return}
    hap('sel','コツッ(Today へ)');const hs=$('hs'),a=$('arc');let y=560;if(a&&a.offsetParent)y=Math.max(0,(a.getBoundingClientRect().top-hs.getBoundingClientRect().top)/SC+hs.scrollTop-150);hs.scrollTo({top:y,behavior:'smooth'})};
  $('hxp').addEventListener('pointerdown',e=>{e.stopPropagation();hap('click','カチッ(おした)',{norip:1})});
  /* 7秒ごとに うしろの 写真を 入れかえる(見えて いる とき だけ)*/
  H61.tm=setInterval(()=>{if(!$('home').classList.contains('on')||dn||(window.HPG&&HPG.i!==0)||rm())return;const P=[...B.querySelectorAll('.ph')];
    H61.i=(H61.i+1)%P.length;P.forEach((p,i)=>p.classList.toggle('on',i===H61.i));$('hxa').style.backgroundImage=P[H61.i].style.backgroundImage},7000)}
function hxRender(){if(!H61.built)return;const L=$('lens'),B=$('hxb'),n=Math.min(3,shots),left=3-n,rm=matchMedia('(prefers-reduced-motion:reduce)').matches;
  L.querySelectorAll('.hxs .s').forEach(p=>p.classList.toggle('u',+p.dataset.j<n));
  $('hxpt').textContent=n===0?'tomorrow, 9:00':left?'developing':'see you at 9:00';
  $('hxpe').textContent=n===0?'':left?`${left} LEFT`:'3 / 3';
  $('hxp').querySelector('svg path').setAttribute('d',n===0?'M12 5v14M6 13l6 6 6-6':'M9 5l7 7-7 7');$('hxp').classList.toggle('dv',n>0);
  /* 3枚 撮りおわったら、うしろは「ひらいた きのう」に */
  const op=n>=3;if(op!==B.classList.contains('op')){B.classList.toggle('op',op);const ks=op?H61Y():H61P;B.querySelectorAll('.ph').forEach((p,i)=>p.style.backgroundImage=`url(${PH[ks[i%ks.length]]})`);$('hxa').style.backgroundImage=`url(${PH[ks[H61.i%ks.length]]})`}
  if(H61.shots>=0&&n>H61.shots&&!rm){const p=L.querySelector(`.hxs .s[data-j="${n-1}"]`);
    p&&p.animate([{stroke:'#fff',strokeWidth:'7',opacity:1},{stroke:'#C8F25A',strokeWidth:'14',opacity:1,offset:.3},{stroke:'rgba(255,255,255,.22)',strokeWidth:'7',opacity:1}],{duration:760,delay:350,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'});
    $('hxp').animate([{transform:'scale(1)'},{transform:'scale(1.08)'},{transform:'scale(1)'}],{duration:420,delay:700,easing:'cubic-bezier(.3,1.6,.4,1)'});
    setTimeout(()=>hap('land','トン(現像に はいった)',{norip:1}),560)}
  H61.shots=n}
{const _r=renderOrb;renderOrb=function(){_r();try{hxBuild();hxRender()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
/* Home に 入った とき:ぼかしの 奥から ピントが よって くる → ガラスが ふわっと 浮く → ピルが 上がる */
{const _hi=homeIn;homeIn=function(s){_hi(s);if(matchMedia('(prefers-reduced-motion:reduce)').matches||!H61.built)return;
  $('hxb').animate([{opacity:0,transform:'scale(1.06)',filter:'brightness(1.6)'},{opacity:1,transform:'none',filter:'none'}],{duration:900,easing:'cubic-bezier(.2,.8,.3,1)',fill:'backwards'});
  $('hxa').animate([{opacity:0},{opacity:.62}],{duration:1400,delay:200,fill:'backwards'});
  $('lens').animate([{transform:'scale(.52)',opacity:0},{transform:'scale(.72)',opacity:1,offset:.7},{transform:'scale(.69)'}],{duration:680,delay:180,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'});
  $('hxp').animate([{transform:'translateY(16px)',opacity:0},{transform:'none',opacity:1}],{duration:520,delay:760,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'});
  setTimeout(()=>hap('tick','ふわっ(浮く)',{norip:1}),640)}}
/* 横スライドの 4ページにも それぞれの 写真を ぼかして 敷く */
const H61PG={1:'d',2:'c',3:'e',4:'f'};
{const _hr=hpRender;hpRender=function(only){_hr(only);try{[1,2,3,4].forEach(i=>{if(only&&only!==i)return;const C=$('hpc'+i);if(!C||C.querySelector('.hpbg'))return;
  let k=H61PG[i];if(i===1&&FR.length)k=null;const img=k?PH[k]:fPic(FR[0]);C.insertAdjacentHTML('afterbegin',`<i class="hpbg" style="background-image:url(${img})"></i><i class="hpvg"></i>`)})}catch(e){console.error(e)}};window.hpRender=hpRender}
try{renderOrb();hpRender()}catch(e){console.error(e)}
