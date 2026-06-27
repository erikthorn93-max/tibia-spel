// Fyller bestiarie-beskrivningar (desc) för monster som saknar lore. Bestiarien
// visar texten när ett monster upptäckts — utan desc står de tomma. Idempotent:
// skriver bara desc där den saknas (rör inte befintliga).
const fs = require("fs");
const m = JSON.parse(fs.readFileSync("data/monsters.json", "utf8"));

const LORE = {
	// ── Grotta / vandöda ──
	"Råtta": "En skabbig kloakråtta. Ofarlig styck, men de kommer sällan ensamma — nybörjarens första byte.",
	"Orm": "En giftlös snok som ringlar i gräs och grottspringor. Snabb att hugga, lätt att trampa ihjäl.",
	"Spindel": "En vanlig jaktspindel. Dess bett svider men dödar sällan — fler ben än mod.",
	"Skelett": "Kvarlevorna av en sedan länge fallen krigare, väckt av grottans gamla illvilja. Faller lika lätt som det en gång reste sig.",
	"Ghoul": "En människoätare som frossar på lik i mörkret. Lukten avslöjar den långt innan klorna gör det.",
	"Jättespindel": "Stor som en hund och dubbelt så hungrig. Dess huggtänder dryper av förlamande gift.",
	"Skelettkrigare": "Ett skelett som mins sin svärdshand. Bär rostig rustning och en vrede som överlevt döden.",
	"Fantom": "En rastlös ande bunden vid platsen där den dog. Vapen biter dåligt på det som redan är borta.",
	"Ghulkungen": "Härskaren över kryptans vandöda — en gång en furste, nu en krönt as. Den som fäller honom tystar hela grottans hunger.",

	// ── Träsk ──
	"Giftpadda": "En uppsvälld padda vars hud svettas gift. Krossa den på avstånd, eller ångra det.",
	"Träskdjävul": "En slemtäckt best som reser sig ur dyn. Den drar ner offer i gyttjan och låter träsket göra resten.",
	"Sumpkräla": "En blodigel stor som en underarm. Fäster sig och suger tills den spricker.",
	"Sumpvarelse": "En vandrande klump av rötter, lera och något som en gång levde. Träsket självt har lärt sig att hata.",

	// ── Kust / pirater ──
	"Strandkrabba": "En argsint pansarkrabba som vaktar tidvattnet. Klorna knäcker ben — och oförsiktiga fingrar.",
	"Sjöorm": "En slingrande havsorm som jagar i bränningen. Glittrande fjäll, dödligt grepp.",
	"Pirat": "En härdad sjörövare med kortsvärd och kortare tålamod. Slåss smutsigt, dör skränande.",
	"Pirat Skytt": "En pirat med musköt och vasst öga. Håll dig inte stilla — och håll dig inte långt borta.",
	"Drunknad sjöman": "En sjöman som havet tog och spottade tillbaka. Vandrar stranden, sökande efter ett skepp som aldrig kommer.",
	"Piratkapten Svartöga": "Bränningens skräck, med ett öga av glas och ett hjärta av krut. Hans skatt är legendarisk — hans grymhet ännu mer.",

	// ── Öken ──
	"Sandorm": "En blek mask som simmar genom sanden. Den känner steg på avstånd och slår underifrån.",
	"Ökenmumie": "En balsamerad död som vägrar vila. Dess lindor döljer förbannelser äldre än kungariket.",
	"Ökengam": "En tålmodig asätare som kretsar över de döende. Hugger först när du är för svag att värja dig.",
	"Sandvaranen": "En pansrad ödla som basar på heta klippor. Snabbare än den ser ut — och svältfödd.",
	"Farao Khem-Ra": "Den begravde gudkonungen, väckt ur sin gyllene sarkofag. Hans vrede har legat och jäst i tusen år av tystnad.",

	// ── Vulkan ──
	"Lavavarelse": "En kropp av levande sten och glödande sprickor. Den lämnar brinnande fotspår var den går.",
	"Askhök": "En rovfågel som häckar i rök och gnistor. Dyker ur askmolnen med klor som hett järn.",
	"Glödmask": "En larv som äter sig genom vulkanberget. Dess inälvor lyser av smält malm.",
	"Sotdemon": "En mindre eldande sprungen ur kraterns djup. Sotsvart hud, ögon som kol — och en törst efter att bränna.",
	"Smältkonungen": "Vulkanens kärna gjuten till kung. Där han stiger fram smälter sten till sjöar och luften själv tar eld.",

	// ── Is ──
	"Istroll": "En frostbiten troll som jagar i snöyran. Långsam men obönhörlig, med nävar som krossar is och ben.",
	"Frostörn": "En vit rovfågel med vingar vassa som issplitter. Slår ner ljudlöst ur snöstormen.",
	"Snöuggla": "En tyst jägare med blick som ser genom yrsnö. Vacker — tills klorna träffar.",
	"Isvarelse": "En gestalt av kristalliserad köld. Dess beröring bränner som eld och stelnar blodet.",
	"Isdraken": "Den uråldriga frostdraken som sover under glaciären. Dess andedräkt fryser floder och dess vrede väcker laviner.",

	// ── Skog ──
	"Skogsvargen": "En mager skogsvarg som jagar i flock. Ensam är den feg; med sina bröder är den döden.",
	"Skogsbjörn": "En revirhävdande brunbjörn. Lämna ungarna i fred — eller bli ett varnande exempel.",
	"Urskogsvältaren": "En urgammal lövklädd jätte, vredgad väktare av skogens hjärta. Den krossar inkräktare som torra kvistar.",

	// ── Höjder / banditer / goblin ──
	"Varg": "En grå slättvarg, hungrig och hänsynslös. Den första riktiga tanden en vandrare möter.",
	"Goblin": "En liten gnällig grönhud med rostig dolk. Mer mod än vett, mer antal än mod.",
	"Goblinsoldat": "En goblin som hittat en hjälm och en idé om disciplin. Farligare i led än ensam.",
	"Bandit": "En vägrövare som hellre tar än arbetar. Bär ofta det stulna guldet på sig.",

	// ── Berg / troll ──
	"Troll": "En klumpig bergstroll med aptit på allt som rör sig. Stark, dum och förvånansvärt seg.",
	"Trollhövding": "Den största och argaste i flocken, krönt med ben och ärr. Att fälla honom bryter trollens vilja.",

	// ── Ork ──
	"Ork": "En muskulös krigare ur orchklanerna. Lever för strid och dör med ett rytande på läpparna.",
	"Orkshamanen": "En orch som mumlar till mörka andar. Lagar sina krigares sår och förbannar deras fiender.",
	"Orköverherre": "Klyftans krigsherre, byggd som en mur och dubbelt så hård. Hans rytande får hela rådet att darra.",

	// ── Minotaur-labyrinten ──
	"Minotaur": "En tjurhövdad best som vaktar irrgångarna. Den känner labyrinten utantill — och du gör det inte.",
	"MinotaurVakt": "En elitminotaur i tung rustning, satt att vakta de inre salarna. Tålamod av sten, yxa av järn.",
	"MinotaurKungen": "Labyrintens krönta tjur, härskare över irrgångarnas mörker. Ingen som mött hans yxa har funnit vägen ut.",

	// ── Dvärgsgruva ──
	"Dvärg": "En grävande gruvdvärg, snar till vrede över inkräktare i sina tunnlar. Hackan duger lika bra mot kött som mot sten.",
	"DvärgenSmeden": "En mästersmed som svingar sin slägga i strid. Hans rustning bär hundra års gnistor.",

	// ── Vampyrkrypta / nekromanti ──
	"Vampyr": "En blek odödlig som törstar efter blod. Den läker av varje sår den slår mot dig.",
	"VampyrHerre": "En urgammal blodsfurste, elegant och obarmhärtig. Sekler av törst har gjort honom till en mardröm med hovmanér.",
	"Nekromant": "En förrädare mot livet självt, som reser de döda till sin tjänst. Döda honom snabbt — annars blir de fler.",
	"Lich": "En trollkarl som bytte sin själ mot odödlighet. Bakom de tomma ögonhålorna brinner en evig, beräknande ondska.",

	// ── Drakar / demoner (endgame) ──
	"Elddraken": "En äldre elddrake vars vingslag väcker stormar av glöd. Hela byar har blivit aska för mindre än ett ögonkast av dess vrede.",
	"Ärkedemonen": "Avgrundens furste, frammanad av de mest hädiska ritualer. Att möta honom är att stirra in i världens ände — och de flesta blinkar.",
};

let added = 0, skipped = 0, missing = [];
for (const [name, desc] of Object.entries(LORE)) {
	if (!m[name]) { missing.push(name); continue; }
	if (m[name].desc) { skipped++; continue; }
	m[name].desc = desc;
	added++;
}
fs.writeFileSync("data/monsters.json", JSON.stringify(m, null, "\t") + "\n");
console.log(`Lore: ${added} tillagda, ${skipped} hade redan desc.`);
if (missing.length) console.log("VARNING okända monster:", missing.join(", "));
const still = Object.entries(m).filter(([k, v]) => !v.desc).map(([k]) => k);
console.log(`Kvar utan desc: ${still.length}` + (still.length ? " → " + still.join(", ") : ""));
