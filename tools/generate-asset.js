#!/usr/bin/env node
// generate-asset — textprompt → färdig 32×32 sprite-ikon i Tibia-stil.
// Flöde: Meshy Text-to-3D (preview → refine) → ladda ner .glb → headless
// Blender-rendering i fast 3/4-vinkel → beskär+skala till 32×32 → spara.
// Ren Node (fetch + child_process), inga npm-beroenden. Kräver Blender + MESHY_API_KEY.
//
// Användning:
//   node tools/generate-asset.js "iron sword" --name iron_sword --category items
//
// Blender hittas via env BLENDER, PATH, eller autodetektering i Program Files.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

// ── Konstanter ────────────────────────────────────────────────────────────────
const MESHY_BASE = "https://api.meshy.ai/openapi/v2/text-to-3d";
const ROOT = path.resolve(__dirname, "..");
const CACHE_DIR = path.join(ROOT, "assets", "_meshy_cache");
const SPRITES_DIR = path.join(ROOT, "assets", "sprites");
const RENDER_SCRIPT = path.join(__dirname, "blender_render_icon.py");
const TARGET_SIZE = 32;                 // Samma som befintliga item-ikoner
const POLL_INTERVAL_MS = 5000;
const POLL_TIMEOUT_MS = 20 * 60 * 1000; // 20 min tak per steg
// Ungefärlig credit-kostnad per Meshy-task (endast för sammanfattning/spårbarhet).
const CREDITS_PREVIEW = 5;
const CREDITS_REFINE = 10;

// ── Hjälpare ──────────────────────────────────────────────────────────────────
function die(msg) {
  console.error("\n✖ " + msg + "\n");
  process.exit(1);
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Minimal argparser: en positionell prompt + --name/--category.
function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) out[a.slice(2)] = argv[++i];
    else out._.push(a);
  }
  return out;
}

// Hittar Blender-körbara: env → PATH → vanliga Windows-installationer.
function findBlender() {
  const candidates = [];
  if (process.env.BLENDER) candidates.push(process.env.BLENDER);
  candidates.push("blender"); // om den ligger i PATH
  const pf = "C:\\Program Files\\Blender Foundation";
  if (fs.existsSync(pf)) {
    for (const d of fs.readdirSync(pf)) {
      const exe = path.join(pf, d, "blender.exe");
      if (fs.existsSync(exe)) candidates.push(exe);
    }
  }
  for (const c of candidates) {
    const r = spawnSync(c, ["--version"], { encoding: "utf8" });
    if (r.status === 0) return c;
  }
  return null;
}

// ── Meshy API ─────────────────────────────────────────────────────────────────
async function meshyPost(apiKey, body) {
  const res = await fetch(MESHY_BASE, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) die(`Meshy POST misslyckades (${res.status}): ${text}`);
  return JSON.parse(text).result; // task-id
}

