
/* ================= v70(PROMPT v74)・ Home の 地 = 単色 ================= */
function h70Build(){const W=$('h65');if(!W||W.querySelector('.h70t'))return;W.insertAdjacentHTML('beforeend','<i class="h70t"></i>');const H=$('home');if(H&&!H.dataset.hb)H.dataset.hb='K'}
{const _r=renderOrb;renderOrb=function(){_r();try{h70Build()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{h70Build()}catch(e){}
Object.assign(window.__kit||(window.__kit={}),{hbg:m=>{const H=$('home');if(H)H.dataset.hb=m}});
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-hb]'))return;C.insertAdjacentHTML('beforeend',[['K','地:黒'],['G','地:深い 緑'],['L','地:黄緑']].map(([m,t])=>`<button data-hb="${m}">${t}</button>`).join(''));
  C.querySelectorAll('[data-hb]').forEach(b=>b.onclick=()=>__kit.hbg(b.dataset.hb))})();
