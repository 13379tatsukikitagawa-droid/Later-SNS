
/* ================= v69(PROMPT v73)・ シャッターボタン ・ テーマカラーの レンズ ================= */
function lz69Build(){const L=$('lens');if(!L||L.querySelector('.lzc'))return;const Z=L.querySelector('.lz');if(!Z)return;
  /* ガラス ・ 輪を 黄緑 / 緑に */
  const g=Z.querySelector('#lzg');if(g)g.innerHTML='<stop offset="0" stop-color="#1d2e16"/><stop offset=".45" stop-color="#070b06"/><stop offset=".85" stop-color="#020302"/><stop offset="1" stop-color="#0c0f0b"/>';
  const cs=Z.querySelectorAll('circle');cs.forEach(c=>{const r=+c.getAttribute('r');
    if(r===137.5){c.setAttribute('stroke','#C8F25A');c.setAttribute('stroke-width','3');c.setAttribute('stroke-opacity','.9')}   /* プロの レンズの 色の 輪 */
    if(r===92)c.setAttribute('stroke','rgba(59,211,90,.16)');
    if(r===70)c.setAttribute('stroke','rgba(200,242,90,.18)')});
  const ir=document.querySelector('#irs defs');ir&&ir.insertAdjacentHTML('beforeend','<linearGradient id="ir69g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#252b22" stop-opacity=".97"/><stop offset="1" stop-color="#0a0d09" stop-opacity=".97"/></linearGradient>');
  /* まんなかの シャッターボタン */
  const bars=[372,652].map(c=>`<rect x="196" y="${c-52}" width="632" height="104" rx="52"/>`).join('')+[372,652].map(c=>`<rect x="${c-52}" y="196" width="104" height="632" rx="52"/>`).join('');
  const lr=L.querySelector('.lzr');(lr||Z).insertAdjacentHTML('afterend',`<svg class="lzc" viewBox="-156 -156 312 312" aria-hidden="true"><defs>
    <radialGradient id="lzcd" cx=".36" cy=".3" r=".8"><stop offset="0" stop-color="#EEFFB0"/><stop offset=".38" stop-color="#C8F25A"/><stop offset=".85" stop-color="#8FCB2E"/><stop offset="1" stop-color="#6FA622"/></radialGradient>
    <radialGradient id="lzcs" r=".5"><stop offset=".7" stop-color="#000" stop-opacity=".55"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs>
    <circle class="pl" r="50" fill="none" stroke="#C8F25A" stroke-width="2"/>
    <g class="rg"><circle r="50" fill="none" stroke="#C8F25A" stroke-width="5" style="filter:drop-shadow(0 0 7px rgba(200,242,90,.7))"/></g>
    <g class="bt"><circle r="46" cy="5" fill="url(#lzcs)"/><circle r="40" fill="url(#lzcd)"/><circle r="40" fill="none" stroke="rgba(255,255,255,.55)" stroke-width="1.2"/>
      <g transform="scale(.058) translate(-512 -512)" fill="#0B0C0D">${bars}</g>
      <ellipse cx="-15" cy="-21" rx="15" ry="7" fill="#fff" opacity=".55" transform="rotate(-28 -15 -21)"/></g></svg>`)}
{const _r=renderOrb;renderOrb=function(){_r();try{lz69Build();const O=$('orb');O&&(O.dataset.sh=String((window.__api&&__api.shots)||0))}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{lz69Build()}catch(e){}
