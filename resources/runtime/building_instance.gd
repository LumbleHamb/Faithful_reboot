# resources/runtime/building_instance.gd
extends Resource
class_name BuildingInstance

@export var instance_id: String = ""
@export var def_id: int = -1
@export var land: String = ""
@export var x: int = 0
@export var y: int = 0
@export var flipped: bool = false
@export var construction_started_at: float = -1.0
@export var construction_complete: bool = true
@export var stored_resources: Dictionary = {}
@export var active_recipe_id: int = -1
@export var recipe_started_at: float = -1.0
@export var assigned_worker_ids: Array = [] # Array[String]
@export var assigned_hauler_ids: Array = [] # Array[String]
