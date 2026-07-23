## SettingsParser
## Parses the parts of Settings.xml relevant to Phase 2: lands, energy
## constants, villager simulation constants, adopted-villager cost, buff
## categories/caps, and the mayor XP/level table. See docs/GAME_SYSTEMS.md
## §5/§8/§9/§10/§4.
##
## Villager constants feed a real WorkerDefinition instance in
## generate_test_data.gd (Phase 2 bonus — WorkerDefinition otherwise has no
## test data among the six items explicitly requested). No LevelDef/
## BuffDef Resource classes exist yet, so levels/buffs are inventory-only
## Dictionaries here.
##
## Editor-only tooling — not shipped in an exported build.
class_name SettingsParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/Settings.xml"


static func parse(path: String = SOURCE_PATH) -> Dictionary:
	var result := {
		"lands": [],
		"energy": {},
		"villager": {},
		"adopted_villager_cost": {},
		"buff_categories": [],
		"max_buffer_by_land": {},
		"levels": [],
		"errors": [],
	}

	var tree = XmlDom.parse_file(path)
	if tree == null:
		result.errors.append("Failed to parse %s" % path)
		return result

	var lands_node = XmlDom.first_child(tree, "Lands")
	if lands_node != null:
		for land_node in lands_node.children:
			if land_node.tag == "Land":
				result.lands.append(land_node.text)

	var energy_node = XmlDom.first_child(tree, "Energy")
	if energy_node != null:
		result.energy = {
			"worktime": XmlDom.attr_float(energy_node, "worktime", 0.0),
			"carryamount": XmlDom.attr_float(energy_node, "carryamount", 0.0),
			"building_hurry_cost": XmlDom.attr_float(energy_node, "buildingHurryCost", 0.0),
			"building_hurry_interval": XmlDom.attr_float(energy_node, "buildingHurryInterval", 0.0),
			"icon_font_energy": XmlDom.attr_string(energy_node, "iconFontEnergy"),
		}

	var villager_node = XmlDom.first_child(tree, "Villager")
	if villager_node != null:
		result.villager = {
			"speed": XmlDom.attr_float(villager_node, "speed", 1.0),
			"haul_speed": XmlDom.attr_float(villager_node, "haulspeed", 1.0),
			"work_rate": XmlDom.attr_float(villager_node, "workrate", 1.0),
			"homeless_modifier": XmlDom.attr_float(villager_node, "homelessmodifier", 1.0),
			"eat_time": XmlDom.attr_float(villager_node, "eattime", 0.0),
			"hunger_length_min": XmlDom.attr_float(villager_node, "hungerlengthmin", 0.0),
			"hunger_length_max": XmlDom.attr_float(villager_node, "hungerlengthmax", 0.0),
		}

	var adopted_node = XmlDom.first_child(tree, "AdoptedVillagers")
	if adopted_node != null:
		var villager_cost_node = XmlDom.first_child(adopted_node, "Villager")
		if villager_cost_node != null:
			result.adopted_villager_cost = {"gold": XmlDom.attr_float(villager_cost_node, "cost", 0.0)}

	var buff_node = XmlDom.first_child(tree, "BuffSystem")
	if buff_node != null:
		var categories_node = XmlDom.first_child(buff_node, "Categories")
		if categories_node != null:
			for cat_node in categories_node.children:
				if cat_node.tag == "Category":
					result.buff_categories.append(XmlDom.attr_string(cat_node, "name"))

		for max_buffer_node in XmlDom.find_all(buff_node, "MaxBuffer"):
			var land = XmlDom.attr_string(max_buffer_node, "land")
			var resources_node = XmlDom.first_child(max_buffer_node, "Resources")
			var xp_percent = XmlDom.attr_float(resources_node, "xpPercent", 0.0) if resources_node != null else 0.0
			result.max_buffer_by_land[land] = xp_percent

	var user_node = XmlDom.first_child(tree, "User")
	if user_node != null:
		result["max_level"] = XmlDom.attr_int(user_node, "maxlevel", 0)
		for xp_node in XmlDom.find_all(user_node, "XP"):
			var max_building := {}
			for mb_node in xp_node.children:
				if mb_node.tag == "MaxBuilding" and mb_node.text.is_valid_int():
					max_building[XmlDom.attr_string(mb_node, "category")] = int(mb_node.text)
			var reward_node = XmlDom.first_child(xp_node, "Reward")
			result.levels.append({
				"level": XmlDom.attr_int(xp_node, "level", -1),
				"xp_to_next": XmlDom.attr_float(xp_node, "toNext", 0.0),
				"max_building": max_building,
				"reward_energy": XmlDom.attr_float(reward_node, "energy", 0.0) if reward_node != null else 0.0,
			})

	return result
