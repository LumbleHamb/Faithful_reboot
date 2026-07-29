## SaveManager (autoload)
## Serializes/deserializes SaveGame to disk and handles new game creation.
## See docs/ARCHITECTURE.md §2.3.
extends Node

const SAVE_DIR := "user://saves/"
const SLOT_FILENAME_FORMAT := "slot_%d.tres"

const SaveGame = preload("res://resources/runtime/save_game.gd")
const PlayerState = preload("res://resources/runtime/player_state.gd")
const InventoryState = preload("res://resources/runtime/inventory_state.gd")
const Villager = preload("res://resources/runtime/villager.gd")
const TownLayout = preload("res://resources/runtime/town_layout.gd")
const TutorialProgress = preload("res://resources/runtime/tutorial_progress.gd")

var current_save: SaveGame = null


## Builds a fresh, fully-populated SaveGame and makes it the current save.
## Does not write to disk — call save_to_slot() after.
func create_new_save() -> SaveGame:
	var save = SaveGame.new()
	save.save_version = 1
	save.created_at_unix = TimeManager.now()
	save.last_saved_at_unix = save.created_at_unix
	
	# Create and populate sub-resources
	save.player_state = PlayerState.new()
	save.inventory = _create_starting_inventory()
	save.villagers = _create_starting_villagers()
	save.tutorial_progress = TutorialProgress.new()
	
	# Set starting layout
	var default_layout = DataManager.get_starting_layout("default_layout")
	if default_layout:
		save.town_layouts["Vanilla"] = default_layout.duplicate(true)
	else:
		push_error("[SaveManager] Could not load 'default_layout' to create new save.")
		save.town_layouts["Vanilla"] = TownLayout.new()

	current_save = save
	print("[SaveManager] New game state created with starting resources and villagers.")
	return save


func _create_starting_inventory() -> InventoryState:
	var inventory = InventoryState.new()
	inventory.resource_amounts.clear()
	var all_resources = DataManager.get_all_resource_definitions()
	for res_def in all_resources:
		if res_def.start_value > 0:
			inventory.resource_amounts[res_def.id] = res_def.start_value
	return inventory


func _create_starting_villagers() -> Array[Villager]:
	var villagers: Array[Villager] = []
	
	var v1 = Villager.new()
	v1.villager_id = "villager_1"
	v1.villager_name = "Destiny Shaw" # Name from video analysis
	v1.gender = Villager.Gender.FEMALE
	villagers.append(v1)
	
	var v2 = Villager.new()
	v2.villager_id = "villager_2"
	v2.villager_name = "Adam"
	v2.gender = Villager.Gender.MALE
	villagers.append(v2)
	
	return villagers


func save_to_slot(slot: int) -> bool:
	if current_save == null:
		push_error("[SaveManager] save_to_slot called with no current_save.")
		return false

	_ensure_save_dir()
	current_save.last_saved_at_unix = TimeManager.now()

	var path := SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)
	var result := ResourceSaver.save(current_save, path)
	if result != OK:
		push_error("[SaveManager] Failed to save slot %d: error %d" % [slot, result])
		return false

	print("[SaveManager] Saved slot %d to %s" % [slot, path])
	return true


func load_from_slot(slot: int) -> SaveGame:
	var path := SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] No save found at %s" % path)
		return null

	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is SaveGame):
		push_error("[SaveManager] Failed to load slot %d from %s" % [slot, path])
		return null

	current_save = loaded
	print("[SaveManager] Loaded slot %d from %s" % [slot, path])
	return current_save


func delete_slot(slot: int) -> bool:
	var path := SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)
	if not FileAccess.file_exists(path):
		return false
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	return dir.remove(SLOT_FILENAME_FORMAT % slot) == OK


func list_slots() -> Array[int]:
	var slots: Array[int] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("slot_") and file_name.ends_with(".tres"):
			var num_str := file_name.trim_prefix("slot_").trim_suffix(".tres")
			if num_str.is_valid_int():
				slots.append(num_str.to_int())
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
