## SkinsParser
## Parses Skins.xml (seasonal/land reskins). No SkinDefinition Resource
## class exists yet — not one of the four databases requested for Phase 2
## — so this exists purely to feed the inventory report
## (docs/DATA_IMPORT.md). Captures headline structure (name/id/land/world
## prefix/object-override count/anim count) rather than full per-object
## override fidelity, since nothing consumes this data yet.
##
## Editor-only tooling — not shipped in an exported build.
class_name SkinsParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/Skins.xml"


static func parse(path: String = SOURCE_PATH) -> Array:
	var results: Array = []
	var tree = XmlDom.parse_file(path)
	if tree == null:
		return results

	for node in XmlDom.find_all(tree, "Skin"):
		var world_node = XmlDom.first_child(node, "World")
		var icon_node = XmlDom.first_child(node, "Icon")
		var land_node = XmlDom.first_child(node, "Land")

		results.append({
			"display_name": XmlDom.attr_string(node, "name"),
			"id": XmlDom.attr_int(node, "id", -1),
			"is_land": XmlDom.attr_bool(node, "isLand"),
			"world_prefix": XmlDom.attr_string(world_node, "prefix") if world_node != null else "",
			"icon_name": XmlDom.attr_string(icon_node, "name") if icon_node != null else "",
			"land_name": XmlDom.attr_string(land_node, "name") if land_node != null else "",
			"object_override_count": XmlDom.find_all(node, "Object").size(),
			"anim_sheet_count": XmlDom.find_all(node, "Anim").size(),
		})

	return results
