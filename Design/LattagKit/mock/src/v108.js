/* ===== v108(モック v109 ・ PROMPT v122):Home の 横スライド Friends ページを しぼる ===== */
const U9FI={add:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.6"/><path d="M2.8 19.5c.5-3.4 3-5.4 6.2-5.4s5.700 2 6.2 5.400M18.500 7.500v6M15.500 10.500h6"/></svg>',go:'<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'};
function u9FrPage(){const C=$('hpc1');if(!C)return;const RQ=REQ||[],V=FR.slice().sort((a,b)=>b.k-a.k).slice(0,7),took=FR.filter(f=>f.k>0).length;
  const av=(()=>{try{const u=avUrl();return u&&u!=='none'?u:`url(${PH.c})`}catch(e){return `url(${PH.c})`}})();
  const rq=RQ.length?`<button class="u9wrq hpe" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><span class="tx"><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>友だちに なりたい</small></span><em>確認</em></button>`:'';
  let h=`<div class="u9fpt hpe"><span class="nb"></span></div><b class="u9fpT hpe">Friends</b>`;
  if(!FR.length){h+=`<small class="u9fps hpe">毎朝 9:00 に、きのうを 見せあう</small>
    <div class="u9fpv hpe" aria-hidden="true"><i class="g">+</i><span class="me" style="background-image:${av}"></span><i class="g">+</i></div>${rq}
    <button class="u9fpb hpe" data-j9="add">${U9FI.add}友だちを よぶ</button><small class="u9fph hpe">QR ・ リンク ・ @ID で つながる</small>`}
  else{h+=`<small class="u9fps hpe${took?' lv':''}">${took?`<i></i>${took}人 撮った ・ 9:00 に ひらく`:'きょうは まだ だれも 撮って いない'}</small>
    <div class="j9fpr hpe">${V.map(f=>{const i=FR.indexOf(f);return `<button class="j9fa${f.k?' k':''}" data-fi="${i}"><span class="j9fav">${j9Ring(f.k)}<i style="background-image:url(${fPic(f)})"></i>${f.k===0?`<s>${J9I.hand}</s>`:''}</span><b>${f.n}</b><small>${f.k?f.k+' / 3':'まだ'}</small></button>`}).join('')}<button class="j9fa ad" data-j9="add"><span class="j9fav"><i>+</i></span><b>よぶ</b><small>&nbsp;</small></button></div>${rq}
    <button class="u9fpb hpe" data-a="go">Friends を ひらく${U9FI.go}</button>`}
  C.className='hpc pf j9fp u9fp';C.innerHTML=h;
  const g=C.querySelector('[data-a="go"]');if(g)g.onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(Friends)');try{openY();setTimeout(()=>{Y72.tab='f';y72Render()},380)}catch(_){openFriend()}};
  j9Acts(C);try{z9QBtns()}catch(e){}}
(()=>{const _hr=hpRender;hpRender=function(only){_hr(only);try{if(only&&only!==1)return;u9FrPage()}catch(e){console.error(e)}};window.hpRender=hpRender})();
try{u9FrPage()}catch(e){console.warn(e)}
