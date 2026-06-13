# Tibia2D Milstolpe 9 — Magi & Återkomst: Implementationsplan

**Mål:** Spelaren kan dö och återfödas (Tibia-stil). Runor fungerar som stridsvapen. Mana-systemet aktiveras. Hälso- och manapotioner läker. Mana-bar syns i HUD. Magic-skill och distance-skill tränas.

**Bakgrund:** Efter M8 är combat och utrustning komplett, men tre stora hål finns:
1. `player_died` signal emittas i `game_state.gd:126` men kopplas **aldrig** till något — spelet fryser vid döden.
2. `mana`/`max_mana` existerar i `GameState` och grows vid level-up, men inget i spelet använder mana.
3. `attack_rune` finns i `data/recipes.json` (rune_altar, L1) men inga rune-items finns i `items.json` och de kan inte "användas".
4. `health_potion` och `mana_potion` finns i alkemin men `GameState.use_item()` eller motsvarighet saknas.

**Tech Stack:** Godot 4.6.2, GDScript, GUT 9.6.0, JSON-data.

**Branch:** `m9-magi-aterkomst` (från master @ 047899b)

---

## Filstruktur

| Fil | Åtgärd | Innehåll |
|-----|--------|---------|
| `data/items.json` | Modifiera | Runor som usable items (type="rune"); potioner med "use" effect |
| `autoload/game_state.gd` | Modifiera | `use_mana()`, `restore_mana()`, `use_item()`, `respawn()`, death penalty |
| `ui/hud.gd` | Modifiera | Mana-bar, `player_died`-koppling → death-overlay, potion/rune quick-slots |
| `entities/player/player.gd` | Modifiera | `_unhandled_input`: F1 = kasta aktiv runa på target |
| `combat/combat_formulas.gd` | Modifiera | `roll_magic(magic_lvl, rune_power) -> float` |
| `ui/death_screen.gd` | Skapa | "Du dog!" overlay, Respawn-knapp, visa XP-förlust |
| `project.godot` | Modifiera | `use_rune` action (F1), `use_potion` action (F2) |
| `tests/unit/test_magic.gd` | Skapa | use_mana, roll_magic, respawn, death-penalty, use_item |
| `tests/unit/test_save.gd` | Modifiera | v6→v7: spara mana, aktiv runa |

---

## Nya/ändrade items

### Runor (type="rune")
| id | name | rune_power | mana_cost | magic_lvl | value |
|----|------|-----------|-----------|-----------|-------|
| attack_rune | Attackruna | 8 | 5 | 1 | 15 |
| fire_rune | Eldruna | 14 | 12 | 8 | 35 |
| healing_rune | Helande runa | — | 8 | 5 | 25 |

### Potioner (type="potion")
| id | name | effect | amount | value |
|----|------|--------|--------|-------|
| health_potion | Hälsopotion | heal_hp | 30 | 40 |
| mana_potion | Manapotion | restore_mana | 40 | 40 |

---

## GameState-ändringar

```gdscript
var active_rune := ""           # id för aktiv runa (F1 kastar)
signal mana_changed(mana, max)  # redan finns
signal player_respawned         # ny

func use_mana(amount: float) -> bool:
    if mana < amount: return false
    mana -= amount
    mana_changed.emit(mana, max_mana)
    return true

func restore_mana(amount: float) -> void:
    mana = minf(mana + amount, max_mana)
    mana_changed.emit(mana, max_mana)

func use_item(item_id: String) -> bool:
    if not inventory.has(item_id): return false
    var d := ItemDB.items.get(item_id, {})
    match String(d.get("type", "")):
        "potion":
            match String(d.get("effect", "")):
                "heal_hp":    heal(float(d.get("amount", 0)))
                "restore_mana": restore_mana(float(d.get("amount", 0)))
            remove_item(item_id, 1)
            return true
    return false

func respawn() -> void:
    # Tibia-stil: tappar halva XP-progrssen mot nästa level
    var penalty := int(float(xp_to_next) * 0.5)
    experience = maxi(experience - penalty, 0)
    health = max_health
    mana = max_mana
    current_zone = "town"
    player_tile = Vector2i(-1, -1)   # World.start_game hanterar startpos
    player_respawned.emit()
```

---

## Combat — roll_magic

```gdscript
static func roll_magic(magic_level: int, rune_power: int) -> float:
    var base := rune_power + magic_level * 0.5
    return base * randf_range(0.85, 1.15)
```

---

## Player — kasta runa (F1)

