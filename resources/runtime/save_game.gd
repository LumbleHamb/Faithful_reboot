## SaveGame
## Top-level save-file container, persisted by SaveManager. See
## docs/DATA_MODEL.md §9 and docs/ARCHITECTURE.md §2.3.
##
## Phase 1: player_state + inventory only. `world_state` is a reserved,
## empty placeholder for Phase 2's town layouts / BuildingInstance /
## Villager data — deliberately NOT schematized yet, since no
## BuildingDefinition content or BuildingSystem exists to populate it. This
## keeps the save FORMAT stable (the slot exists) without building runtime
## schemas ahead of the systems that would use them — see
## docs/IMPLEMENTATION_STATUS.md.
class_name SaveGame
extends Resource

@export var save_version: int = 1
@export var created_at_unix: int = 0
@export var last_saved_at_unix: int = 0

@export var player_state: PlayerState
@export var inventory: InventoryState

## Reserved for Phase 2 (town_layouts, building instances, villagers).
@export var world_state: Dictionary = {}
