## InventoryState
## Per-save resource ledger and storage capacity. See docs/DATA_MODEL.md §6.
##
## Phase 1: schema only, starts empty. Populated on new-game creation once
## ResourceDefinition content and a starting BuildingDefinition/TownLayout
## exist to seed starting amounts and derive capacity from (Phase 2) — see
## docs/IMPLEMENTATION_STATUS.md.
class_name InventoryState
extends Resource

## { resource_id: int -> amount: float }
@export var resource_amounts: Dictionary = {}

## { resource_id: int -> capacity: float (-1 = unlimited) }. Design decision
## (docs/GAME_SYSTEMS.md §6, docs/MISSING_INFORMATION.md #13): SUM of
## StorageDef-equivalent capacities across all owned storage-capable
## buildings, not max. Not computed yet in Phase 1 — no buildings exist.
@export var resource_capacity: Dictionary = {}
