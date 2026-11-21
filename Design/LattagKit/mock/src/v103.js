/* ===== v103(モック v104 ・ PROMPT v117):撮る ボタンを 下から 出さない ・ 置き場所 5案 ===== */
U9.sb='dock';
const U9SC='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 8.5A1.5 1.5 0 015.5 7H8l1.5-2h5L16 7h2.5A1.5 1.5 0 0120 8.5v9a1.5 1.5 0 01-1.5 1.5h-13A1.5 1.5 0 014 17.5z"/><circle cx="12" cy="13" r="3.4"/></svg>';
const U9SM='<svg class="mn" viewBox="0 0 24 24" aria-hidden="true"><path d="M19 14.5A7.5 7.5 0 019.5 5a7.5 7.5 0 109.5 9.5z"/></svg>';
function u9Pips(L){return `<span class="u9pp">${[0,1,2].map(i=>`<b class="${i<L?'':'off'}"></b>`).join('')}</span>`}
function u9SB(){const H=$('home');if(!H)return;const k=U9.sb,st=u9St(),ic=st.lock?U9SM:U9SC;
  const lab=st.lock?'今日は ここまで':`撮る(のこり ${st.left}枚)`;
  H.classList.toggle('u9sb',k!=='off');['dock','float','lens','top','edge'].forEach(x=>H.classList.toggle('u9sb-'+x,k===x));
  H.querySelectorAll('.u9sbf,.u9sbe').forEach(e=>e.remove());document.querySelectorAll('.u9sbd,.u9sbt,.u9sbl').forEach(e=>e.remove());
  const L=$('lens');if(L){L.classList.remove('u9sbl-on');L.onclick=null}
  const go=e=>{e&&e.stopPropagation();try{hap('shutter')}catch(_){}goShoot()};
  if(k==='dock'){const N=$('hpi');if(!N)return;const B=document.createElement('button');B.className='u9sbd';B.setAttribute('aria-label',lab);
    B.innerHTML=`<i class="u9sx">${ic}</i>${u9Pips(st.left)}`;B.onclick=go;const f=N.querySelector('button[data-i="1"]');N.insertBefore(B,f||null)}
  if(k==='float'){H.insertAdjacentHTML('beforeend',`<button class="u9sbf${st.n===0?' idle':''}" aria-label="${lab}"><span class="ph u9sx">${ic}</span>${u9Pips(st.left)}</button>`);H.querySelector('.u9sbf').onclick=go}
  if(k==='edge'){H.insertAdjacentHTML('beforeend',`<button class="u9sbe" aria-label="${lab}"><span class="u9sx">${ic}</span>${u9Pips(st.left)}</button>`);H.querySelector('.u9sbe').onclick=go}
  if(k==='lens'&&L){const C=2*Math.PI*128,seg=C/3-14;
    L.insertAdjacentHTML('beforeend',`<i class="u9sbl">${st.n===0?'<i class="pl"></i>':''}<svg viewBox="0 0 258 258">${[0,1,2].map(i=>`<circle cx="129" cy="129" r="126" fill="none" stroke="${i<st.left?'#C8F25A':'rgba(255,255,255,.18)'}" stroke-width="7" stroke-linecap="round" stroke-dasharray="${seg.toFixed(1)} ${(C-seg).toFixed(1)}" transform="rotate(${-90+7+i*120} 129 129)"/>`).join('')}</svg></i>`);
    L.classList.add('u9sbl-on');L.setAttribute('role','button');L.setAttribute('aria-label',lab);L.onclick=go}
  if(k==='top'){const T=$('hst'),P=T&&T.parentElement;if(P){P.insertAdjacentHTML('beforeend',`<button class="u9sbt" aria-label="${lab}"><span class="u9sx">${ic}</span>${u9Pips(st.left)}</button>`);P.querySelector('.u9sbt').onclick=go}}}
(()=>{const _r=renderHome;renderHome=function(){const r=_r.apply(this,arguments);try{u9SB()}catch(e){console.warn(e)}return r}})();
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9s]'))return;
  C.insertAdjacentHTML('beforeend',['dock:★ v104 撮る:ドック','float:★ v104 撮る:浮かぶ チェキ','lens:★ v104 撮る:レンズ','top:★ v104 撮る:上の 帯','edge:★ v104 撮る:左の つまみ'].map(s=>{const i=s.indexOf(':');return `<button data-u9s="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9s]').forEach(b=>b.onclick=()=>{U9.sb=b.dataset.u9s;u9Demo('s1')})})();
window.__kit=Object.assign(window.__kit||{},{u9sb:k=>{U9.sb=k;try{renderHome()}catch(e){}}});
