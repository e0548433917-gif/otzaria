/* כיוון תפילה — זיהוי הכיוון לפי רחוב (נתוני OpenStreetMap דרך Overpass).
   אזור שהורד פעם אחת נשמר בתיקייה הפרטית של התוסף ועובד מאז בלי אינטרנט.
   בלי רשת באוצריא אפשר לפתוח את אותה כתובת בדפדפן, לשמור את הקובץ ולטעון אותו כאן. */
const OVP=["https://overpass-api.de/api/interpreter","https://overpass.kumi.systems/api/interpreter"];
const ST={idx:[],area:null,sel:null,pan:[0,0],setHere:false,radius:1500};
const fsCall=(m,a)=>O?O.call(m,a).then(dat):Promise.reject(0);

/* ---- אחסון ---- */
async function stLoadIdx(){try{ST.idx=JSON.parse((await fsCall("fs.readFile",{path:"streets/index.json"})).content)||[]}catch(e){
 try{ST.idx=JSON.parse(localStorage.getItem("kivun-streets-idx")||"[]")}catch(e2){ST.idx=[]}}
 try{const r=dat(await O.call("storage.get",{key:"kivun-st-radius"}));if(+r)ST.radius=+r}catch(e){}
 stSettings()}
async function stSaveIdx(){const s=JSON.stringify(ST.idx);try{await fsCall("fs.writeFile",{path:"streets/index.json",content:s})}catch(e){try{localStorage.setItem("kivun-streets-idx",s)}catch(e2){}}}
async function stWriteArea(a){const s=JSON.stringify(a),p="streets/"+a.k+".json";
 try{await fsCall("fs.writeFile",{path:p,content:s})}catch(e){try{localStorage.setItem("kivun-st-"+a.k,s)}catch(e2){throw new Error("אין מקום לשמירה")}}
 ST.idx=ST.idx.filter(x=>x.k!==a.k);ST.idx.push({k:a.k,lat:a.lat,lon:a.lon,r:a.r,d:a.d,n:a.w.length,name:a.name||""});await stSaveIdx();stSettings()}
async function stReadArea(k){try{return JSON.parse((await fsCall("fs.readFile",{path:"streets/"+k+".json"})).content)}catch(e){
 try{return JSON.parse(localStorage.getItem("kivun-st-"+k))}catch(e2){return null}}}
async function stDelete(k){try{await fsCall("fs.deleteEntry",{path:"streets/"+k+".json"})}catch(e){}try{localStorage.removeItem("kivun-st-"+k)}catch(e){}
 ST.idx=ST.idx.filter(x=>x.k!==k);if(ST.area&&ST.area.k===k)ST.area=null;await stSaveIdx();stSettings();if(pos)map()}
/* האזור השמור שמכסה את המיקום (בשוליים של 150 מ' מהקצה) */
function stCover(){if(!pos)return null;let b=null;for(const a of ST.idx){const m=dist(pos,[a.lat,a.lon])*1000;if(m<=a.r-150&&(!b||m<b[1]))b=[a,m]}return b&&b[0]}

/* ---- נתונים ---- */
function stQuery(lat,lon,r){return`[out:json][timeout:60];way["highway"]["name"](around:${r},${lat.toFixed(5)},${lon.toFixed(5)});out tags geom;`}
function stUrl(i,lat,lon,r){return OVP[i]+"?data="+encodeURIComponent(stQuery(lat,lon,r))}
/* קבצי Overpass גולמיים, או קובץ שכבר נשמר מהתוסף */
function stCompact(j,lat,lon,r){if(j&&Array.isArray(j.w))return j;
 const els=(j&&j.elements||[]).filter(e=>e.type==="way"&&Array.isArray(e.geometry)&&e.geometry.length>1);
 if(!els.length)throw new Error("בקובץ אין רחובות");
 if(lat==null){let s=0,t=0,c=0;for(const e of els)for(const g of e.geometry){s+=g.lat;t+=g.lon;c++}lat=s/c;lon=t/c;
  r=0;for(const e of els)for(const g of e.geometry)r=Math.max(r,dist([lat,lon],[g.lat,g.lon])*1000);r=Math.round(r)}
 const w=els.map(e=>{const t=e.tags||{};return[t["name:he"]||t.name||"",t.highway||"",e.geometry.flatMap(g=>[+g.lat.toFixed(6),+g.lon.toFixed(6)])]});
 return{v:1,k:lat.toFixed(3)+"_"+lon.toFixed(3)+"_"+r,lat:+lat.toFixed(5),lon:+lon.toFixed(5),r,d:new Date().toISOString().slice(0,10),w}}
