## XmlDom
## Generic XML -> nested Dictionary parser shared by every Phase 2 import
## script. Godot's built-in XMLParser is a streaming/token reader, not a
## DOM — the original bundle's XML files are small enough (largest is
## ~1,800 lines) to hold fully in memory, so this builds a lightweight DOM
## once per file rather than making every extraction script re-implement
## streaming logic.
##
## Node shape: { "tag": String, "attributes": Dictionary, "children":
## Array[Dictionary], "text": String }. The returned root is a synthetic
## "#root" node whose children are the file's actual top-level tag(s) —
## several original files (e.g. Layout.xml-style files) have more than one
## top-level element or stray top-level text, which a synthetic root
## tolerates without special-casing.
##
## Editor-only tooling (docs/ARCHITECTURE.md tools/xml_import/) — not
## shipped in an exported build.
class_name XmlDom
extends RefCounted


## Returns null on failure (missing file / open error), with the error
## logged via push_error rather than silently swallowed — Phase 2 tooling
## must "report errors," not hide them (see docs/DATA_IMPORT.md).
static func parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[XmlDom] File not found: %s" % path)
		return null

	var parser := XMLParser.new()
	var err := parser.open(path)
	if err != OK:
		push_error("[XmlDom] Failed to open '%s': error %d" % [path, err])
		return null

	var root := {"tag": "#root", "attributes": {}, "children": [], "text": ""}
	var stack: Array = [root]

	while true:
		var read_err := parser.read()
		if read_err != OK:
			break

		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node := {
					"tag": parser.get_node_name(),
					"attributes": {},
					"children": [],
					"text": "",
				}
				for i in parser.get_attribute_count():
					node.attributes[parser.get_attribute_name(i)] = parser.get_attribute_value(i)

				var parent: Dictionary = stack[-1]
				parent.children.append(node)

				if not parser.is_empty():
					stack.append(node)

			XMLParser.NODE_ELEMENT_END:
				if stack.size() > 1:
					stack.pop_back()

			XMLParser.NODE_TEXT:
				var raw := parser.get_node_data()
				var trimmed := raw.strip_edges()
				if trimmed != "":
					var top: Dictionary = stack[-1]
					top.text += trimmed

			_:
				pass  # NODE_COMMENT / NODE_CDATA / NODE_UNKNOWN — ignored

	return root


## Returns all direct-or-nested children of [param node] matching [param tag],
## searched recursively (several original files nest the same tag under
## varying parent structures, e.g. <Object> under a bare root vs. under
## <Objects>).
static func find_all(node: Dictionary, tag: String) -> Array:
	var results: Array = []
	_find_all_recursive(node, tag, results)
	return results


static func _find_all_recursive(node: Dictionary, tag: String, results: Array) -> void:
	for child in node.get("children", []):
		if child.tag == tag:
			results.append(child)
		_find_all_recursive(child, tag, results)


## Returns the first direct child matching [param tag], or null. Non-recursive
## (direct children only) — use this for "one expected child of this shape."
static func first_child(node: Dictionary, tag: String) -> Variant:
	for child in node.get("children", []):
		if child.tag == tag:
			return child
	return null


## Attribute helpers with typed defaults, since every attribute value from
## XMLParser is a String and most callers want an int/float/bool.
static func attr_string(node: Dictionary, key: String, default: String = "") -> String:
	return node.get("attributes", {}).get(key, default)


static func attr_int(node: Dictionary, key: String, default: int = 0) -> int:
	var raw: String = node.get("attributes", {}).get(key, "")
	if raw == "" or not raw.is_valid_int():
		return default
	return raw.to_int()


static func attr_float(node: Dictionary, key: String, default: float = 0.0) -> float:
	var raw: String = node.get("attributes", {}).get(key, "")
	if raw == "" or not raw.is_valid_float():
		return default
	return raw.to_float()


static func attr_bool(node: Dictionary, key: String, default: bool = false) -> bool:
	var raw: String = node.get("attributes", {}).get(key, "")
	if raw == "":
		return default
	return raw in ["1", "true", "y", "yes"]


static func has_attr(node: Dictionary, key: String) -> bool:
	return node.get("attributes", {}).has(key)
