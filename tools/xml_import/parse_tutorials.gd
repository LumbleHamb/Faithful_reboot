## TutorialsParser
## Parses Tutorials.xml into plain Dictionaries shaped like
## TutorialDefinition's fields. See docs/GAME_SYSTEMS.md §11 for the full
## trigger/objective/lock vocabulary this mirrors.
##
## Lock/Allow attribute names are extracted generically (whatever is
## present is captured) since — unlike Resources/Objects/Items, which were
## read in full during docs/GAME_SYSTEMS.md research — the exact <Lock>/
## <Allow> attribute spelling was documented in Tutorials.xml's authoring
## comment but not confirmed against a real instance before this parser was
## written. Run the Phase 2 inventory report and inspect real output before
## treating the field names below as final — see docs/DATA_IMPORT.md.
##
## Editor-only tooling — not shipped in an exported build.
class_name TutorialsParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/Tutorials.xml"

const OBJECTIVE_TYPE_MAP := {
	"build": "BUILD", "assign": "ASSIGN", "collect": "COLLECT", "gather": "GATHER",
	"transport": "TRANSPORT", "useShop": "USE_SHOP", "marketBuy": "MARKET_BUY",
	"marketSell": "MARKET_SELL", "landSize": "LAND_SIZE", "message": "MESSAGE",
	"hurryShop": "HURRY_SHOP", "hurryBuilding": "HURRY_BUILDING", "supply": "SUPPLY",
	"friendView": "FRIEND_VIEW",
}


## Returns { "tutorials": Array[Dictionary], "errors": Array[String] }.
static func parse(path: String = SOURCE_PATH) -> Dictionary:
	var tutorials: Array = []
	var errors: Array[String] = []

	var tree = XmlDom.parse_file(path)
	if tree == null:
		errors.append("Failed to parse %s" % path)
		return {"tutorials": tutorials, "errors": errors}

	for node in XmlDom.find_all(tree, "Tutorial"):
		var id = XmlDom.attr_int(node, "id", -1)
		if id == -1:
			errors.append("Skipped a <Tutorial> with no valid id.")
			continue

		var result := {
			"id": id,
			"trigger_type": XmlDom.attr_string(node, "triggerType", "always").to_upper(),
			"trigger_value": XmlDom.attr_int(node, "triggerValue", -1),
			"display_name": XmlDom.attr_string(node, "name"),
			"description": XmlDom.attr_string(node, "description"),
			"prerequisites": [],
			"reward": {},
			"objectives": [],
			"lock": {},
			"allow_entries": [],
			"allow_consumable_entries": [],
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

		var reward_node = XmlDom.first_child(node, "Reward")
		if reward_node != null:
			for child in reward_node.children:
				if child.tag == "Resource":
					var res_id = XmlDom.attr_int(child, "id", -1)
					if res_id != -1 and child.text.is_valid_float():
						result.reward[res_id] = float(child.text)
				elif child.tag == "Energy" and child.text.is_valid_float():
					result.reward["energy"] = float(child.text)

		for objective_node in XmlDom.find_all(node, "Objective"):
			var obj_type_raw: String = objective_node.text.strip_edges()
			result.objectives.append({
				"type_raw": obj_type_raw,
				"type": OBJECTIVE_TYPE_MAP.get(obj_type_raw, "UNKNOWN:%s" % obj_type_raw),
				"first": XmlDom.attr_int(objective_node, "first", -1),
				"second": XmlDom.attr_int(objective_node, "second", -1),
			})

		var lock_node = XmlDom.first_child(node, "Lock")
		if lock_node != null:
			result.lock = lock_node.attributes.duplicate()
			for allow_node in XmlDom.find_all(lock_node, "Allow"):
				result.allow_entries.append(allow_node.attributes.duplicate())
			for allow_consumable_node in XmlDom.find_all(lock_node, "AllowConsumable"):
				result.allow_consumable_entries.append(allow_consumable_node.attributes.duplicate())

		tutorials.append(result)

	return {"tutorials": tutorials, "errors": errors}
