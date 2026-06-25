// Engångsskript: lägger till Glödöknen-regionens monster, items och recept.
// Skriver tillbaka JSON med tabb-indentering. Kör: node tools/add_glodoknen.js
const fs = require("fs");
const path = require("path");
const DATA = path.join(__dirname, "..", "data");

function load(name) { return JSON.parse(fs.readFileSync(path.join(DATA, name), "utf8")); }
function save(name, obj) { fs.writeFileSync(path.join(DATA, name), JSON.stringify(obj, null, "\t") + "\n", "utf8"); }

// ─────────────── MONSTER ───────────────
const monsters = load("monsters.json");
const L = (item, min, max, chance) => ({ item, min, max, chance });

monsters["Glödskorpion"] = {
	hp: 55, atk: 18, exp: 42, speed: 3, cooldown: 1, aggro_range: 8, color: "#e0641e",
	desc: "En glödhet skorpion vars stjärtgadd bränner allt den når. Den frodas i den soldränkta sanden bortom ruinerna.",
	ability: { type: "burn", chance: 0.30, duration: 6, tick_dmg: 7 },
	loot: [
		L("ember_gland", 1, 1, 0.50),
		L("scarab_shell", 1, 1, 0.25),
		L("iron_coin", 4, 16, 1.0),
		L("amethyst", 1, 1, 0.04),
		L("ruby", 1, 1, 0.02),
		L("gold_coin", 1, 3, 0.08),
	],
};

monsters["Sandskarabé"] = {
	hp: 34, atk: 11, exp: 22, speed: 4, cooldown: 1, aggro_range: 7, color: "#3a8a5a",
	desc: "En snabb, iriserande skalbagge som myllrar kring de gamla gravarna. Skalet är eftertraktat av hantverkare.",
	loot: [
		L("scarab_shell", 1, 2, 0.60),
		L("iron_coin", 2, 10, 1.0),
		L("opal", 1, 1, 0.05),
		L("gilded_scarab", 1, 1, 0.04),
		L("gold_coin", 1, 2, 0.05),
	],
};

monsters["Sandvålnad"] = {
	hp: 72, atk: 23, exp: 64, speed: 3, cooldown: 1, aggro_range: 9, color: "#cdbb92",
	desc: "Anden av en vandrare som gick vilse i öknen. Den driver genom sandstormarna och söker sällskap i döden.",
	loot: [
		L("tomb_dust", 1, 1, 0.50),
		L("bones", 1, 1, 0.80),
		L("iron_coin", 5, 18, 1.0),
		L("ancient_bandage", 1, 1, 0.10),
		L("ancient_coin", 1, 1, 0.06),
		L("sun_shard", 1, 1, 0.03),
		L("gold_coin", 1, 4, 0.10),
	],
};

monsters["Gravväktare"] = {
	hp: 120, atk: 32, exp: 100, speed: 2, cooldown: 1, aggro_range: 8, color: "#b8a55e",
	desc: "En balsamerad krigare bunden att vakta Solgraven i evighet. Dess förgyllda rustning står emot tidens tand.",
	loot: [
		L("tomb_dust", 1, 2, 0.50),
		L("bones", 1, 1, 0.90),
		L("ancient_coin", 1, 1, 0.12),
		L("iron_coin", 8, 24, 1.0),
		L("scarab_shell", 1, 1, 0.30),
		L("sun_shard", 1, 1, 0.06),
		L("gold_coin", 2, 6, 0.15),
	],
};

monsters["Solkonungen Akh-Mortis"] = {
	hp: 1500, atk: 60, exp: 1900, speed: 2, cooldown: 1, aggro_range: 10, color: "#ffb020", boss: true,
	desc: "Den odöde solkungen, balsamerad med smält guld och solens vrede. Han reser sig när någon vågar störa hans grav.",
	ability: { type: "burn", chance: 0.40, duration: 8, tick_dmg: 14 },
	loot: [
		L("sunforged_blade", 1, 1, 0.12),
		L("sun_amulet", 1, 1, 0.15),
		L("sun_shard", 3, 6, 1.0),
		L("gilded_scarab", 1, 2, 0.60),
		L("gold_coin", 40, 90, 1.0),
		L("ancient_coin", 2, 5, 0.50),
		L("ruby", 1, 1, 0.25),
		L("diamond", 1, 1, 0.18),
		L("tomb_dust", 2, 5, 1.0),
		L("bones", 2, 4, 1.0),
	],
};
save("monsters.json", monsters);

// ─────────────── ITEMS ───────────────
const items = load("items.json");

// Material (procedurell ikon — inget sprite-fält)
items["scarab_shell"]  = { name: "Skarabéskal",      type: "material", value: 18,  color: "#3a8a5a" };
items["ember_gland"]   = { name: "Glödkörtel",       type: "material", value: 40,  color: "#e0641e" };
items["tomb_dust"]     = { name: "Gravdamm",         type: "material", value: 14,  color: "#8a7a64" };
items["sun_shard"]     = { name: "Solskärva",        type: "material", value: 120, color: "#ffd24a" };
items["gilded_scarab"] = { name: "Förgylld skarabé", type: "material", value: 260, color: "#e0b020" };

// Utrustning (craftbar + boss-drop)
items["sunforged_blade"] = {
	name: "Solsmidd klinga", type: "weapon", value: 4200, color: "#ffb020",
	atk: 46, skill: "sword", slot: "weapon", level_req: 38, crit_chance: 0.08,
};
items["scarab_shield"] = {
	name: "Skarabésköld", type: "armor", value: 1100, color: "#3a8a5a",
	armor: 6, shielding_bonus: 14, slot: "offhand", level_req: 30,
};
items["sun_amulet"] = {
	name: "Solamulett", type: "armor", value: 1600, color: "#ffd24a",
	armor: 6, crit_chance: 0.06, slot: "amulet", level_req: 32,
};
items["ember_robe"] = {
	name: "Glödmantel", type: "armor", value: 1300, color: "#c0481e",
	armor: 17, def_bonus: 6, slot: "body", level_req: 30,
};
items["sandstrider_boots"] = {
	name: "Sandvandrarstövlar", type: "armor", value: 700, color: "#d0a860",
	armor: 5, speed_bonus: 0.15, slot: "boots", level_req: 26,
};
save("items.json", items);

// ─────────────── RECEPT ───────────────
const recipes = load("recipes.json");
recipes["anvil"].push(
	{ id: "sunforged_blade", skill: "smithing", level: 45, xp: 80, ingredients: { sun_shard: 3, ember_gland: 4, scarab_shell: 6 } },
	{ id: "scarab_shield",   skill: "smithing", level: 32, xp: 40, ingredients: { scarab_shell: 8, ember_gland: 2 } },
);
recipes["crafting_bench"].push(
	{ id: "sun_amulet",        skill: "crafting", level: 34, xp: 46, ingredients: { sun_shard: 2, gilded_scarab: 1 } },
	{ id: "ember_robe",        skill: "crafting", level: 32, xp: 42, ingredients: { ember_gland: 5, scarab_shell: 6 } },
	{ id: "sandstrider_boots", skill: "crafting", level: 28, xp: 30, ingredients: { scarab_shell: 5, tomb_dust: 4 } },
);
save("recipes.json", recipes);

console.log("Klart: la till 5 monster, 10 items, 5 recept för Glödöknen.");
