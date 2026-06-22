// Lägger till agility-hinderbanor (rena XP-noder) och thieving-stånd (XP + byte)
// som gather-noder, placerar dem i zoner intill befintliga features, och
// genererar nod-sprites. XP sätts grovt här och finjusteras av rebalance_xp.js.
const fs = require("fs"), zlib = require("zlib");
const D = "data/";
const nodes = JSON.parse(fs.readFileSync(D + "nodes.json", "utf8"));

// ── Agility-hinder (no_yield: bara XP) ──────────────────────────────────────
const AG = [
  ["log_balance",   1,  "Balansstock"],
  ["rope_swing",    10, "Repgunga"],
  ["climbing_wall", 20, "Klättervägg"],
  ["monkey_bars",   30, "Apstege"],
  ["tightrope",     40, "Lina"],
  ["zipline",       50, "Linbana"],
  ["cliff_climb",   60, "Klippvägg"],
  ["pole_vault",    70, "Stavhopp"],
  ["wind_tunnel",   80, "Vindtunnel"],
  ["sky_bridge",    90, "Himmelsbro"],
];
for (const [id, lvl, label] of AG) {
  if (nodes[id]) { console.log("! finns:", id); continue; }
  nodes[id] = { skill:"agility", level:lvl, tool:"", yields:"holy_ash", no_yield:true,
    xp:20, charges:[4,6], respawn:12, color:"#c8a060", label,
    sprite:"res://assets/sprites/nodes/"+id+".png" };
}

// ── Thieving-stånd (XP + byte) ──────────────────────────────────────────────
// {id, lvl, label, yields, [min,max]}  — saknas [min,max] ⇒ 1 st
const TH = [
  ["fruit_stall",    1,  "Fruktstånd",   "iron_coin", 5, 15],
  ["baker_stall",    8,  "Bagarstånd",   "iron_coin", 10, 24],
  ["silk_stall",     18, "Silkesstånd",  "spider_silk"],
  ["silver_stall",   28, "Silverstånd",  "iron_coin", 30, 70],
  ["gem_stall",      42, "Ädelstensstånd","gem"],
  ["spice_stall",    55, "Kryddstånd",   "iron_coin", 90, 180],
  ["magic_stall",    70, "Magistånd",    "iron_coin", 160, 320],
  ["treasure_stall", 85, "Skattstånd",   "iron_coin", 300, 600],
];
for (const [id, lvl, label, yields, mn, mx] of TH) {
  if (nodes[id]) { console.log("! finns:", id); continue; }
  const o = { skill:"thieving", level:lvl, tool:"", yields, xp:20, charges:[3,5],
    respawn:20, color:"#b85a2a", label, sprite:"res://assets/sprites/nodes/"+id+".png" };
  if (mn !== undefined) { o.yield_min = mn; o.yield_max = mx; }
  nodes[id] = o;
}

