## PlayerState
## Per-save runtime state for the player/mayor. See docs/DATA_MODEL.md §5.
##
## Phase 1: minimal fields only. Owned lands, active skins, and tutorial
## progress are added once Buildings/Land (Phase 2) and Tutorials (Phase 4)
## exist to give those fields meaning — see docs/IMPLEMENTATION_STATUS.md.
##
## Gold is intentionally NOT stored here. Canonical Gold balance lives in
## InventoryState.resource_amounts[<Gold's ResourceDefinition id>], per the
## Gold-duality resolution in docs/DATA_MODEL.md §5 — read Gold through
## InventoryState, never duplicate it on PlayerState.
class_name PlayerState
extends Resource

@export var mayor_level: int = 0
@export var xp_total: float = 0.0
@export var energy_current: float = 0.0

## MagicBeans has no ResourceDefinition id in the original data (it's a
## premium currency, not a storable resource) — it lives only here.
@export var currency_magic_beans: float = 0.0

## The active buildable grid dimensions (e.g. 48 represents a 48x48 tile region)
@export var active_land_size: int = 48

## The active visual skin theme (e.g. "Vanilla", "Winter")
@export var active_skin: String = "Vanilla"

## The list of unlocked/purchased skin themes
@export var unlocked_skins: Array[String] = ["Vanilla"]

## The player's active profile picture/avatar (e.g. "Mayor", "Woodcutter", "Rose")
@export var profile_avatar: String = "Mayor"
