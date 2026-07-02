#!/usr/bin/env node
// postprocess_sprite — enhetlig efterbehandling av sprite-PNG:er:
//   1. 1px mörk outline (samma färg [20,18,24] som gen_sprites.js/gen_monster_sprites.js)
//   2. konsekvent kontrast (mild percentilsträckning av luma)
//
// Idempotent: sprites som redan har outline (t.ex. från gen_*-scripten) lämnas
// orörda, och kontraststräckningen är ~no-op på redan normaliserade bilder.
// Används av generate-asset.js efter Blender-rendering, eller fristående:
//   node tools/postprocess_sprite.js <fil.png|mapp> [fler...] [--no-outline] [--no-contrast]
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUTLINE = [20, 18, 24];   // samma som gen_sprites.js / gen_monster_sprites.js
const ALPHA_FLOOR = 32;         // svagare alfa än så nollas (AA-spill från Blender)

// ── PNG-avkodning (filter 0–4, färgtyp 2/6, 8-bit, ej interlace) ─────────────
function decodePNG(buf) {
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error("inte en PNG");
  let i = 8, W = 0, H = 0, colorType = 0, bitDepth = 0;
  const idat = [];
  while (i < buf.length) {
    const len = buf.readUInt32BE(i);
    const type = buf.toString("ascii", i + 4, i + 8);
    const data = buf.slice(i + 8, i + 8 + len);
    if (type === "IHDR") {
      W = data.readUInt32BE(0); H = data.readUInt32BE(4);
      bitDepth = data[8]; colorType = data[9];
      if (bitDepth !== 8) throw new Error(`bit depth ${bitDepth} stöds ej`);
      if (colorType !== 6 && colorType !== 2) throw new Error(`färgtyp ${colorType} stöds ej (endast RGB/RGBA)`);
      if (data[12] !== 0) throw new Error("interlace stöds ej");
    }
    if (type === "IDAT") idat.push(data);
    if (type === "IEND") break;
    i += 12 + len;
  }
  const bpp = colorType === 6 ? 4 : 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = W * bpp;
  const px = Buffer.alloc(H * stride);
  const paeth = (a, b, c) => {
    const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
  };
  for (let y = 0; y < H; y++) {
    const f = raw[y * (stride + 1)];
    const row = y * stride, prev = row - stride;
    for (let x = 0; x < stride; x++) {
      const v = raw[y * (stride + 1) + 1 + x];
      const left = x >= bpp ? px[row + x - bpp] : 0;
      const up = y > 0 ? px[prev + x] : 0;
      const ul = y > 0 && x >= bpp ? px[prev + x - bpp] : 0;
      let out;
      if (f === 0) out = v;
      else if (f === 1) out = v + left;
      else if (f === 2) out = v + up;
      else if (f === 3) out = v + ((left + up) >> 1);
      else if (f === 4) out = v + paeth(left, up, ul);
      else throw new Error(`okänt PNG-filter ${f}`);
      px[row + x] = out & 0xff;
    }
  }
  // Normalisera till RGBA.
  if (bpp === 4) return { W, H, d: new Uint8Array(px) };
  const rgba = new Uint8Array(W * H * 4);
  for (let p = 0; p < W * H; p++) {
    rgba[p * 4] = px[p * 3]; rgba[p * 4 + 1] = px[p * 3 + 1];
    rgba[p * 4 + 2] = px[p * 3 + 2]; rgba[p * 4 + 3] = 255;
  }
  return { W, H, d: rgba };
}

// ── PNG-kodning (RGBA, filter 0) ─────────────────────────────────────────────
const crcTable = (() => { const t = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0); const tb = Buffer.from(type, "ascii"); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([tb, data])), 0); return Buffer.concat([len, tb, data, crc]); }
function encodePNG(W, H, d) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((W * 4 + 1) * H);
  for (let y = 0; y < H; y++) { raw[y * (W * 4 + 1)] = 0; for (let x = 0; x < W * 4; x++) raw[y * (W * 4 + 1) + 1 + x] = d[y * W * 4 + x]; }
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
}

// ── Steg 1: outline ───────────────────────────────────────────────────────────
// Har spriten redan outline? Kolla andelen opaka kantpixlar (opak med transparent
// 4-granne) som redan ligger nära outline-färgen. gen_*-scripten ger ~100%.
function hasOutline(W, H, d) {
  let edge = 0, dark = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4;
    if (d[i + 3] < ALPHA_FLOOR) continue;
    // Endast pixlar mot transparens räknas — bildkanten är ingen kontur
    // (full-bleed-tiles ska inte trigga outline-försök på nytt).
    let boundary = false;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx >= 0 && ny >= 0 && nx < W && ny < H && d[(ny * W + nx) * 4 + 3] < ALPHA_FLOOR) boundary = true;
    }
    if (!boundary) continue;
    edge++;
    if (Math.abs(d[i] - OUTLINE[0]) <= 30 && Math.abs(d[i + 1] - OUTLINE[1]) <= 30 && Math.abs(d[i + 2] - OUTLINE[2]) <= 30) dark++;
  }
  return edge > 0 && dark / edge >= 0.9;
}

