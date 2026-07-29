## SaveGame
## Top-level save-file container, persisted by SaveManager. See
## docs/DATA_MODEL.md §9 and docs/ARCHITECTURE.md §2.3.
class_name SaveGame
extends Resource

@export var save_version: int = 1
@export var created_at_unix: int = 0
@export var last_saved_at_unix: int = 0

@export var player_state: PlayerState
@export var inventory: InventoryState

@export var town_layouts: Dictionary = {}
@export var villagers: Array[Villager] = []
@export var tutorial_progress: TutorialProgress
