// Genererar 32x32 pixelart-sprites (PNG) för alla items som saknar grafik.
// Ikonform väljs per typ/nyckelord, färgsätts efter items "color". Ren Node + zlib.
const fs = require("fs");
const zlib = require("zlib");
const items = JSON.parse(fs.readFileSync("data/items.json", "utf8"));
const DIR = "assets/sprites/items/";
const W = 32, H = 32;

// ── PNG-kodning ──────────────────────────────────────────────────────────────
const crcTable = (() => {
  const t = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); t[n] = c >>> 0; } return t;
})();
function crc32(buf) { let c = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const tb = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([tb, data])), 0);
  return Buffer.concat([len, tb, data, crc]);
}
function encodePNG(img) {
  const raw = Buffer.alloc((W * 4 + 1) * H); let p = 0;
  for (let y = 0; y < H; y++) { raw[p++] = 0; for (let x = 0; x < W * 4; x++) raw[p++] = img[y * W * 4 + x]; }
  const idat = zlib.deflateSync(raw, { level: 9 });
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0))]);
}

// ── Rit-primitiver ──────────────────────────────────────────────────────────
function img() { return new Uint8Array(W * H * 4); }
function px(im, x, y, c) { x |= 0; y |= 0; if (x < 0 || y < 0 || x >= W || y >= H) return; const i = (y * W + x) * 4; im[i] = c[0]; im[i + 1] = c[1]; im[i + 2] = c[2]; im[i + 3] = c[3] === undefined ? 255 : c[3]; }
function rect(im, x, y, w, h, c) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(im, x + i, y + j, c); }
function disc(im, cx, cy, r, c) { for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) if (x * x + y * y <= r * r) px(im, cx + x, cy + y, c); }
function ring(im, cx, cy, r, c) { for (let a = 0; a < 360; a += 4) px(im, cx + Math.round(r * Math.cos(a * Math.PI / 180)), cy + Math.round(r * Math.sin(a * Math.PI / 180)), c); }
function line(im, x0, y0, x1, y1, c, thick = 1) {
  x0|=0;y0|=0;x1|=0;y1|=0;
  let dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
  while (true) { for (let t = 0; t < thick; t++) { px(im, x0 + t, y0, c); if (thick > 1) px(im, x0, y0 + t, c); } if (x0 === x1 && y0 === y1) break; const e2 = 2 * err; if (e2 >= dy) { err += dy; x0 += sx; } if (e2 <= dx) { err += dx; y0 += sy; } }
}
function tri(im, x0,y0,x1,y1,x2,y2,c){ // fylld triangel (scanline)
  const miny=Math.min(y0,y1,y2),maxy=Math.max(y0,y1,y2);
  for(let y=miny;y<=maxy;y++){const xs=[];
    [[x0,y0,x1,y1],[x1,y1,x2,y2],[x2,y2,x0,y0]].forEach(([ax,ay,bx,by])=>{if((ay<=y&&by>y)||(by<=y&&ay>y)){xs.push(ax+(y-ay)/(by-ay)*(bx-ax));}});
    xs.sort((a,b)=>a-b); for(let k=0;k<xs.length;k+=2){if(xs[k+1]===undefined)break;for(let x=Math.round(xs[k]);x<=Math.round(xs[k+1]);x++)px(im,x,y,c);}}
}
// Mörk kontur runt allt opakt
function outline(im, oc = [20, 18, 24, 255]) {
  const copy = Uint8Array.from(im);
  const op = (x, y) => x >= 0 && y >= 0 && x < W && y < H && copy[(y * W + x) * 4 + 3] > 40;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (copy[(y * W + x) * 4 + 3] > 40) continue;
    if (op(x - 1, y) || op(x + 1, y) || op(x, y - 1) || op(x, y + 1)) px(im, x, y, oc);
  }
}

// ── Färghjälp ────────────────────────────────────────────────────────────────
function hex(h) { h = (h || "#888888").replace("#", ""); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), 255]; }
function scale(c, f) { return [Math.min(255, c[0] * f) | 0, Math.min(255, c[1] * f) | 0, Math.min(255, c[2] * f) | 0, 255]; }
const DARK = c => scale(c, 0.6), LITE = c => scale(c, 1.35);

