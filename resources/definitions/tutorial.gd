# resources/definitions/tutorial.gd
# Defines a complete tutorial, consisting of a series of objectives.
class_name Tutorial
extends Resource

@export var id: int = -1
@export var title: String = ""
@export var objectives: Array[TutorialObjective] = []
