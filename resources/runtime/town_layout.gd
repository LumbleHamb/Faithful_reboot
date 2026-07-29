# resources/runtime/town_layout.gd
extends Resource
class_name TownLayout

@export var land: String = ""
@export var resource_tiles: Array = [] # Array[BuildingInstance]
@export var starting_objects: Array = [] # Array[BuildingInstance]
