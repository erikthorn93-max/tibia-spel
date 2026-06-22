// Brett skill-innehållslyft 1–100. Genererar items/noder/recept, fäster ben-drops,
// placerar gathering-noder intill befintliga samma-skill-noder (nåbara), validerar.
const fs = require("fs");
const D = "data/";
const items = JSON.parse(fs.readFileSync(D + "items.json", "utf8"));
const nodes = JSON.parse(fs.readFileSync(D + "nodes.json", "utf8"));
const recipes = JSON.parse(fs.readFileSync(D + "recipes.json", "utf8"));
const monsters = JSON.parse(fs.readFileSync(D + "monsters.json", "utf8"));

const SPR = (id) => "res://assets/sprites/items/" + id + ".png";
function addItem(id, obj) {
  if (items[id]) { console.log("  ! item finns redan:", id); return; }
  if (obj.sprite === undefined && obj.type !== undefined) obj.sprite = SPR(id);
  items[id] = obj;
}
function mat(id, name, value, color)   { addItem(id, {name, type:"material", value, color}); }
function food(id, name, value, heal, color, buff) { const o={name, type:"food", value, color, heal}; if(buff)o.buff=buff; addItem(id,o); }
function potion(id, name, value, color, extra) { addItem(id, Object.assign({name, type:"potion", value, color}, extra)); }
function ammo(id, name, value, color)  { addItem(id, {name, type:"ammo", value, color, slot:"ammo"}); }
function bow(id, name, value, color, atk, ammoId) { addItem(id, {name, type:"weapon", value, color, atk, skill:"distance", slot:"weapon", range:5, ammo:ammoId}); }
function weapon(id, name, value, color, atk, skill) { addItem(id, {name, type:"weapon", value, color, atk, skill, slot:"weapon"}); }
function armor(id, name, value, color, slot, stat, amount) { const o={name, type:"armor", value, color, slot}; o[stat]=amount; addItem(id,o); }
function furniture(id, name, value, color) { addItem(id, {name, type:"furniture", value, color}); }

// ── MATERIAL ──────────────────────────────────────────────────────────────
mat("coal","Kol",12,"#2b2b2b");
mat("maple_log","Lönnstock",35,"#b5651d");
mat("yew_log","Idegranssock",60,"#4a5a2a");
mat("magic_log","Magisk stock",120,"#4aa0d0");
mat("elder_log","Äldstestock",220,"#6a4a7a");
mat("mithril_ore","Mithrilmalm",55,"#4a6a8a");
mat("adamant_ore","Adamantmalm",90,"#3a7a5a");
mat("runite_ore","Runmalm",160,"#2a8a8a");
mat("dragon_ore","Drakmalm",300,"#8a2a2a");
mat("maple_plank","Lönnplanka",40,"#c5751d");
mat("yew_plank","Idegransplanka",70,"#5a6a3a");
mat("magic_plank","Magisk planka",140,"#5ab0e0");
mat("elder_plank","Äldsteplanka",250,"#7a5a8a");
mat("fox_fur","Rävpäls",40,"#c87a3a");
mat("bear_pelt","Björnpäls",90,"#6a4a2a");
mat("chimera_hide","Chimärhud",200,"#7a3a5a");
mat("big_bones","Stora ben",8,"#d8d0bc");
mat("dragon_bones","Drakben",60,"#d0c0a0");
mat("holy_ash","Helig aska",6,"#f0e8c0");
mat("sunflower_herb","Solrosört",30,"#e0c040");
mat("bloodleaf_herb","Blodbladsört",55,"#a02030");
mat("frostpetal_herb","Frostkronört",80,"#9ad8ff");
mat("dragonherb","Drakört",140,"#c84a2a");
mat("raw_manta","Rå mantarocka",70,"#3a5a7a");
mat("raw_anglerfish","Rå marulk",95,"#4a3a5a");
mat("raw_dark_crab","Rå mörkkrabba",120,"#3a2a3a");
mat("raw_kingfish","Rå kungsfisk",160,"#caa840");

// ── GRÖDOR (mat, råa men ätbara) ────────────────────────────────────────────
food("potato","Potatis",8,15,"#c8a060");
food("cabbage","Kål",12,22,"#5a9a4a");
food("corn","Majs",18,30,"#e0c040");
food("pumpkin","Pumpa",30,45,"#e08020");
food("golden_apple","Gyllene äpple",80,90,"#f0d040",{stat:"skill:farming",amount:5,duration:180});

