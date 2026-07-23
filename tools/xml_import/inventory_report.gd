## Phase 2 dry-run inventory report. Runs every parser against the FULL
## original bundle and prints structured counts/listings/anomalies. Writes
## nothing to data/ — this is analysis only (task 1: "create a complete
## inventory"), not conversion (see generate_test_data.gd for that).
##
## Run: godot --headless --path . --script res://tools/xml_import/inventory_report.gd
extends SceneTree

const ResourcesParser = preload("res://tools/xml_import/parse_resources.gd")
const ObjectsParser = preload("res://tools/xml_import/parse_objects.gd")
const ItemsParser = preload("res://tools/xml_import/parse_items.gd")
const TutorialsParser = preload("res://tools/xml_import/parse_tutorials.gd")
const SettingsParser = preload("res://tools/xml_import/parse_settings.gd")
const SoundsParser = preload("res://tools/xml_import/parse_sounds.gd")
const BuildMenuParser = preload("res://tools/xml_import/parse_build_menu.gd")
const SkinsParser = preload("res://tools/xml_import/parse_skins.gd")


func _initialize() -> void:
	print("=".repeat(70))
	print("PHASE 2 DATA INVENTORY — full original bundle, real parse results")
	print("=".repeat(70))

	_report_resources()
	_report_objects()
	_report_items()
	_report_tutorials()
	_report_settings()
	_report_sounds()
	_report_skins()
	_report_build_menu()

	print("=".repeat(70))
	print("INVENTORY COMPLETE")
	print("=".repeat(70))
	quit(0)


func _report_resources() -> void:
	print("\n--- Resources.xml ---")
	var resources := ResourcesParser.parse()
	print("Total resources: %d" % resources.size())
	for r in resources:
		var score_note := "" if r.has_score_value else " [NO scoreValue attr in original]"
		print("  id=%-3d %-10s tier=%d refines_from=%-3s start=%-6s score=%s%s" % [
			r.id, r.display_name, r.tier,
			(str(r.refines_from_id) if r.refines_from_id != -1 else "-"),
			r.start_value, r.score_value, score_note,
		])


func _report_objects() -> void:
	print("\n--- Objects (Objects.xml manifest + all listed files) ---")
	print("Manifest files: %s" % str(ObjectsParser.parse_manifest()))

	var parsed := ObjectsParser.parse_all()
	var objects: Array = parsed.objects
	var errors: Array = parsed.errors

	print("Total <Object> entries parsed: %d" % objects.size())
	if not errors.is_empty():
		print("PARSE ERRORS (%d):" % errors.size())
		for e in errors:
			print("  ! %s" % e)

	var by_type := {}
	var by_file := {}
	var multi_cost_ids: Array = []
	var gather_count := 0
	var shop_recipe_ref_count := 0
	var duplicate_ids := {}
	var seen_ids := {}

	for obj in objects:
		by_type[obj.type_raw] = by_type.get(obj.type_raw, 0) + 1
		by_file[obj.source_file] = by_file.get(obj.source_file, 0) + 1
		if obj.gather_recipe != null:
			gather_count += 1
		shop_recipe_ref_count += obj.shop_recipe_ids.size()

		if seen_ids.has(obj.id):
			duplicate_ids[obj.id] = duplicate_ids.get(obj.id, [seen_ids[obj.id]])
			duplicate_ids[obj.id].append(obj.source_file)
		else:
			seen_ids[obj.id] = obj.source_file

	print("\nBy type:")
	for t in by_type.keys():
		print("  %-15s %d" % [t, by_type[t]])

	print("\nBy source file:")
	for f in by_file.keys():
		print("  %-32s %d" % [f, by_file[f]])

	print("\nObjects with an inline GATHER recipe (<Produce>): %d" % gather_count)
	print("Total shop-recipe <Item> references across all objects: %d" % shop_recipe_ref_count)

	if not duplicate_ids.is_empty():
		print("\nDUPLICATE ids found across files (%d) — needs a design decision, see docs/MISSING_INFORMATION.md:" % duplicate_ids.size())
		for id in duplicate_ids.keys():
			print("  id=%s appears in: %s" % [id, str(duplicate_ids[id])])

	# Sample a few well-known ids for spot-check accuracy.
	print("\nSpot-check (ids confirmed by manual reading in earlier research):")
	var by_id := {}
	for obj in objects:
		by_id[obj.id] = obj
	for check_id in [1, 8, 25, 26, 163, 27]:
		if by_id.has(check_id):
			var o = by_id[check_id]
			print("  id=%d name=%s type=%s cost=%s storage=%s" % [check_id, o.display_name, o.type_raw, str(o.cost), str(o.storage_capacities)])
		else:
			print("  id=%d NOT FOUND" % check_id)


