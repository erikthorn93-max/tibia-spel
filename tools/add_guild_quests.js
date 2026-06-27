// Ger Thais tre guildhus liv: riktiga questkedjor för de tidigare questlösa
// guildmästarna Gregor (Riddargillet), Elane + Galuna (Paladingillet v.1/v.2)
// och Muriel (Trollkarlsgillet). Tematiska men ÖPPNA för alla — ingen klasslåsning.
// Belöning: tre nya outfits (knight/paladin/sorcerer) via etablerat capstone-mönster
// (tom requires i unlocks.json + outfit i quest rewards.unlocks).
const fs = require("fs");
const J = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const W = (p, o) => fs.writeFileSync(p, JSON.stringify(o, null, "\t") + "\n");

const quests = J("data/quests.json");
const dlg = J("data/dialogue.json");
const outfits = J("data/outfits.json");
const unlocks = J("data/unlocks.json");

// ---- 1. Quests ------------------------------------------------------------
const newQuests = {
	quest_guild_knight: {
		name: "Murens Prov",
		giver: "npc_knight_guild_master",
		requires: [],
		steps: [
			{ type: "kill", monster: "Troll", count: 10,
			  hint: "Trollen kommer ner från bergen. Fäll tio i Bergspasset." },
			{ type: "kill", monster: "Trollhövding", count: 1,
			  hint: "Bryt deras vilja — döda en Trollhövding i Trollgrottan." },
			{ type: "talk_to", npc: "npc_knight_guild_master",
			  hint: "Återvänd till Gregor i Riddargillet." }
		],
		rewards: { xp: 700, gold: 450, items: { steel_platebody: 1 }, unlocks: ["outfit_knight"] }
	},
	quest_guild_marksman: {
		name: "Den Stadiga Handen",
		giver: "npc_elane",
		requires: [],
		steps: [
			{ type: "kill", monster: "Varg", count: 10,
			  hint: "Snabba mål härdar handen. Fäll tio vargar i Höjderna." },
			{ type: "kill", monster: "Goblinsoldat", count: 6,
			  hint: "Goblinsoldater rör sig i flock — sex pilar, sex träffar." },
			{ type: "talk_to", npc: "npc_elane",
			  hint: "Visa Elane att handen sitter stadigt." }
		],
		rewards: { xp: 450, gold: 300, items: { oak_bow: 1, oak_arrow: 60 } }
	},
	quest_guild_paladin: {
		name: "Tro och Stål",
		giver: "npc_galuna",
		requires: ["quest_guild_marksman"],
		steps: [
			{ type: "kill", monster: "Ork", count: 12,
			  hint: "Övre hallen kräver mer. Rensa tolv orcher i Orkklyftan." },
			{ type: "kill", monster: "Orköverherre", count: 1,
			  hint: "När bågen inte räcker — fäll Orköverherren själv." },
			{ type: "talk_to", npc: "npc_galuna",
			  hint: "Återvänd till Galuna i paladingillets övre hall." }
		],
		rewards: { xp: 1000, gold: 700, items: { steel_bow: 1 }, unlocks: ["outfit_paladin"] }
	},
	quest_guild_sorcerer: {
		name: "Runans Mening",
		giver: "npc_muriel",
		requires: [],
		steps: [
			{ type: "kill", monster: "Skelett", count: 12,
			  hint: "Öva runan på de viljelösa döda i Grottan — tolv skelett." },
			{ type: "kill", monster: "Skelettkrigare", count: 5,
			  hint: "Fem skelettkrigare står emot — mena varje rune du kastar." },
			{ type: "talk_to", npc: "npc_muriel",
			  hint: "Återvänd till Muriel i Trollkarlsgillet." }
		],
		rewards: { xp: 700, gold: 450, items: { energy_rune: 8, great_mana_potion: 3 }, unlocks: ["outfit_sorcerer"] }
	}
};
Object.assign(quests, newQuests);

// ---- 2. Dialog: offer- och reward-noder + root-grenar ---------------------
// Hjälpare: infoga quest-grenar i en befintlig root FÖRE dess Goodbye-choice.
function wireRoot(rootId, branches) {
	const root = dlg[rootId];
	const goodbyeIdx = root.choices.findIndex((c) => c.next === null && !c.conditions);
	const at = goodbyeIdx === -1 ? root.choices.length : goodbyeIdx;
	root.choices.splice(at, 0, ...branches);
}

// Gregor — Riddargillet (närstrid)
dlg.gregor_offer = {
	speaker: "npc_knight_guild_master", emotion: "neutral",
	text: "Vill du ha ett riktigt prov? Trollen kommer ner från bergen och prövar muren. Fäll tio i passet, och deras hövding i grottan. Då pratar vi vidare.",
	choices: [
		{ text: "Muren håller. Jag tar det.", next: null, actions: [{ type: "start_quest", quest: "quest_guild_knight" }] },
		{ text: "Inte nu.", next: "gregor_root" }
	]
};
dlg.gregor_reward = {
	speaker: "npc_knight_guild_master", emotion: "friendly",
	text: "Tio troll och en hövding. Din arm svek inte när den tröttnade — där börjar riddaren. Bär detta med stolthet; muren står tack vare dig.",
	choices: [{ text: "För Thais.", next: null }]
};
wireRoot("gregor_root", [
	{ text: "Ge mig ett riktigt prov.", next: "gregor_offer",
	  conditions: [{ type: "quest_available", quest: "quest_guild_knight" }] },
	{ text: "Muren står. Trollen föll.", next: "gregor_reward",
	  conditions: [{ type: "quest_step", quest: "quest_guild_knight", step: 2 }],
	  actions: [{ type: "advance_quest", quest: "quest_guild_knight" }] }
]);