// ── TILLAGAD MAT ────────────────────────────────────────────────────────────
food("baked_potato","Bakad potatis",16,40,"#caa56a");
food("cabbage_stew","Kålsoppa",30,75,"#6aa84a");
food("corn_bread","Majsbröd",40,95,"#e8c860");
food("pumpkin_pie","Pumpapaj",70,125,"#e8902a");
food("golden_apple_pie","Gyllene äppelpaj",180,170,"#f0d850",{stat:"skill:cooking",amount:6,duration:240});
food("cooked_manta","Stekt mantarocka",170,200,"#5a7a9a",{stat:"skill:fishing",amount:6,duration:200});
food("cooked_anglerfish","Stekt marulk",210,230,"#6a5a7a",{stat:"max_hp",amount:30,duration:240});
food("cooked_dark_crab","Stekt mörkkrabba",250,260,"#5a4a5a",{stat:"max_hp",amount:40,duration:240});
food("cooked_kingfish","Stekt kungsfisk",300,300,"#e8c860",{stat:"skill:fishing",amount:8,duration:240});

// ── DRYCKER ─────────────────────────────────────────────────────────────────
potion("divine_health_potion","Gudomlig hälsodryck",240,"#ff3050",{heal:200});
potion("ranging_potion","Distansdryck",120,"#3aa84a",{buff_stat:"skill:distance",buff_amount:6,buff_duration:120});
potion("magic_potion","Magidryck",150,"#4a6ad0",{buff_stat:"skill:magic",buff_amount:6,buff_duration:120});
potion("super_strength_potion","Superstyrkedryck",180,"#d04020",{buff_stat:"atk",buff_amount:10,buff_duration:120});
potion("prayer_potion","Bönedryck",200,"#f0e070",{buff_stat:"skill:prayer",buff_amount:6,buff_duration:150});
potion("frost_resist_potion","Frostskyddsdryck",230,"#9ad8ff",{heal:60,buff_stat:"def",buff_amount:8,buff_duration:120});
potion("dragon_potion","Drakdryck",320,"#c84a2a",{heal:150,buff_stat:"atk",buff_amount:12,buff_duration:150});
potion("overload_potion","Överbelastningsdryck",450,"#e040e0",{heal:120,buff_stat:"atk",buff_amount:16,buff_duration:180});

// ── PILAR ───────────────────────────────────────────────────────────────────
ammo("maple_arrow","Lönnpil",4,"#b5651d");
ammo("yew_arrow","Idegranspil",6,"#4a5a2a");
ammo("magic_arrow","Magisk pil",10,"#4aa0d0");
ammo("elder_arrow","Äldstepil",16,"#6a4a7a");
bow("maple_bow","Lönnbåge",600,"#b5651d",20,"maple_arrow");
bow("yew_bow","Idegransbåge",900,"#4a5a2a",26,"yew_arrow");
bow("magic_bow","Magisk båge",1400,"#4aa0d0",34,"magic_arrow");
bow("elder_bow","Äldstebåge",2200,"#6a4a7a",42,"elder_arrow");

// ── SMIDESUTRUSTNING (per nivåtier) ─────────────────────────────────────────
const smithTiers = [
  {p:"mithril",  name:"Mithril",  color:"#4a6a8a", atk:24, body:10, head:6,  legs:8,  sh:6},
  {p:"adamant",  name:"Adamant",  color:"#3a7a5a", atk:30, body:13, head:8,  legs:10, sh:8},
  {p:"runite",   name:"Run",      color:"#2a8a8a", atk:38, body:16, head:10, legs:13, sh:10},
  {p:"dragon",   name:"Drak",     color:"#8a2a2a", atk:46, body:20, head:13, legs:16, sh:13},
];
for (const t of smithTiers) {
  weapon(t.p+"_sword", t.name+"svärd",      t.atk*22, t.color, t.atk, "sword");
  armor (t.p+"_helmet", t.name+"hjälm", t.head*40, t.color, "helmet","armor", t.head);
  armor (t.p+"_platebody", t.name+"harnesk", t.body*45, t.color, "body","armor", t.body);
  armor (t.p+"_legs", t.name+"benskydd",     t.legs*42, t.color, "legs","armor", t.legs);
  armor (t.p+"_shield", t.name+"sköld",       t.sh*45,  t.color, "offhand","shielding_bonus", t.sh);
}

