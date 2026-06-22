// Lägger till Fiskemästar-kedjan: region, quest, noder, items, recept, unlock, NPC, dialog.
// Validerar kartan (radlängd, walkable-grannar, reachability) innan skrivning.
const fs = require("fs");
const path = require("path");
const DZ = "data";
const J = (p) => JSON.parse(fs.readFileSync(path.join(DZ, p), "utf8"));
const W = (p, o) => fs.writeFileSync(path.join(DZ, p), JSON.stringify(o, null, "\t") + "\n");

// ───────────────────────────────────────── 1. Bygg ön ─────────────────────────────
const WID = 22, HEI = 16;
const cx = 10.5, cy = 7.5, rx = 9.0, ry = 6.0;
const grid = [];
for (let y = 0; y < HEI; y++) {
	const row = [];
	for (let x = 0; x < WID; x++) {
		const d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2;
		if (d <= 0.78) row.push(".");          // gräs
		else if (d <= 1.0) row.push("b");      // strand
		else row.push("~");                    // vatten
	}
	grid.push(row);
}
// Cobble-plats i mitten
for (let y = 0; y < HEI; y++)
	for (let x = 0; x < WID; x++) {
		const d = ((x - cx) / 3.2) ** 2 + ((y - cy) / 2.4) ** 2;
		if (d <= 1.0 && grid[y][x] === ".") grid[y][x] = "c";
	}

const walk = (ch) => !["~", "W", "w", "r", "t"].includes(ch); // ön har inga W/w/r/t
const hasWalkNeighbour = (x, y) =>
	[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy]) => {
		const nx=x+dx, ny=y+dy;
		return nx>=0&&ny>=0&&nx<WID&&ny<HEI&&walk(grid[ny][nx]);
	});

// Strandceller med vatten utåt + gångbar granne inåt → fiskeplatser
const beachSpots = [];
for (let y=0;y<HEI;y++) for (let x=0;x<WID;x++) {
	if (grid[y][x] !== "b") continue;
	const nb=[[1,0],[-1,0],[0,1],[0,-1]].map(([dx,dy])=>[x+dx,y+dy]);
	const water = nb.some(([nx,ny])=>nx>=0&&ny>=0&&nx<WID&&ny<HEI&&grid[ny][nx]==="~");
	const land  = nb.some(([nx,ny])=>nx>=0&&ny>=0&&nx<WID&&ny<HEI&&[".","c"].includes(grid[ny][nx]));
	if (water && land) beachSpots.push([x,y]);
}
// Sprid ut 4 noder via kvadranter
function pick(qx, qy) {
	let best=null, bd=1e9;
	for (const [x,y] of beachSpots) {
		const dd=(x-qx)**2+(y-qy)**2;
		if (dd<bd){bd=dd;best=[x,y];}
	}
	return best;
}
const nodePlacements = [
	["L", pick(6, 2)],    // lobster_pot
	["S", pick(15, 2)],   // swordfish_spot
	["T", pick(4, 13)],   // tuna_spot
	["K", pick(17, 13)],  // shark_spot
];
for (const [ch, pos] of nodePlacements) {
	if (!pos) throw new Error("ingen strandplats för " + ch);
	grid[pos[1]][pos[0]] = ch;
}

// Centrala gräs/cobble-celler för stove, NPC, portal, spelarstart
function nearestType(qx, qy, types) {
	let best=null, bd=1e9;
	for (let y=0;y<HEI;y++) for (let x=0;x<WID;x++) {
		if (!types.includes(grid[y][x])) continue;
		const dd=(x-qx)**2+(y-qy)**2;
		if (dd<bd){bd=dd;best=[x,y];}
	}
	return best;
}
const stove  = nearestType(cx, cy-1, ["c","."]);  grid[stove[1]][stove[0]]="V";
const npc    = nearestType(cx-4, cy, ["."]);        grid[npc[1]][npc[0]]="F";
const portal = nearestType(cx, cy+3, ["."]);        grid[portal[1]][portal[0]]="d";
// spelarstart strax under/intill portalen, på gräs
let pstart = nearestType(portal[0], portal[1]+1, ["."]);
if (!pstart || (pstart[0]===portal[0]&&pstart[1]===portal[1])) pstart = nearestType(cx, cy, ["."]);
grid[pstart[1]][pstart[0]]="P";

const tiles = grid.map(r=>r.join(""));
tiles.forEach((r,i)=>{ if(r.length!==WID) throw new Error("rad "+i+" längd "+r.length); });

const isle = {
	name: "Stormrevet",
	spawn_table: [
		{ count: 3, monster: "Pirat", respawn: 35.0 },
		{ count: 2, monster: "Sjöorm", respawn: 45.0 },
		{ count: 2, monster: "Strandkrabba", respawn: 30.0 }
	],
	tiles: tiles,
	legend: {
		d: { type: "portal", to: "thais_docks", terrain: "f" },
		F: { type: "npc_spawn", npc: "npc_fishmaster" },
		V: { type: "station", station: "stove", terrain: "c" },
		L: { type: "node", node: "lobster_pot", terrain: "b" },
		S: { type: "node", node: "swordfish_spot", terrain: "b" },
		T: { type: "node", node: "tuna_spot", terrain: "b" },
		K: { type: "node", node: "shark_spot", terrain: "b" }
	}
};

