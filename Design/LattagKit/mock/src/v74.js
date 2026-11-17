
/* ================= v74(PROMPT v77)・ Home = ミニマム ================= */
function h74Build(){const O=$('orb');if(!O)return;let N=O.querySelector('.h74n');if(!N){O.insertAdjacentHTML('beforeend','<div class="h74n"><b></b><small></small></div>');N=O.querySelector('.h74n')}
  const L=$('lens');if(L)N.style.top=(L.offsetTop+L.offsetHeight/2-46+131+20)+'px';
  let n=0;try{n=shots}catch(e){}const left=Math.max(0,3-n);
  N.querySelector('b').textContent=n>=3?'きのうの 3枚が ひらいた':'タップして 撮る';
  N.querySelector('small').textContent=n>=3?'あしたの 9:00 に また':`のこり ${left}枚 ・ あしたの 9:00 に ひらく`;
  const H=$('home');if(H&&(!H.dataset.hb||H.dataset.hb==='U'||H.dataset.hb==='K'))H.dataset.hb='M'}
{const _r=renderOrb;renderOrb=function(){_r();try{h74Build()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{h74Build()}catch(e){}
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-hb="M"]'))return;C.insertAdjacentHTML('beforeend','<button data-hb="M">地:ミニマム</button>');C.querySelector('[data-hb="M"]').onclick=()=>__kit.hbg('M')})();
