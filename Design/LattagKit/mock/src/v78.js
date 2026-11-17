
/* ================= v78(PROMPT v85)・ Shake を なくす ================= */
function fq78Card(big){return `<div class="fq78${big?' big':''}"><button class="fqs" data-a="myqr"><b>QR を 見せる</b><small>会った 友だちに</small><span class="qr">${tQR('@yui_0612',big?86:52).replace('class="tqr"','class="q78"')}</span></button>
  <button class="fqc" data-a="scan"><b>QR を 読む</b><small>カメラで 読む</small><span class="sn"><svg viewBox="0 0 48 48"><path d="M6 16V9a3 3 0 013-3h7M32 6h7a3 3 0 013 3v7M42 32v7a3 3 0 01-3 3h-7M16 42H9a3 3 0 01-3-3v-7"/></svg><i></i></span></button></div>`}
function fq78Fix(){const B=$('frbody');if(!B)return;const s=B.querySelector('.f65sk');if(!s)return;const big=s.classList.contains('big');s.outerHTML=fq78Card(big);
  const Q=B.querySelector('.fq78');Q.querySelector('[data-a="myqr"]').onclick=()=>{hap('pop','ぷにっ(QR)');try{openPrf()}catch(e){}setTimeout(()=>{const c=$('pck');c&&c.click()},650)};
  Q.querySelector('[data-a="scan"]').onclick=()=>{try{openScan()}catch(e){}}}
{const _f=fRender;fRender=function(ni){_f(ni);try{fq78Fix()}catch(e){console.error(e)}}}
try{openShake=function(){try{openScan()}catch(e){}}}catch(e){}
Object.assign(window.__kit||(window.__kit={}),{openShake:()=>{try{openScan()}catch(e){}}});
