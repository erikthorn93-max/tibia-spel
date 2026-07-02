#!/usr/bin/env node
// build-manifest — skannar assets/_meshy_cache/ och assets/sprites/ och bygger
// assets/manifest.json: en post per asset med id, category, prompt, glb, sprite,
// renderParams och source (meshy/manual).
//
// Körs om från början varje gång men bevarar fält som inte kan härledas ur
// filsystemet (renderParams, handskriven prompt) från befintligt manifest.
// generate-asset.js uppdaterar sin egen post efter lyckad körning; det här
// scriptet är helhetssynken. Kör: node tools/build-manifest.js
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const CACHE_DIR = path.join(ROOT, "assets", "_meshy_cache");
const SPRITES_DIR = path.join(ROOT, "assets", "sprites");
const MANIFEST = path.join(ROOT, "assets", "manifest.json");

const rel = (p) => path.relative(ROOT, p).split(path.sep).join("/");

// ── Befintligt manifest (för att bevara renderParams m.m.) ───────────────────
let prev = {};
if (fs.existsSync(MANIFEST)) {
  try {
    for (const a of JSON.parse(fs.readFileSync(MANIFEST, "utf8")).assets || []) prev[a.id] = a;
  } catch (e) {
    console.warn("⚠ Kunde inte läsa befintligt manifest, bygger från noll:", e.message);
  }
}

const entries = new Map(); // id → post

function upsert(id, patch) {
  const cur = entries.get(id) || {
    id, category: null, prompt: null, glb: null, sprite: null, renderParams: null, source: "manual",
  };
  for (const [k, v] of Object.entries(patch)) if (v !== undefined && v !== null) cur[k] = v;
  entries.set(id, cur);
  return cur;
}

// ── 1. GLB-cachen: .glb + .meshy.json ────────────────────────────────────────
if (fs.existsSync(CACHE_DIR)) {
  const files = fs.readdirSync(CACHE_DIR);
  const ids = new Set();
  for (const f of files) {
    if (f.endsWith(".glb")) ids.add(f.slice(0, -4));
    else if (f.endsWith(".meshy.json")) ids.add(f.slice(0, -11));
  }
  for (const id of ids) {
    const glbPath = path.join(CACHE_DIR, `${id}.glb`);
    const metaPath = path.join(CACHE_DIR, `${id}.meshy.json`);
    let meta = {};
    if (fs.existsSync(metaPath)) {
      try { meta = JSON.parse(fs.readFileSync(metaPath, "utf8")); }
      catch (e) { console.warn(`⚠ Trasig metadata ignoreras: ${id}.meshy.json (${e.message})`); }
    }
    upsert(id, {
      category: meta.category,
      prompt: meta.prompt,
      glb: fs.existsSync(glbPath) ? rel(glbPath) : null,
      source: meta.source === "unknown" ? "unknown" : "meshy",
    });
  }
}

// ── 2. Sprites: assets/sprites/<category>/*.png ──────────────────────────────
if (fs.existsSync(SPRITES_DIR)) {
  for (const dirent of fs.readdirSync(SPRITES_DIR, { withFileTypes: true })) {
    if (!dirent.isDirectory()) continue;
    const category = dirent.name;
    for (const f of fs.readdirSync(path.join(SPRITES_DIR, category))) {
      if (!f.endsWith(".png")) continue;
      const name = f.slice(0, -4);
      // Samma namn kan finnas i cachen (Meshy-genererad) eller vara helt manuell.
      const existing = entries.get(name);
      if (existing && existing.category && existing.category !== category) {
        // Namnkrock mellan kategorier — gör id:t unikt.
        upsert(`${name}_${category}`, { category, sprite: rel(path.join(SPRITES_DIR, category, f)) });
      } else {
        upsert(name, { category, sprite: rel(path.join(SPRITES_DIR, category, f)) });
      }
    }
  }
}

// ── 3. Bevara icke-härledbara fält från förra manifestet ─────────────────────
for (const [id, cur] of entries) {
  const old = prev[id];
  if (!old) continue;
  if (!cur.renderParams && old.renderParams) cur.renderParams = old.renderParams;
  if (!cur.prompt && old.prompt) cur.prompt = old.prompt;
  if (!cur.category && old.category) cur.category = old.category;
}

// ── 4. Skriv ─────────────────────────────────────────────────────────────────
const assets = [...entries.values()].sort((a, b) => a.id.localeCompare(b.id, "sv"));
const out = { generated: new Date().toISOString(), count: assets.length, assets };
fs.writeFileSync(MANIFEST, JSON.stringify(out, null, 2) + "\n");

const stats = assets.reduce((s, a) => { s[a.source] = (s[a.source] || 0) + 1; return s; }, {});
console.log(`✔ ${rel(MANIFEST)}: ${assets.length} assets (${Object.entries(stats).map(([k, v]) => `${v} ${k}`).join(", ")})`);
console.log(`  med glb: ${assets.filter(a => a.glb).length}, med sprite: ${assets.filter(a => a.sprite).length}, båda: ${assets.filter(a => a.glb && a.sprite).length}`);
