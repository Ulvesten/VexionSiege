extends SceneTree

# Temporary headless verification of Session-07 changes. Run with:
#   godot --headless --path <project> --script res://_verify_tmp.gd
func _initialize() -> void:
	var failures := 0

	# 1) Icons load as real textures (proves import + UIIcons path).
	var icons := {
		"credits": UIIcons.credits(),
		"void_cores": UIIcons.void_cores(),
		"star_shards": UIIcons.star_shards(),
		"settings": UIIcons.settings(),
	}
	for k in icons:
		var tex: Texture2D = icons[k]
		if tex == null:
			print("FAIL: icon '%s' is null" % k); failures += 1
		else:
			print("OK  : icon '%s' = %dx%d" % [k, tex.get_width(), tex.get_height()])

	# 2) Upgrade scaling no longer compounds. Simulate two sequential Max HP
	#    purchases the way _on_upgrade_purchased does (level++, recompute, store).
	var um = preload("res://_game/scripts/managers/upgrade_manager.gd").new()
	um._base_stats = {"max_hp": 100.0, "fire_rate": 1.0}
	um._stats = {"max_hp": 100.0, "fire_rate": 1.0}
	um._levels = {}
	for i in 2:
		um._levels["max_hp"] = um._levels.get("max_hp", 0) + 1
		um._stats["max_hp"] = um._calculate_stat("max_hp")
	print("Max HP after 2 picks = %.1f (expect 140.0; old buggy code gave 160.0)" % um._stats["max_hp"])
	if absf(um._stats["max_hp"] - 140.0) > 0.01:
		failures += 1

	# fire_rate at level 2 must be 1.12^2 = 1.2544 (not 1.12^3).
	um._levels = {"fire_rate": 2}
	var fr := um._calculate_stat("fire_rate")
	print("Fire rate at L2 = %.4f (expect 1.2544)" % fr)
	if absf(fr - 1.2544) > 0.001:
		failures += 1
	um.free()

	print("=== VERIFY %s (failures=%d) ===" % ["PASS" if failures == 0 else "FAIL", failures])
	quit()