function applyOutline(W, H, d) {
  const copy = d.slice();
  let added = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4;
    if (copy[i + 3] >= ALPHA_FLOOR) continue;
    let near = false;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx >= 0 && ny >= 0 && nx < W && ny < H && copy[(ny * W + nx) * 4 + 3] >= ALPHA_FLOOR) near = true;
    }
    if (!near) continue;
    d[i] = OUTLINE[0]; d[i + 1] = OUTLINE[1]; d[i + 2] = OUTLINE[2]; d[i + 3] = 255;
    added++;
  }
  return added;
}

// ── Steg 2: kontrast ──────────────────────────────────────────────────────────
// Mild percentilsträckning → konsekvent "pop" mellan handritade och
// Blender-renderade sprites. Percentiler beräknas på kanalvärden (inte luma)
// så att sträckningen landar exakt på målspannet — då blir en andra körning
// garanterat no-op (spannet ≥ 180 ⇒ hoppa över). Måste köras FÖRE outline
// så att outline-färgen inte förvanskas.
// Pixlar i outline-färgen lämnas orörda av kontrasten: annars ljusas befintliga
// konturer upp, hasOutline känner inte igen dem, och nästa körning lägger en
// ring till. Tolerans ±6 räcker för exakta gen_*-konturer.
function isOutlinePx(d, i) {
  return Math.abs(d[i] - OUTLINE[0]) <= 6 && Math.abs(d[i + 1] - OUTLINE[1]) <= 6 && Math.abs(d[i + 2] - OUTLINE[2]) <= 6;
}

function applyContrast(W, H, d) {
  const vals = [];
  for (let p = 0; p < W * H; p++) {
    if (d[p * 4 + 3] < 128 || isOutlinePx(d, p * 4)) continue;
    vals.push(d[p * 4], d[p * 4 + 1], d[p * 4 + 2]);
  }
  if (vals.length < 24) return false;
  vals.sort((a, b) => a - b);
  const lo = vals[Math.floor(vals.length * 0.02)];
  const hi = vals[Math.min(vals.length - 1, Math.floor(vals.length * 0.98))];
  const range = hi - lo;
  if (range >= 180 || range < 8) return false; // redan bra kontrast / enfärgad
  const TLO = 20, THI = 235, gain = (THI - TLO) / range;
  for (let p = 0; p < W * H; p++) {
    if (d[p * 4 + 3] < ALPHA_FLOOR || isOutlinePx(d, p * 4)) continue;
    for (let ch = 0; ch < 3; ch++) {
      const v = TLO + (d[p * 4 + ch] - lo) * gain;
      d[p * 4 + ch] = v < 0 ? 0 : v > 255 ? 255 : Math.round(v);
    }
  }
  return true;
}

// Kör kontrasten till fixpunkt (avrundning kan lämna spannet strax under
// tröskeln efter första sträckningen — då behövs ett varv till).
function applyContrastStable(W, H, d) {
  let changed = false;
  for (let i = 0; i < 4 && applyContrast(W, H, d); i++) changed = true;
  return changed;
}

// ── Huvudfunktion ─────────────────────────────────────────────────────────────
function postprocessFile(file, opts = {}) {
  const { W, H, d } = decodePNG(fs.readFileSync(file));
  // Nolla AA-spill med mycket låg alfa så outline inte lägger sig runt "spöken".
  for (let p = 0; p < W * H; p++) if (d[p * 4 + 3] < ALPHA_FLOOR) d[p * 4 + 3] = 0;

  // Ordning: kontrast FÖRE outline — annars förvanskar sträckningen
  // outline-färgen och nästa körning lägger en ring till (ej idempotent).
  const result = { file, outline: "hoppade över", contrast: "oförändrad" };
  if (opts.contrast !== false) result.contrast = applyContrastStable(W, H, d) ? "sträckt" : "oförändrad";
  if (opts.outline !== false) {
    if (hasOutline(W, H, d)) result.outline = "fanns redan";
    else result.outline = `+${applyOutline(W, H, d)} px`;
  }
  fs.writeFileSync(file, encodePNG(W, H, d));
  return result;
}

module.exports = { postprocessFile };

// ── CLI ───────────────────────────────────────────────────────────────────────
if (require.main === module) {
  const argv = process.argv.slice(2);
  const opts = { outline: !argv.includes("--no-outline"), contrast: !argv.includes("--no-contrast") };
  const targets = argv.filter((a) => !a.startsWith("--"));
  if (!targets.length) {
    console.error("Användning: node tools/postprocess_sprite.js <fil.png|mapp> [fler...] [--no-outline] [--no-contrast]");
    process.exit(1);
  }
  const files = [];
  for (const t of targets) {
    if (!fs.existsSync(t)) { console.error(`✖ finns inte: ${t}`); process.exit(1); }
    if (fs.statSync(t).isDirectory()) {
      for (const f of fs.readdirSync(t)) if (f.endsWith(".png")) files.push(path.join(t, f));
    } else files.push(t);
  }
  for (const f of files) {
    try {
      const r = postprocessFile(f, opts);
      console.log(`  ✓ ${path.basename(f)}  outline: ${r.outline}, kontrast: ${r.contrast}`);
    } catch (e) {
      console.error(`  ✖ ${path.basename(f)}: ${e.message}`);
    }
  }
  console.log(`Klart: ${files.length} fil(er).`);
}
