# -*- coding: utf-8 -*-
"""Engångsgenerator för data/zones/swamp.json — garanterar lika radlängder."""
import json, io

W, H = 40, 24
rows = [["s"] * W for _ in range(H)]

def put(x, y, ch):
    rows[y][x] = ch

# Yttermurar
for x in range(W):
    put(x, 0, "W"); put(x, H - 1, "W")
for y in range(H):
    put(0, y, "W"); put(W - 1, y, "W")

# Entré från skogen (NV)
put(2, 2, "P")
put(3, 2, "0")   # portal -> forest

# Vattenpöl nordväst med ålstim
for x, y in [(13, 2), (14, 2), (13, 3), (15, 3), (14, 4), (15, 4)]:
    put(x, y, "~")
put(14, 3, "E")  # eel_spot (terräng ~)

# Vattenpöl sydväst med ålstim
for x, y in [(5, 19), (6, 19), (5, 20), (7, 20)]:
    put(x, y, "~")
put(6, 20, "E")

# Kärrörtsfläckar (herbalism 25)
for x, y in [(20, 2), (10, 7), (30, 9), (6, 15)]:
    put(x, y, "h")

# Giftpaddor
for x, y in [(21, 4), (2, 6), (19, 7), (28, 5), (12, 11), (24, 13)]:
    put(x, y, "p")

# Träskdjävlar (utanför hjärtat)
for x, y in [(33, 2), (30, 5), (8, 18), (20, 17)]:
    put(x, y, "d")

# Murklumpar för struktur
for x, y in [(17, 10), (18, 10), (17, 11), (24, 8), (25, 8)]:
    put(x, y, "W")

# Träskets hjärta: muromgärdat SE-hörn, gate "2" i västra muren
for y in range(15, H - 1):
    put(28, y, "W")
for x in range(28, W - 1):
    put(x, 15, "W")
put(28, 19, "2")  # gate traskets_hjarta
for x, y in [(32, 17), (35, 20)]:
    put(x, y, "g")   # gold_vein
for x, y in [(30, 17), (33, 19), (36, 17)]:
    put(x, y, "y")   # willow_tree
for x, y in [(31, 20), (34, 18), (36, 21)]:
    put(x, y, "d")

# Genvägsportal till grottan (SV)
put(2, 21, "1")

tiles = ["".join(r) for r in rows]
assert all(len(t) == W for t in tiles)

data = {
    "name": "Träsket",
    "tiles": tiles,
    "legend": {
        "0": {"type": "portal", "to": "forest", "terrain": "s"},
        "1": {"type": "portal", "to": "cave", "unlock": "genvag_grottan", "terrain": "s"},
        "2": {"type": "gate", "unlock": "traskets_hjarta", "terrain": "s"},
        "E": {"type": "node", "node": "eel_spot", "terrain": "~"},
        "h": {"type": "node", "node": "marsh_patch", "terrain": "s"},
        "g": {"type": "node", "node": "gold_vein", "terrain": "s"},
        "y": {"type": "node", "node": "willow_tree", "terrain": "s"},
        "p": {"type": "spawn", "monster": "Giftpadda", "respawn": 25.0, "terrain": "s"},
        "d": {"type": "spawn", "monster": "Träskdjävul", "respawn": 40.0, "terrain": "s"},
    },
}

with io.open("data/zones/swamp.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print("OK: %dx%d, %d legendtecken" % (W, H, len(data["legend"])))
