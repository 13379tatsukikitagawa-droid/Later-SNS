/* ===== v109(モック v110 ・ PROMPT v123):Home の 丸 3つ の 見た目 4案 ===== */
U9.dv='au';
function u9DV(){const H=$('home'),N=$('hpi');if(!H||!N)return;['pill','cheki','ring','tile'].forEach(k=>H.classList.toggle('u9dv-'+k,U9.dv===k));
  N.querySelectorAll('button[data-i]').forEach(b=>{const i=b.querySelector('i');if(i)b.style.setProperty('--bc',i.style.getPropertyValue('--bc'))})}
(()=>{const _r=renderHome;renderHome=function(){const r=_r.apply(this,arguments);try{u9DV()}catch(e){console.warn(e)}return r}})();
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9v]'))return;
  C.insertAdjacentHTML('beforeend',['key:★ v110 丸:今(キーキャップ)','pill:★ v110 丸:ピル','cheki:★ v110 丸:チェキ','ring:★ v110 丸:リング','tile:★ v110 丸:タイル'].map(s=>{const i=s.indexOf(':');return `<button data-u9v="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9v]').forEach(b=>b.onclick=()=>{U9.dv=b.dataset.u9v;u9Demo('home')})})();
window.__kit=Object.assign(window.__kit||{},{u9dv:k=>{U9.dv=k;try{renderHome()}catch(e){}}});
try{u9DV()}catch(e){}