// ── HANTVERK (päls/ädelsten) ────────────────────────────────────────────────
armor("fox_cloak","Rävmantel",120,"#c87a3a","body","def_bonus",6);
armor("bear_body","Björnrustning",260,"#6a4a2a","body","armor",9);
armor("chimera_robe","Chimärrobe",600,"#7a3a5a","body","armor",14);
armor("gem_ring","Ädelstensring",400,"#c084fc","ring","armor",3);
armor("gem_amulet","Ädelstensamulett",700,"#c084fc","amulet","armor",6);

// ── MÖBLER (construction) ───────────────────────────────────────────────────
furniture("maple_table","Lönnbord",120,"#c5751d");
furniture("yew_wardrobe","Idegransgarderob",260,"#5a6a3a");
furniture("magic_lectern","Magisk pulpet",520,"#5ab0e0");
furniture("elder_throne","Äldstetron",1100,"#7a5a8a");

// ── PRAYER-output ───────────────────────────────────────────────────────────
armor("blessed_charm","Välsignad amulett",300,"#f0e8c0","amulet","armor",4);
armor("holy_symbol","Helig symbol",650,"#f4ecc8","amulet","armor",7);

// ── GATHERING-NODER ─────────────────────────────────────────────────────────
function node(id, skill, level, tool, yields, xp, color, label, charges, respawn, extra) {
  if (nodes[id]) { console.log("  ! nod finns redan:", id); return; }
  const o = {skill, level, tool, yields, xp, charges: charges||[3,5], respawn: respawn||45, color, label};
  if (extra) Object.assign(o, extra);
  nodes[id] = o;
}
// woodcutting
node("maple_tree","woodcutting",45,"hatchet","maple_log",90,"#b5651d","Lönn",[3,5],55);
node("yew_tree","woodcutting",60,"hatchet","yew_log",130,"#4a5a2a","Idegran",[3,5],70);
node("magic_tree","woodcutting",75,"hatchet","magic_log",175,"#4aa0d0","Magiskt träd",[2,4],90);
node("elder_tree","woodcutting",90,"hatchet","elder_log",230,"#6a4a7a","Äldsteträd",[2,3],120);
// mining
node("coal_vein","mining",25,"pickaxe","coal",50,"#2b2b2b","Kolådra",[4,6],40);
node("mithril_vein","mining",40,"pickaxe","mithril_ore",90,"#4a6a8a","Mithrilådra",[3,5],60);
node("adamant_vein","mining",55,"pickaxe","adamant_ore",130,"#3a7a5a","Adamantådra",[2,4],75);
node("runite_vein","mining",70,"pickaxe","runite_ore",175,"#2a8a8a","Runådra",[2,3],100);
node("dragon_vein","mining",85,"pickaxe","dragon_ore",230,"#8a2a2a","Drakådra",[2,3],140);
// fishing
node("manta_spot","fishing",60,"fishing_rod","raw_manta",175,"#3a5a7a","Mantastim",[3,5],60);
node("angler_spot","fishing",70,"fishing_rod","raw_anglerfish",210,"#4a3a5a","Marulksstim",[3,4],70);
node("dark_crab_spot","fishing",80,"fishing_rod","raw_dark_crab",250,"#3a2a3a","Mörkkrabbetina",[2,4],85);
node("kingfish_spot","fishing",90,"fishing_rod","raw_kingfish",300,"#caa840","Kungsfiskvatten",[2,3],110);
// herbalism
node("sunflower_patch","herbalism",40,"sickle","sunflower_herb",90,"#e0c040","Solrosäng",[2,4],55);
node("bloodleaf_patch","herbalism",55,"sickle","bloodleaf_herb",130,"#a02030","Blodbladssnår",[2,3],70);
node("frostpetal_patch","herbalism",70,"sickle","frostpetal_herb",175,"#9ad8ff","Frostkronäng",[2,3],90);
node("dragonherb_patch","herbalism",85,"sickle","dragonherb",230,"#c84a2a","Drakörtssnår",[2,3],120);
// farming
node("potato_patch","farming",15,"sickle","potato",35,"#c8a060","Potatisland",[3,5],35);
node("cabbage_patch","farming",30,"sickle","cabbage",60,"#5a9a4a","Kålland",[3,5],40);
node("corn_patch","farming",45,"sickle","corn",90,"#e0c040","Majsfält",[3,5],50);
node("pumpkin_patch","farming",60,"sickle","pumpkin",130,"#e08020","Pumpaland",[2,4],65);
node("apple_orchard","farming",80,"sickle","golden_apple",200,"#f0d040","Äppelodling",[2,3],90);
// hunting
node("fox_trap","hunting",25,"","fox_fur",50,"#c87a3a","Rävfälla",[2,4],45);
node("bear_trap","hunting",45,"","bear_pelt",100,"#6a4a2a","Björnfälla",[2,3],60);
node("wolf_snare","hunting",65,"","wolf_pelt",150,"#8a7a5a","Vargsnara",[2,3],75);
node("chimera_trap","hunting",85,"","chimera_hide",220,"#7a3a5a","Chimärfälla",[1,2],110);
// firemaking (consumes_tool = stocken)
function campfire(id, level, logId, xp, label) {
  node(id,"firemaking",level,logId,"charcoal",xp,"#c85a1a",label,[2,3],50,{consumes_tool:true});
}
campfire("oak_campfire",15,"oak_log",35,"Ekeld");
campfire("willow_campfire",30,"willow_log",60,"Pileld");
campfire("maple_campfire",45,"maple_log",90,"Lönneld");
campfire("yew_campfire",60,"yew_log",130,"Idegranseld");
campfire("magic_campfire",75,"magic_log",175,"Magisk eld");
campfire("elder_campfire",90,"elder_log",230,"Äldsteeld");

