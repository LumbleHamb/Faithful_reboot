# scripts/autoload/inventory_manager.gd
# Manages the player's inventory, including resource amounts and storage capacity.
# See docs/ARCHITECTURE.md §2.9
extends Node

# --- Public API ---

## Returns the current amount of a given resource.
func amount(resource_id: int) -> float:
	var inventory = _get_inventory()
	if inventory:
		return inventory.resource_amounts.get(resource_id, 0.0)
	return 0.0

## Returns the total storage capacity for a given resource.
func capacity(resource_id: int) -> float:
	var inventory = _get_inventory()
	if inventory:
		# Gold is a special case with effectively unlimited capacity.
		if resource_id == 1: # Assuming 1 is the ID for Gold
			return INF
		return inventory.resource_capacity.get(resource_id, 0.0)
	return 0.0

## Returns the remaining free space for a given resource.
func free_space(resource_id: int) -> float:
	return capacity(resource_id) - amount(resource_id)

## Checks if a quantity of a resource can be added to the inventory.
func can_add(resource_id: int, qty: float) -> bool:
	return free_space(resource_id) >= qty

## Adds a quantity of a resource to the inventory.
## Returns the actual amount added, which may be less than qty if capacity is limited.
func add(resource_id: int, qty: float) -> float:
	var inventory = _get_inventory()
	if not inventory:
		return 0.0

	var can_add_amount = min(qty, free_space(resource_id))
	if can_add_amount > 0:
		var current_amount = inventory.resource_amounts.get(resource_id, 0.0)
		inventory.resource_amounts[resource_id] = current_amount + can_add_amount
		EventBus.resource_changed.emit(resource_id, inventory.resource_amounts[resource_id])
	
	return can_add_amount

## Removes a quantity of a resource from the inventory.
## Returns true if the removal was successful, false otherwise.
func remove(resource_id: int, qty: float) -> bool:
	var inventory = _get_inventory()
	if not inventory:
		return false

	var current_amount = inventory.resource_amounts.get(resource_id, 0.0)
	if current_amount >= qty:
		inventory.resource_amounts[resource_id] = current_amount - qty
		EventBus.resource_changed.emit(resource_id, inventory.resource_amounts[resource_id])
		return true
	
	return false

## Recalculates the total capacity for all resources based on owned buildings.
func recalculate_capacity() -> void:
	var inventory = _get_inventory()
	if not inventory:
		return

	inventory.resource_capacity.clear()
	
	# TODO: This needs BuildingManager to be implemented to get all placed buildings.
	# var all_buildings = BuildingManager.get_all_instances()
	# for building_instance in all_buildings:
	# 	var building_def = DataManager.get_building_definition(building_instance.def_id)
	# 	if building_def and building_def.storage:
	# 		for res_id in building_def.storage.capacities:
	# 			var current_cap = inventory.resource_capacity.get(res_id, 0.0)
	# 			var building_cap = building_def.storage.capacities[res_id]
	# 			if building_cap == -1: # Unlimited
	# 				inventory.resource_capacity[res_id] = INF
	# 			elif not is_inf(inventory.resource_capacity.get(res_id, 0.0)):
	# 				inventory.resource_capacity[res_id] = current_cap + building_cap

	print("[InventoryManager] Capacity recalculation logic is a TODO.")


# --- Private Helpers ---

func _get_inventory():
	if SaveManager and SaveManager.current_save:
		return SaveManager.current_save.inventory
	push_warning("[InventoryManager] Could not get inventory from SaveManager.")
	return null
