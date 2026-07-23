## BuildMenuParser
## Parses BuildMenu.xml (category -> ordered building/decoration id list).
## Inventory-only for Phase 2 — cross-referenced against ObjectsParser
## output to confirm every BuildMenu entry resolves to a real Object id
## (see docs/DATA_IMPORT.md validation section).
##
## Editor-only tooling — not shipped in an exported build.
class_name BuildMenuParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/BuildMenu.xml"


## Returns Array of { "category": String, "items": Array[{"id": int,
## "name": String, "icon": String}] }.
static func parse(path: String = SOURCE_PATH) -> Array:
	var results: Array = []
	var tree = XmlDom.parse_file(path)
	if tree == null:
		return results

	for cat_node in XmlDom.find_all(tree, "Category"):
		var items: Array = []
		for item_node in cat_node.children:
			if item_node.tag != "Item":
				continue
			items.append({
				"id": XmlDom.attr_int(item_node, "id", -1),
				"name": XmlDom.attr_string(item_node, "name"),
				"icon": XmlDom.attr_string(item_node, "icon"),
			})
		results.append({
			"category": XmlDom.attr_string(cat_node, "name"),
			"items": items,
		})

	return results