// ── Ikon-mallar ──────────────────────────────────────────────────────────────
function drawGem(im, c) { // fasetterad ädelsten
  tri(im, 16, 5, 8, 13, 24, 13, LITE(c));          // topp-tabell
  tri(im, 8, 13, 24, 13, 16, 27, c);               // krona ner mot spets
  tri(im, 8, 13, 16, 13, 11, 19, scale(c, 0.75));  // vänster fasett (skugga)
  tri(im, 16, 13, 24, 13, 21, 19, scale(c, 1.3));  // höger fasett (ljus)
  line(im, 8, 13, 24, 13, LITE(c));                // gördellinje
  px(im, 14, 9, [255, 255, 255, 235]); px(im, 15, 10, [255, 255, 255, 170]); // glans
}
function drawCoin(im, c) { // mynthög
  for (const [x, y, r] of [[11, 22, 5], [21, 22, 5], [16, 18, 6]]) {
    disc(im, x, y, r, c); disc(im, x, y, r, [c[0], c[1], c[2], 255]);
    ring(im, x, y, r, DARK(c)); disc(im, x - 1, y - 1, 2, LITE(c));
  }
}
function drawGoblet(im, c) { // juvelbägare/skatt
  for (let y = 6; y <= 14; y++) { const r = Math.round(6 - (y - 6) * 0.3); for (let x = -r; x <= r; x++) px(im, 16 + x, y, c); }
  rect(im, 15, 14, 2, 7, scale(c, 0.8)); rect(im, 11, 21, 10, 2, c);  // stam + fot
  rect(im, 10, 7, 12, 2, LITE(c)); disc(im, 16, 9, 2, [220, 60, 80, 255]); // juvel
}
function drawOre(im, c) { // klumpig sten med ådror
  const stone = [90, 92, 100, 255];
  disc(im, 16, 18, 10, stone); disc(im, 12, 14, 6, scale(stone, 1.15)); disc(im, 21, 21, 5, scale(stone, 0.8));
  for (const [x, y] of [[12, 16], [18, 13], [20, 20], [14, 22], [22, 16]]) disc(im, x, y, 2, c);
  for (const [x, y] of [[13, 17], [19, 14]]) px(im, x, y, LITE(c));
}
function drawLog(im, c) { rect(im, 4, 12, 24, 9, c); rect(im, 4, 12, 24, 2, LITE(c)); rect(im, 4, 19, 24, 2, DARK(c)); disc(im, 6, 16, 4, DARK(c)); ring(im, 6, 16, 2, scale(c, 0.9)); disc(im, 26, 16, 4, scale(c, 0.9)); }
function drawPlank(im, c) { rect(im, 5, 13, 22, 7, c); rect(im, 5, 13, 22, 2, LITE(c)); rect(im, 5, 18, 22, 2, DARK(c)); for (let x = 8; x < 27; x += 6) line(im, x, 13, x, 19, DARK(c)); }
function drawHerb(im, c) { line(im, 16, 26, 16, 14, [60, 110, 50, 255], 2); for (const [dx, dy] of [[-5, -2], [5, -2], [-4, -6], [4, -6], [0, -9]]) disc(im, 16 + dx, 14 + dy, 3, c); disc(im, 16, 12, 2, LITE(c)); }
function drawFur(im, c) { tri(im, 8, 8, 24, 8, 16, 26, c); tri(im, 8, 8, 16, 26, 10, 10, DARK(c)); for (const [x, y] of [[14, 13], [18, 15], [16, 19]]) px(im, x, y, LITE(c)); }
function drawBones(im, c) { const b = c[0] > 100 ? c : [220, 214, 196, 255]; line(im, 8, 24, 24, 8, b, 3); disc(im, 8, 24, 3, b); disc(im, 24, 8, 3, b); disc(im, 7, 22, 2, b); disc(im, 25, 10, 2, b); }
function drawAsh(im, c) { tri(im, 8, 24, 24, 24, 16, 16, c); for (const [x, y] of [[12, 14], [20, 12], [16, 10]]) { px(im, x, y, [255, 255, 200, 255]); px(im, x + 1, y, [255, 255, 220, 200]); } }
function drawFish(im, c) { for (let x = 6; x < 24; x++) { const r = Math.round(5 * Math.sin((x - 6) / 18 * Math.PI)); for (let y = -r; y <= r; y++) px(im, x, 16 + y, c); } tri(im, 23, 16, 28, 11, 28, 21, c); disc(im, 10, 14, 1, [20, 20, 20, 255]); for (let x = 9; x < 22; x += 4) line(im, x, 13, x, 19, DARK(c)); }
function drawVeg(im, c) { disc(im, 16, 18, 9, c); disc(im, 13, 15, 4, LITE(c)); line(im, 16, 9, 16, 5, [60, 120, 50, 255], 2); disc(im, 15, 5, 2, [70, 140, 60, 255]); }
function drawPie(im, c) { disc(im, 16, 19, 10, [200, 160, 90, 255]); rect(im, 6, 18, 20, 6, [170, 130, 70, 255]); disc(im, 16, 16, 7, c); for (const [x, y] of [[13, 14], [19, 15], [16, 18]]) px(im, x, y, LITE(c)); }
function drawPotion(im, c) { rect(im, 13, 6, 6, 4, [210, 220, 230, 255]); tri(im, 10, 12, 22, 12, 16, 12, [200, 210, 220, 255]); for (let y = 12; y < 27; y++) { const r = Math.round(7 * Math.sin((y - 9) / 20 * Math.PI)) + 2; for (let x = -r; x <= r; x++) px(im, 16 + x, y, [210, 220, 230, 90]); } disc(im, 16, 22, 6, c); disc(im, 16, 22, 6, [c[0], c[1], c[2], 210]); disc(im, 14, 20, 2, LITE(c)); ring(im, 16, 21, 7, [200, 215, 230, 255]); }
function drawRune(im, c) { rect(im, 7, 6, 18, 22, scale(c, 0.45)); rect(im, 9, 8, 14, 18, scale(c, 0.7)); rect(im, 7, 6, 18, 2, LITE(c)); // glyf
  line(im, 16, 11, 16, 23, LITE(c), 2); line(im, 16, 14, 12, 17, LITE(c), 2); line(im, 16, 17, 20, 14, LITE(c), 2); disc(im, 16, 11, 2, [255, 255, 255, 230]); }
