# Tibia2D Milstolpe 8 — Rustning & Utrustningssystem: Implementationsplan

**Mål:** Fullständigt 6-slots utrustningssystem (weapon/body/helmet/legs/boots/offhand). Rustning minskar inkommande skada via `CombatFormulas.mitigate()`. Sköldar ger shielding-bonus. Smidbart koppar/järn/stål-rustning i 3 nivåer. Equipment-panel (E-tangent). Sparfilsmigrering v5→v6.

**Bakgrund:** Innan M8 har `GameState` bara `equipped_weapon: String`. `CombatFormulas.mitigate()` tar en `armor`-parameter men `monster.gd` skickar alltid hårdkodade `2`. `copper_plate` i items.json har `"armor": 4` men det används aldrig. M8 rättar detta.

**Tech Stack:** Godot 4.6.2, GDScript, GUT 9.6.0, JSON-data.

**Branch:** `m8-rustning` (från master @ 9ca8ed9)

---

## Filstruktur

| Fil | Åtgärd | Innehåll |
|-----|--------|---------|
| `data/items.json` | Modifiera | `"slot"` på alla vapen/rustningar; nya items: copper/iron/steel helmet, legs, boots; iron_platebody, steel_platebody; wooden/iron/steel shield; iron/steel axe+club |
| `autoload/game_state.gd` | Modifiera | `equipment: Dictionary` (6 slots), `equip()`, `unequip()`, `total_armor()`, `total_shielding_bonus()`, bakåtkompatibla wrappers |
| `entities/monster/monster.gd` | Modifiera | Rad 80: hårdkodad `2` → `GameState.total_armor()` |
| `autoload/save_manager.gd` | Modifiera | SAVE_VERSION 5→6, spara `equipment`-dict, migrera `equipped_weapon` från v5 |
| `data/recipes.json` | Modifiera | Smidesrecept för alla nya rustningsdelar + sköldar |
| `ui/equipment_panel.gd` | Skapa | 6-slot panel: weapon/body/helmet/legs/boots/offhand, klicka slot → ta av, toggle med E |
| `project.godot` | Modifiera | `toggle_equipment` action, physical_keycode 69 (E) |
| `ui/hud.gd` | Modifiera | Lägg till equipment_panel, E-tangent-handler, uppdatera `_refresh_inv` för slot-aware equip |
| `tests/unit/test_equipment.gd` | Skapa | equip/unequip, total_armor, shielding_bonus, compat |
| `tests/unit/test_save.gd` | Modifiera | v5→v6 migration + equipment sparas |

**Nya items — rustning:**
| id | slot | armor | smithing_lvl | value |
|----|------|-------|-------------|-------|
| copper_plate (befintlig) | body | 4 | 5 | 90 |
| copper_helmet | helmet | 2 | 3 | 50 |
| copper_legs | legs | 3 | 4 | 70 |
| copper_boots | boots | 1 | 2 | 35 |
| iron_platebody | body | 8 | 12 | 200 |
| iron_helmet | helmet | 4 | 10 | 110 |
| iron_legs | legs | 6 | 11 | 160 |
| iron_boots | boots | 2 | 8 | 75 |
| steel_platebody | body | 12 | 20 | 380 |
| steel_helmet | helmet | 6 | 18 | 220 |
| steel_legs | legs | 9 | 19 | 300 |
| steel_boots | boots | 3 | 15 | 120 |

**Nya items — sköldar:**
| id | slot | shielding_bonus | smithing_lvl | value |
|----|------|----------------|-------------|-------|
| wooden_shield | offhand | 3 | — (shop/loot) | 45 |
| iron_shield | offhand | 6 | 10 | 130 |
| steel_shield | offhand | 9 | 18 | 290 |

**Nya items — vapen (paritet axe/club):**
| id | slot | atk | skill | smithing_lvl | value |
|----|------|-----|-------|-------------|-------|
| iron_axe | weapon | 13 | axe | 10 | 160 |
| steel_axe | weapon | 17 | axe | 18 | 330 |
| iron_club | weapon | 12 | club | 9 | 140 |
| steel_club | weapon | 16 | club | 16 | 300 |

---

### Task 0: Branch ✓

