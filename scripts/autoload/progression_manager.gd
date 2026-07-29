# scripts/autoload/progression_manager.gd
# Manages player XP and Level progression.
extends Node

# XP required to advance to the *next* level.
# e.g., XP_THRESHOLDS[1] is the XP needed to go from level 1 to 2.
const XP_THRESHOLDS = {
	1: 100,
	2: 250,
	3: 500,
	4: 800,
	5: 1500,
	6: 2600, # From video analysis
	7: 3400, # From video analysis
	# ... to be continued
}

func _ready() -> void:
	# Connect to events that grant XP
	EventBus.building_placed.connect(_on_building_placed)
	# EventBus.recipe_completed.connect(_on_recipe_completed) # Example for later

func add_xp(amount: float) -> void:
	var player_state = SaveManager.current_save.player_state
	if not player_state:
		return

	player_state.xp_total += amount
	print("[ProgressionManager] Granted %d XP. New total: %d" % [amount, player_state.xp_total])
	
	EventBus.xp_changed.emit(player_state.xp_total)
	_check_for_level_up()

func _check_for_level_up() -> void:
	var player_state = SaveManager.current_save.player_state
	if not player_state:
		return
	
	var xp_for_next_level = XP_THRESHOLDS.get(player_state.mayor_level, INF)
	
	while player_state.xp_total >= xp_for_next_level:
		player_state.mayor_level += 1
		player_state.xp_total -= xp_for_next_level
		print("[ProgressionManager] LEVEL UP! Reached level %d." % player_state.mayor_level)
		
		EventBus.level_up.emit(player_state.mayor_level)
		EventBus.xp_changed.emit(player_state.xp_total)
		
		# Get the threshold for the new level
		xp_for_next_level = XP_THRESHOLDS.get(player_state.mayor_level, INF)

# --- Signal Handlers for XP Grants ---

func _on_building_placed(building_instance: BuildingInstance) -> void:
	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if building_def and building_def.xp_value > 0:
		add_xp(building_def.xp_value)
