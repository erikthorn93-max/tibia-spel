// Sätter en OSRS-lik svårighetsgrad på varje quest (Nybörjare/Lätt/Medel/Svår/
// Mästare). Datadrivet: starkaste monstret i kill-stegen + boss-flagga +
// transitivt kedjedjup, med belönings-XP som proxy för strids-lösa quests.
// Idempotent — kör om för att räkna om allt.
const fs = require("fs");
const q = JSON.parse(fs.readFileSync("data/quests.json", "utf8"));
const m = JSON.parse(fs.readFileSync("data/monsters.json", "utf8"));

const depthMemo = {};
function depth(id, seen) {
	seen = seen || {};
	if (depthMemo[id] != null) return depthMemo[id];
	if (seen[id]) return 0;
	seen[id] = true;
	const reqs = (q[id] && q[id].requires) || [];
	const d = reqs.length ? 1 + Math.max(...reqs.map((r) => depth(r, Object.assign({}, seen)))) : 0;
	depthMemo[id] = d;
	return d;
}

function difficulty(id) {
	const v = q[id];
	let maxExp = 0, boss = false, hasKill = false;
	for (const s of v.steps || []) {
		if (s.type === "kill") {
			hasKill = true;
			const mm = m[s.monster];
			if (mm) {
				maxExp = Math.max(maxExp, mm.exp || 0);
				if (mm.boss) boss = true;
			}
		}
	}
	const xp = (v.rewards && v.rewards.xp) || 0;
	const d = depth(id);
	// Tutorial-liknande: ingen strid, ingen kedja, blygsam belöning → Nybörjare.
	if (!hasKill && d === 0 && xp <= 250) return "Nybörjare";
	let eff = maxExp;
	if (boss) eff = Math.max(eff, 800);          // bossar är alltid en rejäl tröskel
	if (!hasKill) eff = Math.max(eff, xp * 0.3); // strids-lösa: belöning som proxy
	eff *= 1 + 0.12 * d;                          // kedjor blir gradvis svårare
	if (eff < 40) return "Nybörjare";
	if (eff < 130) return "Lätt";
	if (eff < 450) return "Medel";
	if (eff < 1200) return "Svår";
	return "Mästare";
}

const dist = {};
for (const id of Object.keys(q)) {
	const diff = difficulty(id);
	q[id].difficulty = diff;
	dist[diff] = (dist[diff] || 0) + 1;
}
fs.writeFileSync("data/quests.json", JSON.stringify(q, null, "\t") + "\n");
console.log("Svårighet satt på", Object.keys(q).length, "quests:", JSON.stringify(dist));
