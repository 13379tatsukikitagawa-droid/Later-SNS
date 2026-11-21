/* ===== v104(モック v105 ・ PROMPT v118)===== */
U9.sb='none';
const U9WI={go:'<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
  share:'<svg viewBox="0 0 24 24"><path d="M12 15V3.5M7.5 8 12 3.5 16.5 8"/><path d="M5 12.5V19a1.5 1.5 0 001.5 1.5h11A1.5 1.5 0 0019 19v-6.5"/></svg>',
  scan:'<svg viewBox="0 0 24 24"><path d="M4 9V5.5A1.5 1.5 0 015.5 4H9M15 4h3.5A1.5 1.5 0 0120 5.5V9M20 15v3.5a1.5 1.5 0 01-1.5 1.5H15M9 20H5.5A1.5 1.5 0 014 18.5V15M7 12h10"/></svg>',
  mag:'<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg>',
  star:'<svg class="sr" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2.5l2.7 6 6.5.6-4.9 4.3 1.5 6.4L12 16.5 6.2 19.8l1.5-6.4L2.8 9.1l6.5-.6z" fill="#FAFAF7" stroke="#111113" stroke-width="1.6" stroke-linejoin="round"/></svg>'};
arcFriends=function(){const B=$('afc');if(!B)return;const A=$('arc');if(A&&A.firstElementChild!==B)A.insertBefore(B,A.firstElementChild);
  const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';B.className='afc j9af u9w';
  const RQ=REQ||[],V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0).length;
  let h=`<div class="u9wh" data-j9="open"><div><b>Friends</b>${took?`<small class="lv"><i></i>${took}人 撮った ・ 9:00 に ひらく</small>`:`<small>${FR.length?'きょうは まだ だれも':'つながると 毎朝 9:00 に 見せあえる'}</small>`}</div><button class="go" aria-label="Friends を ひらく">${U9WI.go}</button></div>`;
  if(FR.length)h+=`<div class="j9fpr j9afr">${V.map(f=>{const i=FR.indexOf(f);return `<button class="j9fa${f.k?' k':''}" data-fi="${i}"><span class="j9fav">${j9Ring(f.k)}<i style="background-image:url(${fPic(f)})"></i>${f.k===0?`<s>${J9I.hand}</s>`:''}</span><b>${f.n}</b><small>${f.k?f.k+' / 3':'まだ'}</small></button>`}).join('')}</div>`;
  if(RQ.length)h+=`<button class="j9rq" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>友だちに なりたい</small><em>確認 ›</em></button>`;
  h+=`<div class="u9wg"><button class="u9wl" data-j9="link"><i class="tp"></i><span class="ic">${U9WI.share}</span>${U9WI.star}<b class="t">リンクを 送る</b><small>LINE ・ AirDrop</small></button>
      <button class="u9wq" data-j9="qr" aria-label="QR を 見せる"><span class="qr">${tQR('@'+K9.id,120)}</span><b>QR を 見せる</b></button></div>
    <div class="u9wr"><button class="sc" data-j9="scan"><i>${U9WI.scan}</i><b>QR を 読む</b></button><button class="id" data-j9="id"><i>${U9WI.mag}</i><span>名前 か @ID</span></button></div>`;
  B.innerHTML=h;j9Acts(B);B.querySelectorAll('[data-j9="open"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(Friends)');openFriend()});
  if(!J9RM()&&!B._u9w){B._u9w=1;B.querySelectorAll('.u9wg>button,.u9wr>button').forEach((c,j)=>c.animate([{opacity:0,transform:'translateY(16px) scale(.94)'},{opacity:1,transform:'none'}],{duration:520,delay:100+j*70,easing:'cubic-bezier(.3,1.35,.5,1)',fill:'backwards'}))}};
function u9Wx(){const T=$('aact');if(!T)return;const X=T.previousElementSibling;if(X&&X.classList.contains('axh')&&!X.classList.contains('u9wx')){X.classList.add('u9wx');X.innerHTML='<b>Tr<i>ip</i></b><small>旅行 ・ 合宿 ・ イベント</small>'}
  const n=T.querySelector('.acd.nw small');if(n&&T.children.length===1)n.textContent='みんなで 撮る 2〜7日の アルバム'}
function u9NB(){const H=$('home');if(!H)return;H.classList.toggle('u9nb',U9.sb==='none')}
(()=>{const _r=renderHome;renderHome=function(){const r=_r.apply(this,arguments);try{u9NB();u9Wx()}catch(e){console.warn(e)}return r}})();
try{arcFriends();u9NB();u9Wx()}catch(e){}
