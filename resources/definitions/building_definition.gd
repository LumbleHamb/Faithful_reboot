## BuildingDefinition
## Static content schema for one placeable building/decoration. Mirrors the
## original's single overloaded <Object> tag (Objects.xml manifest +
## Vanilla_*/Crossover_*/seasonal XML) — one schema covers town halls, mines,
## shops, storage, market, houses, decorations, etc. via `type` + optional
## fields, matching how the source data itself is structured.
## See docs/GAME_SYSTEMS.md §3/§4 and docs/DATA_MODEL.md §2.
##
## Phase 1: schema only. No .tres instances exist yet in data/buildings/ —
## no gameplay content has been authored (see docs/IMPLEMENTATION_STATUS.md).
##
## Cost/prerequisite fields use plain Dictionary/Array shapes rather than
## dedicated CostBundle/PrerequisiteSet Resource types (docs/DATA_MODEL.md
## §0) — those shared primitives are introduced once a second definition
## type actually needs them, to avoid building shared infrastructure ahead
## of a real second consumer. ProductionRecipe uses the same plain-Dictionary
## convention for the same reason.
class_name BuildingDefinition
extends Resource

## Observed `type=` values across the original's Object XML.
enum BuildingType {
	TOWNHALL, MINE, SHOP, STORE, MARKET, DECORATION, HOUSE,
	RESOURCE_TILE, PRESENT, MISC, SKIN_SWITCH, ENTERTAINER, RIVER,
	HOT_AIR_BALLOON, TREE,
}

## Original Objects id. Must stay stable — cross-referenced by BuildMenu,
## Skins, Tutorials, and land-to-land prerequisite mappings.
@export var id: int = -1

@export var display_name: String = ""
@export var type: BuildingType = BuildingType.MISC

## Optional grouping used for level-up building caps (e.g. "house", "shop").
@export var category: String = ""

@export var width: int = 1
@export var height: int = 1

## One-time XP granted on construction.
@export var xp_value: float = 0.0

## e.g. ["Vanilla"], ["Frontier"], or ["All"].
@export var compatible_lands: Array[String] = []

## { resource_id: int -> amount: float }. Key "magic_beans" is reserved for
## the premium-currency portion of a cost, matching the original's
## <MagicBeans> tag alongside <Resource> costs.
@export var cost: Dictionary = {}

## Same shape as `cost`. Empty (and `sellable = false`) for buildings the
## original never allows selling (e.g. every Town Hall tier).
@export var sell: Dictionary = {}
@export var sellable: bool = true

@export var build_time_seconds: float = 0.0

## Each entry: { "kind": "level"|"building"|"tutorial"|"land_upgrade"|
## "reward_unlockable", "target_id": int, "min_value": int }. All entries
## are ANDed together, matching the original's multiple-<Prerequisite> tags.
@export var prerequisites: Array[Dictionary] = []

## -1 = this building is not an upgrade of anything.
@export var upgrade_of_id: int = -1
## true = can only ever be reached via upgrade, never freshly built.
@export var upgrade_only: bool = false
## -1 = unlimited; otherwise the max number of this building the player may own.
@export var owned_limit: int = -1

## { resource_id: int -> capacity: float (-1 = unlimited) }. Present when
## this building stores resources (Town Hall, Stockpile, Warehouse, ...).
@export var storage_capacities: Dictionary = {}

## -1 = not a MINE-type building. Otherwise the id of this building's single
## ProductionRecipe (kind == GATHER).
@export var gather_recipe_id: int = -1

## Ids of this building's available ProductionRecipes (kind == CRAFT).
## Present for SHOP-type buildings.
@export var shop_recipe_ids: Array[int] = []

@export var info_text: String = ""
@export var description_text: String = ""