// ── RECEPT ──────────────────────────────────────────────────────────────────
function recipe(station, id, skill, level, xp, ingredients) {
  recipes[station] = recipes[station] || [];
  recipes[station].push({id, skill, level, xp, ingredients});
}
// SMITHING (anvil)
const smRec = [
  ["mithril",40,110,3,2,42,130,44,150,43,140,41,120],
  ["adamant",55,180,3,3,57,200,60,240,58,220,56,190],
  ["runite",70,260,3,3,72,290,76,360,74,330,71,275],
  ["dragon",85,360,4,3,87,400,92,480,90,450,86,380],
];
for (const r of smRec) {
  const p=r[0], ore=p+"_ore";
  recipe("anvil", p+"_sword",     "smithing", r[1], r[2],  {[ore]:r[3], coal:r[4]});
  recipe("anvil", p+"_shield",    "smithing", r[5], r[6],  {[ore]:r[3], coal:r[4]});
  recipe("anvil", p+"_helmet",    "smithing", r[11],r[12], {[ore]:r[3], coal:r[4]});
  recipe("anvil", p+"_legs",      "smithing", r[9], r[10], {[ore]:r[3]+1, coal:r[4]+1});
  recipe("anvil", p+"_platebody", "smithing", r[7], r[8],  {[ore]:r[3]+2, coal:r[4]+1});
}
// FLETCHING + CRAFTING (crafting_bench)
recipe("crafting_bench","maple_arrow","fletching",40,28,{arrow_shaft:1,feathers:1,maple_log:1});
recipe("crafting_bench","yew_arrow","fletching",55,34,{arrow_shaft:1,feathers:1,yew_log:1});
recipe("crafting_bench","magic_arrow","fletching",70,40,{arrow_shaft:1,feathers:1,magic_log:1});
recipe("crafting_bench","elder_arrow","fletching",85,48,{arrow_shaft:1,feathers:1,elder_log:1});
recipe("crafting_bench","maple_bow","fletching",45,100,{maple_log:3});
recipe("crafting_bench","yew_bow","fletching",60,140,{yew_log:3});
recipe("crafting_bench","magic_bow","fletching",75,190,{magic_log:3});
recipe("crafting_bench","elder_bow","fletching",90,250,{elder_log:3});
recipe("crafting_bench","fox_cloak","crafting",30,70,{fox_fur:2});
recipe("crafting_bench","gem_ring","crafting",45,90,{gem:1});
recipe("crafting_bench","bear_body","crafting",50,120,{bear_pelt:3});
recipe("crafting_bench","gem_amulet","crafting",55,120,{gem:2});
recipe("crafting_bench","chimera_robe","crafting",85,220,{chimera_hide:3,shadow_silk:2});
// CONSTRUCTION (workbench)
recipe("workbench","maple_plank","construction",45,50,{maple_log:1});
recipe("workbench","yew_plank","construction",60,70,{yew_log:1});
recipe("workbench","magic_plank","construction",75,90,{magic_log:1});
recipe("workbench","elder_plank","construction",90,120,{elder_log:1});
recipe("workbench","maple_table","construction",48,80,{maple_plank:3});
recipe("workbench","yew_wardrobe","construction",62,120,{yew_plank:4});
recipe("workbench","magic_lectern","construction",78,180,{magic_plank:4});
recipe("workbench","elder_throne","construction",92,260,{elder_plank:5});
// COOKING (stove)
recipe("stove","baked_potato","cooking",15,18,{potato:1});
recipe("stove","cabbage_stew","cooking",35,55,{cabbage:2,marsh_herb:1});
recipe("stove","corn_bread","cooking",45,70,{corn:2});
recipe("stove","pumpkin_pie","cooking",60,110,{pumpkin:1});
recipe("stove","cooked_manta","cooking",60,170,{raw_manta:1});
recipe("stove","cooked_anglerfish","cooking",70,210,{raw_anglerfish:1});
recipe("stove","cooked_dark_crab","cooking",80,250,{raw_dark_crab:1});
recipe("stove","golden_apple_pie","cooking",85,200,{golden_apple:1});
recipe("stove","cooked_kingfish","cooking",90,300,{raw_kingfish:1});
// ALCHEMY (alchemy_table)
recipe("alchemy_table","divine_health_potion","alchemy",40,90,{sunflower_herb:2,mint_herb:1});
recipe("alchemy_table","ranging_potion","alchemy",45,100,{sunflower_herb:1,feathers:2});
recipe("alchemy_table","magic_potion","alchemy",50,120,{bloodleaf_herb:1,gem:1});
recipe("alchemy_table","super_strength_potion","alchemy",55,140,{bloodleaf_herb:2,nightshade_herb:1});
recipe("alchemy_table","prayer_potion","alchemy",60,150,{frostpetal_herb:1,holy_ash:1});
recipe("alchemy_table","frost_resist_potion","alchemy",70,175,{frostpetal_herb:2});
recipe("alchemy_table","dragon_potion","alchemy",85,220,{dragonherb:2,gem:1});
recipe("alchemy_table","overload_potion","alchemy",90,280,{dragonherb:3,bloodleaf_herb:2});
// PRAYER (prayer_altar)
recipe("prayer_altar","holy_ash","prayer",1,20,{bones:5});
recipe("prayer_altar","holy_ash","prayer",10,35,{bone_chips:8});
recipe("prayer_altar","blessed_charm","prayer",25,90,{troll_bone:2,holy_ash:1});
recipe("prayer_altar","holy_symbol","prayer",45,160,{troll_bone:4,gem:1});
recipe("prayer_altar","holy_ash","prayer",60,200,{big_bones:3});
recipe("prayer_altar","holy_ash","prayer",80,300,{dragon_bones:2});