### Task 1: items.json — slot-fält + nya föremål (TDD) ✓
- [x] Alla befintliga vapen/rustningar: lägg till `"slot"` fält.
- [x] Koppar-tier: copper_helmet, copper_legs, copper_boots + slot på copper_plate.
- [x] Järn-tier: iron_platebody, iron_helmet, iron_legs, iron_boots.
- [x] Stål-tier: steel_platebody, steel_helmet, steel_legs, steel_boots.
- [x] Sköldar: wooden_shield, iron_shield, steel_shield.
- [x] Vapen (paritet): iron_axe, steel_axe, iron_club, steel_club.
- [x] Commit: `feat: items — slot-fält på alla equippables + ny rustning/sköld/vapen i 3 nivåer`

### Task 2: GameState — equipment-dict + metoder (TDD) ✓
- [x] Failande test: `test_equip_body_armor`, `test_total_armor_sums_slots`, `test_total_shielding_bonus`, `test_equip_replaces_existing`, `test_equip_wrong_slot_fails`.
- [x] `EQUIPMENT_SLOTS`, `var equipment: Dictionary` (6 slots, weapon startar med rusty_sword).
- [x] `equip(slot, item_id)`: validera slot, kolla item.slot-fält, ta från inventory, sätt slot.
- [x] `unequip(slot)`: returnera till inventory.
- [x] `total_armor()`: summera armor från body/helmet/legs/boots.
- [x] `total_shielding_bonus()`: shielding_bonus från offhand.
- [x] Bakåtkompatibelt: `equipped_weapon` property getter, `equip_weapon()`→`equip("weapon")`, `unequip_weapon()`→`unequip("weapon")`, `weapon_skill()` läser `equipment["weapon"]`.
- [x] Commit: `feat: GameState — equipment-dict 6 slots, equip/unequip, total_armor, compat (TDD)`

### Task 3: Combat + SaveManager (TDD) ✓
- [x] `monster.gd` rad 80: `2` → `GameState.total_armor()`.
- [x] `save_manager.gd`: SAVE_VERSION = 6, spara `"equipment": GameState.equipment`, migrera v5: `equipped_weapon` → `equipment["weapon"]`, övriga slots = "".
- [x] Test: mitigation med utrustad kopparharnesk är högre än utan; v5→v6 migration.
- [x] Commit: `feat: rustning påverkar strid + sparfil v6 med migration (TDD)`

### Task 4: recipes.json — smidesrecept ✓
- [x] Koppar: copper_helmet (L3), copper_boots (L2), copper_legs (L4) — koppar_ore.
- [x] Järn: iron_platebody (L12), iron_helmet (L10), iron_legs (L11), iron_boots (L8), iron_shield (L10), iron_axe (L10), iron_club (L9).
- [x] Stål: steel_platebody (L20), steel_helmet (L18), steel_legs (L19), steel_boots (L15), steel_shield (L18), steel_axe (L18), steel_club (L16).
- [x] Commit: `feat: smidesrecept för alla rustningsdelar, sköldar och vapen i 3 nivåer`

### Task 5: Equipment-UI + E-tangent + HUD ✓
- [x] `ui/equipment_panel.gd`: PanelContainer, 6 slots (weapon/body/helmet/legs/boots/offhand) med svenska namn, visar utrustat föremål, knapp "Ta av" per slot.
- [x] `project.godot`: `toggle_equipment` action, physical_keycode 69 (E).
- [x] `ui/hud.gd`: lägg till equipment_panel; E-tangent toggle; uppdatera `_refresh_inv` — ta bort equipped_weapon-sektion, visa slot-based "Utrusta" för alla items med "slot"-fält.
- [x] Commit: `feat: equipment-panel (E-tangent) + HUD-uppdatering för slot-aware utrustning`

### Task 6: Helsvit + planbock ✓ (kod klar — kör testerna lokalt)
- [x] Alla filer skrivna och committade.
- [ ] GUT headless: alla tester gröna (inkl. nya M8-tester).
- [ ] **Manuell smoke-test (Erik):** Starta spelet, tryck E (equipment-panel öppnas), ge sig copper_plate via konsolen (`give copper_plate`), utrusta den (slot body), tryck E igen (panelen visar copper_plate i body), angrip ett monster — ta skada och verifiera att rustningen räknas. Tryck E → "Ta av" → copper_plate tillbaka i inventory.
- [ ] Merge m8-rustning → master.

#### GUT-kommando (PowerShell)
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

#### Merge-instruktion
```powershell
cd C:\Users\Hem\tibia2d
git checkout master
git merge --no-ff m8-rustning -m "feat: Milstolpe 8 — Rustning & Utrustningssystem (merge m8-rustning)"
```
