## SoundsParser
## Parses Sounds.xml (id -> filename/volume/isMusic). No SoundDefinition
## Resource class exists yet — not one of the four databases requested for
## Phase 2 — so this exists purely to feed the inventory report
## (docs/DATA_IMPORT.md). Building/recipe parsers reference sound ids
## (sound_select_id, collect_sfx_id, ...) that this table can resolve to a
## filename for display purposes.
##
## Editor-only tooling — not shipped in an exported build.
class_name SoundsParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/Sounds.xml"


static func parse(path: String = SOURCE_PATH) -> Array:
	var results: Array = []
	var tree = XmlDom.parse_file(path)
	if tree == null:
		return results

	for node in XmlDom.find_all(tree, "Sound"):
		results.append({
			"id": XmlDom.attr_int(node, "id", -1),
			"extension": XmlDom.attr_string(node, "extension"),
			"volume": XmlDom.attr_float(node, "volume", 1.0),
			"is_music": XmlDom.attr_bool(node, "isMusic"),
			"filename": node.text,
		})

	return results
