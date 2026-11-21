/* ===== v102(モック v103 ・ PROMPT v116):地球を やめる ・ 下の 撮る場所の 4案 ===== */
U9.zn='slot';
const U9ZM='<svg class="mn" viewBox="0 0 24 24" aria-hidden="true"><path d="M19 14.5A7.5 7.5 0 019.5 5a7.5 7.5 0 109.5 9.5z" fill="#C8F25A"/></svg>';
const U9ZCK='<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="3.5" width="14" height="17" rx="2" fill="none" stroke="#111113" stroke-width="2.2"/><rect x="7.6" y="6" width="8.8" height="8.4" rx="1" fill="#111113"/></svg>';
const U9ZSR='<svg class="sr" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2.5l2.7 6 6.5.6-4.9 4.3 1.5 6.4L12 16.5 6.2 19.8l1.5-6.4L2.8 9.1l6.5-.6z" fill="#6EC8FF" stroke="#FAFAF7" stroke-width="1.8" stroke-linejoin="round"/></svg>';
function u9Zone(st,prev){const L=st.left,used=i=>i>=L,go=i=>prev!=null&&prev>L&&i>=L&&i<prev,k=U9.zn;
  if(k==='film')return `<span class="u9zf"><span class="fr">${[0,1,2].map(i=>`<i class="${used(i)?'used':''}${go(i)?' go':''}">${st.lock&&i===1?U9ZM:''}</i>`).join('')}</span></span>`;
  if(k==='btn'){const C=2*Math.PI*44,seg=C/3-10;
    const rg=[0,1,2].map(i=>`<circle cx="48" cy="48" r="44" fill="none" stroke="${used(i)?'rgba(255,255,255,.16)':'#C8F25A'}" stroke-width="5" stroke-linecap="round" stroke-dasharray="${seg.toFixed(1)} ${(C-seg).toFixed(1)}" transform="rotate(${-90+5+i*120} 48 48)"/>`).join('');
    return `<span class="u9zb${st.lock?' lock':''}"><svg class="rg" viewBox="0 0 96 96">${rg}</svg><b>${st.lock?U9ZM:U9ZCK}</b></span>`}
  if(k==='stk')return `<span class="u9zk"><i class="tp"></i>${[0,1,2].map(i=>`<i class="u9ck${used(i)?' used':''}${go(i)?' go':''}"><u></u></i>`).join('')}${st.lock?U9ZM:''}${U9ZSR}</span>`;
  return `<span class="u9zs"><span class="ck">${[0,1,2].map(i=>`<i class="u9ck${used(i)?' in':''}${go(i)?' go':''}"><u></u></i>`).join('')}</span><span class="bd"><i class="sl"></i><i class="st"></i><i class="bt"></i><i class="ln"></i></span>${st.lock?U9ZM:''}</span>`}
(()=>{const _o=u9Shutter;u9Shutter=function(){const M=$('hmoon');const S0=M&&M.querySelector('.u9dm');const prev=S0&&S0.dataset.left!==undefined?+S0.dataset.left:null;
  _o();if(!M)return;const on=U9.zn!=='globe';M.classList.toggle('u9z',on);if(!on)return;
  const S=M.querySelector('.u9dm'),st=u9St();S.innerHTML=`<i class="grab"></i><span class="u9zz${st.n===0?' idle':''}">${u9Zone(st,prev)}</span>`}})();
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9z]'))return;
  C.insertAdjacentHTML('beforeend',['slot:★ v103 下:カメラの 口','film:★ v103 下:フィルムの 帯','btn:★ v103 下:シャッター','stk:★ v103 下:ステッカー','globe:★ v103 下:地球(いま)'].map(s=>{const i=s.indexOf(':');return `<button data-u9z="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9z]').forEach(b=>b.onclick=()=>{U9.zn=b.dataset.u9z;u9Demo('s1')})})();
window.__kit=Object.assign(window.__kit||{},{u9zn:k=>{U9.zn=k;try{renderHome()}catch(e){}}});
