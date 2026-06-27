// Ger monster utan element_mod tematiska charm-svagheter/resistenser, så charm-
// taktiken (eld/energi/död/fysisk) blir meningsfull mot fler fiender — inte bara
// hälften. Endast de fyra giltiga charm-elementen används. Generiska djur lämnas
// neutrala med flit (annars betyder svagheter ingenting). Idempotent: rör bara
// monster som saknar element_mod.
const fs = require("fs");
const m = JSON.parse(fs.readFileSync("data/monsters.json", "utf8"));

// >1 = svag, <1 = tål, 0 = immun. Värden i linje med befintliga (t.ex. Skelett
// death:0.3, fire:1.4). Charm-element: fire, energy, death, physical.
const MODS = {
	// ── Vandöda: tål sin egen död-magi, brinner lätt ──
	"Ökenmumie":        { death: 0.3, fire: 1.5 },           // torra lindor
	"Farao Khem-Ra":    { death: 0.2, fire: 1.4 },           // boss, balsamerad
	"Drunknad sjöman":  { death: 0.4, energy: 1.3 },         // våt vandöd → blixt
	"Vampyr":           { death: 0.3, fire: 1.3 },
	"VampyrHerre":      { death: 0.2, fire: 1.4 },           // boss
	"Nekromant":        { death: 0.4, fire: 1.3 },
	"Lich":             { death: 0.2, fire: 1.4 },           // boss

	// ── Eldvarelser & demoner: tål eld, sårbara för energi ──
	"Lavavarelse":      { fire: 0.3, energy: 1.3 },
	"Glödmask":         { fire: 0.3, energy: 1.3 },
	"Askhök":           { fire: 0.4, energy: 1.4 },          // bräcklig fågel
	"Sotdemon":         { fire: 0.3, energy: 1.3 },
	"Smältkonungen":    { fire: 0.2, energy: 1.4 },          // boss, vulkankärna
	"Elddraken":        { fire: 0.2, energy: 1.3 },          // boss
	"Ärkedemonen":      { fire: 0.3, death: 0.5, energy: 1.3 }, // boss, infernalisk

	// ── Isvarelser: smälter av eld, frostpansar mot fysiskt ──
	"Istroll":          { fire: 1.5, physical: 0.7 },
	"Frostörn":         { fire: 1.4, energy: 0.7 },
	"Snöuggla":         { fire: 1.4 },
	"Isvarelse":        { fire: 1.5, physical: 0.6 },
	"Isdraken":         { fire: 1.4, physical: 0.6 },        // boss

	// ── Vatten/kust: leder elektricitet ──
	"Strandkrabba":     { energy: 1.4, physical: 0.7 },      // skal
	"Sjöorm":           { energy: 1.5 },

	// ── Växt/natur/träsk: torrt löv och rötter brinner ──
	"Urskogsvältaren":  { fire: 1.5, physical: 0.6 },        // boss, lövklädd
	"Sumpvarelse":      { fire: 1.4, physical: 0.7 },
	"Sumpkräla":        { fire: 1.3 },
	"Giftpadda":        { fire: 1.3 },

	// ── Insekter/spindlar: chitin brinner ──
	"Spindel":          { fire: 1.3 },
	"Jättespindel":     { fire: 1.4 },
	"Grottspindel":     { fire: 1.3 },
	"Giftvävare":       { fire: 1.3 },
	"Skuggspindel":     { fire: 1.3 },
	"Spindeldrottningen Morwena": { fire: 1.4 },            // boss
	"Sandskarabé":      { fire: 1.3 },
	"Sandvaranen":      { fire: 1.3, physical: 0.7 },        // pansrad ödla
	"Sandorm":          { fire: 1.3 },                       // ökenmask
	"Träskdjävul":      { fire: 1.3, physical: 0.7 },        // slemmig

	// ── Pansrade/sten: magi går runt rustningen ──
	"Troll":            { fire: 1.3, physical: 0.7 },
	"Trollhövding":     { fire: 1.4, physical: 0.7 },        // boss
	"Minotaur":         { energy: 1.3, physical: 0.7 },
	"MinotaurVakt":     { energy: 1.3, physical: 0.6 },
	"MinotaurKungen":   { energy: 1.4, physical: 0.6 },      // boss
	"Dvärg":            { energy: 1.3, physical: 0.7 },
	"DvärgenSmeden":    { energy: 1.4, fire: 0.6, physical: 0.7 }, // smed, eldhärdad
	"Orköverherre":     { energy: 1.4, physical: 0.6 },      // boss, byggd som mur
	"Orkshamanen":      { energy: 1.3, death: 0.6 },         // andebunden

	// ── Sjörövar-bossar: sega men inte magiska ──
	"Piratkapten Svartöga": { energy: 1.3, physical: 0.7 }, // boss
};

let added = 0, skipped = 0, missing = [];
for (const [name, mods] of Object.entries(MODS)) {
	if (!m[name]) { missing.push(name); continue; }
	if (m[name].element_mod && Object.keys(m[name].element_mod).length) { skipped++; continue; }
	m[name].element_mod = mods;
	added++;
}
fs.writeFileSync("data/monsters.json", JSON.stringify(m, null, "\t") + "\n");
console.log(`Element-mods: ${added} tillagda, ${skipped} hade redan.`);
if (missing.length) console.log("VARNING okända monster:", missing.join(", "));

// Rapport: bossar utan svaghet (>1) — alla bossar bör vara taktiskt angripbara.
const bossNoWeak = Object.entries(m).filter(([k, v]) =>
	v.boss && !Object.values(v.element_mod || {}).some((x) => x > 1)).map(([k]) => k);
console.log("Bossar utan svaghet (>1):", bossNoWeak.length ? bossNoWeak.join(", ") : "inga");