async function stDownload(){if(!pos)return;const m=$("stMsg");m.textContent="מוריד את רחובות האזור…";$("stDl").disabled=true;let j=null,err="";
 for(let i=0;i<OVP.length&&!j;i++){try{j=await getJ(stUrl(i,pos[0],pos[1],ST.radius))}catch(e){err=e}}
 $("stDl").disabled=false;
 if(!j){m.textContent="ההורדה לא הצליחה. ייתכן שאין חיבור, או שאוצריא עדיין לא מתירה את הכתובת. אפשר להשתמש בדרך שבלי אינטרנט שמתחת.";return}
 try{const a=stCompact(j,pos[0],pos[1],ST.radius);a.name=place||src;await stWriteArea(a);ST.area=a;m.textContent=`נשמרו ${a.w.length} רחובות. מעכשיו האזור זמין גם בלי אינטרנט.`;map()}
 catch(e){m.textContent="שמירת האזור נכשלה: "+(e.message||"שגיאה")}}
async function stImport(){const m=$("stMsg");let txt=null;
 if(O){try{const r=dat(await O.call("fs.pickUserFile",{title:"בחר את קובץ הרחובות ששמרת"}));if(!r||r.cancelled)return;
   txt=dat(await O.call("fs.readTextFile",{token:r.token}))}catch(e){m.textContent="לא ניתן לפתוח את הקובץ.";return}}
 else{txt=await new Promise(res=>{const f=document.createElement("input");f.type="file";f.onchange=()=>f.files[0]?f.files[0].text().then(res):res(null);f.click()});if(txt==null)return}
 try{const a=stCompact(JSON.parse(txt));await stWriteArea(a);ST.area=a;m.textContent=`נטענו ${a.w.length} רחובות ונשמרו לשימוש בלי אינטרנט.`;
  if(!pos||dist(pos,[a.lat,a.lon])*1000>a.r)setPos([a.lat,a.lon],"מרכז אזור הרחובות שנטען",null,false);else map()}
 catch(e){m.textContent="הקובץ אינו קובץ רחובות תקין. ודא ששמרת את כל הטקסט שהדפדפן הציג."}}
function stBrowser(){if(!pos)return;const url=stUrl(0,pos[0],pos[1],ST.radius);$("stUrl").textContent=url;$("stUrlBox").hidden=false;
 if(O)O.call("app.openUrl",{url}).catch(()=>{});else try{window.open(url,"_blank")}catch(e){}}

