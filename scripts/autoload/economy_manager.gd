# scripts/autoload/economy_manager.gd
# Executes production recipes, handles hauling, and resource consumption/granting.
extends Node

var _active_producers: Dictionary = {} # { instance_id: BuildingInstance }
var _haul_tasks: Dictionary = {} # { instance_id: BuildingInstance }

func _ready() -> void:
	EventBus.worker_assigned.connect(_on_worker_assigned)
	EventBus.hauler_assigned.connect(_on_hauler_assigned)

func _process(delta: float) -> void:
	_process_producers(delta)
	_process_haulers(delta)

func _process_producers(delta: float) -> void:
	if _active_producers.is_empty():
		return

	for instance_id in _active_producers.keys():
		var instance = _active_producers[instance_id]
		var building_def = DataManager.get_building_definition(instance.def_id)
		var recipe = DataManager.get_production_recipe(building_def.gather_recipe_id)
		
		var output_res_id = recipe.output_resource_id
		var current_stored = instance.stored_resources.get(output_res_id, 0.0)
		
		if current_stored >= recipe.max_output_stack_size:
			_active_producers.erase(instance_id)
			print("[EconomyManager] %s internal storage is full. Pausing production." % building_def.display_name)
			continue
			
		var total_worker_efficiency = 0.0
		for worker_id in instance.assigned_worker_ids:
			var villager = _find_villager_by_id(worker_id)
			if villager:
				if villager.is_hungry:
					total_worker_efficiency += 0.0 # Hungry workers do not produce
				elif villager.is_homeless:
					total_worker_efficiency += 0.5 # Homelessness halves efficiency
				else:
					total_worker_efficiency += 1.0 # Standard efficiency
			else:
				total_worker_efficiency += 1.0

		var total_rate_per_hour = recipe.villager_resources_per_hour * total_worker_efficiency
		var production_this_frame = delta * (total_rate_per_hour / 3600.0)
		var new_stored_amount = min(current_stored + production_this_frame, recipe.max_output_stack_size)
		
		instance.stored_resources[output_res_id] = new_stored_amount
		EventBus.building_storage_changed.emit(instance_id, output_res_id, new_stored_amount)

func _process_haulers(delta: float) -> void:
	if _haul_tasks.is_empty():
		return
	
	for instance_id in _haul_tasks.keys():
		var instance = _haul_tasks[instance_id]
		if instance.stored_resources.is_empty():
			continue

		# Instant transfer for Phase 3
		for res_id in instance.stored_resources.keys():
			var amount_to_haul = instance.stored_resources[res_id]
			if amount_to_haul > 0:
				var amount_hauled = InventoryManager.add(res_id, amount_to_haul)
				instance.stored_resources[res_id] -= amount_hauled
				EventBus.building_storage_changed.emit(instance_id, res_id, instance.stored_resources[res_id])
				
				if amount_hauled > 0:
					print("[EconomyManager] Hauled %f of resource %d from %s" % [amount_hauled, res_id, instance.instance_id])
					var res_def = DataManager.get_resource_definition(res_id)
					var res_name = res_def.name if res_def else "Resource"
					var color = Color.GOLD if res_id == 1 else (Color.YELLOW if res_id == 40 else Color.SPRING_GREEN)
					
					var world_pos = Vector2(instance.x * 64 + 32, instance.y * 64 + 16)
					EventBus.spawn_floating_text.emit("+%d %s" % [floor(amount_hauled), res_name], world_pos, color)
				
				# If storage was full and is now not, resume production
				var was_paused = not _active_producers.has(instance.instance_id)
				if was_paused and instance.assigned_worker_ids.size() > 0:
					_start_production(instance)


func _on_worker_assigned(villager: Villager, building_instance: BuildingInstance) -> void:
	_start_production(building_instance)

func _on_hauler_assigned(villager: Villager, building_instance: BuildingInstance) -> void:
	if not _haul_tasks.has(building_instance.instance_id):
		_haul_tasks[building_instance.instance_id] = building_instance
		print("[EconomyManager] Hauler assigned to %s. Ready to haul." % building_instance.instance_id)

func _start_production(building_instance: BuildingInstance) -> void:
	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if building_def and building_def.gather_recipe_id != -1:
		if not _active_producers.has(building_instance.instance_id):
			_active_producers[building_instance.instance_id] = building_instance
			building_instance.recipe_started_at = TimeManager.now()
			print("[EconomyManager] Production started for %s." % building_def.display_name)


func can_afford(cost_bundle: CostBundle) -> bool:
	if not cost_bundle: return true
	for entry in cost_bundle.entries:
		if InventoryManager.amount(entry.resource_id) < entry.amount:
			return false
	return true


func apply_cost(cost_bundle: CostBundle) -> void:
	if not cost_bundle: return
	if not can_afford(cost_bundle):
		push_warning("[EconomyManager] apply_cost called for a cost that cannot be afforded.")
		return
		
	for entry in cost_bundle.entries:
		InventoryManager.remove(entry.resource_id, entry.amount)


func grant_reward(reward) -> void: print("[EconomyManager] Granting reward (TODO)")

func _find_villager_by_id(id: String) -> Villager:
	if not SaveManager.current_save: return null
	for v in SaveManager.current_save.villagers:
		if v.villager_id == id:
			return v
	return null