```gdscript
# i _unhandled_input:
elif event.is_action_pressed("use_rune"):
    _cast_rune()

func _cast_rune() -> void:
    var rune_id := GameState.active_rune
    if rune_id == "" or target == null or not is_instance_valid(target): return
    var d := ItemDB.items.get(rune_id, {})
    var cost := float(d.get("mana_cost", 0))
    if not GameState.use_mana(cost):
        World.hud.show_message("Inte tillräckligt med mana!")
        return
    if not GameState.inventory.has(rune_id):
        World.hud.show_message("Du har inga %s kvar." % d.get("name", rune_id))
        return
    GameState.remove_item(rune_id, 1)
    var mlvl := GameState.effective_skill_level("magic")
    var power := int(d.get("rune_power", 5))
    match String(d.get("effect", "damage")):
        "damage", "":
            var dmg := CombatFormulas.roll_magic(mlvl, power)
            target.take_damage(dmg)
            GameState.gain_skill_xp("magic", 2)
            GameState.gain_skill_xp("distance", 1)
        "heal":
            GameState.heal(float(power) + mlvl * 0.5)
            GameState.gain_skill_xp("magic", 2)
```

---

## Death Screen

`ui/death_screen.gd` — CanvasLayer (layer 10) som visas ovanpå allt.
- Röd fade-overlay + "Du dog!" text
- Visar XP-förlust: "Förlorade X erfarenhetspoäng"
- Knapp "Återfödas" → `GameState.respawn()` → `World.start_game(...)` → dölj overlay

---

## HUD-uppdateringar

- Mana-bar under HP-bar (blå, redan `mana_changed` signal finns)
- Quick-slot rad: F1-ikon för aktiv runa, F2 för hälsopotion
- `GameState.player_died.connect(_show_death_screen)`

---

### Task 0: Branch ✓

### Task 1: items.json — runor + potioner med effektdata (TDD)
- [ ] `attack_rune`, `fire_rune`, `healing_rune`: type="rune", rune_power, mana_cost, magic_lvl, effect
- [ ] `health_potion`, `mana_potion`: type="potion", effect, amount
- [ ] Test: items har korrekt type/effect-fält
- [ ] Commit: `feat: items — runor och potioner med type/effect/rune_power`

### Task 2: GameState — use_mana, use_item, respawn, death-penalty (TDD)
- [ ] `use_mana(amount)`: returnerar bool, emittar mana_changed
- [ ] `restore_mana(amount)`: clampar på max_mana
- [ ] `use_item(item_id)`: potion-dispatch (heal / restore_mana), tar från inventory
- [ ] `respawn()`: 50% XP-förlust, full HP/mana, zon → town, emittar player_respawned
- [ ] `var active_rune := ""`
- [ ] Sparfil v7: spara mana, active_rune; migrera v6
- [ ] Test: use_mana insufficient, use_item health_potion, respawn XP-förlust
- [ ] Commit: `feat: GameState — use_mana, use_item, respawn + sparfil v7 (TDD)`

### Task 3: CombatFormulas + Player runa-kastning (TDD)
- [ ] `CombatFormulas.roll_magic(magic_level, rune_power)` → float
- [ ] `player.gd`: `_cast_rune()`, `use_rune` action
- [ ] Test: roll_magic > 0, mana dras av, runa tas från inventory
- [ ] Commit: `feat: roll_magic + player kastar runa via F1 (TDD)`

### Task 4: DeathScreen + HUD mana-bar + koppling player_died (TDD)
- [ ] `ui/death_screen.gd`: CanvasLayer layer=10, röd overlay, XP-förlust text, Respawn-knapp
- [ ] `ui/hud.gd`: mana-bar (blå ColorRect under hp-bar), koppla `player_died` → death_screen.show()
- [ ] `hud.gd` koppla `player_respawned` → dölj death_screen, `World.start_game(...)`
- [ ] Test: player_died visas death_screen, respawn återställer health/mana
- [ ] Commit: `feat: death screen + mana-bar i HUD + player_died kopplad (TDD)`

### Task 5: Helsvit + quick-slots (TDD)
- [ ] HUD quick-slot: visa aktiv runa (F1) och hälsopotion (F2) om de finns i inventory
- [ ] `_unhandled_input` F2 → `GameState.use_item("health_potion")`
- [ ] Alla tester gröna
- [ ] Commit: `feat: HUD quick-slots F1/F2, helsvit grön`

### Task 6: Smoke-test & merge
- [ ] GUT headless: alla tester gröna
- [ ] **Manuell smoke-test (Erik):** Smida en attack_rune vid rune_altar. Tryck F1 → kasta runa på råtta → HP-bar minskar. Drick health_potion (F2). Låt råttorna döda spelaren → death screen visas → klicka Respawn → tillbaka i town.
- [ ] Merge m9-magi-aterkomst → master

#### GUT-kommando
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