/* ---- ציור ---- */
const stM=()=>[111320*Math.cos(pos[0]*R),110540];
function stView(){const hw=300/zoom,[kx,ky]=stM();return{hw,hh:hw*.8,kx,ky,cx:ST.pan[0],cy:ST.pan[1]}}
function stXY(v,la,lo){const x=(lo-pos[1])*v.kx-v.cx,y=(la-pos[0])*v.ky-v.cy;return[200+x*200/v.hw,160-y*160/v.hh]}
async function streetMap(){const svg=$("map"),panel=$("stPanel");panel.hidden=false;const cov=stCover();
 if(!cov){ST.area=null;svg.innerHTML=`<text x="200" y="150" text-anchor="middle" font-size="14" fill="var(--color-on-surface)">אין עדיין מפת רחובות לאזור הזה</text><text x="200" y="174" text-anchor="middle" font-size="12" fill="var(--color-on-surface-dim)">אפשר להוריד אותה פעם אחת בכפתור שמתחת</text>`;
  $("stNone").hidden=false;$("stTxt").textContent="";return}
 $("stNone").hidden=true;
 if(!ST.area||ST.area.k!==cov.k){ST.area=await stReadArea(cov.k);ST.sel=null;if(!ST.area){svg.innerHTML="";$("stTxt").textContent="קובץ האזור חסר. הורד אותו שוב.";return}}
 const v=stView(),b=bear(),P=(la,lo)=>stXY(v,la,lo),f=n=>n.toFixed(1);let lines="",labels="",hl="";
 for(let i=0;i<ST.area.w.length;i++){const[nmS,hw,g]=ST.area.w[i];let d="",best=null,bx=[1e9,-1e9,1e9,-1e9];
  for(let k=0;k<g.length;k+=2){const p=P(g[k],g[k+1]);bx=[Math.min(bx[0],p[0]),Math.max(bx[1],p[0]),Math.min(bx[2],p[1]),Math.max(bx[3],p[1])];d+=(k?"L":"M")+f(p[0])+","+f(p[1]);
   if(k){const q=P(g[k-2],g[k-1]),L=Math.hypot(p[0]-q[0],p[1]-q[1]);if(!best||L>best[0])best=[L,q,p]}}
  if(bx[1]<-50||bx[0]>450||bx[3]<-50||bx[2]>370)continue;const big=/^(motorway|trunk|primary|secondary)/.test(hw);
  lines+=`<path d="${d}" fill="none" stroke="var(--color-on-surface-dim)" stroke-opacity=".75" stroke-width="${big?4:2.5}" stroke-linecap="round" stroke-linejoin="round"/>`;
  if(best&&best[0]>70&&nmS){let a=Math.atan2(best[2][1]-best[1][1],best[2][0]-best[1][0])/R;if(a>90)a-=180;if(a<-90)a+=180;
   const cl=x=>Math.max(15,Math.min(385,x)),mx=cl((best[1][0]+best[2][0])/2),my=Math.max(15,Math.min(300,(best[1][1]+best[2][1])/2));
   labels+=`<text transform="translate(${f(mx)},${f(my)}) rotate(${f(a)})" y="-5" text-anchor="middle" font-size="11" fill="var(--color-on-surface)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">${esc(nmS)}</text>`}}
 if(ST.sel){const g=ST.area.w[ST.sel.i][2],q=P(g[ST.sel.k],g[ST.sel.k+1]),p=P(g[ST.sel.k+2],g[ST.sel.k+3]);
  hl=`<line x1="${f(q[0])}" y1="${f(q[1])}" x2="${f(p[0])}" y2="${f(p[1])}" stroke="var(--color-primary)" stroke-width="7" stroke-linecap="round"/>`}
 const a=P(pos[0],pos[1]),L=150,e=[a[0]+Math.sin(b*R)*L,a[1]-Math.cos(b*R)*L];
 svg.innerHTML=lines+hl+labels+`<line x1="${f(a[0])}" y1="${f(a[1])}" x2="${f(e[0])}" y2="${f(e[1])}" stroke="var(--color-primary)" stroke-width="3" stroke-dasharray="8 4"/><circle cx="${f(e[0])}" cy="${f(e[1])}" r="6" fill="var(--color-primary)"/>`
  +`<text x="${f(e[0])}" y="${f(e[1]-9)}" text-anchor="middle" font-size="12" fill="var(--color-on-surface)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">לירושלים</text>`
  +`<circle cx="${f(a[0])}" cy="${f(a[1])}" r="6" fill="var(--color-on-surface)" stroke="var(--color-surface)" stroke-width="2"/>`
  +`<text x="392" y="18" direction="rtl" text-anchor="start" font-size="12" fill="var(--color-on-surface-dim)">↑ צפון · ${Math.round(v.hw*2)} מ' לרוחב</text>`
  +`<text x="8" y="312" direction="ltr" text-anchor="start" font-size="10" fill="var(--color-on-surface-dim)">© OpenStreetMap contributors · ${esc(ST.area.d||"")}</text>`;
 stText()}
/* ההוראה: לאורך איזה רחוב לעמוד, ובכמה מעלות להסתובב ממנו */
function stText(){const t=$("stTxt");if(!ST.sel){t.textContent=ST.setHere?"לחץ במפה על המקום שבו אתה נמצא.":"לחץ במפה על הרחוב שלידך, ותקבל הוראה ביחס לכיוון שלו.";return}
 const g=ST.area.w[ST.sel.i][2],k=ST.sel.k,s=bearing([g[k],g[k+1]],[g[k+2],g[k+3]]),b=bear(),
  d1=((b-s+540)%360)-180,d2=((b-s+360)%360)-180,[sd,d]=Math.abs(d1)<=Math.abs(d2)?[s,d1]:[(s+180)%360,d2],n=ST.area.w[ST.sel.i][0]||"הרחוב";
 const turnS=Math.abs(d)<5?"וזה הכיוון.":`והסתובב ${Math.round(Math.abs(d))}° ${d>0?"ימינה":"שמאלה"}.`;
 t.textContent=`עמוד במקביל ל${n}, כשפניך לאורך הרחוב לכיוון ${nm(sd)}, ${turnS}`+(Math.abs(Math.abs(d)-90)<8?` (כמעט ניצב לרחוב: פנים אל הבתים שבצד ה${nm(b)} שלו.)`:"")}
