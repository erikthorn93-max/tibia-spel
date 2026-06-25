// Genererar 32x32 pixelart-sprites (PNG) för monster som saknar grafik.
// Återanvänder PNG-primitiverna från gen_sprites.js. Kör: node tools/gen_monster_sprites.js
const fs = require("fs");
const path = require("path");
const OUT = path.join(__dirname, "..", "assets", "sprites", "monsters");
const W = 32, H = 32;

// --- PNG-encoder ---
const crcTable = (() => { const t = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0); const tb = Buffer.from(type, "ascii"); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([tb, data])), 0); return Buffer.concat([len, tb, data, crc]); }
function encodePNG(im) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((W * 4 + 1) * H);
  for (let y = 0; y < H; y++) { raw[y * (W * 4 + 1)] = 0; for (let x = 0; x < W * 4; x++) raw[y * (W * 4 + 1) + 1 + x] = im[y * W * 4 + x]; }
  const zlib = require("zlib"); const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0))]);
}

// --- ritprimitiver ---
function img() { return new Uint8Array(W * H * 4); }
function px(im, x, y, c) { x |= 0; y |= 0; if (x < 0 || y < 0 || x >= W || y >= H) return; const i = (y * W + x) * 4; im[i] = c[0]; im[i + 1] = c[1]; im[i + 2] = c[2]; im[i + 3] = c[3] === undefined ? 255 : c[3]; }
function rect(im, x, y, w, h, c) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(im, x + i, y + j, c); }
function disc(im, cx, cy, r, c) { for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) if (x * x + y * y <= r * r) px(im, cx + x, cy + y, c); }
function oval(im, cx, cy, rx, ry, c) { for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++) if ((x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1) px(im, cx + x, cy + y, c); }
function ring(im, cx, cy, r, c) { for (let a = 0; a < 360; a += 4) px(im, cx + Math.round(r * Math.cos(a * Math.PI / 180)), cy + Math.round(r * Math.sin(a * Math.PI / 180)), c); }
function line(im, x0, y0, x1, y1, c, thick = 1) { const dx = Math.abs(x1 - x0), dy = Math.abs(y1 - y0); const sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1; let err = dx - dy; let x = x0, y = y0; for (; ;) { for (let t = 0; t < thick; t++) { px(im, x, y + t - (thick >> 1), c); px(im, x + t - (thick >> 1), y, c); } if (x === x1 && y === y1) break; const e2 = 2 * err; if (e2 > -dy) { err -= dy; x += sx; } if (e2 < dx) { err += dx; y += sy; } } }
function tri(im, x0, y0, x1, y1, x2, y2, c) { const minY = Math.min(y0, y1, y2), maxY = Math.max(y0, y1, y2); for (let y = minY; y <= maxY; y++) { const xs = []; const ed = [[x0, y0, x1, y1], [x1, y1, x2, y2], [x2, y2, x0, y0]]; for (const [ax, ay, bx, by] of ed) { if ((ay <= y && by > y) || (by <= y && ay > y)) xs.push(ax + (y - ay) / (by - ay) * (bx - ax)); } xs.sort((a, b) => a - b); for (let i = 0; i + 1 < xs.length; i += 2) for (let x = Math.round(xs[i]); x <= Math.round(xs[i + 1]); x++) px(im, x, y, c); } }
function outline(im, oc = [20, 18, 24, 255]) { const copy = im.slice(); for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const i = (y * W + x) * 4; if (copy[i + 3] === 0) { let near = false; for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < W && ny < H && copy[(ny * W + nx) * 4 + 3] > 0) near = true; } if (near) px(im, x, y, oc); } } }

function hex(h) { h = (h || "#888888").replace("#", ""); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), 255]; }
function scale(c, f) { return [Math.min(255, c[0] * f) | 0, Math.min(255, c[1] * f) | 0, Math.min(255, c[2] * f) | 0, 255]; }
const LITE = c => scale(c, 1.4), DARK = c => scale(c, 0.6);
const EYE = [240, 230, 90, 255];   // gula ögon