// ── BEN-DROPS PÅ MONSTER ────────────────────────────────────────────────────
function addLoot(name, item, min, max, chance) {
  const m = monsters[name];
  if (!m) { console.log("  ! monster saknas:", name); return; }
  m.loot = m.loot || [];
  if (m.loot.some(l => l.item === item)) return;
  m.loot.push({item, min, max, chance});
}
["Skogsbjörnen","Skogsbjörn","MinotaurKungen","Smältkonungen","VampyrHerre","Farao Khem-Ra"].forEach(n=>addLoot(n,"big_bones",1,2,0.55));
["Elddraken","Isdraken","Ärkedemonen"].forEach(n=>addLoot(n,"dragon_bones",1,3,0.85));

// ── NODPLACERING I ZONER (intill befintliga samma-skill-noder) ──────────────
const CAND = "ABCDEFGHIJKLMNPQRSTUVXYZabdefghijklmnopqsuvwxyz#%&*+=?@$";
function loadZone(z){ return JSON.parse(fs.readFileSync(D+"zones/"+z+".json","utf8")); }
function saveZone(z,o){ fs.writeFileSync(D+"zones/"+z+".json", JSON.stringify(o,null,"\t")+"\n"); }

// placements: [zone, newNodeId, anchorNodeId, count]
const PLACE = [
  ["thais_heights","maple_tree","oak_tree",2],
  ["thais_wilds","yew_tree","willow_tree",2],
  ["thais_wilds","magic_tree","willow_tree",2],
  ["thais_wilds","elder_tree","willow_tree",1],
  ["thais_mountains","coal_vein","iron_vein",2],
  ["thais_mountains","mithril_vein","gold_vein",2],
  ["thais_mountains","adamant_vein","gem_vein",2],
  ["thais_gemcavern","runite_vein","gem_vein",2],
  ["thais_gemcavern","dragon_vein","gem_vein",1],
  ["thais_fishing_isle","manta_spot","tuna_spot",2],
  ["thais_fishing_isle","angler_spot","shark_spot",2],
  ["thais_fishing_isle","dark_crab_spot","shark_spot",1],
  ["thais_fishing_isle","kingfish_spot","shark_spot",1],
  ["forest","sunflower_patch","mint_patch",1],
  ["thais_wilds","sunflower_patch","marsh_patch",1],
  ["thais_wilds","bloodleaf_patch","nightshade_patch",2],
  ["thais_wilds","frostpetal_patch","marsh_patch",2],
  ["thais_wilds","dragonherb_patch","nightshade_patch",1],
  ["thais_fields","potato_patch","farm_patch",2],
  ["thais_fields","cabbage_patch","farm_patch",2],
  ["thais_fields","corn_patch","farm_patch",2],
  ["thais_fields","pumpkin_patch","farm_patch",1],
  ["thais_fields","apple_orchard","farm_patch",1],
  ["thais_heights","fox_trap","hunting_trap",1],
  ["thais_heights","bear_trap","hunting_trap",1],
  ["thais_heights","wolf_snare","bird_trap",1],
  ["thais_heights","chimera_trap","hunting_trap",1],
  ["thais_heights","oak_campfire","campfire_spot",1],
  ["thais_heights","willow_campfire","campfire_spot",1],
  ["thais_heights","maple_campfire","campfire_spot",1],
  ["thais_heights","yew_campfire","campfire_spot",1],
  ["thais_heights","magic_campfire","campfire_spot",1],
  ["thais_heights","elder_campfire","campfire_spot",1],
];

