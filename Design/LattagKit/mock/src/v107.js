/* ===== v107(モック v108 ・ PROMPT v121):Friends = マイカード ===== */
arcFriends=function(){const B=$('afc');if(!B)return;const A=$('arc');if(A&&A.firstElementChild!==B)A.insertBefore(B,A.firstElementChild);
  const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';B.className='afc j9af u9w';
  const RQ=REQ||[],V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0).length;
  const nm=(typeof OB!=='undefined'&&OB&&OB.name)||'たつき',av=(()=>{try{const u=avUrl();return u&&u!=='none'?u:`url(${PH.c})`}catch(e){return `url(${PH.c})`}})();
  let h=`<div class="u9wh" data-j9="open"><div><b>Friends</b>${took?`<small class="lv"><i></i>${took}人 撮った ・ 9:00 に ひらく</small>`:`<small>${FR.length?'きょうは まだ だれも 撮って いない':'つながると 毎朝 9:00 に 見せあえる'}</small>`}</div><button class="go" aria-label="Friends を ひらく">${U9WI.go}</button></div>`;
  if(FR.length)h+=`<div class="j9fpr j9afr">${V.map(f=>{const i=FR.indexOf(f);return `<button class="j9fa${f.k?' k':''}" data-fi="${i}"><span class="j9fav">${j9Ring(f.k)}<i style="background-image:url(${fPic(f)})"></i>${f.k===0?`<s>${J9I.hand}</s>`:''}</span><b>${f.n}</b><small>${f.k?f.k+' / 3':'まだ'}</small></button>`}).join('')}</div>`;
  if(RQ.length)h+=`<button class="u9wrq" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><span class="tx"><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>友だちに なりたい</small></span><em>確認</em></button>`;
  h+=`<div class="u9wm"><button class="u9wq" data-j9="qr" aria-label="QR を 見せる"><i class="tp"></i><span class="qr">${tQR('@'+K9.id,120)}</span><b>タップで 大きく</b></button>
      <div class="me"><span class="av" style="background-image:${av}"></span><div><b>${nm}</b><small>@${K9.id}</small></div></div>
      <button class="u9wl" data-j9="link"><span class="ic">${U9WI.share}</span><b class="t">リンクを 送る</b></button>
      <small class="u9wn">LINE ・ AirDrop ・ インスタ</small></div>
    <div class="u9wr"><button class="sc" data-j9="scan"><i>${U9WI.scan}</i><b>QR を 読む</b></button><button class="id" data-j9="id"><i>${U9WI.mag}</i><span>ID で さがす</span></button></div>`;
  B.innerHTML=h;j9Acts(B);B.querySelectorAll('[data-j9="open"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(Friends)');openFriend()});
  if(!J9RM()&&!B._u9w3){B._u9w3=1;B.querySelectorAll('.u9wrq,.u9wm,.u9wr>button').forEach((c,j)=>c.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:460,delay:80+j*60,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'}))}};
try{arcFriends()}catch(e){console.warn(e)}
