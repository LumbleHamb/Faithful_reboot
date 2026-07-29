# scripts/autoload/worker_manager.gd
# Manages villager population, job assignment, and simulation.
extends Node

## Assigns the first available idle villager to the given building instance as a WORKER.
func assign_worker(building_instance: BuildingInstance) -> bool:
	if not building_instance:
		push_warning("[WorkerManager] assign_worker called with null instance.")
		return false
	
	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if not building_def or building_def.gather_recipe_id == -1:
		print("[WorkerManager] Cannot assign worker to building without a gather recipe.")
		return false
		
	var recipe = DataManager.get_production_recipe(building_def.gather_recipe_id)
	if not recipe:
		push_error("[WorkerManager] Could not find recipe with ID %d" % building_def.gather_recipe_id)
		return false

	# Check if there is an open worker slot
	if building_instance.assigned_worker_ids.size() >= recipe.worker_max:
		print("[WorkerManager] No vacant worker slots in %s" % building_def.display_name)
		return false
		
	var idle_villager = _find_idle_villager()
	if not idle_villager:
		print("[WorkerManager] No idle villagers available.")
		return false
		
	# Assign the villager
	idle_villager.role = Villager.Role.WORKER
	idle_villager.assigned_building_instance_id = building_instance.instance_id
	building_instance.assigned_worker_ids.append(idle_villager.villager_id)
	
	print("[WorkerManager] Assigned %s to %s as a Worker." % [idle_villager.villager_name, building_def.display_name])
	
	EventBus.worker_assigned.emit(idle_villager, building_instance)
	return true

## Assigns the first available idle villager to the given building instance as a HAULER.
func assign_hauler(building_instance: BuildingInstance) -> bool:
	if not building_instance:
		push_warning("[WorkerManager] assign_hauler called with null instance.")
		return false
	
	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if not building_def or building_def.gather_recipe_id == -1:
		print("[WorkerManager] Cannot assign hauler to building without a gather recipe.")
		return false
		
	var recipe = DataManager.get_production_recipe(building_def.gather_recipe_id)
	if not recipe:
		push_error("[WorkerManager] Could not find recipe with ID %d" % building_def.gather_recipe_id)
		return false

	# Check if there is an open hauler slot
	if building_instance.assigned_hauler_ids.size() >= recipe.hauler_max:
		print("[WorkerManager] No vacant hauler slots in %s" % building_def.display_name)
		return false
		
	var idle_villager = _find_idle_villager()
	if not idle_villager:
		print("[WorkerManager] No idle villagers available.")
		return false
		
	# Assign the villager
	idle_villager.role = Villager.Role.HAULER
	idle_villager.assigned_building_instance_id = building_instance.instance_id
	building_instance.assigned_hauler_ids.append(idle_villager.villager_id)
	
	print("[WorkerManager] Assigned %s to %s as a Hauler." % [idle_villager.villager_name, building_def.display_name])
	
	EventBus.hauler_assigned.emit(idle_villager, building_instance)
	return true


func _find_idle_villager() -> Villager:
	if not SaveManager.current_save:
		return null
		
	for villager in SaveManager.current_save.villagers:
		if villager.role == Villager.Role.UNASSIGNED:
			return villager
	return null

# --- Placeholder Functions from Architecture ---

func total_population() -> int:
	if SaveManager.current_save:
		return SaveManager.current_save.villagers.size()
	return 0

func housing_capacity() -> int:
	# TODO: Implement by summing capacity from all owned houses
	return 0

func idle_villagers() -> Array:
	var idle = []
	if SaveManager.current_save:
		for villager in SaveManager.current_save.villagers:
			if villager.role == Villager.Role.UNASSIGNED:
				idle.append(villager)
	return idle

func unassign(villager_id: String) -> void:
	print("[WorkerManager] Unassigning villager %s (TODO)" % villager_id)

func adopt_villager() -> bool:
	print("[WorkerManager] Adopting a new villager (TODO)")
	return true
