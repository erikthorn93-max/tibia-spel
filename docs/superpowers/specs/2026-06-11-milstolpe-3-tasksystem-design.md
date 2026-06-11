# Tibia2D Milstolpe 3 — Tasksystem: Designspec

**Datum:** 2026-06-11
**Bygger på:** `2026-06-10-tibia2d-design.md` §4 (tasksystemet), milstolpe 2 (skillsystem, mergad och taggad `m2-skillsystem`)

## Mål

Tasksystemet "Killing in the Name of..." spelbart fullt ut: Taskmaster-NPC, 8 tasks, Slayer-progression, monster-unlocks som öppnar nya områden, första bossen (Ghulkungen), bestiary med tier-bonusar, samt en debug-konsol för test.

## Designbeslut (från brainstorming)

| Fråga | Beslut |
|-------|--------|
| Monsterscope | 4 nya monster + 1 boss |
| Bossdesign | Eget bossrum med gate, 1 h respawn-cooldown |
| Bestiary-tiers | Tibia-troget: 100 / 400 / 1000 kills, +2 % skada per tier |
| Debug-konsol | Byggs i M3, alltid registrerad (singleplayer offline) |
| Unlock-spawns | Nya områden öppnas — avstängda sektioner i befintliga zoner bakom gate-tiles |
| Arkitektur | Två nya autoloads: TaskSystem + UnlockSystem (minimal, grund för M5) |

---

## 1. Innehåll

### Nya monster (`data/monsters.json`)

| Monster | Ungefärlig styrka | Låses upp via | Bor i |
|---------|-------------------|---------------|-------|
| Jättespindel | ~2× Spindel | Spindel-task | Spindelhålan (ny grottsektion) |
| Skelettkrigare | ~2× Skelett | Skelett-task | Kryptan (ny djupare grottsektion) |
| Fantom | ~1,5× Ghoul | Ghoul-task | Mörka dungen (ny skogssektion) |
| **Ghulkungen** (boss) | ~800 hp, hög attack | Ghoul-task OCH Fantom-task klarade | Bossrummet (egen ingång i grottan) |

Ghulkungen markeras `"boss": true` i monsters.json: 2× visuell skala, garanterad unik loot (**Ghulkungens krona** — trofé, värde 2 500 guld), garanterat guld (200–400), och 2 000 Slayer-XP direkt vid kill (enda Slayer-XP-källan utöver task-belöningar).

### Tasks (`data/tasks.json`, 8 st)

Format per designdokumentet §4:

```json
"task_skelett": {
  "monster": "Skelett",
  "required": 100,
  "slayer_level_req": 5,
  "reward_slayer_xp": 1500,
  "reward_gold": 800,
  "unlocks": "kryptan",
  "repeatable": true
}
```

| Task | Kills | Slayer-krav | Slayer-XP | Guld | Unlock |
|------|-------|-------------|-----------|------|--------|
| Råtta | 30 | 1 | 100 | 150 | — |
| Orm | 50 | 1 | 200 | 250 | — |
| Spindel | 75 | 3 | 400 | 500 | `spindelhalan` |
| Skelett | 100 | 5 | 700 | 800 | `kryptan` |
| Ghoul | 150 | 10 | 1200 | 1500 | `morka_dungen` |
| Jättespindel | 100 | 8 | 900 | 1000 | — |
| Skelettkrigare | 125 | 12 | 1100 | 1200 | — |
| Fantom | 150 | 15 | 1500 | 2000 | — |

- XP-siffrorna är satta mot Slayer-kurvan (xp_base 50, growth 1,1): de fem bastaskarna ger kumulativt ~2 600 XP ≈ Slayer 17, vilket gör Fantom-taskens krav (15) nåbart. Får finjusteras vid speltest.
- Bossrummets gate (`bossrummet`) öppnas automatiskt när både Ghoul- och Fantom-tasken är klarade (kontrolleras vid `claim_reward`).
- `repeatable: true` på alla: kan tas om för **halv** Slayer-XP och halvt guld, ingen ny unlock.

### Task-slots

1 slot från start, +1 vid Slayer 15, +1 vid Slayer 30 (max 3).

### Nya områden

Avstängda sektioner i befintliga kartor bakom **gate-tiles**:

- **Grottan:** Spindelhålan (Jättespindel-spawns), Kryptan (Skelettkrigare-spawns), Bossrummet (Ghulkungen).
- **Skogen:** Mörka dungen (Fantom-spawns).

Gate-tile i zon-legenden: `{"type": "gate", "unlock": "spindelhalan"}`. Innan unlock: oframkomlig, ritas som rasmassor/stenblock (grå). Efter unlock: tilen blir gångbar och visualen tas bort. Zonen lyssnar på `UnlockSystem.unlock_added` och öppnar gates live (utan zonomladdning). Spawn-punkter innanför gaten är vanliga spawns — de blir nåbara först när gaten öppnats.

---

## 2. Arkitektur

Två nya autoloads (registreras efter MonsterDB, före World):

### `autoload/task_system.gd`

Äger: aktiva tasks (med progress), klarade task-id:n, bestiary-kills, Slayer-XP-utdelning.

```
take_task(task_id) -> bool          # respekterar slots + slayer-krav
abandon_task(task_id) -> void       # progress nollas
record_kill(monster_name) -> void   # bestiary++ samt aktiv task-progress
claim_reward(task_id) -> bool       # XP/guld, unlock, boss-gate-kontroll
damage_multiplier(monster_name) -> float   # 1.0 + 0.02 * tier
slots() -> int                      # 1 / 2 / 3 utifrån Slayer-nivå
tier(monster_name) -> int           # 0-3 utifrån kills (100/400/1000)
```