async function meshyGet(apiKey, taskId) {
  const res = await fetch(`${MESHY_BASE}/${taskId}`, {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  const text = await res.text();
  if (!res.ok) die(`Meshy GET misslyckades (${res.status}): ${text}`);
  return JSON.parse(text);
}

// Upsertar assetens post i assets/manifest.json (skapas om det saknas).
// Full omsynk görs av tools/build-manifest.js — här uppdateras bara egna posten.
function updateManifest(entry) {
  const manifestPath = path.join(ROOT, "assets", "manifest.json");
  let doc = { generated: null, count: 0, assets: [] };
  if (fs.existsSync(manifestPath)) {
    try { doc = JSON.parse(fs.readFileSync(manifestPath, "utf8")); }
    catch (e) { console.warn("⚠ manifest.json gick inte att läsa, skriver om:", e.message); }
  }
  if (!Array.isArray(doc.assets)) doc.assets = [];
  const i = doc.assets.findIndex((a) => a.id === entry.id);
  if (i >= 0) doc.assets[i] = { ...doc.assets[i], ...entry };
  else doc.assets.push(entry);
  doc.assets.sort((a, b) => a.id.localeCompare(b.id, "sv"));
  doc.generated = new Date().toISOString();
  doc.count = doc.assets.length;
  fs.writeFileSync(manifestPath, JSON.stringify(doc, null, 2) + "\n");
  return manifestPath;
}

// Pollar en task tills SUCCEEDED. Avbryter vid FAILED/moderation eller timeout.
async function pollTask(apiKey, taskId, label) {
  const started = Date.now();
  let lastProgress = -1;
  while (true) {
    const t = await meshyGet(apiKey, taskId);
    if (t.status === "SUCCEEDED") {
      process.stdout.write(`\r  ${label}: 100% klart          \n`);
      return t;
    }
    if (t.status === "FAILED" || t.status === "CANCELED") {
      const err = t.task_error && t.task_error.message ? t.task_error.message : t.status;
      die(`Meshy ${label} avbröts: ${err}\n  (kan bero på innehållsmoderation — testa en annan prompt)`);
    }
    if (t.progress !== lastProgress) {
      lastProgress = t.progress;
      process.stdout.write(`\r  ${label}: ${t.progress || 0}% (${t.status})   `);
    }
    if (Date.now() - started > POLL_TIMEOUT_MS) die(`Meshy ${label} tog för lång tid (timeout).`);
    await sleep(POLL_INTERVAL_MS);
  }
}

// ── Huvudflöde ────────────────────────────────────────────────────────────────
async function main() {
  const args = parseArgs(process.argv.slice(2));
  const prompt = args._[0];
  const name = args.name;
  const category = args.category;

  if (!prompt || !name || !category) {
    die('Användning: node tools/generate-asset.js "iron sword" --name iron_sword --category items');
  }
  if (!/^[a-z0-9_]+$/.test(name)) die(`--name får bara innehålla a-z, 0-9 och _ (fick: "${name}")`);
  if (!/^[a-z0-9_]+$/.test(category)) die(`--category får bara innehålla a-z, 0-9 och _ (fick: "${category}")`);

  const apiKey = process.env.MESHY_API_KEY;
  if (!apiKey) {
    die("MESHY_API_KEY saknas.\n  Sätt den i miljön, t.ex. i PowerShell:  $env:MESHY_API_KEY=\"din-nyckel\"\n  Se .env.example för format. Lägg ALDRIG en riktig nyckel i git.");
  }

  const blender = findBlender();
  if (!blender) {
    die(
      "Blender hittades inte.\n" +
      "  • Installera Blender (https://www.blender.org/download/), eller\n" +
      "  • Peka ut den med env:  $env:BLENDER=\"C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe\"\n" +
      "  • ...eller lägg blender.exe i PATH."
    );
  }

  fs.mkdirSync(CACHE_DIR, { recursive: true });
  const glbPath = path.join(CACHE_DIR, `${name}.glb`);
  const metaPath = path.join(CACHE_DIR, `${name}.meshy.json`);
  const outDir = path.join(SPRITES_DIR, category);
  const outPath = path.join(outDir, `${name}.png`);
  fs.mkdirSync(outDir, { recursive: true });

  let meta = { name, prompt, previewTaskId: null, refineTaskId: null, credits: 0, cached: false };

  // Steg 1–2: generering — hoppa över om .glb redan finns i cachen.
  if (fs.existsSync(glbPath)) {
    console.log(`↩ Återanvänder cachad modell: ${path.relative(ROOT, glbPath)}`);
    meta.cached = true;
    if (fs.existsSync(metaPath)) meta = { ...meta, ...JSON.parse(fs.readFileSync(metaPath, "utf8")), cached: true };
  } else {
    console.log(`▶ Meshy Text-to-3D: "${prompt}"`);

    // Steg 1: preview (grovgeometri).
    const previewId = await meshyPost(apiKey, { mode: "preview", prompt, should_remesh: true });
    meta.previewTaskId = previewId;
    console.log(`  preview-task: ${previewId}`);
    await pollTask(apiKey, previewId, "preview");
    meta.credits += CREDITS_PREVIEW;

    // Steg 2: refine (texturering) via preview-task-id.
    const refineId = await meshyPost(apiKey, { mode: "refine", preview_task_id: previewId });
    meta.refineTaskId = refineId;
    console.log(`  refine-task:  ${refineId}`);
    const refined = await pollTask(apiKey, refineId, "refine");
    meta.credits += CREDITS_REFINE;

    // Ladda ner .glb till cachen.
    const glbUrl = refined.model_urls && refined.model_urls.glb;
    if (!glbUrl) die("Meshy returnerade ingen .glb-url i model_urls.");
    console.log("⬇ Laddar ner .glb ...");
    const glbRes = await fetch(glbUrl);
    if (!glbRes.ok) die(`Nedladdning av .glb misslyckades (${glbRes.status}).`);
    fs.writeFileSync(glbPath, Buffer.from(await glbRes.arrayBuffer()));
    fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2));
    console.log(`  sparad: ${path.relative(ROOT, glbPath)}`);
  }

  // Steg 3–4: headless Blender-rendering + beskär/skala (allt i Blender-scriptet).
  console.log("▶ Renderar i Blender (3/4-vinkel) ...");
  const r = spawnSync(
    blender,
    ["--background", "--python", RENDER_SCRIPT, "--",
      "--glb", glbPath, "--out", outPath, "--size", String(TARGET_SIZE)],
    { stdio: "inherit" }
  );
  if (r.status !== 0) die("Blender-rendering misslyckades (se utskrift ovan).");
  if (!fs.existsSync(outPath)) die("Blender producerade ingen PNG — okänt fel.");

  // Steg 4b: enhetlig efterbehandling (1px outline + kontrast) — samma stil
  // som de handritade sprites från gen_sprites.js/gen_monster_sprites.js.
  console.log("▶ Efterbehandlar (outline + kontrast) ...");
  const pp = require("./postprocess_sprite.js").postprocessFile(outPath);
  console.log(`  outline: ${pp.outline}, kontrast: ${pp.contrast}`);

  // Steg 5: uppdatera manifestet.
  const manifestPath = updateManifest({
    id: name,
    category,
    prompt,
    glb: path.relative(ROOT, glbPath).split(path.sep).join("/"),
    sprite: path.relative(ROOT, outPath).split(path.sep).join("/"),
    renderParams: { size: TARGET_SIZE, angle: "3/4", script: "tools/blender_render_icon.py", postprocess: { outline: true, contrast: true } },
    source: "meshy",
  });

  // Steg 6: sammanfattning.
  console.log("\n✔ Klar!");
  console.log(`  Ikon:        ${path.relative(ROOT, outPath)}  (${TARGET_SIZE}×${TARGET_SIZE})`);
  console.log(`  GLB-cache:   ${path.relative(ROOT, glbPath)}`);
  console.log(`  Manifest:    ${path.relative(ROOT, manifestPath)} (post "${name}" uppdaterad)`);
  if (meta.cached) {
    console.log("  Meshy:       (cachad — ingen ny generering, 0 credits)");
  } else {
    console.log(`  Meshy tasks: preview=${meta.previewTaskId}  refine=${meta.refineTaskId}`);
    console.log(`  Credits:     ~${meta.credits} (uppskattat)`);
  }
}

main().catch((e) => die(e && e.stack ? e.stack : String(e)));
