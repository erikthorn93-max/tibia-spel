// Rebalanserar all gathering-/crafting-XP till en jämn, konsekvent kurva.
// Mål: "actions per level" (APL) vid upplåsning hålls bunden och likartad mellan
// skills, istället för att explodera 3 → 1100+ på höga nivåer.
// reward = xp_next(level) / APL(level), där APL växer milt och linjärt med nivån.
const fs = require("fs");
const D = "data/";
const recipes = JSON.parse(fs.readFileSync(D + "recipes.json", "utf8"));
const nodes   = JSON.parse(fs.readFileSync(D + "nodes.json", "utf8"));
const skills  = JSON.parse(fs.readFileSync(D + "skills.json", "utf8"));

function xpNext(lvl, sk) {
  const d = skills[sk] || {};
  const b = d.xp_base || 50, g = d.xp_growth || 1.1;
  return b * Math.pow(g, lvl);
}
// APL = hur många handlingar en level "kostar" vid upplåsningsnivån.
// Gathering är den primära XP-källan → fler handlingar/level.
// Crafting förbrukar material (som redan gett XP) → färre handlingar, mer XP/styck.
function aplGather(lvl) { return Math.min(Math.max(Math.round(3 + 0.85 * lvl), 4), 100); }
function aplCraft(lvl)  { return Math.min(Math.max(Math.round(3 + 0.65 * lvl), 4), 85); }

// Avrunda till "snygga" tal så XP-belöningar inte blir 8237 utan ~8200.
function nice(x) {
  if (x < 50) return Math.round(x);
  if (x < 200) return Math.round(x / 5) * 5;
  if (x < 1000) return Math.round(x / 10) * 10;
  if (x < 5000) return Math.round(x / 50) * 50;
  return Math.round(x / 100) * 100;
}

let changed = 0;
// Noder (gathering)
for (const nid in nodes) {
  const n = nodes[nid];
  const r = nice(Math.max(xpNext(n.level, n.skill) / aplGather(n.level), 10));
  if (n.xp !== r) { n.xp = r; changed++; }
}
// Recept (crafting)
for (const st in recipes) for (const rec of recipes[st]) {
  const r = nice(Math.max(xpNext(rec.level, rec.skill) / aplCraft(rec.level), 12));
  if (rec.xp !== r) { rec.xp = r; changed++; }
}

fs.writeFileSync(D + "nodes.json",   JSON.stringify(nodes, null, "\t") + "\n");
fs.writeFileSync(D + "recipes.json", JSON.stringify(recipes, null, "\t") + "\n");

// ── Rapport: APL efter rebalans (ska vara ~jämn ≈ APL-målen) ────────────────
const rows = [];
for (const st in recipes) for (const r of recipes[st]) rows.push({k:"craft", s:r.skill, l:r.level, xp:r.xp});
for (const nid in nodes) { const n = nodes[nid]; rows.push({k:"gather", s:n.skill, l:n.level, xp:n.xp}); }
const apl = (r) => xpNext(r.l, r.s) / r.xp;
const med = (a) => { a = a.slice().sort((x,y)=>x-y); return a.length ? a[Math.floor(a.length/2)] : 0; };
const bands = [[1,9],[10,19],[20,29],[30,39],[40,49],[50,59],[60,69],[70,79],[80,89],[90,99]];
console.log("uppdaterade XP-värden:", changed, "\n");
console.log("LVL-band | gather APL(min-med-max) | craft APL(min-med-max)");
for (const [lo,hi] of bands) {
  const g = rows.filter(r=>r.k==="gather"&&r.l>=lo&&r.l<=hi).map(apl);
  const c = rows.filter(r=>r.k==="craft"&&r.l>=lo&&r.l<=hi).map(apl);
  const f = a => a.length ? (Math.min(...a).toFixed(0)+"-"+med(a).toFixed(0)+"-"+Math.max(...a).toFixed(0)) : "—";
  console.log(String(lo).padStart(2)+"-"+hi+"   | "+f(g).padEnd(22)+"| "+f(c));
}
// Exempel-XP vid några nivåer
console.log("\nExempel gather-XP:");
for (const lvl of [1,15,30,50,70,90,99]) console.log("  lvl "+String(lvl).padStart(2)+": "+nice(xpNext(lvl,"mining")/aplGather(lvl)));
console.log("Exempel craft-XP:");
for (const lvl of [1,15,30,50,70,90,99]) console.log("  lvl "+String(lvl).padStart(2)+": "+nice(xpNext(lvl,"smithing")/aplCraft(lvl)));