function drawSword(im, c) { line(im, 24, 7, 12, 21, c, 3); line(im, 24, 7, 13, 20, LITE(c), 1); line(im, 10, 19, 16, 25, [120, 90, 50, 255], 3); line(im, 9, 24, 14, 29, [90, 70, 40, 255], 2); disc(im, 11, 27, 2, [200, 170, 80, 255]); }
function drawBow(im, c) { for (let t = 0; t < 18; t++) { const a = (-50 + t * 6) * Math.PI / 180; px(im, 12 + Math.round(11 * Math.cos(a)), 16 + Math.round(11 * Math.sin(a)), c); px(im, 12 + Math.round(12 * Math.cos(a)), 16 + Math.round(12 * Math.sin(a)), DARK(c)); } line(im, 12 + Math.round(11 * Math.cos(-50 * Math.PI / 180)), 16 + Math.round(11 * Math.sin(-50 * Math.PI / 180)), 12 + Math.round(11 * Math.cos(58 * Math.PI / 180)), 16 + Math.round(11 * Math.sin(58 * Math.PI / 180)), [230, 230, 210, 255]); }
function drawArrow(im, c) { line(im, 6, 26, 24, 8, [150, 120, 80, 255], 2); tri(im, 24, 8, 20, 10, 26, 14, c); line(im, 6, 26, 9, 24, [230, 230, 220, 255], 1); line(im, 6, 26, 8, 28, [230, 230, 220, 255], 1); }
function drawHelmet(im, c) { for (let x = 7; x <= 25; x++) { const r = Math.round(9 * Math.sin((x - 7) / 18 * Math.PI)); for (let y = 0; y <= r; y++) px(im, x, 18 - y, c); } rect(im, 7, 16, 19, 4, DARK(c)); rect(im, 14, 9, 4, 9, scale(c, 0.5)); rect(im, 8, 11, 17, 2, LITE(c)); }
function drawBody(im, c) { rect(im, 9, 9, 14, 16, c); tri(im, 9, 9, 4, 14, 9, 18, c); tri(im, 23, 9, 28, 14, 23, 18, c); rect(im, 9, 9, 14, 3, LITE(c)); rect(im, 9, 22, 14, 3, DARK(c)); line(im, 16, 9, 16, 25, DARK(c)); }
function drawLegs(im, c) { rect(im, 9, 8, 14, 6, c); rect(im, 9, 14, 6, 12, c); rect(im, 17, 14, 6, 12, c); rect(im, 9, 8, 14, 2, LITE(c)); rect(im, 9, 24, 6, 2, DARK(c)); rect(im, 17, 24, 6, 2, DARK(c)); }
function drawShield(im, c) { for (let y = 6; y <= 26; y++) { const t = (y - 6) / 20; const r = Math.round(10 * (1 - t * t)); for (let x = -r; x <= r; x++) px(im, 16 + x, y, c); } line(im, 16, 6, 16, 26, LITE(c), 2); line(im, 6, 11, 26, 11, DARK(c)); ring(im, 16, 14, 4, [230, 220, 160, 255]); }
function drawBoot(im, c) { rect(im, 11, 8, 7, 14, c); rect(im, 11, 18, 14, 6, c); rect(im, 11, 22, 16, 3, DARK(c)); rect(im, 11, 8, 7, 2, LITE(c)); }
function drawAmulet(im, c) { for (let a = 200; a <= 340; a += 6) px(im, 16 + Math.round(8 * Math.cos(a * Math.PI / 180)), 12 + Math.round(8 * Math.sin(a * Math.PI / 180)), [210, 200, 150, 255]); disc(im, 16, 20, 5, c); disc(im, 14, 18, 2, LITE(c)); ring(im, 16, 20, 5, [220, 210, 160, 255]); }
function drawRing(im, c) { ring(im, 16, 19, 7, [220, 200, 120, 255]); ring(im, 16, 19, 6, [240, 220, 140, 255]); disc(im, 16, 11, 3, c); disc(im, 15, 10, 1, LITE(c)); }
function drawTable(im, c) { rect(im, 6, 12, 20, 4, c); rect(im, 6, 12, 20, 2, LITE(c)); rect(im, 8, 16, 3, 11, DARK(c)); rect(im, 21, 16, 3, 11, DARK(c)); }
function drawChair(im, c) { rect(im, 10, 6, 4, 20, c); rect(im, 10, 16, 12, 4, c); rect(im, 10, 16, 12, 2, LITE(c)); rect(im, 11, 20, 2, 7, DARK(c)); rect(im, 19, 20, 2, 7, DARK(c)); }
function drawCabinet(im, c) { rect(im, 8, 6, 16, 22, c); rect(im, 8, 6, 16, 2, LITE(c)); line(im, 16, 6, 16, 28, DARK(c)); disc(im, 13, 17, 1, [240, 230, 160, 255]); disc(im, 19, 17, 1, [240, 230, 160, 255]); }
function drawKnife(im, c) { line(im, 8, 22, 22, 10, c, 4); line(im, 8, 22, 21, 10, LITE(c), 1); rect(im, 6, 21, 5, 5, [90, 70, 40, 255]); }
function drawDrumstick(im, c) { disc(im, 12, 14, 6, [170, 90, 50, 255]); disc(im, 11, 12, 3, [200, 120, 70, 255]); line(im, 16, 17, 26, 26, [235, 225, 200, 255], 3); disc(im, 26, 26, 2, [235, 225, 200, 255]); }
function drawDefault(im, c) { disc(im, 16, 16, 9, c); disc(im, 13, 13, 4, LITE(c)); }

