
/* ================= v68(PROMPT v71)・ 本物の カメラの レンズ ================= */
function lz68Build(){const L=$('lens');if(!L||L.querySelector('.lz'))return;const B=L.querySelector('.lnb');if(!B)return;
  /* ギザギザ(ローレット)120本 */
  let kn='';for(let k=0;k<120;k++){const a=k*3*Math.PI/180,c=Math.cos(a),s=Math.sin(a);kn+=`M${(c*139).toFixed(1)} ${(s*139).toFixed(1)}L${(c*151).toFixed(1)} ${(s*151).toFixed(1)}`}
  const T='LATTAG ● 3 SHOTS A DAY ● OPENS 9:00 ● ';
  B.insertAdjacentHTML('afterend',`<svg class="lz" viewBox="-156 -156 312 312" aria-hidden="true"><defs>
   <linearGradient id="lzm" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f2f2f5"/><stop offset=".22" stop-color="#5b5b61"/><stop offset=".5" stop-color="#1c1c1f"/><stop offset=".74" stop-color="#7a7a80"/><stop offset="1" stop-color="#26262a"/></linearGradient>
   <radialGradient id="lzb" r=".5"><stop offset=".72" stop-color="#17171a"/><stop offset=".9" stop-color="#0c0c0e"/><stop offset="1" stop-color="#202024"/></radialGradient>
   <radialGradient id="lzg" cx=".44" cy=".38" r=".62"><stop offset="0" stop-color="#1b2433"/><stop offset=".45" stop-color="#07090d"/><stop offset=".85" stop-color="#020203"/><stop offset="1" stop-color="#0d0d10"/></radialGradient>
   <path id="lzt" d="M0 -121 A121 121 0 1 1 -0.01 -121"/></defs>
   <circle r="155" fill="url(#lzm)"/>
   <circle r="149" fill="url(#lzb)"/>
   <path d="${kn}" stroke="rgba(255,255,255,.09)" stroke-width="1.6"/>
   <circle r="137.5" fill="#0a0a0c" stroke="rgba(255,255,255,.14)" stroke-width="1"/>
   <g class="fr"><text dy="3.2"><textPath href="#lzt" startOffset="0" textLength="752" lengthAdjust="spacing">${T.replace(/3 SHOTS/,'<tspan class="g">3 SHOTS</tspan>')}${T.replace(/3 SHOTS/,'<tspan class="g">3 SHOTS</tspan>')}</textPath></text></g>
   <circle r="113" fill="url(#lzg)" stroke="#000" stroke-width="3"/>
   <circle r="111" fill="none" stroke="rgba(255,255,255,.18)" stroke-width="1"/>
   <circle r="92" fill="none" stroke="rgba(120,160,255,.10)" stroke-width="1.2"/>
   <circle r="70" fill="none" stroke="rgba(200,242,90,.10)" stroke-width="1"/>
  </svg>`);
  /* 反射(しぼりの 上 ・ カメラの 印の 下) */
  const I=$('irs');(I||L.querySelector('.lz')).insertAdjacentHTML('afterend',`<div class="lzr" aria-hidden="true"><i class="c1"></i><i class="c2"></i><i class="cg"></i><i class="hl"></i><i class="dt"></i></div><i class="lzf"></i>`);
  /* しぼりの 円を ガラスの 内側に */
  const cc=document.querySelector('#ir66c circle');cc&&cc.setAttribute('r','109');
  /* 押す ・ はなす */
  let dn=false;L.addEventListener('pointerdown',()=>{dn=true});
  L.addEventListener('pointerup',()=>{if(!dn)return;dn=false;const F=L.querySelector('.lzf');if(F&&!matchMedia('(prefers-reduced-motion:reduce)').matches)F.animate([{opacity:0,transform:'scale(.4)'},{opacity:.9,transform:'scale(1)',offset:.35},{opacity:0,transform:'scale(1.25)'}],{duration:420,easing:'cubic-bezier(.2,.7,.3,1)'})});
  ['pointerleave','pointercancel'].forEach(e=>L.addEventListener(e,()=>{dn=false}))}
/* かぎ:ボタンの 中で 描く(入る 動きも ボタン 基準)*/
function ck68Fix(){document.querySelectorAll('#odbs .odb').forEach(b=>{const W=b.querySelector('.w'),C=b.querySelector('.ck');if(W&&C&&C.parentNode!==W)W.appendChild(C)})}
{const _r=renderOrb;renderOrb=function(){_r();try{lz68Build();ck68Fix()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{lz68Build();ck68Fix()}catch(e){}