// --- monsterfigurer ---
function drawSpider(im, c, big = false) {
  const cx = 16, cy = 17, ab = big ? 9 : 7;        // bakkroppsradie
  // ben (4 par)
  for (const side of [-1, 1]) for (let k = 0; k < 4; k++) {
    const ang = (-35 + k * 24) * Math.PI / 180;
    const len = big ? 13 : 11;
    const kx = cx + side * 3, ky = cy - 1 + k;
    const ex = cx + side * Math.round(len * Math.cos(ang));
    const ey = cy - 4 + Math.round(len * Math.sin(ang)) + k * 2;
    line(im, kx, ky, cx + side * 6, ky - 2, DARK(c), 2);
    line(im, cx + side * 6, ky - 2, ex, ey, DARK(c), 2);
  }
  disc(im, cx, cy + 2, ab, c);                      // bakkropp
  disc(im, cx - 2, cy, ab - 2, LITE(c));            // highlight
  disc(im, cx, cy - ab + 1, big ? 6 : 5, scale(c, 0.85)); // huvud/framkropp
  // ögon
  px(im, cx - 2, cy - ab, EYE); px(im, cx + 2, cy - ab, EYE);
  if (big) { px(im, cx - 3, cy - ab + 2, EYE); px(im, cx + 3, cy - ab + 2, EYE);
    // krona på drottningen
    for (let i = -4; i <= 4; i += 2) line(im, cx + i, cy - ab - 4, cx + i, cy - ab - 7, [230, 200, 70, 255], 1);
    rect(im, cx - 5, cy - ab - 4, 11, 2, [230, 200, 70, 255]);
  }
}
function drawRodent(im, c) {  // mus/råtta
  const cx = 15, cy = 18;
  line(im, cx + 7, cy + 1, 29, cy - 3, scale(c, 1.1), 2);   // svans
  oval(im, cx, cy, 8, 6, c);                                 // kropp
  oval(im, cx - 2, cy - 2, 5, 4, LITE(c));                   // highlight
  disc(im, cx - 7, cy - 3, 4, c);                            // huvud
  disc(im, cx - 9, cy - 6, 2, scale(c, 0.9));               // öra
  disc(im, cx - 5, cy - 6, 2, scale(c, 0.9));
  px(im, cx - 8, cy - 3, [20, 20, 24, 255]);                 // öga
  px(im, cx - 11, cy - 2, [240, 180, 180, 255]);             // nos
  for (const dx of [-3, 2, 6]) line(im, cx + dx, cy + 5, cx + dx, cy + 8, DARK(c), 1); // ben
}
function drawRabbit(im, c) {  // kanin
  const cx = 16, cy = 19;
  oval(im, cx, cy, 8, 6, c);                                 // kropp
  oval(im, cx - 2, cy - 2, 5, 4, LITE(c));
  disc(im, cx - 5, cy - 5, 4, c);                            // huvud
  oval(im, cx - 7, cy - 11, 2, 5, scale(c, 0.95));           // öra v
  oval(im, cx - 3, cy - 11, 2, 5, scale(c, 0.95));           // öra h
  px(im, cx - 6, cy - 5, [30, 25, 28, 255]);                 // öga
  disc(im, cx + 8, cy + 1, 3, [240, 238, 230, 255]);         // svans
  for (const dx of [-4, 4]) line(im, cx + dx, cy + 5, cx + dx, cy + 8, DARK(c), 2); // ben
}
function drawBird(im, c) {  // kråka
  const cx = 16, cy = 16;
  oval(im, cx, cy + 2, 6, 8, c);                             // kropp (upprätt)
  oval(im, cx - 1, cy, 4, 6, LITE(c));
  disc(im, cx, cy - 7, 4, c);                                // huvud
  tri(im, cx + 3, cy - 8, cx + 10, cy - 7, cx + 3, cy - 5, [210, 160, 60, 255]); // näbb
  px(im, cx + 1, cy - 8, EYE);                               // öga
  tri(im, cx - 6, cy, cx - 1, cy + 2, cx - 4, cy + 9, DARK(c)); // vinge
  line(im, cx - 2, cy + 10, cx - 2, cy + 13, [210, 160, 60, 255], 1); // ben
  line(im, cx + 2, cy + 10, cx + 2, cy + 13, [210, 160, 60, 255], 1);
}
function drawBoar(im, c) {  // vildsvin
  const cx = 16, cy = 18;
  oval(im, cx, cy, 10, 7, c);                                // kropp
  oval(im, cx - 2, cy - 3, 6, 3, LITE(c));                   // rygg-highlight
  disc(im, cx - 8, cy + 1, 5, scale(c, 0.95));              // huvud
  tri(im, cx - 13, cy + 1, cx - 8, cy - 1, cx - 8, cy + 3, scale(c, 0.85)); // tryne
  px(im, cx - 9, cy - 1, [25, 20, 22, 255]);                 // öga
  disc(im, cx - 6, cy - 4, 2, DARK(c));                      // öra
  tri(im, cx - 12, cy + 2, cx - 10, cy + 4, cx - 14, cy + 5, [230, 225, 200, 255]); // bete
  for (const dx of [-6, -1, 4, 8]) line(im, cx + dx, cy + 6, cx + dx, cy + 10, DARK(c), 2); // ben
  // borst på ryggen
  for (let x = cx - 6; x <= cx + 4; x += 3) line(im, x, cy - 6, x, cy - 9, DARK(c), 1);
}

