class_name CombatFormulas
## Statiska skadeformler. Tibia-inspirerade, medvetet enkla.

## Kritisk träff: skadan multipliceras med detta vid crit.
const CRIT_MULTIPLIER := 1.5
const CRIT_BASE_CHANCE := 0.05    # grundchans innan skill/utrustning
const CRIT_PER_SKILL   := 0.002   # +0,2 %-enheter per nivå i stridsskillen
const CRIT_MAX_CHANCE  := 0.50    # tak så crit aldrig blir garanterat

## Kritträff-chans (0–1): grundchans + skill-skalning + utrustningsbonus.
static func crit_chance(skill: int, bonus := 0.0) -> float:
	return clampf(CRIT_BASE_CHANCE + skill * CRIT_PER_SKILL + bonus, 0.0, CRIT_MAX_CHANCE)

## Slår om en attack blir kritisk.
static func roll_crit(skill: int, bonus := 0.0) -> bool:
	return randf() < crit_chance(skill, bonus)

# ── Träffchans & undvikande ──────────────────────────────────────────────────
# Spelarens vapenslag vägs mot monstrets undvikande. Medvetet förlåtande: ett
# högt golv gör att tidiga nivåer aldrig känns hopplösa, och taket garanterar att
# inget slag är 100 % säkert mot vigare fiender. Rena funktioner → testbara.

const HIT_BASE := 0.80          # träffchans när accuracy == evasion
const HIT_PER_DIFF := 0.01      # ±chans per stegs skillnad i accuracy − evasion
const HIT_FLOOR := 0.40         # lägsta träffchans för spelarens slag
const HIT_CEIL := 0.99          # högsta möjliga träffchans
const MONSTER_HIT_FLOOR := 0.55 # monster träffar alltid minst så här ofta (max ~45 % väjning)
const EVASION_PER_SPEED := 3.0  # monstrets undvikande härleds ur dess fart

## Spelarens träffvärde: stridsskill + nivå.
static func accuracy(level: int, skill: int) -> int:
	return level + skill

## Monstrets undvikande härlett ur dess fart (snabba fiender väjer mer).
static func monster_evasion(speed: float) -> int:
	return int(speed * EVASION_PER_SPEED)

## Spelarens undvikande: agility väger tyngst, sköldvana bidrar lite.
static func player_evasion(agility: int, shielding: int) -> int:
	@warning_ignore("integer_division")
	return agility + shielding / 2

## Monstrets träffvärde härlett ur dess attack (hårdare fiender träffar säkrare).
static func monster_accuracy(atk: int) -> int:
	return 12 + atk

## Träffchans (0–1) givet accuracy mot evasion, klamrad mellan golv och tak.
## `chance_floor` låter försvarssidan ha ett högre golv (monster missar mer sällan).
static func hit_chance(acc: int, eva: int, chance_floor := HIT_FLOOR) -> float:
	return clampf(HIT_BASE + (acc - eva) * HIT_PER_DIFF, chance_floor, HIT_CEIL)

## Slår om ett slag träffar.
static func roll_hit(acc: int, eva: int, chance_floor := HIT_FLOOR) -> bool:
	return randf() < hit_chance(acc, eva, chance_floor)

static func max_melee(level: int, skill: int, weapon_atk: int) -> int:
	return maxi(int(weapon_atk * (skill + 4) / 28.0 + level / 10.0), 1)

static func roll_melee(level: int, skill: int, weapon_atk: int) -> int:
	return randi_range(0, max_melee(level, skill, weapon_atk))

static func roll_monster(monster_atk: int) -> int:
	return randi_range(0, monster_atk)

static func mitigate(raw_dmg: int, shielding: int, armor: int) -> int:
	@warning_ignore("integer_division")
	var reduction := randi_range(armor / 2, armor) + shielding / 3
	return maxi(raw_dmg - reduction, 0)

