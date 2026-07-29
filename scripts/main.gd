## Main
## Root scene script. Orchestrates the main game view, including UI and building placement.
extends Node

const BuildingScene = preload("res://scenes/building.tscn")
const BuildingInstance = preload("res://resources/runtime/building_instance.gd")
const BuildingDefinition = preload("res://resources/definitions/building_definition.gd")
const TransientMessageScene = preload("res://scenes/ui/transient_message.tscn")

const TILE_SIZE = 64

# --- State ---
var _placement_mode_active: bool = false
var _building_to_place_def: BuildingDefinition = null
var _ghost_building: Node2D = null
var _occupied_coords: Dictionary = {} # Key: Vector2i, Value: bool
var _next_instance_id: int = 1

# --- Scene Refs ---
@onready var world_container = $WorldContainer
@onready var build_menu = $UILayer/BuildMenu
@onready var building_popup = $UILayer/BuildingPopup
@onready var tutorial_popup = $UILayer/TutorialPopup


func _ready() -> void:
	print("[Main] Scene ready. GameManager state = %s" % GameManager.State.keys()[GameManager.current_state])
	TutorialManager.set_tutorial_popup(tutorial_popup)
	
	EventBus.building_selected_for_placement.connect(_on_building_selected_for_placement)
	EventBus.building_instance_selected.connect(_on_building_instance_selected)
	EventBus.spawn_floating_text.connect(_on_spawn_floating_text)

	_initialize_world_layout()


func _input(event: InputEvent) -> void:
	if not _placement_mode_active:
		return

	if event is InputEventMouseMotion:
		_update_ghost_position()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_placement()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_placement()
		elif event.keycode == KEY_R:
			if _ghost_building:
				_ghost_building.rotation_degrees = fmod(_ghost_building.rotation_degrees + 90, 360)
				_check_placement_validity()


# --- Private Methods ---

func _initialize_world_layout() -> void:
	if not SaveManager.current_save:
		# This can happen if game is run directly from Main.tscn
		# For development, we can create a new save here.
		print("[Main] No current save found. Creating a new one for this session.")
		GameManager.start_new_game()
		if not SaveManager.current_save:
			push_error("[Main] Failed to create a new save. World cannot be initialized.")
			return

	var layout = SaveManager.current_save.town_layouts.get("Vanilla")
	if not layout:
		push_error("[Main] No 'Vanilla' layout found in save file.")
		return

	# Load initial buildings from the save file
	for instance in layout.starting_objects:
		_create_building_node(instance)
		var grid_pos = Vector2i(instance.x, instance.y)
		var building_def = DataManager.get_building_definition(instance.def_id)
		if building_def:
			_add_building_to_occupied_grid(grid_pos, building_def, instance.rotation_degrees)
		
		# Ensure instance IDs are unique
		var id_num = instance.instance_id.to_int()
		if id_num >= _next_instance_id:
			_next_instance_id = id_num + 1


func _on_building_selected_for_placement(building_def: BuildingDefinition) -> void:
	if _placement_mode_active:
		_cancel_placement()

	if not EconomyManager.can_afford(building_def.cost):
		var msg = TransientMessageScene.instantiate()
		msg.text = "Not enough resources!"
		$UILayer.add_child(msg)
		return

	print("[Main] Entering placement mode for: %s" % building_def.display_name)
	_building_to_place_def = building_def
	if _building_to_place_def:
		_ghost_building = BuildingScene.instantiate()
		world_container.add_child(_ghost_building)
		var temp_instance = BuildingInstance.new()
		temp_instance.def_id = building_def.id
		_ghost_building.set_building(temp_instance)
		_ghost_building.modulate = Color(1, 1, 1, 0.5)
		_placement_mode_active = true
		_update_ghost_position()

func _update_ghost_position() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var world_pos = world_container.get_global_transform().affine_inverse().xform(mouse_pos)

	var grid_x = floor(world_pos.x / TILE_SIZE)
	var grid_y = floor(world_pos.y / TILE_SIZE)
	_ghost_building.position = Vector2(grid_x * TILE_SIZE, grid_y * TILE_SIZE)
	_check_placement_validity()