function stClick(ev){if(!ST.area||!pos)return;const svg=$("map"),pt=svg.createSVGPoint();pt.x=ev.clientX;pt.y=ev.clientY;
 const c=pt.matrixTransform(svg.getScreenCTM().inverse()),v=stView();
 if(ST.setHere){const x=(c.x-200)*v.hw/200+v.cx,y=(160-c.y)*v.hh/160+v.cy,[kx,ky]=stM(),np=[pos[0]+y/ky,pos[1]+x/kx];
  ST.setHere=false;$("stHere").classList.remove("on");ST.pan=[0,0];zoomKeep(()=>setPos(np,"נקודה שסומנה במפת הרחובות",null,false));
  mode="m:"+np[0].toFixed(6)+","+np[1].toFixed(6);save(mode);return}
 let best=null;ST.area.w.forEach(([,,g],i)=>{for(let k=0;k+3<g.length;k+=2){const q=stXY(v,g[k],g[k+1]),p=stXY(v,g[k+2],g[k+3]),dx=p[0]-q[0],dy=p[1]-q[1],
  u=Math.max(0,Math.min(1,((c.x-q[0])*dx+(c.y-q[1])*dy)/(dx*dx+dy*dy||1))),dd=Math.hypot(q[0]+u*dx-c.x,q[1]+u*dy-c.y);if(!best||dd<best[0])best=[dd,i,k]}});
 if(best&&best[0]<14){ST.sel={i:best[1],k:best[2]};streetMap()}}
function zoomKeep(fn){const z=zoom;fn();zoom=z;map()}

/* ---- הגדרות: האזורים השמורים והסבר לעבודה בלי אינטרנט ---- */
function stSettings(){const l=$("stList");if(!l)return;l.replaceChildren();
 if(!ST.idx.length){const li=document.createElement("li");li.textContent="עדיין לא נשמר אף אזור.";l.append(li)}
 for(const a of ST.idx){const li=document.createElement("li"),x=document.createElement("button");
  li.textContent=`${a.name||a.lat+", "+a.lon} — ${a.n} רחובות, ברדיוס ${a.r>=1000?(a.r/1000)+' ק"מ':a.r+" מ'"} (${a.d}) `;
  x.textContent="מחק";x.onclick=()=>stDelete(a.k);li.append(x);l.append(li)}
 $("stRad").value=String(ST.radius)}

/* ---- חיבור לממשק ---- */
(function(){const prevMap=map;
 map=function(){if($("mapMode").value==="street"&&pos)return streetMap();$("stPanel").hidden=true;return prevMap()};
 $("mapMode").onchange=()=>map(); $("stDl").onclick=stDownload;$("stImp").onclick=stImport;$("stBrw").onclick=stBrowser;
 $("stHere").onclick=()=>{ST.setHere=!ST.setHere;$("stHere").classList.toggle("on",ST.setHere);stText()};
 $("stRad").onchange=()=>{ST.radius=+$("stRad").value;try{O&&O.call("storage.set",{key:"kivun-st-radius",value:ST.radius}).catch(()=>{})}catch(e){}};
 $("bSet").onclick=()=>{const o=$("set").hidden;pop("bHelp","help",false);pop("bFb","fb",false);pop("bSet","set",o)};
 const svg=$("map");let drag=null,moved=false;
 svg.addEventListener("pointerdown",e=>{if($("mapMode").value!=="street"||!ST.area)return;drag=[e.clientX,e.clientY,ST.pan[0],ST.pan[1]];moved=false});
 svg.addEventListener("pointermove",e=>{if(!drag)return;const r=svg.getBoundingClientRect(),v=stView(),dx=(e.clientX-drag[0])*400/r.width,dy=(e.clientY-drag[1])*320/r.height;
  if(Math.hypot(dx,dy)>4)moved=true;if(moved){ST.pan=[drag[2]-dx*v.hw/200,drag[3]+dy*v.hh/160];streetMap()}});
 addEventListener("pointerup",e=>{if(drag&&!moved&&e.target&&svg.contains(e.target))stClick(e);drag=null});
 const zr=$("zReset").onclick;$("zReset").onclick=()=>{ST.pan=[0,0];zr()};
 stLoadIdx();if(O)O.on("plugin.boot",()=>stLoadIdx())})();
