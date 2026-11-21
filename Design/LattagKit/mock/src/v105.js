/* ===== v105(モック v106 ・ PROMPT v119):デザインの 総点検 ===== */
const U9WD={MON:'月',TUE:'火',WED:'水',THU:'木',FRI:'金',SAT:'土',SUN:'日'},U9MO={JAN:1,FEB:2,MAR:3,APR:4,MAY:5,JUN:6,JUL:7,AUG:8,SEP:9,OCT:10,NOV:11,DEC:12};
const U9TX=[[/^(DEVELOPING|EMPTY FILM) · ([A-Z]{3}) (\d+)$/,(m,a,mo,d)=>`${a==='DEVELOPING'?'現像中':'まだ 0枚'} ・ ${U9MO[mo]||mo}/${d}`],
  [/^SHOOT$/,'撮る'],[/^shot$/,'に 撮った'],[/^start$/,'から'],[/^opens 9:00 · (.+)$/,'あと $1 で ひらく'],[/^lights out · (.+)$/,'消灯 $1'],
  [/^YESTERDAY$/,'きのう'],[/^(MON|TUE|WED|THU|FRI|SAT|SUN)$/,(m,w)=>U9WD[w]+'曜日'],[/^Moments$/,'枚'],[/^Left$/,'のこり'],[/^People ›$/,'人 ›'],[/^you\.$/,'わたし.'],
  [/^ALBUMS$/,'アルバム'],[/^7 DAYS · RECAP ›$/,'7日で 消える ・ まとめ ›'],[/^(\d+)D LEFT · (MON|TUE|WED|THU|FRI|SAT|SUN)$/,(m,n,w)=>`あと ${n}日 ・ ${U9WD[w]}`],[/^GOES TOMORROW$/,'あした 消える'],
  [/^ON THIS DAY$/,'この日'],[/^(\d+) MONTHS? AGO$/i,'$1か月 前'],[/^(\d+) days left$/i,'あと $1日'],[/^(\d+)d$/,'$1日'],[/^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC) (\d+)$/,(m,mo,d)=>`${U9MO[mo]}/${d}`],[/^(\d+)h$/,'$1時間']];
function u9Txt(root){if(!root)return;const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let n;const L=[];while(n=w.nextNode())L.push(n);
  L.forEach(n=>{const t=n.nodeValue.trim();if(!t)return;for(const [re,to] of U9TX){if(re.test(t)){const v=t.replace(re,to);if(v!==t)n.nodeValue=n.nodeValue.replace(t,v);break}}})}
function u9Fix(){const A=$('arc'),T=$('tdv');u9Txt(T);u9Txt(A);if(!A)return;
  const md=$('amd');if(md){const x=md.previousElementSibling;if(x&&x.classList.contains('axh'))x.classList.add('u9xm')}
  const mb=A.querySelector('#ayh .bt .w[data-a="mondo"]');if(mb&&!mb._u9){mb._u9=1;mb.innerHTML='きのうを ひらく';mb.setAttribute('aria-label','きのうを ひらく');mb.addEventListener('click',e=>{e.stopImmediatePropagation();hap('pop','ぷにっ(きのう)');try{openY()}catch(_){}} ,true)}}
arcFriends=function(){const B=$('afc');if(!B)return;const A=$('arc');if(A&&A.firstElementChild!==B)A.insertBefore(B,A.firstElementChild);
  const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';B.className='afc j9af u9w';
  const RQ=REQ||[],V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0).length;
  let h=`<div class="u9wh" data-j9="open"><div><b>Friends</b>${took?`<small class="lv"><i></i>${took}人 撮った ・ 9:00 に ひらく</small>`:`<small>${FR.length?'きょうは まだ だれも 撮って いない':'つながると 毎朝 9:00 に 見せあえる'}</small>`}</div><button class="go" aria-label="Friends を ひらく">${U9WI.go}</button></div>`;
  if(FR.length)h+=`<div class="j9fpr j9afr">${V.map(f=>{const i=FR.indexOf(f);return `<button class="j9fa${f.k?' k':''}" data-fi="${i}"><span class="j9fav">${j9Ring(f.k)}<i style="background-image:url(${fPic(f)})"></i>${f.k===0?`<s>${J9I.hand}</s>`:''}</span><b>${f.n}</b><small>${f.k?f.k+' / 3':'まだ'}</small></button>`}).join('')}</div>`;
  if(RQ.length)h+=`<button class="u9wrq" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><span class="tx"><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>友だちに なりたい</small></span><em>確認</em></button>`;
  h+=`<div class="u9wg"><button class="u9wl" data-j9="link"><span class="ic">${U9WI.share}</span><span class="ar">${U9WI.go}</span><b class="t">リンクを 送る</b><small>LINE ・ AirDrop</small></button>
      <button class="u9wq" data-j9="qr" aria-label="QR を 見せる"><i class="tp"></i><span class="qr">${tQR('@'+K9.id,120)}</span><b>QR を 見せる</b></button></div>
    <div class="u9wr"><button class="sc" data-j9="scan"><i>${U9WI.scan}</i><b>QR を 読む</b></button><button class="id" data-j9="id"><i>${U9WI.mag}</i><span>ID で さがす</span></button></div>`;
  B.innerHTML=h;j9Acts(B);B.querySelectorAll('[data-j9="open"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(Friends)');openFriend()});
  if(!J9RM()&&!B._u9w2){B._u9w2=1;B.querySelectorAll('.u9wrq,.u9wg>button,.u9wr>button').forEach((c,j)=>c.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:460,delay:80+j*60,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'}))}};
function u9Wx(){const T=$('aact');if(!T)return;const X=T.previousElementSibling;
  if(X&&X.classList.contains('axh')&&!X.classList.contains('u9wx2')){X.classList.add('u9wx','u9wx2');X.innerHTML=`<div><b>Trip</b><small>旅行 ・ 合宿 ・ イベントを みんなで</small></div><button class="go" aria-label="Trip を ひらく">${U9WI.go}</button>`;
    X.querySelector('.go').onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(Trip)');try{hpGo(2)}catch(_){}}}
  const n=T.querySelector('.acd.nw small');if(n&&T.children.length===1)n.textContent='2〜7日の アルバム'}
(()=>{const _r=renderHome;renderHome=function(){const r=_r.apply(this,arguments);try{u9Fix()}catch(e){console.warn(e)}return r};
  let t=0;const run=()=>{clearTimeout(t);t=setTimeout(()=>{try{u9Fix()}catch(e){}},60)};
  ['tdv','arc'].forEach(id=>{const e=$(id);if(e)new MutationObserver(run).observe(e,{childList:true,subtree:true,characterData:true})})})();
try{arcFriends();u9Wx();u9Fix()}catch(e){console.warn(e)}
