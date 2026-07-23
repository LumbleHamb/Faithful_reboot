## ResourcesParser
## Parses the original Resources.xml into plain Dictionaries shaped like
## ResourceDefinition's fields (see resources/definitions/resource_definition.gd).
## Returns Dictionaries, not Resource instances — materialization into real
## .tres files is a separate step (generate_test_data.gd) so this parser can
## also be used in a pure dry-run/inventory mode with no ResourceSaver calls.
##
## Editor-only tooling — not shipped in an exported build.
class_name ResourcesParser
extends RefCounted

const XmlDom = preload("res://tools/xml_import/xml_dom.gd")

const SOURCE_PATH := "res://original/TradeNations.app/bundle/Resources.xml"

## Resources.xml has no machine-readable tier/refinement data — the
## original only marks this via human-readable XML *comments* ("Tier 1" /
## "Tier 2"), which are not structured attributes and are intentionally not
## parsed as data by XmlDom (see xml_dom.gd — comments are ignored).
## This is a small, stable, hand-authored enrichment table capturing that
## same knowledge as actual data instead. It is content-authoring metadata
## for the CONVERTER, not a gameplay hardcode — if Resources.xml ever
## changes, this table must be updated to match (see docs/DATA_IMPORT.md).
const TIER_AND_REFINEMENT := {
	1: {"tier": 0, "refines_from_id": -1},   # Gold — currency
	10: {"tier": 1, "refines_from_id": -1},  # Wood — raw
	20: {"tier": 1, "refines_from_id": -1},  # Rock — raw
	40: {"tier": 1, "refines_from_id": -1},  # Wheat — raw
	50: {"tier": 1, "refines_from_id": -1},  # Wool — raw
	11: {"tier": 2, "refines_from_id": 10},  # Lumber — refined from Wood
	21: {"tier": 2, "refines_from_id": 20},  # Cut Stone — refined from Rock
	51: {"tier": 2, "refines_from_id": 50},  # Cloth — refined from Wool
}


## Returns an Array of Dictionaries, or an empty Array (with errors logged
## via push_error/push_warning) on failure.
static func parse(path: String = SOURCE_PATH) -> Array:
	var results: Array = []
	var tree = XmlDom.parse_file(path)
	if tree == null:
		return results

	var nodes = XmlDom.find_all(tree, "Resource")
	for node in nodes:
		var id = XmlDom.attr_int(node, "id", -1)
		if id == -1:
			push_warning("[ResourcesParser] Skipped a <Resource> with no valid id.")
			continue

		var enrichment: Dictionary = TIER_AND_REFINEMENT.get(id, null)
		if enrichment == null:
			push_warning("[ResourcesParser] No tier/refinement entry for resource id %d — defaulting tier=1, refines_from_id=-1. Update TIER_AND_REFINEMENT in parse_resources.gd." % id)
			enrichment = {"tier": 1, "refines_from_id": -1}

		var score_value_raw = XmlDom.attr_string(node, "scoreValue")
		var has_score_value := score_value_raw != ""

		results.append({
			"id": id,
			"display_name": XmlDom.attr_string(node, "name"),
			"tier": enrichment.tier,
			"score_value": XmlDom.attr_float(node, "scoreValue", 0.0),
			"has_score_value": has_score_value,  # inventory-only flag; Cloth has none in the original
			"start_value": XmlDom.attr_float(node, "startValue", 0.0),
			"refines_from_id": enrichment.refines_from_id,
			"icon_font_char": XmlDom.attr_string(node, "iconfontchar"),
			"stack_sprite": XmlDom.attr_string(node, "stacksprite"),
			"single_sprite": XmlDom.attr_string(node, "singlesprite"),
			"hauler_anim_id": XmlDom.attr_int(node, "haulerAnim", -1),
			"collect_sfx_id": XmlDom.attr_int(node, "collectSFX", -1),
		})

	return results
