// Usage: TZ=UTC node native/tools/golden.js index.html android/app/src/test/resources/golden.json
// Runs the web app's own engine functions (extracted from index.html) on random logs and records the results.
const fs=require('fs');
const html=fs.readFileSync(process.argv[2],'utf8');
const grab=(start,end)=>{const i=html.indexOf(start);const j=html.indexOf(end,i);if(i<0||j<0)throw new Error(start);return html.slice(i,j);};
let src = grab('const CHORE_POOL','// ─── STORAGE');
src += grab('const neglectDays','const loadCard');
src += grab('const DAY_MS','// ─── CHORE ROW');
src = src.replace(/^const DAILY_MINUTES.*$/m,'const DAILY_MINUTES = 25;');
const NOW = Date.UTC(2026,10,10,19,0,0); // fixed "now"
const RealDate = Date;
global.Date = class extends RealDate { constructor(...a){ super(...(a.length?a:[NOW])); } static now(){ return NOW; } };
eval(src + `; global.E={CHORE_POOL,neglectDays,enrichChore,pickableChores,suggestFill,getXP,getRank,getStreak,minutesByDay,recentDays,hashCode:null};`);
let seed=42; const rnd=()=>{seed=(seed*1103515245+12345)%2147483648; return seed/2147483648;};
const players=['1','2'], st=['approved','approved','approved','pending','rejected'];
const logs=[];
for(let i=0;i<400;i++){
  const c=E.CHORE_POOL[Math.floor(rnd()*E.CHORE_POOL.length)];
  const p=players[Math.floor(rnd()*2)];
  const ts=NOW - Math.floor(rnd()*45*86400000);
  const l={id:'l'+i,playerId:p,playerName:'p'+p,choreId:c.id,choreName:c.name,points:c.pts,status:st[Math.floor(rnd()*st.length)],timestamp:ts};
  if(rnd()<0.6) l.minutes=c.tiers[Math.floor(rnd()*3)];
  logs.push(l);
}
// a long current streak for player 1
for(let d=0;d<12;d++) logs.push({id:'s'+d,playerId:'1',playerName:'p1',choreId:'make-bed',choreName:'make bed',points:8,status:'approved',timestamp:NOW-d*86400000-3600000});
logs.sort((a,b)=>b.timestamp-a.timestamp); // the web app keeps logs newest-first (loadLogs)
const out={now:NOW,logs:logs.map(l=>({...l,timestamp:new RealDate(l.timestamp).getTime()})),players:{}};
for(const p of players){
  const pool=E.pickableChores(p,logs);
  const xp=E.getXP(p,logs);
  out.players[p]={
    xp, rank:E.getRank(xp), streak:E.getStreak(p,logs),
    pickable:pool.map(c=>[c.id,c.neglectDays,c.currentMinutes,c.escalLevel]),
    fillEmpty:E.suggestFill([],pool,25),
    fillKitchen:E.suggestFill(['wipe-counters'],pool,25),
    minutes:Object.fromEntries(Object.entries(E.minutesByDay(p,logs)).map(([k,v])=>[new RealDate(+k).toISOString().slice(0,10),v])),
  };
}
fs.writeFileSync(process.argv[3],JSON.stringify(out));
console.log('xp',out.players['1'].xp,out.players['2'].xp,'streak',out.players['1'].streak,out.players['2'].streak);
