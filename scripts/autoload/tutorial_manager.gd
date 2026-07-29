# scripts/autoload/tutorial_manager.gd
# Manages tutorial progression.
extends Node

const TUTORIALS_PATH := "res://data/tutorials/"

var _tutorials: Dictionary = {} # { id: Tutorial }
var _active_tutorial: Tutorial = null
var _active_objective_index: int = -1
var _tutorial_popup = null

func _ready() -> void:
	_load_all()
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.worker_assigned.connect(_on_worker_assigned)

func set_tutorial_popup(popup) -> void:
	_tutorial_popup = popup

func start_tutorials() -> void:
	# Called by GameManager when a new game starts.
	# For now, just start the first tutorial.
	if _tutorials.has(1):
		_start_tutorial(_tutorials[1])
	else:
		print("[TutorialManager] No tutorial with ID 1 found.")

func _load_all() -> void:
	var dir = DirAccess.open(TUTORIALS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = TUTORIALS_PATH.path_join(file_name)
				var tutorial = ResourceLoader.load(full_path)
				if tutorial is Tutorial:
					_tutorials[tutorial.id] = tutorial
			file_name = dir.get_next()
	print("[TutorialManager] Loaded %d tutorials." % _tutorials.size())

func _start_tutorial(tutorial: Tutorial) -> void:
	print("[TutorialManager] Starting tutorial: '%s'" % tutorial.title)
	_active_tutorial = tutorial
	_active_objective_index = 0
	_show_current_objective()

func _show_current_objective() -> void:
	if _active_tutorial and _active_objective_index < _active_tutorial.objectives.size():
		var objective = _active_tutorial.objectives[_active_objective_index]
		if _tutorial_popup:
			_tutorial_popup.show_objective(objective.text)
		else:
			print("[TutorialManager] New Objective: %s" % objective.text)
	else:
		_complete_tutorial()

func _advance_objective() -> void:
	_active_objective_index += 1
	_show_current_objective()

func _complete_tutorial() -> void:
	print("[TutorialManager] Tutorial '%s' complete!" % _active_tutorial.title)
	if _tutorial_popup:
		_tutorial_popup.hide()
	# TODO: Update save data
	_active_tutorial = null
	_active_objective_index = -1

# --- Event Handlers for Checking Objectives ---

func _on_building_placed(building_instance: BuildingInstance) -> void:
	if not _active_tutorial: return
	
	var objective = _active_tutorial.objectives[_active_objective_index]
	if objective.type == TutorialObjective.ObjectiveType.BUILD and objective.target_def_id == building_instance.def_id:
		print("[TutorialManager] Objective complete: Built target building.")
		_advance_objective()

func _on_worker_assigned(villager: Villager, building_instance: BuildingInstance) -> void:
	if not _active_tutorial: return
	
	var objective = _active_tutorial.objectives[_active_objective_index]
	if objective.type == TutorialObjective.ObjectiveType.ASSIGN_WORKER and objective.target_def_id == building_instance.def_id:
		print("[TutorialManager] Objective complete: Assigned worker.")
		_advance_objective()
