# EventBus (scripts/autoload/event_bus.gd)
# A global singleton for decoupled inter-system communication.
# Managers and UI elements emit signals here, and other systems listen for them
# without needing direct references.

extends Node

# Emitted when a user selects a building from the build menu, requesting to place it.
# The main game logic will listen for this to enter "placement mode".
# - building_def: The BuildingDefinition resource of the selected building.
signal building_selected_for_placement(building_def)

# Emitted when a player clicks on a building in the world.
# - building_instance: The BuildingInstance data for the selected building.
signal building_instance_selected(building_instance)

# Emitted after a building has been successfully placed in the world.
# - building_instance: The BuildingInstance of the newly placed building.
signal building_placed(building_instance)

# Emitted when a worker is assigned to a building.
# - villager: The Villager who was assigned.
# - building_instance: The BuildingInstance they were assigned to.
signal worker_assigned(villager, building_instance)

# Emitted when a hauler is assigned to a building.
# - villager: The Villager who was assigned as a hauler.
# - building_instance: The BuildingInstance they were assigned to.
signal hauler_assigned(villager, building_instance)

# Emitted when a building's internal storage changes.
# - building_instance_id: The ID of the building whose storage changed.
# - resource_id: The ID of the resource that changed.
# - new_amount: The new amount of the resource in storage.
signal building_storage_changed(building_instance_id, resource_id, new_amount)

# Emitted when the amount of any resource or currency changes.
# The UI listens to this to update the resource display.
# - resource_id: The ID of the resource or currency that changed.
# - new_amount: The new total amount.
signal resource_changed(resource_id, new_amount)

# Emitted when a recipe (gather or craft) is completed.
# - building_instance_id: The ID of the building where the recipe finished.
# - recipe_id: The ID of the completed recipe.
# - reward: The CostBundle resource representing the rewards.
signal recipe_completed(building_instance_id, recipe_id, reward)

# Emitted when the player levels up.
# - new_level: The new level the player has reached.
signal level_up(new_level)

# Emitted when the player's total XP changes.
# - new_xp_total: The new total XP amount.
signal xp_changed(new_xp_total)

# Emitted to spawn visual floating text above buildings or coordinates
# - text: The string to show (e.g. "+5 Wood")
# - global_position: Where to spawn the floating text in 2D space
# - color: The visual color of the text
signal spawn_floating_text(text: String, global_position: Vector2, color: Color)