// ── Placering i zoner (intill valfri befintlig feature ⇒ nåbar) ─────────────
const PLACE = [
  ["thais_heights","log_balance"],["thais_heights","rope_swing"],
  ["thais_heights","climbing_wall"],["thais_heights","monkey_bars"],
  ["thais_wilds","tightrope"],["thais_wilds","zipline"],["thais_wilds","cliff_climb"],
  ["thais_mountains","pole_vault"],["thais_mountains","wind_tunnel"],["thais_mountains","sky_bridge"],
  ["thais_heights","fruit_stall"],["thais_heights","baker_stall"],["thais_heights","silver_stall"],
  ["thais_fields","silk_stall"],["thais_fields","gem_stall"],
  ["thais_wilds","spice_stall"],["thais_wilds","magic_stall"],["thais_wilds","treasure_stall"],
];
const CAND = "ABCDEFGHIKLMNQRSTUVYZabdghklopqsuyz#%&*+=?@$0123456789";
function loadZone(z){ return JSON.parse(fs.readFileSync(D+"zones/"+z+".json","utf8")); }
function saveZone(z,o){ fs.writeFileSync(D+"zones/"+z+".json", JSON.stringify(o,null,"\t")+"\n"); }
function usedChars(z){ const s=new Set(Object.keys(z.legend)); for(const r of z.tiles) for(const c of r) s.add(c); return s; }
function primaryFloor(z){ const lk=new Set(Object.keys(z.legend)); const f={}; for(const r of z.tiles) for(const c of r) if(!lk.has(c)) f[c]=(f[c]||0)+1; return Object.entries(f).sort((a,b)=>b[1]-a[1])[0][0]; }
function anyFeatureChar(z){ for(const k in z.legend){ const t=z.legend[k].type; if(["node","spawn","shop","npc","station","taskmaster"].includes(t)) return k; } return null; }
function firstPos(z,ch){ for(let r=0;r<z.tiles.length;r++){ const c=z.tiles[r].indexOf(ch); if(c>=0) return [r,c]; } return null; }
function setTile(z,r,c,ch){ const row=z.tiles[r]; z.tiles[r]=row.slice(0,c)+ch+row.slice(c+1); }
function freeNear(z,ar,ac,floor,occ){ for(let rad=1;rad<=20;rad++){ for(let dr=-rad;dr<=rad;dr++) for(let dc=-rad;dc<=rad;dc++){ if(Math.max(Math.abs(dr),Math.abs(dc))!==rad) continue; const r=ar+dr,c=ac+dc; if(r<1||c<1||r>=z.tiles.length-1||c>=z.tiles[0].length-1) continue; if(occ.has(r+","+c)) continue; if(z.tiles[r][c]!==floor) continue; return [r,c]; } } return null; }

const cache={}, occ={}, fails=[]; let placed=0;
for (const [zone, nid] of PLACE) {
  const z = cache[zone] || (cache[zone]=loadZone(zone));
  occ[zone] = occ[zone] || new Set();
  const anchorCh = anyFeatureChar(z);
  if (!anchorCh) { fails.push(zone+": ingen feature att ankra mot"); continue; }
  const ap = firstPos(z, anchorCh);
  const floor = primaryFloor(z);
  const used = usedChars(z);
  let ch=null; for (const cc of CAND) if (!used.has(cc)) { ch=cc; break; }
  if (!ch) { fails.push(zone+": slut på tecken"); continue; }
  const spot = freeNear(z, ap[0], ap[1], floor, occ[zone]);
  if (!spot) { fails.push(zone+"/"+nid+": ingen ledig golvruta"); continue; }
  occ[zone].add(spot[0]+","+spot[1]);
  z.legend[ch] = { type:"node", node:nid, terrain:floor };
  setTile(z, spot[0], spot[1], ch);
  placed++;
}
for (const z in cache) saveZone(z, cache[z]);
fs.writeFileSync(D+"nodes.json", JSON.stringify(nodes,null,"\t")+"\n");

