extends GutTest
## Regressionsvakt: varje utrustningsslot får en giltig silhuett-ikon utan att
## rit-koden kraschar, och cachen återanvänder samma textur.

const SLOTS := [
	"amulet", "helmet", "backpack", "weapon", "body", "offhand",
	"tool", "legs", "ammo", "ring", "ring2", "boots", "light",
]

func test_alla_slots_far_giltig_silhuett() -> void:
	var trasiga: Array = []
	for slot in SLOTS:
		var tex := EquipIcons.silhouette(slot)
		if tex == null or tex.get_width() != EquipIcons.SIZE or tex.get_height() != EquipIcons.SIZE:
			trasiga.append(slot)
	assert_eq(trasiga, [], "alla slots ska ge en %d×%d-silhuett" % [EquipIcons.SIZE, EquipIcons.SIZE])

func test_okand_slot_ger_fallback() -> void:
	var tex := EquipIcons.silhouette("__finns_inte__")
	assert_not_null(tex, "okänd slot ska få fallback-silhuett")
	assert_eq(tex.get_width(), EquipIcons.SIZE)

func test_cache_aterananvander_textur() -> void:
	var a := EquipIcons.silhouette("helmet")
	var b := EquipIcons.silhouette("helmet")
	assert_eq(a, b, "samma slot ska ge samma cachade textur")

func test_silhuett_har_synliga_pixlar() -> void:
	var img := EquipIcons.silhouette("weapon").get_image()
	var fyllda := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				fyllda += 1
	assert_gt(fyllda, 10, "silhuetten ska ha ritade pixlar")