Signaler: `task_taken(id)`, `task_progress(id)`, `task_completed(id)`, `bestiary_changed`.

Slayer-XP delas ut ENDAST via `claim_reward` och boss-kill — `gain_skill_xp("slayer", ...)` anropas aldrig någon annanstans.

### `autoload/unlock_system.gd`

Minimal — grunden M5 bygger vidare på:

```
unlock(id) -> void        # idempotent
is_unlocked(id) -> bool
unlocked: Dictionary      # set-semantik {id: true}
```

Signal: `unlock_added(id)`.

### Dataflöde

```
monster.die()
  → TaskSystem.record_kill(namn)
      → bestiary[namn] += 1  → bestiary_changed
      → aktiv task med matchande monster: progress += 1 → task_progress
  → (om boss): Slayer-XP direkt + cooldown-timestamp sätts
spelare hos Taskmastern → claim_reward(id)
  → Slayer-XP + guld → UnlockSystem.unlock(...) → unlock_added
  → zonen öppnar gate-tiles live
player._update_attack: dmg *= TaskSystem.damage_multiplier(target.monster_name)
```

### Boss-cooldown

Vid Ghulkungen-kill sparas Unix-timestamp. Bossens spawn-punkt spawnar bara om `now - last_kill >= 3600`. Går man in i bossrummet under cooldown visar HUD:en "Ghulkungen är inte här... (X min)".

---

## 3. UI

### Taskmaster-NPC + taskpanel

Klickbar NPC i stan nära stationsraden (samma entity-mönster som handlaren). Klick intill → taskpanel med tre sektioner:

1. **Tillgängliga** — filtrerade på Slayer-nivå; monster, antal, belöning, "Ta task"-knapp (spärrad om slots fulla).
2. **Aktiva** — progress ("Skelett 34/100"), "Avbryt"-knapp (progress nollas).
3. **Klara** — "Hämta belöning"-knapp; unlock-meddelande i HUD ("Spindelhålan har öppnats!").

### Bestiary-panel (B)

Programmatisk panel (samma mönster som skillpanelen). Rad per monster som dödats minst en gång: namn, kills, tier-stjärnor (★ per uppnådd tier), aktuell skadebonus. Odödade monster visas som "???". Ny input-action `toggle_bestiary` (fysisk B).

### HUD

Aktiva tasks som rad under buffarna: "Skelett 34/100 · Ghoul 12/150". Uppdateras via `task_progress`.

### Debug-konsol (§)

`ui/debug_console.gd` — CanvasLayer med LineEdit + utskriftslogg, alltid registrerad. Ny input-action `toggle_console` (fysisk §, tangenten under Esc). Kommandon:

```
give <item_id> [antal]   gold <antal>    xp <skill> <mängd>
kills <monster> <antal>  unlock <id>     tasklist
tp <zon>                 heal            spawn <monster>
```

Okänt kommando ger hjälptext. Konsolen får inte sluka spelinput när den är stängd.

---

## 4. Save v3

Nya fält: aktiva tasks med progress, klarade task-id:n, bestiary-kills, upplåsta id:n, boss-cooldown-timestamps.

`SAVE_VERSION := 3`. Migrering v2→v3 fyller tomma defaults (samma mönster som v1→v2: gamla saves laddar felfritt, nya system börjar från noll). Autosave-flödet orört.

---

## 5. Testning

### GUT (nya/utökade)

| Testfil | Täcker |
|---------|--------|
| `test_task_system.gd` (ny) | take/abandon/complete, slot-gräns via Slayer, belöningar, repeterbara halv-belöningar, Slayer-XP endast via tasks/boss |
| `test_bestiary.gd` (ny) | kill-räkning, tier-trösklar 100/400/1000, damage_multiplier-formeln |
| `test_unlock_system.gd` (ny) | unlock/is_unlocked, idempotens, signal |
| `test_tasks_data.gd` (ny) | datavalidering: task-monster finns i MonsterDB, unlock-id:n har gates i någon zon |
| `test_zone.gd` (utökas) | gate-parsing, gates blockerar före/öppnar efter unlock |
| `test_save.gd` (utökas) | v2→v3-migrering |

### Acceptanskriterier (manuellt speltest)

1. Taskmastern visar tasks filtrerade på Slayer-nivå; slots respekteras
2. Ta Spindel-tasken → döda 75 spindlar → hämta belöning → Spindelhålan öppnas → Jättespindlar spawnar där
3. Skadebonus: sätt kills med debug-konsolen (`kills Råtta 100`) → bestiaryt visar ★ → mätbart högre skada mot Råttor
4. Klara Ghoul- + Fantom-tasken → bossrummet öppnas → Ghulkungen droppar kronan + stor Slayer-XP
5. Döda bossen igen direkt → "Ghulkungen är inte här... (X min)"
6. Repeterbar task ger halv belöning
7. Bestiary-panelen (B) visar kills/tiers/bonus; odödade som "???"
8. Debug-konsolen: alla kommandon fungerar; § öppnar/stänger; ingen input läcker
9. v2-save laddar felfritt; tasks/bestiary börjar tomma
10. Alla GUT-tester gröna; 60+ FPS i perftestet

## Utanför scope (M3)

- Quests, dialogträd, TTS (M4)
- Fulla UnlockSystem-låstyper: skills, recept, outfits, genvägar (M5)
- Fler bossar, fler task-kategorier, task-milstolpar à la "5 tasks i kategori" (M7+) — bossvillkoret i M3 är hårdkodat till Ghoul+Fantom-tasks
- Charm-mekanik utöver tier-skadebonusen
