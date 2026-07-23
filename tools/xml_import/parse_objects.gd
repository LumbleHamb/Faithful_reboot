## ObjectsParser
## Parses every original <Object> across the file set listed by
## Objects.xml (the manifest itself is read, not hardcoded — see
## parse_manifest() — matching the original's own data-driven load order).
## Covers buildings, decorations, mines, shops, storage, market, resource
## tiles, and every other overloaded use of the <Object> tag (see
## docs/GAME_SYSTEMS.md §3/§4).
##
## Returns one rich Dictionary per <Object>, a superset of what
## BuildingDefinition/ProductionRecipe actually need — the extra fields
## (sound ids, animation names) exist for the Phase 2 inventory report;
## generate_test_data.gd only reads the subset it materializes.
##
## Editor-only tooling — not shipped in an exported build.
class_name ObjectsParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const BUNDLE_DIR := "res://original/TradeNations.app/bundle/"
const MANIFEST_PATH := BUNDLE_DIR + "Objects.xml"

## Files present in every land regardless of the manifest (the manifest
## only lists 10+/decoration/event packs — the two base building files are
## always loaded first by the original, so they're included explicitly
## rather than guessed).
const ALWAYS_LOADED_FILES := [
	"Vanilla_BuildingsTo10.xml",
]


## Reads Objects.xml and returns the list of building/decoration XML
## filenames it references (data-driven — nothing here is hardcoded except
## the always-loaded base file noted above, which the manifest itself does
## not list).
static func parse_manifest(path: String = MANIFEST_PATH) -> Array[String]:
	var files: Array[String] = ALWAYS_LOADED_FILES.duplicate()
	var tree = XmlDom.parse_file(path)
	if tree == null:
		return files

	for node in XmlDom.find_all(tree, "File"):
		var name = XmlDom.attr_string(node, "name")
		if name != "" and not files.has(name):
			files.append(name)

	return files


## Parses every <Object> in every manifest-listed file. Returns
## { "objects": Array[Dictionary], "errors": Array[String] } — errors are
## per-file parse failures, collected rather than aborting the whole run
## (task 4's "report errors" requirement).
static func parse_all() -> Dictionary:
	var all_objects: Array = []
	var errors: Array[String] = []

	for file_name in parse_manifest():
		var path := BUNDLE_DIR + file_name
		var tree = XmlDom.parse_file(path)
		if tree == null:
			errors.append("Failed to parse %s" % path)
			continue

		var nodes = XmlDom.find_all(tree, "Object")
		for node in nodes:
			var obj := _parse_object_node(node, file_name)
			if obj == null:
				errors.append("Skipped an <Object> with no valid id in %s" % file_name)
				continue
			all_objects.append(obj)

	return {"objects": all_objects, "errors": errors}


