## ItemsParser
## Parses Items.xml, which mixes two unrelated original mechanics under one
## <Item> tag distinguished by `type`:
##   type="shopItem"   -> a CRAFT ProductionRecipe (see docs/GAME_SYSTEMS.md §2)
##   type="landUpgrade" -> a land-size purchase (docs/GAME_SYSTEMS.md §7) —
##                         no LandUpgradeDefinition Resource class exists yet
##                         (not one of the four databases requested this
##                         phase); returned here as plain Dictionaries purely
##                         for the Phase 2 inventory (see docs/DATA_IMPORT.md).
##   other types (e.g. "gold"/"energy"/"building" store items, seen in
##   TownhallStore.xml/ItemOfTheDay.xml rather than Items.xml itself) are out
##   of scope for this parser.
##
## Editor-only tooling — not shipped in an exported build.
class_name ItemsParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/Items.xml"


## Returns { "shop_items": Array[Dictionary], "land_upgrades": Array[Dictionary],
## "other": Array[Dictionary], "errors": Array[String] }.
static func parse(path: String = SOURCE_PATH) -> Dictionary:
	var shop_items: Array = []
	var land_upgrades: Array = []
	var other: Array = []
	var errors: Array[String] = []

	var tree = XmlDom.parse_file(path)
	if tree == null:
		errors.append("Failed to parse %s" % path)
		return {"shop_items": shop_items, "land_upgrades": land_upgrades, "other": other, "errors": errors}

	for node in XmlDom.find_all(tree, "Item"):
		var item_type = XmlDom.attr_string(node, "type")
		match item_type:
			"shopItem":
				shop_items.append(_parse_shop_item(node))
			"landUpgrade":
				land_upgrades.append(_parse_land_upgrade(node))
			_:
				other.append({
					"id": XmlDom.attr_int(node, "id", -1),
					"type": item_type,
					"name": XmlDom.attr_string(node, "name"),
				})

	return {"shop_items": shop_items, "land_upgrades": land_upgrades, "other": other, "errors": errors}


static func _parse_shop_item(node: Dictionary) -> Dictionary:
	var result := {
		"id": XmlDom.attr_int(node, "id", -1),
		"display_name": XmlDom.attr_string(node, "name"),
		"time_seconds": XmlDom.attr_float(node, "time", 0.0),
		"prerequisites": [],
		"hurry_interval_seconds": 0.0,
		"hurry_cost": 0.0,
		"input_cost": {},
		"reward_xp": 0.0,
		"reward": {},
		"compatible_lands": [],
	}

	for prereq_node in XmlDom.find_all(node, "Prerequisite"):
		var kind = XmlDom.attr_string(prereq_node, "type")
		var value_text: String = prereq_node.text.strip_edges()
		var entry := {"kind": kind, "target_id": -1, "min_value": 0}
		if kind == "level" and value_text.is_valid_int():
			entry.min_value = int(value_text)
		elif value_text.is_valid_int():
			entry.target_id = int(value_text)
		result.prerequisites.append(entry)

	var hurry_node = XmlDom.first_child(node, "HurryCost")
	if hurry_node != null:
		result.hurry_interval_seconds = XmlDom.attr_float(hurry_node, "timeInterval", 0.0)
		result.hurry_cost = float(hurry_node.text) if hurry_node.text.is_valid_float() else 0.0

	var cost_node = XmlDom.first_child(node, "Cost")
	if cost_node != null:
		for child in cost_node.children:
			if child.tag == "Resource":
				var res_id = XmlDom.attr_int(child, "id", -1)
				if res_id != -1 and child.text.is_valid_float():
					result.input_cost[res_id] = float(child.text)

	var reward_node = XmlDom.first_child(node, "Reward")
	if reward_node != null:
		result.reward_xp = XmlDom.attr_float(reward_node, "xp", 0.0)
		for child in reward_node.children:
			if child.tag == "Resource":
				var res_id = XmlDom.attr_int(child, "id", -1)
				if res_id != -1 and child.text.is_valid_float():
					result.reward[res_id] = float(child.text)

	var compat_node = XmlDom.first_child(node, "CompatibleLand")
	if compat_node != null:
		result.compatible_lands = [compat_node.text]

	return result


static func _parse_land_upgrade(node: Dictionary) -> Dictionary:
	var result := {
		"id": XmlDom.attr_int(node, "id", -1),
		"display_name": XmlDom.attr_string(node, "name"),
		"new_land_size": XmlDom.attr_int(node, "value", 0),
		"prerequisites": [],
		"cost": {},
		"alternate_cost_magic_beans": -1.0,
		"compatible_land": "",
	}

	for prereq_node in XmlDom.find_all(node, "Prerequisite"):
		var kind = XmlDom.attr_string(prereq_node, "type")
		var value_text: String = prereq_node.text.strip_edges()
		var entry := {"kind": kind, "target_id": -1, "min_value": 0}
		if kind == "level" and value_text.is_valid_int():
			entry.min_value = int(value_text)
		elif value_text.is_valid_int():
			entry.target_id = int(value_text)
		result.prerequisites.append(entry)

	var cost_node = XmlDom.first_child(node, "Cost")
	if cost_node != null:
		for child in cost_node.children:
			if child.tag == "Resource":
				var res_id = XmlDom.attr_int(child, "id", -1)
				if res_id != -1 and child.text.is_valid_float():
					result.cost[res_id] = float(child.text)

	var alt_cost_node = XmlDom.first_child(node, "AlternateCost")
	if alt_cost_node != null:
		var beans_node = XmlDom.first_child(alt_cost_node, "MagicBeans")
		if beans_node != null and beans_node.text.is_valid_float():
			result.alternate_cost_magic_beans = float(beans_node.text)

	var compat_node = XmlDom.first_child(node, "CompatibleLand")
	if compat_node != null:
		result.compatible_land = compat_node.text

	return result