const zoneCache = {};
const placedCount = {};
function getZone(z){ if(!zoneCache[z]) zoneCache[z]=loadZone(z); return zoneCache[z]; }
function usedChars(z){
  const set=new Set(Object.keys(z.legend));
  for(const row of z.tiles) for(const ch of row) set.add(ch);
  return set;
}
function findAnchorChar(z, anchorNode){
  for(const k in z.legend){ const v=z.legend[k]; if(v.type==="node"&&v.node===anchorNode) return {char:k, base:v.terrain||"."}; }
  return null;
}
function setTile(z,r,c,ch){ const row=z.tiles[r]; z.tiles[r]=row.slice(0,c)+ch+row.slice(c+1); }
function primaryFloor(z){
  // mest frekventa råa terräng-tecknet (ej legend-special) = öppet golv
  const legendKeys=new Set(Object.keys(z.legend));
  const freq={}; for(const row of z.tiles) for(const ch of row) if(!legendKeys.has(ch)) freq[ch]=(freq[ch]||0)+1;
  return Object.entries(freq).sort((a,b)=>b[1]-a[1])[0][0];
}
function gridHas(z, ch){ for(const row of z.tiles) if(row.indexOf(ch)>=0) return true; return false; }
function findFreeFloorNear(z, ar, ac, floorCh, occupied){
  // spiralsök efter ledig golvruta = floorCh, ej upptagen
  for(let rad=1; rad<=18; rad++){
    for(let dr=-rad; dr<=rad; dr++) for(let dc=-rad; dc<=rad; dc++){
      if(Math.max(Math.abs(dr),Math.abs(dc))!==rad) continue;
      const r=ar+dr, c=ac+dc;
      if(r<1||c<1||r>=z.tiles.length-1||c>=z.tiles[0].length-1) continue;
      if(occupied.has(r+","+c)) continue;
      if(z.tiles[r][c]!==floorCh) continue;
      return [r,c];
    }
  }
  return null;
}
function anchorPositions(z, anchorChar){
  const pos=[];
  for(let r=0;r<z.tiles.length;r++) for(let c=0;c<z.tiles[r].length;c++) if(z.tiles[r][c]===anchorChar) pos.push([r,c]);
  return pos;
}