## Magiskada: runans kraft + magic-skill skalning, ±15% variation.
static func roll_magic(magic_level: int, rune_power: int) -> float:
	var base := rune_power + magic_level * 0.5
	return base * randf_range(0.85, 1.15)
## Bågskjutning: distance-skill + vapnets ATK, ±15% variation.
static func roll_ranged(distance_level: int, weapon_atk: int) -> float:
	var base := weapon_atk + distance_level * 0.4
	return base * randf_range(0.85, 1.15)

## Bågskyttets toppvärde (utan ±15%-variation) — används av kraftslaget.
static func max_ranged(distance_level: int, weapon_atk: int) -> float:
	return weapon_atk + distance_level * 0.4

# ── Specialattack ("kraftslag") ──────────────────────────────────────────────
# En laddmätare som fylls när man landar vapenslag och laddas ur för ett enda
# kraftfullt, garanterat kritiskt slag. Rena funktioner → testbara.

const SPEC_MAX := 100.0          # full mätare
const SPEC_GAIN := 14.0          # laddning per landat slag (~8 slag till fullt)
const SPEC_MULTIPLIER := 2.0     # kraftslagets skademultiplikator (på toppvärdet)

## Lägger laddning till mätaren, klamrad till [0, SPEC_MAX].
static func charge_spec(energy: float, amount := SPEC_GAIN) -> float:
	return clampf(energy + amount, 0.0, SPEC_MAX)

## True när mätaren är full och kraftslaget kan släppas.
static func spec_ready(energy: float) -> bool:
	return energy >= SPEC_MAX

## Kraftslagets skada: vapnets toppvärde gånger en multiplikator (default = vapentyp-
## oberoende standard). Vapentyper skickar in sin egen mult via spec_profile.
static func spec_damage(base_dmg: float, mult := SPEC_MULTIPLIER) -> float:
	return base_dmg * mult

## True om ett monster (givet dess MonsterDB-data) står emot gift. Immunt om
## datan har poison_immune=true (odöda, elementarer, konstruktioner) ELLER om
## varelsen själv utsöndrar gift — en giftpadda kan inte förgiftas av sitt eget
## gift. Ren funktion (datan injiceras) → testbar.
static func monster_poison_immune(data: Dictionary) -> bool:
	if bool(data.get("poison_immune", false)):
		return true
	return String(data.get("ability", {}).get("type", "")) == "poison"

## Avgör om ett vapens giftbeläggning proccar denna träff, givet ett slumptal i
## [0,1). Giftvapen (venom_blade m.fl.) bär ability {type:poison, chance,
## duration, tick_dmg}. Returnerar {apply:true, duration, tick_dmg} när giftet
## fastnar, annars {apply:false}. Slumptalet injiceras → ren och testbar.
static func weapon_poison_proc(ability: Dictionary, roll: float) -> Dictionary:
	if String(ability.get("type", "")) != "poison":
		return {"apply": false}
	if roll >= float(ability.get("chance", 0.0)):
		return {"apply": false}
	return {
		"apply": true,
		"duration": float(ability.get("duration", 5.0)),
		"tick_dmg": float(ability.get("tick_dmg", 4.0)),
	}

## Kraftslagets karaktär per vapentyp. Rena parametrar → testbara.
##   power  — ett hårt enkelmålsslag (svärd m.fl.)
##   cleave — träffar målet + intilliggande fiender (yxa)
##   crush  — enkelmål + bedövar (klubba)
##   double — två snabba skott mot målet (båge)
## mult = skademultiplikator per träff; stun = bedövningstid i sek (0 = ingen).
static func spec_profile(weapon_skill: String) -> Dictionary:
	match weapon_skill:
		"axe":      return {"kind": "cleave", "mult": 1.8, "stun": 0.0}
		"club":     return {"kind": "crush",  "mult": 1.8, "stun": 2.5}
		"distance": return {"kind": "double", "mult": 1.3, "stun": 0.0}
		_:          return {"kind": "power",  "mult": SPEC_MULTIPLIER, "stun": 0.0}
