/* ================= v57 グループ作成は ぜんぶ New trip に ・ 暗室の ACTIVE も Trip の 形に ================= */
openGnw=function(){openTrip()};
{const _aa=arcActive;arcActive=function(){_aa();const A=$('aact');if(!A)return;
  A.querySelectorAll('.acd[data-a="g"]').forEach(c=>{const g=GRP[+c.dataset.i];if(!g||!g.trip)return;c.classList.add('actr');
    c.innerHTML=`<i class="bg" style="background-image:url(${PH[g.cover||'a']})"></i><i class="sh2"></i><span class="mono tk">DAY ${tDayNo(g)} / ${tDays(g)}</span>
      <span class="tn">${rmEsc(g.en||tEn(g.n))}</span><span class="acj">${rmEsc(g.n)}</span>${tFilm(g)}<span class="acx"><em>${g.cnt||0}</em>/23</span>${g.un?`<span class="acu">${g.un}</span>`:''}`});
  const n=$('acnew');if(n){n.classList.add('actr-nw');n.innerHTML=`<span class="st3">${['f','b','d'].map((p,j)=>`<i style="background-image:url(${PH[p]});--r:${(j-1)*9}deg;--x:${(j-1)*16}px"></i>`).join('')}<span class="pl">${ICO.plus}</span></span><b>New trip</b><small>旅行 ・ 合宿 ・ イベント</small>`}}}
try{arcActive()}catch(e){}

/* Trip の 日付が ない ときの 守り */
{const _d=tDays,_n=tDayNo;const fix=g=>{if(!(g.from instanceof Date)||isNaN(g.from)){const d=new Date();d.setHours(0,0,0,0);g.from=new Date(+d-864e5);g.to=new Date(+d+864e5)}};
 tDays=function(g){fix(g);return _d(g)};tDayNo=function(g){fix(g);return _n(g)}}
{const _ts=tripSeed;tripSeed=function(){_ts();try{renderGroups()}catch(e){}};window.tripSeed=tripSeed}