const charAssign = {}; // zone -> {nodeId: char}
const occupiedByZone = {};
let placedTotal=0, placeFails=[];
for(const [zone,newNode,anchor,count] of PLACE){
  const z=getZone(zone);
  occupiedByZone[zone]=occupiedByZone[zone]||new Set();
  const anc=findAnchorChar(z, anchor);
  if(!anc){ placeFails.push(`${zone}: ankarnod ${anchor} hittas ej`); continue; }
  const anchors=anchorPositions(z, anc.char);
  if(anchors.length===0){ placeFails.push(`${zone}: inga ${anchor}-rutor`); continue; }
  // golvtecken att placera på: ankarbasen om den finns i rutnätet (t.ex. vatten "~"),
  // annars zonens vanligaste golvtecken (t.ex. "g")
  const floorCh = gridHas(z, anc.base) ? anc.base : primaryFloor(z);
  // välj/återanvänd tecken för denna newNode i denna zon
  charAssign[zone]=charAssign[zone]||{};
  let ch=charAssign[zone][newNode];
  if(!ch){
    const used=usedChars(z);
    for(const cand of CAND){ if(!used.has(cand)){ ch=cand; break; } }
    if(!ch){ placeFails.push(`${zone}: slut på tecken`); continue; }
    charAssign[zone][newNode]=ch;
    z.legend[ch]={type:"node", node:newNode, terrain:floorCh};
  }
  let placed=0;
  for(let i=0;i<count*4 && placed<count;i++){
    const [ar,ac]=anchors[i % anchors.length];
    const spot=findFreeFloorNear(z, ar, ac, floorCh, occupiedByZone[zone]);
    if(!spot){ continue; }
    occupiedByZone[zone].add(spot[0]+","+spot[1]);
    setTile(z, spot[0], spot[1], ch);
    placed++; placedTotal++;
  }
  placedCount[newNode]=(placedCount[newNode]||0)+placed;
  if(placed<count) placeFails.push(`${zone}/${newNode}: placerade ${placed}/${count}`);
}

// ── SKRIV ───────────────────────────────────────────────────────────────────
fs.writeFileSync(D+"items.json", JSON.stringify(items,null,"\t")+"\n");
fs.writeFileSync(D+"nodes.json", JSON.stringify(nodes,null,"\t")+"\n");
fs.writeFileSync(D+"recipes.json", JSON.stringify(recipes,null,"\t")+"\n");
fs.writeFileSync(D+"monsters.json", JSON.stringify(monsters,null,"\t")+"\n");
for(const z in zoneCache) saveZone(z, zoneCache[z]);

// ── VALIDERING ────────────────────────────────────────────────────────────────
let errs=[];
for(const st in recipes) for(const r of recipes[st]){
  if(!items[r.id]) errs.push("recept-output saknas: "+r.id);
  for(const ing in r.ingredients) if(!items[ing]) errs.push("ingrediens saknas: "+ing+" (i "+r.id+")");
}
for(const nid in nodes){
  if(!items[nodes[nid].yields]) errs.push("nod-yield saknas: "+nodes[nid].yields+" ("+nid+")");
  const t=nodes[nid].tool; if(t && !items[t]) errs.push("nod-tool saknas: "+t+" ("+nid+")");
}
console.log("\n=== KLART ===");
console.log("items totalt:", Object.keys(items).length);
console.log("noder totalt:", Object.keys(nodes).length);
let rc=0; for(const st in recipes) rc+=recipes[st].length; console.log("recept totalt:", rc);
console.log("noder placerade i zoner:", placedTotal);
if(placeFails.length) console.log("PLACERINGS-VARNINGAR:\n  "+placeFails.join("\n  "));
console.log("VALIDERINGSFEL:", errs.length? "\n  "+errs.join("\n  ") : "inga");
