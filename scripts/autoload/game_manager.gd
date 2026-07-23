## GameManager (autoload)
## Application state machine, boot/initialization orchestration, and (later)
## scene transitions. See docs/ARCHITECTURE.md §2.1.
##
## Registered last among the autoloads (see project.godot [autoload] order)
## so that by the time GameManager._ready() runs, DataManager/TimeManager/
## SaveManager already exist and can be called into safely.
##
## Phase 1: BOOT -> MAIN_MENU only. Real scene transitions to a World.tscn
## don't exist yet — there is nothing to transition to (Phase 2). See
## docs/IMPLEMENTATION_STATUS.md remaining-tasks list.
extends Node

enum State { BOOT, MAIN_MENU, LOADING_SAVE, IN_GAME, PAUSED }

var current_state: State = State.BOOT


func _ready() -> void:
	_boot()


func _boot() -> void:
	print("[GameManager] Boot sequence starting.")
	DataManager.load_all()
	current_state = State.MAIN_MENU
	print("[GameManager] Boot complete. State = MAIN_MENU.")


## Creates a fresh SaveGame and marks the game as in-progress. Does not yet
## instantiate a world scene — see the Phase 2 TODO below.
func start_new_game() -> SaveGame:
	current_state = State.LOADING_SAVE
	var save := SaveManager.create_new_save()
	current_state = State.IN_GAME
	print("[GameManager] New game started.")
	# TODO (Phase 2): instantiate World.tscn for the starting land once
	# BuildingDefinition content and a starting TownLayout exist.
	return save


func continue_game(slot: int) -> SaveGame:
	current_state = State.LOADING_SAVE
	var save := SaveManager.load_from_slot(slot)
	if save == null:
		current_state = State.MAIN_MENU
		return null
	current_state = State.IN_GAME
	print("[GameManager] Continued game from slot %d." % slot)
	# TODO (Phase 2): instantiate World.tscn for the loaded land(s).
	return save


func quit_to_main_menu() -> void:
	current_state = State.MAIN_MENU
	# TODO (Phase 2+): tear down the active World.tscn instance, if any.
