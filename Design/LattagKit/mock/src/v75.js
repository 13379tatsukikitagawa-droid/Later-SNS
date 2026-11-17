
/* ================= v75(PROMPT v78)・ Home = # が 主役 ================= */
function h75Build(){const O=$('orb'),L=$('lens');if(!O||!L)return;let G=O.querySelector('.h75g');
  const cx=195,cy=L.offsetTop+L.offsetHeight/2-40;  /* レンズの 中心(orb の 座標)*/
  if(!G){O.insertAdjacentHTML('afterbegin','<svg class="h75g" viewBox="0 0 390 600" aria-hidden="true"></svg>');G=O.querySelector('.h75g')}
  /* アイコンと 同じ 比:棒の 太さ 90 ・ 棒の 中心 = レンズの 中心 ± 132 ・ レンズの まわり 124 は 黒で 切る */
  const w=74,d=130,R=w/2,top=cy-d-w/2-46,bot=cy+d+w/2+34;
  G.innerHTML=`<defs><linearGradient id="h75b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D4F870"/><stop offset="1" stop-color="#B9E84A"/></linearGradient></defs><g fill="url(#h75b)">
    <rect x="-40" y="${cy-d-R}" width="470" height="${w}" rx="${R}"/><rect x="-40" y="${cy+d-R}" width="470" height="${w}" rx="${R}"/>
    <rect x="${cx-d-R}" y="${top}" width="${w}" height="${bot-top}" rx="${R}"/><rect x="${cx+d-R}" y="${top}" width="${w}" height="${bot-top}" rx="${R}"/></g>
    <circle cx="${cx}" cy="${cy}" r="126" fill="#000"/>`;
  const H=$('home');if(H&&(!H.dataset.hb||['U','K','M'].includes(H.dataset.hb)))H.dataset.hb='H'}
function h75Tag(){const h=document.querySelector('#hhd .hh');if(!h||h.querySelector('.h75t'))return;
  h.insertAdjacentHTML('beforeend','<button class="h75t" aria-label="ダブルタップで きのうへ"><i></i><span>TODAY</span><em class="tip">2回 タップで きのうへ</em><svg viewBox="0 0 12 12"><path d="M3 4.5h6.5L7.5 2.5M9 7.5H2.5l2 2"/></svg></button>');
  const B=h.querySelector('.h75t');let lt=0;B.onclick=()=>{const n=performance.now();if(n-lt>380){lt=n;hap('tick',null,{norip:1});B.classList.remove('hint');void B.offsetWidth;B.classList.add('hint');return}lt=0;const s=B.querySelector('span');hap('sel','カチ(きりかえ)');
    if(!matchMedia('(prefers-reduced-motion:reduce)').matches)s.animate([{transform:'none',opacity:1},{transform:'translateY(-8px)',opacity:0}],{duration:160,easing:'ease-in'}).onfinish=()=>{s.textContent='YESTERDAY';s.animate([{transform:'translateY(8px)',opacity:0},{transform:'none',opacity:1}],{duration:200,easing:'cubic-bezier(.3,1.3,.5,1)'})};
    setTimeout(()=>{try{openY($('dsw'))}catch(e){openY()}setTimeout(()=>{s.textContent='TODAY'},900)},260)}}
{const _r=renderOrb;renderOrb=function(){_r();try{h75Build();h75Tag()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{h75Build();h75Tag()}catch(e){}
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-hb="H"]'))return;C.insertAdjacentHTML('beforeend','<button data-hb="H">地:# (本番)</button>');C.querySelector('[data-hb="H"]').onclick=()=>{__kit.hbg('H');h75Build()}})();
