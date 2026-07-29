# resources/definitions/tutorial_objective.gd
# Defines a single objective within a tutorial.
class_name TutorialObjective
extends Resource

enum ObjectiveType {
	BUILD,          # Build a specific type of building.
	ASSIGN_WORKER,  # Assign a worker to a specific type of building.
	ASSIGN_HAULER,  # Assign a hauler to a specific type of building.
	COLLECT,        # Manually collect resources (not yet implemented).
	HURRY,          # Use the 'hurry' mechanic (not yet implemented).
}

@export var type: ObjectiveType
@export var text: String = "" # e.g., "Build a Small Cottage"
@export var target_def_id: int = -1 # e.g., the BuildingDefinition ID for Small Cottage
@export var quantity: int = 1