// ── Reachability-validering (samma regler som zone.gd) ──
function resolveTerr(ch) {
	if (ch === "P") return { terr: ".", blocked: false };
	const e = isle.legend[ch];
	if (e) {
		const terr = e.terrain || ",";
		const blocked = ["node","station"].includes(e.type);
		return { terr, blocked };
	}
	return { terr: ch, blocked: false };
}
function isWalk(x,y){ const {terr,blocked}=resolveTerr(tiles[y][x]); return !blocked && !["~","W","w","r","t"].includes(terr); }
let P=null; for(let y=0;y<HEI;y++)for(let x=0;x<WID;x++) if(tiles[y][x]==="P") P=[x,y];
const seen=Array.from({length:HEI},()=>new Array(WID).fill(false));
const q=[P]; seen[P[1]][P[0]]=true;
while(q.length){const[x,y]=q.pop();for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=WID||ny>=HEI)continue;if(seen[ny][nx])continue;if(!isWalk(nx,ny))continue;seen[ny][nx]=true;q.push([nx,ny]);}}
function reachableAdjacent(x,y){return[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>{const nx=x+dx,ny=y+dy;return nx>=0&&ny>=0&&nx<WID&&ny<HEI&&seen[ny][nx];});}
for(let y=0;y<HEI;y++)for(let x=0;x<WID;x++){const ch=tiles[y][x];const e=isle.legend[ch];
	if(ch==="d"&&!seen[y][x]) throw new Error("portal ej nåbar");
	if(e&&["node","station"].includes(e.type)&&!reachableAdjacent(x,y)) throw new Error(ch+" ("+e.type+") ej nåbar @"+x+","+y);
	if(e&&e.type==="npc_spawn"&&!reachableAdjacent(x,y)) throw new Error("NPC ej nåbar");
}
W("zones/thais_fishing_isle.json", isle);
console.log("Karta OK ("+WID+"x"+HEI+"). Noder:", nodePlacements.map(n=>n[0]+"@"+n[1]).join(" "),
	"| stove",stove,"npc",npc,"portal",portal,"P",pstart);

// ───────────────────────────────────────── 2. Båt-portal i docks ──────────────────
const docks = J("zones/thais_docks.json");
const drows = docks.tiles.map(r=>r.split(""));
// hitta fri inre ',' på västsidan
let placed=false;
outer: for(let y=3;y<drows.length-2;y++) for(let x=2;x<6;x++){
	if(drows[y][x]===","){ drows[y][x]="F"; placed=true; break outer; }
}
if(!placed) throw new Error("ingen plats för båt-portal i docks");
docks.tiles = drows.map(r=>r.join(""));
docks.legend.F = { type:"portal", to:"thais_fishing_isle", terrain:"f", unlock:"fiskeon" };
W("zones/thais_docks.json", docks);
console.log("Båt-portal tillagd i thais_docks.");

// ───────────────────────────────────────── 3. Noder ───────────────────────────────
const nodes = J("nodes.json");
nodes.tuna_spot = { skill:"fishing", level:40, tool:"fishing_rod", yields:"raw_tuna", xp:90, charges:[3,5], respawn:55, color:"#2a6a9a", label:"Tonfiskstim" };
nodes.shark_spot = { skill:"fishing", level:50, tool:"fishing_rod", yields:"raw_shark", xp:140, charges:[2,4], respawn:75, color:"#5a6a7a", label:"Hajvatten" };
W("nodes.json", nodes);

// ───────────────────────────────────────── 4. Items ───────────────────────────────
const items = J("items.json");
items.raw_tuna  = { name:"Rå tonfisk", type:"material", value:30 };
items.raw_shark = { name:"Rå haj", type:"material", value:55 };
items.cooked_tuna  = { name:"Grillad tonfisk", type:"food", value:90, color:"#c88858", heal:110, buff:{ stat:"skill:fishing", amount:4, duration:150 } };
items.cooked_shark = { name:"Hajbiff", type:"food", value:150, color:"#9aa6b0", heal:170, buff:{ stat:"skill:fishing", amount:5, duration:180 } };
W("items.json", items);

// ───────────────────────────────────────── 5. Recept (stove) ──────────────────────
const recipes = J("recipes.json");
recipes.stove.push({ id:"cooked_tuna",  skill:"cooking", level:40, xp:110, ingredients:{ raw_tuna:1 } });
recipes.stove.push({ id:"cooked_shark", skill:"cooking", level:50, xp:150, ingredients:{ raw_shark:1 } });
W("recipes.json", recipes);

