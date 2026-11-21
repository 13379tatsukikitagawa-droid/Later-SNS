/* ===== v113(モック v114 ・ PROMPT v127):Home の 3つの ボタン「ニュース」3案 ===== */
U9DVK.push('np','tv','wx');
const U9WX={sun:'<svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="8" fill="#FFD84D"/><g stroke="#FFD84D" stroke-width="2.6" stroke-linecap="round">'+[0,45,90,135,180,225,270,315].map(a=>{const r=a*Math.PI/180;return `<line x1="${(20+13*Math.cos(r)).toFixed(1)}" y1="${(20+13*Math.sin(r)).toFixed(1)}" x2="${(20+17*Math.cos(r)).toFixed(1)}" y2="${(20+17*Math.sin(r)).toFixed(1)}"/>`}).join('')+'</g></svg>',
  cloud:'<svg viewBox="0 0 40 40"><path d="M11 29h19a6.500 6.500 0 00.600-13A9 9 0 0013 17.500 6 6 0 0011 29z" fill="#C9C9CF"/></svg>',
  part:'<svg viewBox="0 0 40 40"><circle cx="15" cy="15" r="7" fill="#FFD84D"/><g stroke="#FFD84D" stroke-width="2.4" stroke-linecap="round"><line x1="15" y1="2" x2="15" y2="4.500"/><line x1="2" y1="15" x2="4.500" y2="15"/><line x1="5.800" y1="5.800" x2="7.600" y2="7.600"/><line x1="24.200" y1="5.800" x2="22.400" y2="7.600"/></g><path d="M14 33h17a6 6 0 00.500-12A8 8 0 0016 22a5.500 5.500 0 00-2 11z" fill="#E4E4E8"/></svg>',
  moon:'<svg viewBox="0 0 40 40"><path d="M27 26A11 11 0 0115.500 9.500 11 11 0 1027 26z" fill="#FFD84D"/><circle cx="29" cy="11" r="1.300" fill="#FAFAF7"/><circle cx="33" cy="18" r="1" fill="#FAFAF7"/></svg>'};
function u9News(){const RQ=(typeof REQ!=='undefined'&&REQ)||[],took=FR.filter(f=>f.k>0).length,h=new Date().getHours(),open=h>=9;
  const d0=new Date(),dt=`${d0.getMonth()+1}/${d0.getDate()}`;let T=null;try{const t=(typeof G9!=='undefined'&&G9.trips)||[],now=Date.now();T=t.find(x=>x.from<=now&&x.to>=now)||null}catch(e){}
  const tday=T?Math.max(1,Math.round((Date.now()-T.from)/864e5)+1):0,n0=RQ[0]&&RQ[0].f.n;
  return {dt,
    np:{1:RQ.length?`【速報】<mark>${n0}氏</mark>${RQ.length>1?`ら${RQ.length}人`:''} 友だち申請`:took?`<mark>${took}人</mark>が撮影 9:00 解禁へ`:FR.length?'友だち、まだ <mark>誰も撮らず</mark>':'友だち <mark>募集中</mark>(本紙調べ)',
        2:T?`${T.n}の旅 <mark>${tday}日目</mark>に突入`:'旅の予定 <mark>いまだ白紙</mark>',
        3:open?'きのうの写真 <mark>ついに公開</mark>':'きのうの1枚 <mark>9:00 解禁</mark>へ'},
    tv:{1:RQ.length?`${n0}さん${RQ.length>1?`ら${RQ.length}人`:''}が 友だちに なりたい 模様。本人は「まだ 照れて いる」と コメント`:took?`友だち ${took}人が 撮影済み。9:00 に 一斉 解禁へ`:FR.length?'友だち、きょうは まだ 誰も 撮って いない もよう':'友だち 0人。関係者「さみしい」',
        2:T?`${T.n}の旅は ${tday}日目。${T.shot||0}枚を 記録`:'旅の予定は いまだ白紙。関係者は「どこか 行きたい」',
        3:open?'きのうの写真、ついに 公開。7日で 消える ため 注意':'きのうの1枚、きょう 9:00 に 解禁へ'},
    wx:{1:RQ.length?['sun','晴れ',`申請 ${RQ.length}件`]:took?['sun','晴れ',`${took}人 撮影`]:FR.length?['part','くもり','所により 撮影']:['cloud','くもり','友だち 0人'],
        2:T?['sun','旅日和',`${T.n} ・ ${tday}日目`]:['cloud','くもり','予定 なし'],
        3:open?['sun','快晴','公開中']:['moon','夜','9:00 から 晴れ']}}}
(()=>{const _dv=u9DV;u9DV=function(){_dv();const N=$('hpi');if(!N)return;const k=U9.dv;if(!['np','tv','wx'].includes(k)){N.querySelectorAll('.u9nw').forEach(e=>e.remove());return}
  const D=u9News(),lab={1:'友だち',2:'Trip',3:'きのう'};N.dataset.wx=D.dt+' 発表';
  N.querySelectorAll('button[data-i]').forEach(b=>{const n=+b.dataset.i;if(!lab[n])return;let w=b.querySelector('.u9nw');if(!w){b.insertAdjacentHTML('beforeend','<div class="u9nw"></div>');w=b.querySelector('.u9nw')}
    if(k==='np')w.innerHTML=`<div class="ms">Lattag新聞<small>${D.dt}</small></div><p class="hl">${D.np[n]}</p><div class="ft"><b>${lab[n]}</b>つづき ›</div>`;
    if(k==='tv'){w.innerHTML=`<div class="tg">${lab[n]}</div><div class="hl"><p>${D.tv[n]}</p></div><div class="ar">›</div>`;requestAnimationFrame(()=>{const s=w.querySelector('.hl p'),c=w.querySelector('.hl');b.classList.toggle('u9mq',!!(s&&c&&s.scrollWidth>c.clientWidth+4))})}
    if(k==='wx'){const [ic,t,s]=D.wx[n];w.innerHTML=`<div class="pl">${lab[n]}</div>${U9WX[ic]}<b class="w">${t}</b><small class="s">${s}</small>`}
    b.setAttribute('aria-label',lab[n]+'。'+(w.textContent||''))})}})();
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9v="np"]'))return;
  C.insertAdjacentHTML('beforeend',['np:★ v114 ニュース:新聞の 切りぬき','tv:★ v114 ニュース:テレビの 速報','wx:★ v114 ニュース:天気予報'].map(s=>{const i=s.indexOf(':');return `<button data-u9v="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9v]').forEach(b=>b.onclick=()=>{U9.dv=b.dataset.u9v;u9Demo('home')})})();
try{u9DV()}catch(e){console.warn(e)}
