# scripts/building.gd
extends Node2D

var building_instance: BuildingInstance

@onready var color_rect: ColorRect = $ColorRect
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	area_2d.input_event.connect(_on_input_event)

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