func _check_placement_validity() -> bool:
	if not _ghost_building: return false

	var grid_pos = Vector2i(_ghost_building.position / TILE_SIZE)
	var building_def = _building_to_place_def
	
	var width = building_def.width
	var height = building_def.height
	if fmod(_ghost_building.rotation_degrees, 180) != 0:
		width = building_def.height
		height = building_def.width

	var land_size = 48
	if SaveManager.current_save and SaveManager.current_save.player_state:
		land_size = SaveManager.current_save.player_state.active_land_size

	for x in range(width):
		for y in range(height):
			var cell_to_check = grid_pos + Vector2i(x, y)
			# Boundary limits check
			if cell_to_check.x < 0 or cell_to_check.y < 0 or cell_to_check.x >= land_size or cell_to_check.y >= land_size:
				_ghost_building.modulate = Color(1.0, 0.5, 0.5, 0.7)
				return false
			# Overlapping checks
			if _occupied_coords.has(cell_to_check):
				_ghost_building.modulate = Color(1.0, 0.5, 0.5, 0.7)
				return false
	
	_ghost_building.modulate = Color(0.5, 1.0, 0.5, 0.7)
	return true

func _place_building() -> void:
	if _placement_mode_active and _check_placement_validity():
		if _building_to_place_def:
			var grid_pos = Vector2i(_ghost_building.position / TILE_SIZE)
			
			var new_instance = BuildingInstance.new()
			new_instance.instance_id = str(_next_instance_id)
			_next_instance_id += 1
			new_instance.def_id = _building_to_place_def.id
			new_instance.x = grid_pos.x
			new_instance.y = grid_pos.y
			new_instance.rotation_degrees = _ghost_building.rotation_degrees
			
			SaveManager.current_save.town_layouts["Vanilla"].starting_objects.append(new_instance)
			
			_create_building_node(new_instance)
			
			_add_building_to_occupied_grid(grid_pos, _building_to_place_def, new_instance.rotation_degrees)
			
			EconomyManager.apply_cost(_building_to_place_def.cost)
			
			print("[Main] Placed building: %s (ID: %s)" % [_building_to_place_def.display_name, new_instance.instance_id])
			
			EventBus.building_placed.emit(new_instance)
			_cancel_placement()

func _create_building_node(instance: BuildingInstance) -> void:
	var building_node = BuildingScene.instantiate()
	building_node.position = Vector2(instance.x * TILE_SIZE, instance.y * TILE_SIZE)
	building_node.rotation_degrees = instance.rotation_degrees
	world_container.add_child(building_node)
	building_node.set_building(instance)

func _cancel_placement() -> void:
	if _ghost_building:
		_ghost_building.queue_free()
	_ghost_building = null
	_placement_mode_active = false
	_building_to_place_def = null

func _add_building_to_occupied_grid(grid_pos: Vector2i, building_def: BuildingDefinition, rotation_degrees: float = 0.0) -> void:
	var width = building_def.width
	var height = building_def.height
	if fmod(rotation_degrees, 180) != 0:
		width = building_def.height
		height = building_def.width
		
	for x in range(width):
		for y in range(height):
			_occupied_coords[grid_pos + Vector2i(x, y)] = true

# --- Signal Handlers ---

func _on_toggle_build_menu_pressed() -> void:
	build_menu.visible = not build_menu.visible
	if build_menu.visible:
		build_menu.populate_build_menu()

func _on_building_instance_selected(instance: BuildingInstance) -> void:
	building_popup.show_for_building(instance)

func _on_spawn_floating_text(text: String, global_pos: Vector2, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = global_pos
	
	# Add beautiful contrast outlining so the numbers are highly visible over grass/terrain
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 20)
	
	world_container.add_child(label)
	
	# Animate float & fade cleanly using Godot 4.7 tweens
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", global_pos.y - 65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(label.queue_free)