function drawScorpion(im, c) {  // glödskorpion
  const cx = 15, cy = 18;
  // svans som böjer sig upp över ryggen
  let px0 = cx + 4, py0 = cy + 1;
  const seg = [[6, -2], [9, -6], [10, -11], [8, -15]];
  for (const [dx, dy] of seg) { const nx = cx + dx, ny = cy + dy; line(im, px0, py0, nx, ny, c, 3); disc(im, nx, ny, 2, LITE(c)); px0 = nx; py0 = ny; }
  disc(im, cx + 8, cy - 16, 2, [255, 220, 90, 255]);          // gadd glöder
  oval(im, cx, cy + 1, 7, 5, c);                              // kropp
  oval(im, cx - 1, cy - 1, 5, 3, LITE(c));                    // highlight
  // ben
  for (const s of [-1, 1]) for (let k = 0; k < 3; k++) line(im, cx - 2 + k * 3, cy + 4, cx - 6 + k * 4, cy + 7 + s * 0, DARK(c), 1);
  disc(im, cx - 7, cy - 1, 3, c);                             // huvud
  // klor
  for (const s of [-1, 1]) { line(im, cx - 8, cy - 1 + s * 3, cx - 13, cy - 1 + s * 5, c, 2); disc(im, cx - 13, cy - 1 + s * 5, 2, LITE(c)); }
  px(im, cx - 8, cy - 2, EYE); px(im, cx - 6, cy - 2, EYE);
}
function drawScarab(im, c) {  // sandskarabé
  const cx = 16, cy = 17;
  // ben
  for (const s of [-1, 1]) for (let k = 0; k < 3; k++) line(im, cx + s * 4, cy - 2 + k * 4, cx + s * 10, cy - 4 + k * 5, DARK(c), 2);
  oval(im, cx, cy + 1, 9, 8, c);                              // skal
  line(im, cx, cy - 6, cx, cy + 8, DARK(c), 1);              // delningslinje
  oval(im, cx - 3, cy - 2, 4, 3, LITE(c));                    // glansfläck
  oval(im, cx + 4, cy + 2, 3, 4, LITE(c));
  disc(im, cx, cy - 8, 4, scale(c, 0.85));                   // huvud
  for (let i = -3; i <= 3; i += 2) line(im, cx + i, cy - 11, cx + i, cy - 14, scale(c, 0.7), 1); // antenner/horn
  px(im, cx - 2, cy - 8, EYE); px(im, cx + 2, cy - 8, EYE);
}
function drawWraith(im, c) {  // sandvålnad — svävande hamn
  const cx = 16;
  // trasig dimkjol
  for (let x = -8; x <= 8; x++) { const h = 26 + Math.round(3 * Math.sin(x * 0.9)); for (let y = 12; y < h; y++) if ((x + y) % 2 === 0) px(im, cx + x, y, scale(c, 0.8 + 0.2 * Math.random())); }
  oval(im, cx, 11, 8, 9, c);                                  // kåpa/kropp
  oval(im, cx - 2, 8, 4, 4, LITE(c));                         // highlight
  disc(im, cx, 8, 5, scale(c, 0.9));                          // huvud
  // huva-skugga
  for (let x = -5; x <= 5; x++) px(im, cx + x, 4, DARK(c));
  px(im, cx - 2, 8, [120, 230, 255, 255]); px(im, cx + 2, 8, [120, 230, 255, 255]); // spöklika ögon
  px(im, cx - 2, 9, [120, 230, 255, 160]); px(im, cx + 2, 9, [120, 230, 255, 160]);
}
function drawGuardian(im, c, big = false) {  // gravväktare / solkonung
  const cx = 16, cy = 16, gold = [230, 190, 70, 255];
  // ben
  rect(im, cx - 5, cy + 6, 4, 8, DARK(c)); rect(im, cx + 1, cy + 6, 4, 8, DARK(c));
  // bål med förgylld bröstplåt
  rect(im, cx - 6, cy - 4, 12, 11, c);
  rect(im, cx - 6, cy - 4, 12, 3, gold);
  oval(im, cx, cy + 1, 4, 4, gold);
  // armar + spjut
  rect(im, cx - 9, cy - 3, 3, 9, scale(c, 0.85)); rect(im, cx + 6, cy - 3, 3, 9, scale(c, 0.85));
  line(im, cx + 9, cy - 8, cx + 9, cy + 12, [150, 110, 60, 255], 2); tri(im, cx + 7, cy - 8, cx + 11, cy - 8, cx + 9, cy - 13, gold);
  // skallhuvud
  disc(im, cx, cy - 8, 5, [225, 215, 190, 255]);
  px(im, cx - 2, cy - 8, [180, 40, 30, 255]); px(im, cx + 2, cy - 8, [180, 40, 30, 255]); // glödande ögon
  rect(im, cx - 2, cy - 5, 4, 2, [60, 50, 50, 255]);          // käke
  if (big) {
    // krona av solstrålar
    for (let i = -5; i <= 5; i += 2) line(im, cx + i, cy - 13, cx + i, cy - 17, gold, 1);
    rect(im, cx - 6, cy - 13, 13, 2, gold);
    disc(im, cx, cy - 18, 2, [255, 230, 120, 255]);
  }
}
const MONSTERS = [
  ["Glödskorpion", "Glödskorpion", "#e0641e", "scorpion"],
  ["Sandskarabé", "Sandskarabé", "#3a8a5a", "scarab"],
  ["Sandvålnad", "Sandvålnad", "#cdbb92", "wraith"],
  ["Gravväktare", "Gravväktare", "#b8a55e", "guardian"],
  ["Solkonungen Akh-Mortis", "Solkonungen_Akh-Mortis", "#ffb020", "guardianboss"],
  ["Grottspindel", "Grottspindel", "#3a2f26", "spider"],
  ["Giftvävare", "Giftvävare", "#5a2a6a", "spider"],
  ["Skuggspindel", "Skuggspindel", "#1a1426", "spider"],
  ["Spindeldrottningen Morwena", "Spindeldrottningen_Morwena", "#4a1040", "spiderboss"],
  ["Fältmus", "Fältmus", "#8a7a5a", "rodent"],
  ["Vildkanin", "Vildkanin", "#b0a088", "rabbit"],
  ["Åkerkråka", "Åkerkråka", "#2a2a30", "bird"],
  ["Vildsvin", "Vildsvin", "#6a5440", "boar"],
];

let made = 0;
for (const [name, file, color, kind] of MONSTERS) {
  const im = img(); const c = hex(color);
  if (kind === "spider") drawSpider(im, c, false);
  else if (kind === "spiderboss") drawSpider(im, c, true);
  else if (kind === "scorpion") drawScorpion(im, c);
  else if (kind === "scarab") drawScarab(im, c);
  else if (kind === "wraith") drawWraith(im, c);
  else if (kind === "guardian") drawGuardian(im, c, false);
  else if (kind === "guardianboss") drawGuardian(im, c, true);
  else if (kind === "rodent") drawRodent(im, c);
  else if (kind === "rabbit") drawRabbit(im, c);
  else if (kind === "bird") drawBird(im, c);
  else if (kind === "boar") drawBoar(im, c);
  outline(im);
  fs.writeFileSync(path.join(OUT, file + ".png"), encodePNG(im));
  console.log("  ✓", file + ".png  (" + name + ")");
  made++;
}
console.log("Klart: " + made + " monster-sprites genererade.");
