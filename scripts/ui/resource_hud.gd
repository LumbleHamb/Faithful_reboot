# scripts/ui/resource_hud.gd
extends Panel

@onready var gold_label: Label = $HBoxContainer/GoldLabel
@onready var wood_label: Label = $HBoxContainer/WoodLabel
@onready var wheat_label: Label = $HBoxContainer/WheatLabel
@onready var level_label: Label = $HBoxContainer/LevelLabel
@onready var xp_label: Label = $HBoxContainer/XPLabel

# Map resource IDs to their UI labels
var _resource_labels: Dictionary = {}

func _ready() -> void:
	# Resource IDs are defined in their .tres files
	# Gold = 1, Wood = 10, Wheat = 40
	_resource_labels[1] = gold_label
	_resource_labels[10] = wood_label
	_resource_labels[40] = wheat_label
	
	_initialize_display()
	
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.level_up.connect(_on_level_up)
	EventBus.xp_changed.connect(_on_xp_changed)

func _initialize_display() -> void:
	# Init resource labels
	for res_id in _resource_labels:
		var amount = InventoryManager.amount(res_id)
		_update_label(res_id, amount)
		
	# Init progression labels
	if SaveManager.current_save and SaveManager.current_save.player_state:
		var player_state = SaveManager.current_save.player_state
		_on_level_up(player_state.mayor_level)
		_on_xp_changed(player_state.xp_total)

func _on_resource_changed(resource_id: int, new_amount: float) -> void:
	_update_label(resource_id, new_amount)

func _update_label(resource_id: int, amount: float) -> void:
	if _resource_labels.has(resource_id):
		var label = _resource_labels[resource_id]
		var resource_def = DataManager.get_resource_definition(resource_id)
		if resource_def:
			label.text = "%s: %d" % [resource_def.name, floor(amount)]

func _on_level_up(new_level: int) -> void:
	level_label.text = "Level: %d" % new_level
	# Also update XP label since the threshold changes
	if SaveManager.current_save and SaveManager.current_save.player_state:
		_on_xp_changed(SaveManager.current_save.player_state.xp_total)

func _on_xp_changed(new_xp: float) -> void:
	if SaveManager.current_save and SaveManager.current_save.player_state:
		var current_level = SaveManager.current_save.player_state.mayor_level
		var xp_for_next_level = ProgressionManager.XP_THRESHOLDS.get(current_level, INF)
		xp_label.text = "XP: %d/%s" % [floor(new_xp), str(xp_for_next_level) if xp_for_next_level != INF else "---"]