// Elane — Paladingillet v.1 (bågskytte)
dlg.elane_offer = {
	speaker: "npc_elane", emotion: "neutral",
	text: "Vill du härda handen? Vargarna i Höjderna rör sig snabbt — tio av dem lär dig tålamodet. Sedan sex goblinsoldater, som inte står still de heller.",
	choices: [
		{ text: "Jag siktar lugnt.", next: null, actions: [{ type: "start_quest", quest: "quest_guild_marksman" }] },
		{ text: "Inte nu.", next: "elane_root" }
	]
};
dlg.elane_reward = {
	speaker: "npc_elane", emotion: "friendly",
	text: "Stadig hand, jämn andning. Ta den här bågen — den är ärligare än de flesta människor. Galuna i övre hallen tar emot dig nu; du har förtjänat trappan.",
	choices: [{ text: "Tack, Elane.", next: null }]
};
wireRoot("elane_root", [
	{ text: "Lär mig sikta på riktigt.", next: "elane_offer",
	  conditions: [{ type: "quest_available", quest: "quest_guild_marksman" }] },
	{ text: "Målen föll. Handen är stadig.", next: "elane_reward",
	  conditions: [{ type: "quest_step", quest: "quest_guild_marksman", step: 2 }],
	  actions: [{ type: "advance_quest", quest: "quest_guild_marksman" }] }
]);

// Galuna — Paladingillet v.2 (kräver Elanes prov)
dlg.galuna_offer = {
	speaker: "npc_galuna", emotion: "neutral",
	text: "Elane sänder dig upp — bra. Här lär vi det som kommer efter bågen. Orkklyftan vräker fram tolv orcher och en överherre. Fäll dem, så vet jag vad du är gjord av.",
	choices: [
		{ text: "Tro och stål. Jag går.", next: null, actions: [{ type: "start_quest", quest: "quest_guild_paladin" }] },
		{ text: "Inte än.", next: "galuna_root" }
	]
};
dlg.galuna_reward = {
	speaker: "npc_galuna", emotion: "friendly",
	text: "Överherren föll för din hand allena. Tro bär stålet, stålet bär dig. Du hör hemma i övre hallen nu — bär paladinens regalier som en av oss.",
	choices: [{ text: "Med ära.", next: null }]
};
wireRoot("galuna_root", [
	{ text: "Jag är redo för övre hallens prov.", next: "galuna_offer",
	  conditions: [{ type: "quest_available", quest: "quest_guild_paladin" }] },
	{ text: "Orköverherren är fälld.", next: "galuna_reward",
	  conditions: [{ type: "quest_step", quest: "quest_guild_paladin", step: 2 }],
	  actions: [{ type: "advance_quest", quest: "quest_guild_paladin" }] }
]);

// Muriel — Trollkarlsgillet (runmagi)
dlg.muriel_offer = {
	speaker: "npc_muriel", emotion: "neutral",
	text: "Vill du lära runan att betyda något? Öva den på de viljelösa döda i Grottan — tolv skelett, sedan fem skelettkrigare som faktiskt slår tillbaka. Mena varje stavelse.",
	choices: [
		{ text: "Jag menar den.", next: null, actions: [{ type: "start_quest", quest: "quest_guild_sorcerer" }] },
		{ text: "Inte nu.", next: "muriel_root" }
	]
};
dlg.muriel_reward = {
	speaker: "npc_muriel", emotion: "friendly",
	text: "Du sa runan och världen lyssnade. Det är skillnaden mellan att skrika och att tala. Ta dessa — och regalierna. De impatienta begraver vi; du studerade rätt.",
	choices: [{ text: "Tack, mästare.", next: null }]
};
wireRoot("muriel_root", [
	{ text: "Lär mig att mena runan.", next: "muriel_offer",
	  conditions: [{ type: "quest_available", quest: "quest_guild_sorcerer" }] },
	{ text: "De döda föll för runan.", next: "muriel_reward",
	  conditions: [{ type: "quest_step", quest: "quest_guild_sorcerer", step: 2 }],
	  actions: [{ type: "advance_quest", quest: "quest_guild_sorcerer" }] }
]);

// ---- 3. Outfits -----------------------------------------------------------
outfits.outfit_knight = {
	name: "Riddarens rustning", unlock: "outfit_knight",
	colors: { shirt: "#9aa0ad", pants: "#3a3f4a", hair: "#5a4632" }
};
outfits.outfit_paladin = {
	name: "Paladinens mundering", unlock: "outfit_paladin",
	colors: { shirt: "#2f5a3a", pants: "#3a4a2a", hair: "#caa14a" }
};
outfits.outfit_sorcerer = {
	name: "Trollkarlens skrud", unlock: "outfit_sorcerer",
	colors: { shirt: "#2a2f6a", pants: "#1a1a3a", hair: "#cfd8ff" }
};

// ---- 4. Unlocks (tom requires -> beviljas direkt av quest rewards) ---------
unlocks.outfit_knight = {
	name: "Riddarens rustning", category: "outfit", requires: {},
	desc: "Belönas av Gregor för att ha klarat Murens Prov i Riddargillet."
};
unlocks.outfit_paladin = {
	name: "Paladinens mundering", category: "outfit", requires: {},
	desc: "Belönas av Galuna för att ha klarat Tro och Stål i paladingillets övre hall."
};
unlocks.outfit_sorcerer = {
	name: "Trollkarlens skrud", category: "outfit", requires: {},
	desc: "Belönas av Muriel för att ha klarat Runans Mening i Trollkarlsgillet."
};

W("data/quests.json", quests);
W("data/dialogue.json", dlg);
W("data/outfits.json", outfits);
W("data/unlocks.json", unlocks);
console.log("Klart: 4 quests, 8 dialognoder, 3 outfits, 3 unlocks tillagda.");