func _report_items() -> void:
	print("\n--- Items.xml ---")
	var parsed := ItemsParser.parse()
	print("Shop recipes (type=shopItem): %d" % parsed.shop_items.size())
	print("Land upgrades (type=landUpgrade): %d" % parsed.land_upgrades.size())
	print("Other item types: %d -> %s" % [parsed.other.size(), str(parsed.other)])

	if not parsed.land_upgrades.is_empty():
		print("Land upgrade compatible_land distribution:")
		var by_land := {}
		for lu in parsed.land_upgrades:
			by_land[lu.compatible_land] = by_land.get(lu.compatible_land, 0) + 1
		for land in by_land.keys():
			print("  %-10s %d" % [land, by_land[land]])

	if parsed.shop_items.size() > 0:
		print("First 3 shop items (spot-check):")
		for i in range(min(3, parsed.shop_items.size())):
			var s = parsed.shop_items[i]
			print("  id=%d name=%s time=%s cost=%s reward_xp=%s reward=%s" % [s.id, s.display_name, s.time_seconds, str(s.input_cost), s.reward_xp, str(s.reward)])


func _report_tutorials() -> void:
	print("\n--- Tutorials.xml ---")
	var parsed := TutorialsParser.parse()
	print("Total tutorials: %d" % parsed.tutorials.size())
	if not parsed.errors.is_empty():
		print("Errors: %s" % str(parsed.errors))

	var trigger_counts := {}
	var objective_type_counts := {}
	var lock_count := 0
	var unknown_objective_types := {}

	for t in parsed.tutorials:
		trigger_counts[t.trigger_type] = trigger_counts.get(t.trigger_type, 0) + 1
		if not t.lock.is_empty():
			lock_count += 1
		for obj in t.objectives:
			objective_type_counts[obj.type] = objective_type_counts.get(obj.type, 0) + 1
			if obj.type.begins_with("UNKNOWN:"):
				unknown_objective_types[obj.type] = true

	print("By trigger type: %s" % str(trigger_counts))
	print("Tutorials with a <Lock>: %d" % lock_count)
	print("Objective type counts: %s" % str(objective_type_counts))
	if not unknown_objective_types.is_empty():
		print("UNRECOGNIZED objective verbs found: %s" % str(unknown_objective_types.keys()))

	if parsed.tutorials.size() > 0:
		var t0 = parsed.tutorials[0]
		print("First tutorial (spot-check): id=%d name=%s trigger=%s objectives=%s" % [t0.id, t0.display_name, t0.trigger_type, str(t0.objectives)])

	# Show a real <Lock> example if one exists, to confirm actual attribute names.
	for t in parsed.tutorials:
		if not t.lock.is_empty():
			print("First real <Lock> found (id=%d): attrs=%s allow_entries=%s allow_consumable_entries=%s" % [t.id, str(t.lock), str(t.allow_entries), str(t.allow_consumable_entries)])
			break


func _report_settings() -> void:
	print("\n--- Settings.xml (subset) ---")
	var s := SettingsParser.parse()
	print("Lands: %s" % str(s.lands))
	print("Energy: %s" % str(s.energy))
	print("Villager: %s" % str(s.villager))
	print("AdoptedVillagerCost: %s" % str(s.adopted_villager_cost))
	print("Buff categories: %s" % str(s.buff_categories))
	print("MaxBuffer by land: %s" % str(s.max_buffer_by_land))
	print("Max level: %s" % str(s.get("max_level", "?")))
	print("Levels parsed: %d (first 3: %s)" % [s.levels.size(), str(s.levels.slice(0, min(3, s.levels.size())))])


func _report_sounds() -> void:
	print("\n--- Sounds.xml ---")
	var sounds := SoundsParser.parse()
	print("Total sounds: %d" % sounds.size())
	var music_count := 0
	for snd in sounds:
		if snd.is_music:
			music_count += 1
	print("Music tracks: %d, SFX: %d" % [music_count, sounds.size() - music_count])


func _report_skins() -> void:
	print("\n--- Skins.xml ---")
	var skins := SkinsParser.parse()
	print("Total skins: %d" % skins.size())
	for sk in skins:
		print("  name=%-10s id=%s isLand=%s worldPrefix=%-8s objectOverrides=%d anims=%d" % [
			sk.display_name, sk.id, sk.is_land, sk.world_prefix, sk.object_override_count, sk.anim_sheet_count,
		])


func _report_build_menu() -> void:
	print("\n--- BuildMenu.xml ---")
	var categories := BuildMenuParser.parse()
	print("Categories: %d" % categories.size())
	var total_items := 0
	for cat in categories:
		print("  %-12s %d items" % [cat.category, cat.items.size()])
		total_items += cat.items.size()
	print("Total BuildMenu item entries: %d" % total_items)

	# Cross-check: do all BuildMenu item ids resolve to a real Object id?
	var object_ids := {}
	for obj in ObjectsParser.parse_all().objects:
		object_ids[obj.id] = true
	var unresolved: Array = []
	for cat in categories:
		for item in cat.items:
			if not object_ids.has(item.id):
				unresolved.append(item.id)
	if unresolved.is_empty():
		print("Cross-check OK: every BuildMenu item id resolves to a parsed Object.")
	else:
		print("Cross-check FOUND %d unresolved BuildMenu item ids: %s" % [unresolved.size(), str(unresolved)])
