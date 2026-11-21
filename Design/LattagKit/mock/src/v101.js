/* ===== v101(PROMPT v115):ドームの 3案(# を やめる)  名前:u9 ===== */
U9.dm='fan';
const U9MN='<svg class="mn" viewBox="0 0 24 24" aria-hidden="true"><path d="M19 14.5A7.5 7.5 0 019.5 5a7.5 7.5 0 109.5 9.5z" fill="#C8F25A"/></svg>';
function u9Dome(st,prev){const L=st.left,used=i=>i>=L,go=i=>prev!=null&&prev>L&&i===L;
  if(U9.dm==='count'){const arc=[0,1,2].map(i=>{const a=(-60+i*60)*Math.PI/180,x=42+Math.sin(a)*30,y=40-Math.cos(a)*30;return `<circle cx="${x}" cy="${y-18}" r="3.2" fill="${used(i)?'rgba(255,255,255,.22)':'#C8F25A'}"/>`}).join('');
    return `<span class="u9cnt${st.lock?' lock':''}"><svg class="tk" viewBox="0 0 84 62">${arc}</svg>${st.lock?U9MN:`<b class="${prev!=null&&prev!==L?'go':''}">${L}</b>`}</span>`}
  if(U9.dm==='glow')return `<span class="u9glow">${[0,1,2].map(i=>`<i class="${used(i)?'used':''}"></i>`).join('')}${st.lock?U9MN:''}</span>`;
  return `<span class="u9fan">${[0,1,2].map(i=>`<i class="${used(i)?'used':''}${go(i)?' go':''}"><u></u></i>`).join('')}${st.lock?`<b>${U9MN}</b>`:''}</span>`}
function u9Shutter(){const M=$('hmoon'),H=$('home');if(!M||!H)return;let S=M.querySelector('.u9dm');
  if(!S){M.insertAdjacentHTML('beforeend','<span class="u9dm" aria-hidden="true"></span>');S=M.querySelector('.u9dm');u9Bind(M)}
  const st=u9St(),prev=S.dataset.left!==undefined?+S.dataset.left:null;S.dataset.left=st.left;
  S.className='u9dm'+(st.lock?' lock':'')+(st.n===0?' idle':'');
  S.innerHTML=`<i class="grab"></i>${u9Dome(st,prev)}`;
  const lab=st.lock?'今日は ここまで。あしたの 9:00 に ひらく':`今日を撮る(のこり ${st.left}枚)`;
  M.setAttribute('aria-label',lab+'。下に ひっぱると しまえる');M.setAttribute('role','button');
  let P=H.querySelector('.u9pill');if(!P){H.insertAdjacentHTML('beforeend','<div class="u9pill" role="group" aria-label="今日を撮る"></div>');P=H.querySelector('.u9pill');u9PillBind(P)}
  P.innerHTML=`<button class="u9b${st.lock?' lock':''}" data-a="shoot" aria-label="${lab}">${st.lock?U9MOON:`<b>${st.left}</b>`}</button><span class="lbl">${st.lock?'また あした':'のこり'}</span><button class="up" data-a="up" aria-label="今日を撮る を 出す">${U9UP}</button>`}
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9d]'))return;
  C.insertAdjacentHTML('beforeend',['fan:★ v102 ドーム:チェキの 扇','count:★ v102 ドーム:カウンター','glow:★ v102 ドーム:地球の 光'].map(s=>{const i=s.indexOf(':');return `<button data-u9d="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9d]').forEach(b=>b.onclick=()=>{U9.dm=b.dataset.u9d;u9Demo('s1')})})();
window.__kit=Object.assign(window.__kit||{},{u9dm:k=>{U9.dm=k;try{renderHome()}catch(e){}}});
