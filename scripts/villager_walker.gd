# scripts/villager_walker.gd
extends Node2D
class_name VillagerWalker

## VillagerWalker (presentation)
## Spawns a cute 2D villager walker on the map grid that physically walks 
## back and forth between their cottage (home) and workplace, executing 
## animations and displaying job-role tags.

var villager_id: String = ""
var role: int = 0 # 1: WORKER, 2: HAULER
var home_pos: Vector2
var work_pos: Vector2
var target_pos: Vector2

var speed: float = 75.0
var state: int = 0 # 0: walking to work, 1: working, 2: walking home, 3: resting

var _sprite: Sprite2D
var _label: Label
var _work_timer: float = 0.0

func _ready() -> void:
	# Create sprite dynamically
	_sprite = Sprite2D.new()
	# Load default worker icon
	var tex = load("res://assets/art/converted/WOODICON.png")
	if not tex:
		tex = load("res://assets/art/converted/WIZARD_20.png")
	if tex:
		_sprite.texture = tex
		_sprite.scale = Vector2(0.5, 0.5)
	add_child(_sprite)
	
	# Create nametag above head
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(-40, -32)
	_label.custom_minimum_size = Vector2(80, 20)
	add_child(_label)
	
	position = home_pos
	target_pos = work_pos

func configure(id: String, v_name: String, v_role: int, home: Vector2, work: Vector2) -> void:
	villager_id = id
	role = v_role
	home_pos = home
	work_pos = work
	
	_label.text = v_name
	if role == 1: # WORKER
		_label.add_theme_color_override("font_color", Color.SKY_BLUE)
	else: # HAULER
		_label.add_theme_color_override("font_color", Color.ORANGE)

func _process(delta: float) -> void:
	match state:
		0: # Walking to work
			position = position.move_toward(target_pos, speed * delta)
			if position.distance_to(target_pos) < 5.0:
				state = 1
				_work_timer = randf_range(3.0, 6.0) # Work/chop for 3-6 seconds
		1: # Working animation
			_work_timer -= delta
			# Pulse scale gently to simulate work motion
			_sprite.scale = Vector2(0.5, 0.5) * (1.0 + sin(Time.get_ticks_msec() / 100.0) * 0.15)
			if _work_timer <= 0.0:
				_sprite.scale = Vector2(0.5, 0.5)
				state = 2
				target_pos = home_pos
		2: # Walking home
			position = position.move_toward(target_pos, speed * delta)
			if position.distance_to(target_pos) < 5.0:
				state = 3
				_work_timer = randf_range(2.0, 4.0) # Rest at home for 2-4 seconds
		3: # Resting at home
			if _work_timer > 0.0:
				_work_timer -= delta
			else:
				state = 0
				target_pos = work_pos
