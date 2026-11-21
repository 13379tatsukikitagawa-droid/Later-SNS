/* ===== v106(モック v107 ・ PROMPT v120):丸 3つ ・ スクロールで 小さく ===== */
const U9MUP='<svg viewBox="0 0 24 24"><path d="M12 19V5M6 11l6-6 6 6"/></svg>';
function u9Mini(){const H=$('home'),N=$('hpi'),S=$('hs');if(!H||!N||!S)return;let M=H.querySelector('.u9md');
  if(!M){H.insertAdjacentHTML('beforeend','<nav class="u9md" aria-label="ページ(小)"></nav>');M=H.querySelector('.u9md');
    M.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;e.stopPropagation();
      if(b.classList.contains('up')){hap('tick');S.scrollTo({top:0,behavior:J9RM()?'auto':'smooth'});return}
      hap('pop','ぷにっ(小さな 丸)');const t=N.querySelector(`button[data-i="${b.dataset.i}"]`);S.scrollTo({top:0,behavior:'auto'});if(t)t.click()});
    let on=false;const chk=()=>{const v=S.scrollTop>150;if(v!==on){on=v;H.classList.toggle('u9mini',v&&U9.sb==='none');if(v)try{hap('notch',null,{norip:1})}catch(_){}}};
    S.addEventListener('scroll',chk,{passive:true});chk()}
  M.innerHTML=[1,2,3].map(i=>{const b=N.querySelector(`button[data-i="${i}"]`);if(!b)return '';const ic=b.querySelector('i');return `<button data-i="${i}" aria-label="${b.getAttribute('aria-label')}" style="--bc:${ic.style.getPropertyValue('--bc')}">${ic.innerHTML}</button>`}).join('')+`<button class="up" aria-label="上へ もどる">${U9MUP}</button>`}
(()=>{const _r=renderHome;renderHome=function(){const r=_r.apply(this,arguments);try{u9Mini()}catch(e){console.warn(e)}return r}})();
try{u9Mini()}catch(e){console.warn(e)}
