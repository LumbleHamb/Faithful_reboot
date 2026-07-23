## DataManager (autoload)
## Loads and indexes static game-content definitions (ResourceDefinition,
## BuildingDefinition, ProductionRecipe, WorkerDefinition) from res://data/.
## See docs/ARCHITECTURE.md §2.2.
##
## Phase 1: the loading pipeline and lookup API exist and are exercised by
## tests/test_foundation.gd; res://data/ subfolders are empty (no gameplay
## content yet) — load_all() is expected to succeed against zero files,
## proving the mechanism, not the content. Real content is converted from
## original/TradeNations.app/bundle/ in a later phase (see
## docs/IMPLEMENTATION_ROADMAP.md Phase 1.3, still pending — see
## docs/IMPLEMENTATION_STATUS.md).
extends Node

const RESOURCE_DEFINITIONS_PATH := "res://data/resources/"
const BUILDING_DEFINITIONS_PATH := "res://data/buildings/"
const PRODUCTION_RECIPES_PATH := "res://data/recipes/"
const WORKER_DEFINITIONS_PATH := "res://data/workers/"

var resource_definitions: Dictionary = {}   # { id: ResourceDefinition }
var building_definitions: Dictionary = {}   # { id: BuildingDefinition }
var production_recipes: Dictionary = {}     # { id: ProductionRecipe }
var worker_definitions: Dictionary = {}     # { id: WorkerDefinition }

var _is_loaded: bool = false


## Loads every static content table. Safe to call more than once (e.g. from
## a test or a future "reload content" debug action) — it simply re-scans
## and rebuilds each index.
func load_all() -> void:
	resource_definitions = _load_definitions(RESOURCE_DEFINITIONS_PATH, "id")
	building_definitions = _load_definitions(BUILDING_DEFINITIONS_PATH, "id")
	production_recipes = _load_definitions(PRODUCTION_RECIPES_PATH, "id")
	worker_definitions = _load_definitions(WORKER_DEFINITIONS_PATH, "id")
	_is_loaded = true
	print("[DataManager] Loaded %d resource defs, %d building defs, %d recipes, %d worker defs." % [
		resource_definitions.size(),
		building_definitions.size(),
		production_recipes.size(),
		worker_definitions.size(),
	])


func is_loaded() -> bool:
	return _is_loaded


func get_resource_definition(id: int) -> ResourceDefinition:
	return resource_definitions.get(id, null)


func get_building_definition(id: int) -> BuildingDefinition:
	return building_definitions.get(id, null)


func get_production_recipe(id: int) -> ProductionRecipe:
	return production_recipes.get(id, null)


func get_worker_definition(id: String) -> WorkerDefinition:
	return worker_definitions.get(id, null)


## Generic loader: scans [param folder_path] for .tres Resource files and
## indexes them by their [param id_field] property. A missing folder or an
## empty folder is not an error — Phase 1 ships with no content yet.
func _load_definitions(folder_path: String, id_field: String) -> Dictionary:
	var index: Dictionary = {}
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return index

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := folder_path.path_join(file_name)
			var res: Resource = ResourceLoader.load(full_path)
			if res != null and (id_field in res):
				index[res.get(id_field)] = res
			else:
				push_warning("[DataManager] Skipped '%s' — missing '%s' field or failed to load." % [full_path, id_field])
		file_name = dir.get_next()
	dir.list_dir_end()

	return index