// ───────────────────────────────────────── 6. Unlock ──────────────────────────────
const unlocks = J("unlocks.json");
unlocks.fiskeon = {
	name:"Stormrevet",
	category:"area",
	requires:{ quest:"quest_fiskemastaren", skill:"fishing", level:40 },
	hint:"Klara Fiskemästarens prov och nå Fishing 40 — då vågar Brandt segla ut till Stormrevet."
};
W("unlocks.json", unlocks);

// ───────────────────────────────────────── 7. Quest ───────────────────────────────
const quests = J("quests.json");
quests.quest_fiskemastaren = {
	name:"Fiskemästarens prov",
	giver:"npc_captain",
	requires:["quest_sjovagen"],
	steps:[
		{ type:"collect", item:"raw_swordfish", count:3, hint:"Fånga 3 svärdfiskar för att visa att du behärskar djuphavsfiske." },
		{ type:"collect", item:"raw_lobster",  count:3, hint:"Fånga 3 humrar längs revet." },
		{ type:"talk_to", npc:"npc_captain", hint:"Visa fångsten för Kapten Brandt vid hamnen." }
	],
	rewards:{ xp:2500, gold:800, skill_xp:{ fishing:4000 }, items:{ lobster_dinner:3 } }
};
W("quests.json", quests);

// ───────────────────────────────────────── 8. NPC ─────────────────────────────────
const npcs = J("npcs.json");
npcs.npc_fishmaster = {
	name:"Fiskemästare Silja",
	zone:"thais_fishing_isle",
	position:[npc[0], npc[1]],
	barks:["Revet föder den som respekterar det.","De stora nappar i skymningen."],
	dialogue_root:"fishmaster_root"
};
W("npcs.json", npcs);

// ───────────────────────────────────────── 9. Dialog ──────────────────────────────
const dlg = J("dialogue.json");
// Kaptenens nya val (infoga före "Goodbye.")
const croot = dlg.captain_root.choices;
const gi = croot.findIndex(c => c.next === null && /goodbye/i.test(c.text));
const insertAt = gi >= 0 ? gi : croot.length;
const newChoices = [
	{
		text:"Jag har bemästrat djupet — vad ligger längre västerut?",
		next:"captain_fish_offer",
		conditions:[
			{ type:"quest_completed", quest:"quest_sjovagen" },
			{ type:"skill_level", skill:"fishing", level:30 },
			{ type:"quest_available", quest:"quest_fiskemastaren" }
		]
	},
	{
		text:"Jag har mästarens fångst med mig.",
		next:"captain_fish_report",
		conditions:[ { type:"quest_step", quest:"quest_fiskemastaren", step:2 } ],
		actions:[ { type:"advance_quest", quest:"quest_fiskemastaren" } ]
	}
];
croot.splice(insertAt, 0, ...newChoices);
dlg.captain_fish_offer = {
	speaker:"npc_captain", emotion:"neutral",
	text:"Längre väst ligger Stormrevet — ökänt för sina vrak och de största fiskar någon skådat. Bevisa att du är en mästare: ta tre svärdfiskar och tre humrar, så vet jag att du klarar revet.",
	choices:[
		{ text:"Jag antar utmaningen.", next:null, actions:[ { type:"start_quest", quest:"quest_fiskemastaren" } ] },
		{ text:"En annan gång.", next:null }
	]
};
dlg.captain_fish_report = {
	speaker:"npc_captain", emotion:"friendly",
	text:"Vid alla tidvatten — det här är fångst värdig en mästare. Visa mig Fishing 40 så sätter jag segel mot Stormrevet. Båten ligger redo vid kajen.",
	choices:[ { text:"Tack, kapten.", next:null } ]
};
dlg.fishmaster_root = {
	speaker:"npc_fishmaster", emotion:"neutral",
	text:"Så du nådde Stormrevet i alla fall. Få gör det. Här simmar fiskar du aldrig sett i Thais vatten.",
	choices:[
		{ text:"Vad simmar här ute?", next:"fishmaster_fish" },
		{ text:"Några råd?", next:"fishmaster_tip" },
		{ text:"Hej då.", next:null }
	]
};
dlg.fishmaster_fish = {
	speaker:"npc_fishmaster", emotion:"neutral",
	text:"Tonfisk i de djupare stimmen — kräver stadig hand vid Fishing 40. Och haj, om du vågar; bara mästare på 50 drar upp en sådan. Stek dem vid elden här så ger de mer styrka än något i staden.",
	choices:[ { text:"Tillbaka.", next:"fishmaster_root" }, { text:"Hej då.", next:null } ]
};
dlg.fishmaster_tip = {
	speaker:"npc_fishmaster", emotion:"friendly",
	text:"Håll dig nära vattenbrynet och akta piraterna som strandat på revet. Och ta med dig stekspaden — färsk fångst som tillagas på plats smakar bäst.",
	choices:[ { text:"Tillbaka.", next:"fishmaster_root" }, { text:"Hej då.", next:null } ]
};
W("dialogue.json", dlg);

console.log("Klart: quest, unlock, noder, items, recept, NPC och dialog tillagda.");
