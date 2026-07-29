# resources/definitions/building_definition.gd
extends Resource
class_name BuildingDefinition

const CostBundle = preload("res://resources/shared/cost_bundle.gd")
const PrerequisiteSet = preload("res://resources/shared/prerequisite_set.gd")

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

## Path to the visual representation in assets/art/converted/
@export var icon_path: String = ""

## e.g. ["Vanilla"], ["Frontier"], or ["All"].
@export var compatible_lands: Array[String] = []

@export var cost: CostBundle = CostBundle.new()

## Same shape as `cost`. Empty (and `sellable = false`) for buildings the
## original never allows selling (e.g. every Town Hall tier).
@export var sell: CostBundle = CostBundle.new()
@export var sellable: bool = true

@export var build_time_seconds: float = 0.0

## Defines the set of prerequisites for this building to be available.
@export var prerequisites: PrerequisiteSet = PrerequisiteSet.new()

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
