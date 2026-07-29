# scripts/ui/building_popup.gd
extends Panel

var building_instance: BuildingInstance

@onready var name_label: Label = $VBoxContainer/BuildingNameLabel
@onready var building_icon: TextureRect = $VBoxContainer/BuildingIcon
@onready var storage_label: Label = $VBoxContainer/StoredResourcesLabel
@onready var workers_label: Label = $VBoxContainer/AssignedWorkersLabel
@onready var assign_worker_button: Button = $VBoxContainer/AssignWorkerButton
@onready var assign_hauler_button: Button = $VBoxContainer/AssignHaulerButton
@onready var close_button: Button = $VBoxContainer/CloseButton

func _ready() -> void:
	assign_worker_button.pressed.connect(_on_assign_worker_pressed)
	assign_hauler_button.pressed.connect(_on_assign_hauler_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	EventBus.building_storage_changed.connect(_on_building_storage_changed)
	EventBus.worker_assigned.connect(_on_worker_or_hauler_assigned)
	EventBus.hauler_assigned.connect(_on_worker_or_hauler_assigned)
	
	hide()

func show_for_building(instance: BuildingInstance) -> void:
	building_instance = instance
	if not building_instance:
		push_error("[BuildingPopup] show_for_building called with null instance.")
		hide()
		return
		
	_update_display()
	show()

func _update_display() -> void:
	if not building_instance or not is_visible():
		return

	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if not building_def:
		push_error("[BuildingPopup] Could not find definition for instance.")
		hide()
		return

	name_label.text = building_def.display_name
	
	# Set building icon
	if building_def.icon_path != "":
		var texture = load(building_def.icon_path)
		if texture:
			building_icon.texture = texture
			building_icon.show()
		else:
			building_icon.hide()
	else:
		building_icon.hide()
	
	var has_gather_recipe = building_def.gather_recipe_id != -1
	if not has_gather_recipe:
		storage_label.hide()
		workers_label.hide()
		assign_worker_button.hide()
		assign_hauler_button.hide()
		return
	
	storage_label.show()
	workers_label.show()
	
	var recipe = DataManager.get_production_recipe(building_def.gather_recipe_id)
	
	# Update storage label
	var output_res_id = recipe.output_resource_id
	var output_res_def = DataManager.get_resource_definition(output_res_id)
	var current_stored = building_instance.stored_resources.get(output_res_id, 0.0)
	storage_label.text = "Storage: %d / %d %s" % [floor(current_stored), recipe.max_output_stack_size, output_res_def.name]
	
	# Update workers label
	var worker_names = _get_villager_names(building_instance.assigned_worker_ids)
	var hauler_names = _get_villager_names(building_instance.assigned_hauler_ids)
	workers_label.text = "Workers (%d/%d): %s\nHaulers (%d/%d): %s" % [
		worker_names.size(), recipe.worker_max, ", ".join(worker_names),
		hauler_names.size(), recipe.hauler_max, ", ".join(hauler_names)
	]

	assign_worker_button.disabled = worker_names.size() >= recipe.worker_max
	assign_hauler_button.disabled = hauler_names.size() >= recipe.hauler_max

func _get_villager_names(villager_ids: Array) -> Array:
	var names = []
	if not SaveManager.current_save: return names
	
	for villager in SaveManager.current_save.villagers:
		if villager.villager_id in villager_ids:
			names.append(villager.villager_name)
	return names

# --- Signal Handlers ---

func _on_assign_worker_pressed() -> void:
	if building_instance:
		WorkerManager.assign_worker(building_instance)

func _on_assign_hauler_pressed() -> void:
	if building_instance:
		WorkerManager.assign_hauler(building_instance)

func _on_close_pressed() -> void:
	hide()

func _on_building_storage_changed(instance_id: String, resource_id: int, new_amount: float) -> void:
	if building_instance and building_instance.instance_id == instance_id:
		_update_display()

func _on_worker_or_hauler_assigned(villager: Villager, instance: BuildingInstance) -> void:
	if building_instance and building_instance.instance_id == instance.instance_id:
		_update_display()