static func _parse_object_node(node: Dictionary, source_file: String) -> Variant:
	var id = XmlDom.attr_int(node, "id", -1)
	if id == -1:
		return null

	var result := {
		"id": id,
		"source_file": source_file,
		"display_name": XmlDom.attr_string(node, "name"),
		"type_raw": XmlDom.attr_string(node, "type"),
		"category": XmlDom.attr_string(node, "category"),
		"width": XmlDom.attr_int(node, "width", 1),
		"height": XmlDom.attr_int(node, "height", 1),
		"xp_value": XmlDom.attr_float(node, "xpValue", 0.0),
		"available_from_store": XmlDom.attr_bool(node, "availableFromStore"),
		"upgrade_id_attr": XmlDom.attr_int(node, "upgradeID", 0),
		"compatible_lands": [],
		"cost": {},
		"sell": {},
		"sellable": true,
		"build_time_seconds": 0.0,
		"build_fade_anim": false,
		"prerequisites": [],
		"upgrade_of_id": -1,
		"upgrade_only": false,
		"owned_limit": -1,
		"storage_capacities": {},
		"gather_recipe": null,
		"shop_recipe_ids": [],
		"info_text": "",
		"description_text": "",
		"finish_time_unix": -1,
		"idle_anim": "",
		"sound_select_id": -1,
		"sound_buy_id": -1,
		"sound_sell_id": -1,
	}

	var compat = XmlDom.first_child(node, "CompatibleLand")
	if compat != null:
		result.compatible_lands = [compat.text]

	var cost_node = XmlDom.first_child(node, "Cost")
	if cost_node != null:
		result.cost = _parse_cost_like(cost_node)

	var sell_node = XmlDom.first_child(node, "Sell")
	if sell_node != null:
		if sell_node.children.is_empty():
			result.sellable = not (sell_node.text.strip_edges() == "false")
			result.sell = {}
		else:
			result.sellable = true
			result.sell = _parse_cost_like(sell_node)

	var build_time_node = XmlDom.first_child(node, "BuildTime")
	if build_time_node != null:
		result.build_time_seconds = float(build_time_node.text) if build_time_node.text.is_valid_float() else 0.0
		result.build_fade_anim = XmlDom.attr_bool(build_time_node, "fadeAnim")

	for prereq_node in XmlDom.find_all(node, "Prerequisite"):
		var kind = XmlDom.attr_string(prereq_node, "type")
		var value_text: String = prereq_node.text.strip_edges()
		var entry := {"kind": kind, "target_id": -1, "min_value": 0}
		if kind == "level":
			entry.min_value = int(value_text) if value_text.is_valid_int() else 0
		elif value_text.is_valid_int():
			entry.target_id = int(value_text)
		result.prerequisites.append(entry)

	var upgrade_of_node = XmlDom.first_child(node, "UpgradeOf")
	if upgrade_of_node != null:
		result.upgrade_of_id = int(upgrade_of_node.text) if upgrade_of_node.text.is_valid_int() else -1
		result.upgrade_only = XmlDom.attr_bool(upgrade_of_node, "upgradeOnly")

	var limit_node = XmlDom.first_child(node, "Limit")
	if limit_node != null and limit_node.text.is_valid_int():
		result.owned_limit = int(limit_node.text)

	var resources_node = XmlDom.first_child(node, "Resources")
	if resources_node != null:
		for res_node in resources_node.children:
			if res_node.tag != "Resource":
				continue
			var res_id = XmlDom.attr_int(res_node, "id", -1)
			var qty_raw = XmlDom.attr_string(res_node, "qty")
			if res_id == -1:
				continue
			result.storage_capacities[res_id] = -1.0 if qty_raw == "unlimited" else (float(qty_raw) if qty_raw.is_valid_float() else 0.0)

	var produce_node = XmlDom.first_child(node, "Produce")
	if produce_node != null:
		var output_node = XmlDom.first_child(produce_node, "Output")
		var rate_node = XmlDom.first_child(produce_node, "Rate")
		var worker_type_node = XmlDom.first_child(node, "WorkerType")
		var workers_node = XmlDom.first_child(node, "Workers")
		result.gather_recipe = {
			"hurry_cost": XmlDom.attr_float(produce_node, "hurryCost", 0.0),
			"output_resource_id": XmlDom.attr_int(output_node, "resource_id", -1) if output_node != null else -1,
			"max_output_stack_size": XmlDom.attr_float(output_node, "maxOutputStackSize", 0.0) if output_node != null else 0.0,
			"resources_per_hour_passive": XmlDom.attr_float(rate_node, "resourcesPerHour", 0.0) if rate_node != null else 0.0,
			"villager_resources_per_hour": XmlDom.attr_float(rate_node, "villagerResourcesPerHour", 0.0) if rate_node != null else 0.0,
			"mayor_resources": XmlDom.attr_float(rate_node, "mayorResources", 0.0) if rate_node != null else 0.0,
			"mayor_resources_no_energy": XmlDom.attr_float(rate_node, "mayorResourcesNoEnergy", 0.0) if rate_node != null else 0.0,
			"worker_type_label": worker_type_node.text if worker_type_node != null else "",
			"worker_max": XmlDom.attr_int(workers_node, "workerMax", 1) if workers_node != null else 1,
			"hauler_max": XmlDom.attr_int(workers_node, "haulerMax", 1) if workers_node != null else 1,
		}

	for item_node in XmlDom.find_all(node, "Item"):
		if item_node.text.is_valid_int():
			result.shop_recipe_ids.append(int(item_node.text))

	var info_node = XmlDom.first_child(node, "Info")
	if info_node != null:
		result.info_text = info_node.text

	var desc_node = XmlDom.first_child(node, "Description")
	if desc_node != null:
		result.description_text = desc_node.text

	var finish_time_node = XmlDom.first_child(node, "FinishTime")
	if finish_time_node != null and finish_time_node.text.is_valid_int():
		result.finish_time_unix = int(finish_time_node.text)

	var idle_anim_node = XmlDom.first_child(node, "IdleAnim")
	if idle_anim_node != null:
		result.idle_anim = XmlDom.attr_string(idle_anim_node, "name")

	var sounds_node = XmlDom.first_child(node, "Sounds")
	if sounds_node != null:
		result.sound_select_id = XmlDom.attr_int(sounds_node, "select", -1)
		result.sound_buy_id = XmlDom.attr_int(sounds_node, "buy", -1)
		result.sound_sell_id = XmlDom.attr_int(sounds_node, "sell", -1)

	return result


## Shared by <Cost>/<Sell> parsing: a container of <Resource id=X>qty</Resource>
## and/or a single <MagicBeans>qty</MagicBeans>. Returns { resource_id: float,
## ..., "magic_beans": float (only present if the tag existed) }.
static func _parse_cost_like(container: Dictionary) -> Dictionary:
	var out := {}
	for child in container.children:
		if child.tag == "Resource":
			var res_id = XmlDom.attr_int(child, "id", -1)
			if res_id != -1 and child.text.is_valid_float():
				out[res_id] = float(child.text)
		elif child.tag == "MagicBeans":
			if child.text.is_valid_float():
				out["magic_beans"] = float(child.text)
	return out
