## TutorialDefinition
## Static content schema for one tutorial step. Mirrors Tutorials.xml's
## <Tutorial> schema — trigger, objectives, reward, and the town-wide
## feature-lock/allow-exception vocabulary. See docs/GAME_SYSTEMS.md §11
## and docs/DATA_MODEL.md §8 (TutorialDef/TutorialObjective/TutorialLock,
## consolidated here into one class the same way Phase 1 consolidated
## GatherRecipe/CraftRecipe into one ProductionRecipe).
##
## New this phase (Phase 2) — Phase 1 only built the four content-definition
## schemas explicitly requested then (Resource/Building/ProductionRecipe/
## WorkerDefinition); Tutorials is one of the four databases requested for
## Phase 2, so its schema is added now.
##
## Objectives/prerequisites/lock use plain Dictionary/Array shapes, matching
## the same "defer shared primitives" decision from
## docs/IMPLEMENTATION_STATUS.md #5 — CostBundle/PrerequisiteSet still
## aren't built, and a Tutorial's "cost" is really always a Reward, never a
## Cost, so it doesn't add a new consumer of that decision either way.
class_name TutorialDefinition
extends Resource

enum TriggerType { ALWAYS, BUILD, SELECT }

## 13-verb vocabulary from Tutorials.xml <Objective> tags.
enum ObjectiveType {
	BUILD, ASSIGN, COLLECT, GATHER, TRANSPORT, USE_SHOP,
	MARKET_BUY, MARKET_SELL, LAND_SIZE, MESSAGE,
	HURRY_SHOP, HURRY_BUILDING, SUPPLY, FRIEND_VIEW,
}

## Original Tutorials.xml id. Must stay stable — other tutorials reference
## it via a "tutorial" kind Prerequisite.
@export var id: int = -1

@export var trigger_type: TriggerType = TriggerType.ALWAYS
## Building id this tutorial triggers on ("build"/"select" trigger types
## only); -1 for ALWAYS.
@export var trigger_value: int = -1

@export var display_name: String = ""
@export var description: String = ""

## Each entry: { "kind": "level"|"building"|"tutorial"|"land_upgrade"|
## "reward_unlockable", "target_id": int, "min_value": int }. ANDed.
@export var prerequisites: Array[Dictionary] = []

## { resource_id: int -> amount: float }. Empty if this tutorial grants no
## reward on completion.
@export var reward: Dictionary = {}

## Each entry: { "type": "build"|"assign"|...|"friend_view",
## "first": int, "second": int }. All must complete, in order, to finish
## this tutorial. Meaning of first/second is objective-type-dependent —
## see docs/GAME_SYSTEMS.md §11 for the full per-type parameter table.
@export var objectives: Array[Dictionary] = []

## Town-wide feature locks this tutorial imposes while active. Booleans
## default false (nothing locked) so an empty/default TutorialLock is a
## no-op, matching a tutorial with no <Lock> tag in the original.
@export var lock_world: bool = false
@export var lock_buildings: bool = false
@export var lock_consumables: bool = false
@export var lock_energy: bool = false
@export var lock_workers: bool = false
@export var lock_haulers: bool = false
@export var lock_sell: bool = false
@export var lock_friend_shop_restricted: bool = false

## Allow[building_id] -> exception value; a missing key means no exception
## is granted for that building while the corresponding lock above is active.
@export var allow_build_count: Dictionary = {}       # { building_id: int(-1=unlimited) }
@export var allow_energy_count: Dictionary = {}      # { building_id: int(-1=unlimited) }
@export var allow_workers: Dictionary = {}           # { building_id: bool }
@export var allow_haulers: Dictionary = {}           # { building_id: bool }
@export var allow_sell: Dictionary = {}              # { building_id: bool }
@export var allow_messages: Dictionary = {}          # { building_id: String }
@export var allow_consumable_count: Dictionary = {}  # { item_id: int(-1=unlimited) }
@export var allow_consumable_messages: Dictionary = {}  # { item_id: String }