// ── Nod-sprites (32x28) ─────────────────────────────────────────────────────
const NW=32, NH=28;
const crcT=(()=>{const t=[];for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=(c&1)?(0xEDB88320^(c>>>1)):(c>>>1);t[n]=c>>>0;}return t;})();
function crc(b){let c=0xFFFFFFFF;for(let i=0;i<b.length;i++)c=crcT[(c^b[i])&0xFF]^(c>>>8);return(c^0xFFFFFFFF)>>>0;}
function chunk(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length,0);const tb=Buffer.from(t);const cc=Buffer.alloc(4);cc.writeUInt32BE(crc(Buffer.concat([tb,d])),0);return Buffer.concat([l,tb,d,cc]);}
function enc(img){const raw=Buffer.alloc((NW*4+1)*NH);let p=0;for(let y=0;y<NH;y++){raw[p++]=0;for(let x=0;x<NW*4;x++)raw[p++]=img[y*NW*4+x];}const idat=zlib.deflateSync(raw,{level:9});const sig=Buffer.from([137,80,78,71,13,10,26,10]);const ih=Buffer.alloc(13);ih.writeUInt32BE(NW,0);ih.writeUInt32BE(NH,4);ih[8]=8;ih[9]=6;return Buffer.concat([sig,chunk("IHDR",ih),chunk("IDAT",idat),chunk("IEND",Buffer.alloc(0))]);}
function nimg(){return new Uint8Array(NW*NH*4);}
function px(im,x,y,c){x|=0;y|=0;if(x<0||y<0||x>=NW||y>=NH)return;const i=(y*NW+x)*4;im[i]=c[0];im[i+1]=c[1];im[i+2]=c[2];im[i+3]=c[3]===undefined?255:c[3];}
function rect(im,x,y,w,h,c){for(let j=0;j<h;j++)for(let i=0;i<w;i++)px(im,x+i,y+j,c);}
function line(im,x0,y0,x1,y1,c,th=1){x0|=0;y0|=0;x1|=0;y1|=0;let dx=Math.abs(x1-x0),dy=-Math.abs(y1-y0),sx=x0<x1?1:-1,sy=y0<y1?1:-1,e=dx+dy;while(true){for(let t=0;t<th;t++)px(im,x0+t,y0,c);if(x0===x1&&y0===y1)break;const e2=2*e;if(e2>=dy){e+=dy;x0+=sx;}if(e2<=dx){e+=dx;y0+=sy;}}}
function disc(im,cx,cy,r,c){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++)if(x*x+y*y<=r*r)px(im,cx+x,cy+y,c);}
function tri(im,x0,y0,x1,y1,x2,y2,c){const miny=Math.min(y0,y1,y2),maxy=Math.max(y0,y1,y2);for(let y=miny;y<=maxy;y++){const xs=[];[[x0,y0,x1,y1],[x1,y1,x2,y2],[x2,y2,x0,y0]].forEach(([ax,ay,bx,by])=>{if((ay<=y&&by>y)||(by<=y&&ay>y))xs.push(ax+(y-ay)/(by-ay)*(bx-ax));});xs.sort((a,b)=>a-b);for(let k=0;k<xs.length;k+=2){if(xs[k+1]===undefined)break;for(let x=Math.round(xs[k]);x<=Math.round(xs[k+1]);x++)px(im,x,y,c);}}}
function outline(im){const cp=Uint8Array.from(im);const op=(x,y)=>x>=0&&y>=0&&x<NW&&y<NH&&cp[(y*NW+x)*4+3]>40;for(let y=0;y<NH;y++)for(let x=0;x<NW;x++){if(cp[(y*NW+x)*4+3]>40)continue;if(op(x-1,y)||op(x+1,y)||op(x,y-1)||op(x,y+1))px(im,x,y,[20,18,24,255]);}}
function drawObstacle(im){ // träbalk på stolpar (agility)
  const wood=[170,120,60,255],dk=[110,78,40,255];
  rect(im,4,18,4,9,dk); rect(im,24,18,4,9,dk);            // stolpar
  rect(im,3,12,26,5,wood); rect(im,3,12,26,2,[200,150,90,255]); // balk
  for(let x=6;x<27;x+=5) line(im,x,12,x,16,dk);          // plankskarvar
  line(im,3,12,29,12,[210,160,100,255]);
}
function drawStall(im){ // marknadsstånd (thieving)
  const awn=[180,60,50,255],awn2=[230,230,220,255],wood=[150,100,55,255];
  rect(im,4,16,24,3,wood); rect(im,6,19,2,8,[110,72,40,255]); rect(im,24,19,2,8,[110,72,40,255]); // bord
  for(let i=0;i<6;i++) tri(im,4+i*4,6,8+i*4,6,6+i*4,12, i%2?awn:awn2);  // randig markis
  rect(im,4,6,24,1,[120,40,35,255]);
  disc(im,11,15,2,[230,180,60,255]); disc(im,16,15,2,[200,70,60,255]); disc(im,21,15,2,[120,180,80,255]); // varor
}
for (const [id] of AG) { const im=nimg(); drawObstacle(im); outline(im); fs.writeFileSync("assets/sprites/nodes/"+id+".png", enc(im)); }
for (const t of TH)    { const im=nimg(); drawStall(im);   outline(im); fs.writeFileSync("assets/sprites/nodes/"+t[0]+".png", enc(im)); }

console.log("agility-noder:", AG.length, "| thieving-noder:", TH.length, "| placerade:", placed);
if (fails.length) console.log("VARNINGAR:\n  "+fails.join("\n  "));
