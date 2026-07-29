# resources/shared/prerequisite_set.gd
extends Resource
class_name PrerequisiteSet

@export var all_of: Array[PrerequisiteEntry] = []
@export var one_of: Array[PrerequisiteEntry] = [] # (not in original, but useful for OR logic)
