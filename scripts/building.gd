# scripts/building.gd
extends Node2D

var building_instance: BuildingInstance
var _harvest_bubble: Panel = null

@onready var color_rect: ColorRect = $ColorRect
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	area_2d.input_event.connect(_on_input_event)
	_create_harvest_bubble()

func _create_harvest_bubble() -> void:
	_harvest_bubble = Panel.new()
	_harvest_bubble.name = "HarvestBubble"
	_harvest_bubble.custom_minimum_size = Vector2(40, 40)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.84, 0.0, 0.95) # Gold
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	_harvest_bubble.add_theme_stylebox_override("panel", sb)
	
	var label = Label.new()
	label.text = "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 22)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	_harvest_bubble.add_child(label)
	add_child(_harvest_bubble)
	_harvest_bubble.visible = false

func _process(delta: float) -> void:
	if not building_instance:
		return
		
	# Check if building has any stored resources to display the harvest bubble
	var has_stored = false
	for res_id in building_instance.stored_resources.keys():
		if building_instance.stored_resources[res_id] >= 1.0:
			has_stored = true
			break
			
	if has_stored and building_instance.construction_complete:
		_harvest_bubble.visible = true
		var tile_size = 64
		var building_def = DataManager.get_building_definition(building_instance.def_id)
		var width = building_def.width if building_def else 1
		var height = building_def.height if building_def else 1
		var building_size = Vector2(width * tile_size, height * tile_size)
		
		var target_pos = Vector2(building_size.x / 2 - 20, -32)
		# Gentle bouncing animation
		target_pos.y += sin(Time.get_ticks_msec() / 150.0) * 6.0
		_harvest_bubble.position = target_pos
	else:
		_harvest_bubble.visible = false

func set_building(instance: BuildingInstance):
	# Resolve child nodes on-demand in case set_building is called before add_child
	if not color_rect: color_rect = $ColorRect
	if not sprite_2d: sprite_2d = $Sprite2D
	if not area_2d: area_2d = $Area2D
	if not collision_shape: collision_shape = $Area2D/CollisionShape2D

	building_instance = instance
	var building_def = DataManager.get_building_definition(instance.def_id)
	if not building_def:
		push_error("Invalid BuildingInstance passed to set_building: def_id %d not found." % instance.def_id)
		return

	name = building_def.display_name

	var tile_size = 64 # Assuming TILE_SIZE from main.gd
	var building_size = Vector2(building_def.width * tile_size, building_def.height * tile_size)

	# Configure visuals
	color_rect.size = building_size
	
	# Configure collision shape for clicks
	var shape = RectangleShape2D.new()
	shape.size = building_size
	collision_shape.shape = shape
	# The collision shape should be centered on the building's visual
	collision_shape.position = building_size / 2

	# Set color based on building type for visual distinction (default footprint colors)
	match building_def.type:
		BuildingDefinition.BuildingType.TOWNHALL:
			color_rect.color = Color(1.0, 0.84, 0.0, 0.25)
		BuildingDefinition.BuildingType.MINE:
			color_rect.color = Color(0.55, 0.27, 0.07, 0.25)
		BuildingDefinition.BuildingType.HOUSE:
			color_rect.color = Color(0.25, 0.41, 0.88, 0.25)
		_:
			color_rect.color = Color(0.3, 0.3, 0.3, 0.25)

	# Try to load and apply real art asset texture
	if building_def.icon_path != "":
		var texture = load(building_def.icon_path)
		if texture:
			sprite_2d.texture = texture
			# Center the sprite on the building footprint
			sprite_2d.position = building_size / 2
			sprite_2d.visible = true
		else:
			push_warning("[Building] Failed to load icon texture: %s" % building_def.icon_path)
			sprite_2d.visible = false
			color_rect.color.a = 1.0
	else:
		sprite_2d.visible = false
		color_rect.color.a = 1.0

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[Building] Clicked on: %s" % name)
		EventBus.building_instance_selected.emit(building_instance)
		get_viewport().set_input_as_handled()
