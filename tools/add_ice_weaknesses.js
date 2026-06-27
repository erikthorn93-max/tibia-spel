// Kompletterar element_mod med "ice" så att is-magin (ice_strike, ice_wave) blir
// taktisk på samma sätt som eld redan är: eldvarelser fräser bort av is, medan
// is-monster knappt känner den. Tidigare hade is-skolan noll interaktion med
// fiende-element. Idempotent: rör bara monster som saknar en "ice"-nyckel.
const fs = require("fs");
const m = JSON.parse(fs.readFileSync("data/monsters.json", "utf8"));

// >1 = svag, <1 = tål. Speglar de befintliga eld-värdena (motsatt polaritet).
const ICE = {
	// ── Eld/lava: is släcker dem ──
	"Lavavarelse":   1.5,
	"Glödmask":      1.5,
	"Askhök":        1.5,
	"Sotdemon":      1.4,
	"Smältkonungen": 1.4,  // boss, vulkankärna
	"Elddraken":     1.5,  // boss
	"Ärkedemonen":   1.4,  // boss, infernalisk

	// ── Is/frost: tål sin egen köld ──
	"Istroll":   0.4,
	"Frostörn":  0.5,
	"Snöuggla":  0.5,
	"Isvarelse": 0.3,
	"Isdraken":  0.4,  // boss
};

let added = 0, skipped = 0, missing = [];
for (const [name, ice] of Object.entries(ICE)) {
	if (!m[name]) { missing.push(name); continue; }
	if (!m[name].element_mod) m[name].element_mod = {};
	if ("ice" in m[name].element_mod) { skipped++; continue; }
	m[name].element_mod.ice = ice;
	added++;
}
fs.writeFileSync("data/monsters.json", JSON.stringify(m, null, "\t") + "\n");
console.log(`Is-mods: ${added} tillagda, ${skipped} hade redan.`);
if (missing.length) console.log("VARNING okända monster:", missing.join(", "));
