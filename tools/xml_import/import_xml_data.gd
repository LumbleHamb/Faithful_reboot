# tools/xml_import/import_xml_data.gd
extends SceneTree

## Importer script to materialize resources, items, and building definitions 
## from the original XML files directly into Godot .tres files under res://data/.

const CostEntry = preload("res://resources/shared/cost_entry.gd")
const CostBundle = preload("res://resources/shared/cost_bundle.gd")
const PrerequisiteEntry = preload("res://resources/shared/prerequisite_entry.gd")
const PrerequisiteSet = preload("res://resources/shared/prerequisite_set.gd")

func _init() -> void:
	print("==================================================")
	print("Starting automated XML data import into .tres...")
	print("==================================================")
	
	_ensure_dirs()
	_import_resources()
	_import_recipes()
	_import_buildings()
	
	print("==================================================")
	print("XML Data Import Completed Successfully!")
	print("==================================================")
	quit()

func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/resources/")
	DirAccess.make_dir_recursive_absolute("res://data/recipes/")
	DirAccess.make_dir_recursive_absolute("res://data/buildings/")

func _import_resources() -> void:
	print("\nImporting ResourceDefinitions...")
	var parsed_resources = ResourcesParser.parse()
	var count = 0
	
	for r in parsed_resources:
		var res_def = ResourceDefinition.new()
		res_def.id = r["id"]
		res_def.display_name = r["display_name"]
		res_def.tier = r["tier"]
		res_def.score_value = r["score_value"]
		res_def.start_value = r["start_value"]
		res_def.refines_from_id = r["refines_from_id"]
		res_def.icon_font_char = r["icon_font_char"]
		
		var filename = r["display_name"].to_lower().replace(" ", "_") + ".tres"
		var path = "res://data/resources/" + filename
		ResourceSaver.save(res_def, path)
		count += 1
		
	print("Saved %d ResourceDefinition files under res://data/resources/" % count)

func _import_recipes() -> void:
	print("\nImporting ProductionRecipes (Craft items)...")
	var items_data = ItemsParser.parse()
	var count = 0
	
	for item in items_data["shop_items"]:
		var recipe = ProductionRecipe.new()
		recipe.id = item["id"]
		recipe.display_name = item["display_name"]
		recipe.kind = 1 # CRAFT (ProductionRecipe.RecipeKind.CRAFT)
		recipe.time_seconds = item["time_seconds"]
		recipe.reward_xp = item["reward_xp"]
		recipe.input_cost = item["input_cost"]
		recipe.reward = item["reward"]
		recipe.hurry_cost = item["hurry_cost"]
		recipe.hurry_interval_seconds = item["hurry_interval_seconds"]
		
		var lands: Array[String] = []
		for l in item["compatible_lands"]:
			lands.append(l)
		recipe.compatible_lands = lands
		
		var filename = item["display_name"].to_lower().replace(" ", "_") + ".tres"
		var path = "res://data/recipes/" + filename
		ResourceSaver.save(recipe, path)
		count += 1
		
	print("Saved %d ProductionRecipe files under res://data/recipes/" % count)

func _import_buildings() -> void:
	print("\nImporting BuildingDefinitions...")
	var parsed_objects_data = ObjectsParser.parse_all()
	var count = 0
	
	for obj in parsed_objects_data["objects"]:
		var b_def = BuildingDefinition.new()
		b_def.id = obj["id"]
		b_def.display_name = obj["display_name"]
		b_def.type = _map_building_type(obj["type_raw"])
		b_def.category = obj["category"]
		b_def.width = obj["width"]
		b_def.height = obj["height"]
		b_def.xp_value = obj["xp_value"]
		b_def.build_time_seconds = obj["build_time_seconds"]
		b_def.upgrade_of_id = obj["upgrade_id_attr"]
		b_def.upgrade_only = obj["upgrade_only"]
		b_def.owned_limit = obj["owned_limit"]
		b_def.info_text = obj["info_text"]
		b_def.description_text = obj["description_text"]
		
		var lands: Array[String] = []
		for l in obj["compatible_lands"]:
			lands.append(l)
		b_def.compatible_lands = lands
		
		# Set house capacity placeholder
		if b_def.type == 6: # HOUSE
			b_def.house_capacity = 2 if b_def.id == 101 else (4 if b_def.id == 102 else 2)
			
		# Map cost
		var cost_bundle = CostBundle.new()
		for res_id in obj["cost"].keys():
			var entry = CostEntry.new()
			entry.resource_id = res_id
			entry.amount = obj["cost"][res_id]
			cost_bundle.entries.append(entry)
		b_def.cost = cost_bundle
		
		# Map sell
		var sell_bundle = CostBundle.new()
		for res_id in obj["sell"].keys():
			var entry = CostEntry.new()
			entry.resource_id = res_id
			entry.amount = obj["sell"][res_id]
			sell_bundle.entries.append(entry)
		b_def.sell = sell_bundle
		b_def.sellable = obj["sellable"]
		
		# Map prerequisites
		var prereq_set = PrerequisiteSet.new()
		for p in obj["prerequisites"]:
			var entry = PrerequisiteEntry.new()
			entry.kind = _map_prereq_kind(p["kind"])
			entry.target_id = p["target_id"] if entry.kind != 0 else p["min_value"]
			entry.required_count = p["min_value"] if entry.kind == 1 else 1
			prereq_set.all_of.append(entry)
		b_def.prerequisites = prereq_set
		
		# Map storage capacities
		b_def.storage_capacities = obj["storage_capacities"]
		
		# Map gather recipe if applicable
		if obj["gather_recipe"] != null:
			var g_rec = obj["gather_recipe"]
			var recipe = ProductionRecipe.new()
			recipe.id = obj["id"] + 50000 # Unique recipe ID offset
			recipe.display_name = "Gather at " + obj["display_name"]
			recipe.kind = 0 # GATHER
			recipe.output_resource_id = g_rec["output_resource_id"]
			recipe.max_output_stack_size = g_rec["max_output_stack_size"]
			recipe.villager_resources_per_hour = g_rec["villager_resources_per_hour"]
			recipe.worker_max = g_rec["worker_max"]
			recipe.hauler_max = g_rec["hauler_max"]
			
			var recipe_path = "res://data/recipes/gather_%d.tres" % obj["id"]
			ResourceSaver.save(recipe, recipe_path)
			
			b_def.gather_recipe_id = recipe.id
			
		var shop_ids: Array[int] = []
		for s_id in obj["shop_recipe_ids"]:
			shop_ids.append(s_id)
		b_def.shop_recipe_ids = shop_ids
		
		# Generate path-friendly filename
		var filename = obj["display_name"].to_lower().replace(" ", "_").replace("'", "").replace("/", "_") + "_%d.tres" % obj["id"]
		var path = "res://data/buildings/" + filename
		ResourceSaver.save(b_def, path)
		count += 1
		
	print("Saved %d BuildingDefinition files under res://data/buildings/" % count)

func _map_building_type(type_str: String) -> int:
	match type_str.to_lower():
		"townhall": return 0
		"mine": return 1
		"shop": return 2
		"store": return 3
		"market": return 4
		"decoration": return 5
		"house": return 6
		"resource_tile": return 7
		"present": return 8
		"misc": return 9
		"skinswitch": return 10
		"entertainer": return 11
		"river": return 12
		"hot_air_balloon": return 13
		"tree": return 14
		_: return 9 # MISC

func _map_prereq_kind(kind_str: String) -> int:
	match kind_str.to_lower():
		"level": return 0
		"building": return 1
		"tutorial": return 2
		_: return 0
