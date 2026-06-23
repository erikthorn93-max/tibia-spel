// Breddar loot: lägger till värdesaks-items (ädelstenar, skatter, guldmynt) i
// items.json och utökar monstrens drop-tabeller tier-baserat (efter exp).
// Idempotent: redan tillagda items/drops hoppas över. Kör: node tools/expand_loot.js
const fs = require("fs");
const path = require("path");
const ROOT = path.join(__dirname, "..");
const itemsPath = path.join(ROOT, "data", "items.json");
const monPath = path.join(ROOT, "data", "monsters.json");

const items = JSON.parse(fs.readFileSync(itemsPath, "utf8"));
const mon = JSON.parse(fs.readFileSync(monPath, "utf8"));

// --- nya värdesaks-items ---
const SPR = id => `res://assets/sprites/items/${id}.png`;
const NEW_ITEMS = {
  gold_coin:       { name: "Guldmynt", type: "currency", value: 50, color: "#f0c850" },
  ruby:            { name: "Rubin", type: "material", value: 300, color: "#e0314a" },
  emerald:         { name: "Smaragd", type: "material", value: 260, color: "#22a558" },
  sapphire:        { name: "Safir", type: "material", value: 280, color: "#2a6ad0" },
  topaz:           { name: "Topas", type: "material", value: 180, color: "#e0a020" },
  amethyst:        { name: "Ametist", type: "material", value: 210, color: "#9a4ec8" },
  opal:            { name: "Opal", type: "material", value: 150, color: "#8fd0d8" },
  diamond:         { name: "Diamant", type: "material", value: 600, color: "#bfe8f0" },
  black_pearl:     { name: "Svart pärla", type: "material", value: 340, color: "#3a3550" },
  pearl:           { name: "Pärla", type: "material", value: 75, color: "#e8e4d8" },
  gold_ring:       { name: "Guldring", type: "material", value: 120, color: "#f0c850" },
  gold_necklace:   { name: "Guldhalsband", type: "material", value: 200, color: "#f0c850" },
  silver_amulet:   { name: "Silveramulett", type: "material", value: 70, color: "#cdd2da" },
  gold_nugget:     { name: "Guldklimp", type: "material", value: 95, color: "#e8b840" },
  jewelled_goblet: { name: "Juvelbägare", type: "material", value: 240, color: "#e0c060" },
  ancient_coin:    { name: "Forntida mynt", type: "material", value: 55, color: "#b8a060" },
};
let itemsAdded = 0;
for (const id in NEW_ITEMS) {
  if (items[id]) continue;
  items[id] = { ...NEW_ITEMS[id], sprite: SPR(id) };
  itemsAdded++;
}

// --- loot-breddning ---
function tier(exp) { return exp < 20 ? 0 : exp < 60 ? 1 : exp < 200 ? 2 : 3; }
// enkel deterministisk hash → variation per monster
function hash(s) { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return h; }
function pickN(arr, n, seed) { const out = []; const a = arr.slice(); for (let i = 0; i < n && a.length; i++) { const idx = (seed + i * 7) % a.length; out.push(a.splice(idx, 1)[0]); } return out; }

// tier → kandidat-värdesaker [item, chance, min, max]
const POOLS = {
  0: [["ancient_coin", 0.03, 1, 1], ["gold_nugget", 0.015, 1, 1], ["pearl", 0.012, 1, 1]],
  1: [["opal", 0.02, 1, 1], ["topaz", 0.018, 1, 1], ["gold_nugget", 0.03, 1, 1], ["ancient_coin", 0.04, 1, 2]],
  2: [["ruby", 0.022, 1, 1], ["emerald", 0.022, 1, 1], ["sapphire", 0.02, 1, 1], ["topaz", 0.03, 1, 1],
      ["amethyst", 0.025, 1, 1], ["pearl", 0.05, 1, 2], ["gold_ring", 0.03, 1, 1], ["silver_amulet", 0.04, 1, 1]],
  3: [["ruby", 0.03, 1, 2], ["emerald", 0.03, 1, 2], ["sapphire", 0.028, 1, 2], ["amethyst", 0.03, 1, 1],
      ["diamond", 0.014, 1, 1], ["black_pearl", 0.025, 1, 1], ["gold_necklace", 0.03, 1, 1], ["jewelled_goblet", 0.025, 1, 1]],
};
const GOLD = { 1: [1, 3, 0.06], 2: [3, 8, 0.12], 3: [6, 18, 0.25] };

let monTouched = 0, dropsAdded = 0;
for (const name in mon) {
  const m = mon[name];
  const loot = m.loot || (m.loot = []);
  const has = id => loot.some(e => e.item === id);
  const add = (item, chance, min, max) => { if (!has(item)) { loot.push({ item, min, max, chance }); dropsAdded++; return true; } return false; };
  const t = tier(m.exp || 0);
  const seed = hash(name);
  let touched = false;

  // Bossar FÖRST: garanterad guldhög + sällsynt diamant + skatt (tar precedens
  // över tier-poolen så de inte degraderas till svagare dubbletter).
  if (m.boss) {
    if (add("gold_coin", 1.0, 20, 60)) touched = true;
    if (add("diamond", 0.2, 1, 1)) touched = true;
    if (add("jewelled_goblet", 0.4, 1, 1)) touched = true;
  }
  // Värdesaker per tier (gold_coin för t1+; en liten chans-pool för alla tiers)
  if (t >= 1) {
    const [gmin, gmax, gch] = GOLD[t];
    if (add("gold_coin", gch, gmin, gmax)) touched = true;
  }
  const pool = POOLS[t];
  const picks = pickN(pool, t <= 1 ? 1 : 2, seed);
  for (const [item, chance, min, max] of picks) if (add(item, chance, min, max)) touched = true;
  if (touched) monTouched++;
}

fs.writeFileSync(itemsPath, JSON.stringify(items, null, "\t") + "\n");
fs.writeFileSync(monPath, JSON.stringify(mon, null, "\t") + "\n");
console.log(`Nya items: ${itemsAdded} | monster berörda: ${monTouched} | nya drops: ${dropsAdded}`);
