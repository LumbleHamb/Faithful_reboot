## SaveManager (autoload)
## Serializes/deserializes SaveGame to disk. See docs/ARCHITECTURE.md §2.3.
##
## Save format: Godot native Resource serialization (.tres — human-readable
## and diffable for development). An export build can switch to compressed
## binary via ResourceSaver flags later with no schema change; see
## docs/ARCHITECTURE.md §2.3 for the full reasoning. This is a development
## convenience, not something dictated by the original game's own (opaque,
## server-synced) save format — see docs/ARCHITECTURE.md §6, assumption 10.
##
## IMPORTANT: saves are written to user://saves/, never res://saves/.
## res://saves/ (inside the project source tree) is reserved for potential
## bundled/example save data later; it is NOT a runtime write target — once
## a game is exported, res:// is packed read-only, so writing there would
## work in-editor and silently fail in a real build. See
## docs/IMPLEMENTATION_STATUS.md for this decision.
##
## Phase 1: PlayerState + InventoryState only round-trip. SaveGame.world_state
## stays an empty Dictionary (reserved for Phase 2) — see save_game.gd.
extends Node

const SAVE_DIR := "user://saves/"
const SLOT_FILENAME_FORMAT := "slot_%d.tres"

var current_save: SaveGame = null


## Builds a fresh SaveGame with default PlayerState/InventoryState and makes
## it the current save. Does not write to disk — call save_to_slot() after.
func create_new_save() -> SaveGame:
	var save := SaveGame.new()
	save.save_version = 1
	save.created_at_unix = TimeManager.now()
	save.last_saved_at_unix = save.created_at_unix
	save.player_state = PlayerState.new()
	save.inventory = InventoryState.new()
	current_save = save
	return save


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