// ── Mall-väljare ─────────────────────────────────────────────────────────────
function pick(id, type) {
  const has = (s) => id.includes(s);
  if (type === "rune") return drawRune;
  if (type === "potion") return drawPotion;
  if (type === "ammo") return drawArrow;
  if (type === "furniture") { if (has("table")) return drawTable; if (has("chair") || has("throne")) return drawChair; return drawCabinet; }
  if (type === "weapon") { if (has("bow")) return drawBow; if (has("knuckle")) return drawKnife; return drawSword; }
  if (type === "armor") {
    if (has("helmet")) return drawHelmet;
    if (has("legs")) return drawLegs;
    if (has("shield")) return drawShield;
    if (has("boots")) return drawBoot;
    if (has("amulet") || has("charm") || has("symbol")) return drawAmulet;
    if (has("ring")) return drawRing;
    return drawBody; // platebody/body/robe/cloak/vest
  }
  if (type === "food") {
    if (has("pie") || has("bread") || has("stew")) return drawPie;
    if (has("cooked") || has("baked")) return drawFish;
    if (has("potato") || has("cabbage") || has("corn") || has("pumpkin") || has("apple")) return drawVeg;
    return drawDrumstick;
  }
  // ädelstenar & skatter
  if (/(^|_)(ruby|emerald|sapphire|diamond|topaz|amethyst|opal|pearl|gem)(_|$)/.test(id)) return drawGem;
  if (has("coin") || has("nugget")) return drawCoin;
  if (has("goblet") || has("chalice") || has("crown") && has("jewel")) return drawGoblet;
  // material & övrigt
  if (has("_ore") || id === "coal") return drawOre;
  if (has("plank")) return drawPlank;
  if (has("_log")) return drawLog;
  if (has("herb") || id === "dragonherb") return drawHerb;
  if (has("fur") || has("pelt") || has("hide")) return drawFur;
  if (has("bone")) return drawBones;
  if (has("ash")) return drawAsh;
  if (id.startsWith("raw_")) return drawFish;
  return drawDefault;
}

// ── Generera ─────────────────────────────────────────────────────────────────
const have = new Set(fs.readdirSync(DIR).filter(f => f.endsWith(".png")).map(f => f.slice(0, -4)));
let made = 0, skip = 0;
for (const id in items) {
  const it = items[id];
  const sp = it.sprite;
  if (!sp || !sp.includes("/items/")) continue;
  const base = sp.split("/").pop().replace(".png", "");
  if (have.has(base)) { skip++; continue; }
  const im = img();
  const c = hex(it.color);
  pick(id, it.type)(im, c);
  outline(im);
  fs.writeFileSync(DIR + base + ".png", encodePNG(im));
  made++;
}
console.log("genererade sprites:", made, "| fanns redan:", skip);
