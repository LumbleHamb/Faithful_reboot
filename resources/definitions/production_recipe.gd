## ProductionRecipe
## Static content schema for a resource-production recipe. The original had
## two distinct mechanics, represented here via `kind` on one schema (same
## overloaded-tag pattern as BuildingDefinition):
##
##   GATHER — a MINE-type building's passive/worker/mayor-driven single-output
##            production (Logging Camp, Quarry, Pen, Farm, Gold Panner).
##   CRAFT  — a SHOP-type building's multi-recipe crafting (Items.xml
##            type="shopItem" — e.g. the Baker Shop's Cookies/Tarts/Donuts/...).
##
## See docs/GAME_SYSTEMS.md §2 and docs/DATA_MODEL.md §2/§3.
##
## Phase 1: schema only. No .tres instances exist yet in data/recipes/ — no
## gameplay content has been authored (see docs/IMPLEMENTATION_STATUS.md).
class_name ProductionRecipe
extends Resource

enum RecipeKind { GATHER, CRAFT }

## Original Items.xml id for CRAFT recipes; a synthetic/authoring id for
## GATHER recipes (which have no original standalone id — they're inline
## <Produce> blocks on the building itself).
@export var id: int = -1
@export var kind: RecipeKind = RecipeKind.GATHER
@export var display_name: String = ""

# --- GATHER fields (mine-type buildings) ---

@export var output_resource_id: int = -1
@export var max_output_stack_size: float = 0.0
## Flavor-only job title (e.g. "Wood Cutter", "Quarryman") — not a distinct
## mechanical worker type.
@export var worker_type_label: String = ""
@export var worker_max: int = 1
@export var hauler_max: int = 1
@export var villager_resources_per_hour: float = 0.0
## Direct mayor action yield (energy-gated).
@export var mayor_resources: float = 0.0
## Direct mayor action yield when out of energy. Every sampled original
## value for this is 0 — kept faithful rather than "fixed"; see
## docs/GAME_SYSTEMS.md §2 and docs/MISSING_INFORMATION.md.
@export var mayor_resources_no_energy: float = 0.0

# --- CRAFT fields (shop-type buildings) ---

@export var time_seconds: float = 0.0
## { resource_id: int -> amount: float } consumed to start this recipe.
@export var input_cost: Dictionary = {}
@export var reward_xp: float = 0.0
## { resource_id: int -> amount: float } granted on completion (typically Gold).
@export var reward: Dictionary = {}

# --- Shared ---

@export var hurry_cost: float = 0.0
@export var hurry_interval_seconds: float = 0.0
@export var compatible_lands: Array[String] = []
