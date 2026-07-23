# Trade Nations — Modern Data Model

This is a schema design, not code. It defines the shape every gameplay system in
`GAME_SYSTEMS.md` will be loaded into once implementation starts (Phase 1 of
`IMPLEMENTATION_ROADMAP.md`). Target engine is Godot 4.x, so schemas are expressed as
Godot `Resource` classes (GDScript-flavored pseudocode) since that's how the roadmap
plans to load/author data — but no gameplay logic is implemented here, only field
shapes and their provenance.

Convention: every field that has a directly-recovered value from the original XML is
marked **[original]**; every field that is a necessary modern addition (no original
equivalent, or original value unrecoverable) is marked **[new]**. This keeps the
"faithful vs redesigned" distinction from `RECONSTRUCTION.md` visible at the schema
level, not just in prose.

---

## 0. Shared Primitives

Used by nearly every other schema — defined once, reused everywhere, mirroring how
the original XML reuses the same `<Cost>`/`<Prerequisite>` shapes across Objects,
Items, and Tutorials (see `GAME_SYSTEMS.md` "Cross-System Notes").

```gdscript
# CostEntry — one line of a cost/sell/reward bundle.
class_name CostEntry
extends Resource

enum CurrencyKind { RESOURCE, GOLD, MAGIC_BEANS, ENERGY, XP }  # [new] unified enum;
    # original XML spells Gold as Resource id=1 and MagicBeans as its own tag —
    # kept distinct here only for authoring clarity, both settle to the same
    # ledger at runtime.

@export var kind: CurrencyKind                # [original]
@export var resource_id: int = -1             # [original] only used when kind == RESOURCE
@export var amount: float                     # [original]


# CostBundle — replaces <Cost>, <Sell>, <Reward>, <AlternateCost>.
class_name CostBundle
extends Resource

@export var entries: Array[CostEntry] = []    # [original]


# PrerequisiteKind — the vocabulary shared by Objects/Items/Tutorials.
class_name Prerequisite
extends Resource

enum Kind { LEVEL, BUILDING, TUTORIAL, LAND_UPGRADE, REWARD_UNLOCKABLE }  # [original]

@export var kind: Kind                        # [original]
@export var target_id: int = -1               # [original] building id / tutorial id / land-upgrade id
@export var min_value: int = 0                # [original] e.g. required level number


class_name PrerequisiteSet
extends Resource

@export var all_of: Array[Prerequisite] = []  # [original] ANDed, matches observed XML (multiple
                                               # <Prerequisite> tags on one Object = all required)
```

---

## 1. Resource Definitions

Backs `GAME_SYSTEMS.md` §1.

```gdscript
class_name ResourceDef
extends Resource

@export var id: int                           # [original] Resources.xml id, KEEP STABLE
@export var name: String                      # [original]
@export var tier: int                         # [new] derived: 0=currency(Gold), 1=raw, 2=refined
@export var score_value: float                # [original] scoreValue — net-worth weight, formula
                                               #            it feeds into is unrecovered (see MISSING_INFORMATION.md)
@export var start_value: float                # [original] startValue — new-game starting amount
@export var refines_from: int = -1            # [original, inferred] tier-1 source resource id
                                               #            (e.g. Lumber.refines_from = Wood.id)
@export var icon_font_char: String            # [original] compact UI glyph
@export var stack_sprite: String              # [original] visual key — actual art pending asset-format work
@export var single_sprite: String             # [original]
@export var hauler_anim_id: int                # [original]
@export var collect_sfx_id: int                # [original] → Sounds.xml id
```

A parallel small table for non-`Resource` currencies:

```gdscript
class_name CurrencyDef
extends Resource

@export var id: String                        # [original] "gold" | "magic_beans" | "z2points" [new: "energy"]
@export var display_name: String              # [original/new]
@export var is_premium: bool                  # [original] true for magic_beans
@export var icon_font_char: String            # [original] where known (Energy: "}", Z2Points: "_")
```

---

## 2. Building Definitions

Backs `GAME_SYSTEMS.md` §3 (Buildings) and §4 (Decorations) — one schema for both,
matching the original's single-`<Object>`-for-everything design.

```gdscript
class_name BuildingDef
extends Resource

enum BuildingType {                            # [original] observed `type=` values
    TOWNHALL, MINE, SHOP, STORE, MARKET, DECORATION, HOUSE,
    RESOURCE_TILE, PRESENT, MISC, SKIN_SWITCH, ENTERTAINER, RIVER,
    HOT_AIR_BALLOON, TREE,
}

@export var id: int                            # [original] Objects id, KEEP STABLE (cross-referenced
                                                 #            by BuildMenu, Skins, Tutorials, PrereqMappings)
@export var name: String                       # [original]
@export var type: BuildingType                 # [original]
@export var category: String = ""              # [original] optional, feeds LevelDef.max_building caps
@export var width: int                         # [original] footprint tiles
@export var height: int                        # [original]
@export var xp_value: float                    # [original] one-time XP on construction
@export var available_from_store: bool         # [original]
@export var compatible_lands: Array[String]    # [original] ["Vanilla"] | ["Frontier"] | ["All"]

@export var prerequisites: PrerequisiteSet      # [original]
@export var cost: CostBundle                   # [original]
@export var sell: CostBundle                   # [original] null/empty if unsellable (Sell=false, e.g. Town Halls)
@export var build_time_seconds: float          # [original]
@export var build_fade_anim: bool = false      # [original] purpose not fully confirmed, kept for fidelity

@export var upgrade_of_id: int = -1            # [original]
@export var upgrade_only: bool = false         # [original] true = never freshly buildable
@export var owned_limit: int = -1              # [original] -1 = unlimited, else hard cap (e.g. 1 for Town Hall tiers)

@export var storage: StorageDef = null         # [original] present if this Object stores resources
@export var mine: GatherRecipe = null          # [original] present if type == MINE
@export var shop_recipes: Array[int] = []      # [original] CraftRecipe ids, present if type == SHOP
@export var buff: BuffDef = null                # [original] present if this Object grants a passive buff
@export var buffable_categories: Array[String] = []  # [original] categories this building can RECEIVE buffs in
@export var skin_switch_target: String = ""    # [original] present if type == SKIN_SWITCH

@export var finish_time_unix: int = -1         # [original] calendar-locked unlock (e.g. holiday presents);
                                                 #            -1 = not calendar-gated [new: Phase 5 concern]

# Presentation — kept for completeness; actual art requires asset-format work (see MISSING_INFORMATION.md)
@export var idle_anim: String                  # [original]
@export var build_menu_anim: String            # [original]
@export var construction_anim: String          # [original]
@export var work_anim_male: String             # [original]
@export var work_anim_female: String           # [original]
@export var work_anim_male_idle: String        # [original]
@export var work_anim_female_idle: String      # [original]
@export var sound_select_id: int = -1          # [original]
@export var sound_buy_id: int = -1             # [original] Market only
@export var sound_sell_id: int = -1            # [original] Market only
@export var info_text: String                  # [original]
@export var description_text: String           # [original]
```

```gdscript
class_name StorageDef
extends Resource

# One capacity entry per resource id this building can store.
# Gold is always effectively unlimited per original data — represent as -1 (unlimited).
@export var capacities: Dictionary = {}        # [original] { resource_id: int (-1 = unlimited) }
```

```gdscript
class_name BuffDef
extends Resource

@export var category: String                  # [original] "shops" | "school" | "carnival" | "wheat" | "inn"
@export var only_one: bool                     # [original] onlyOne attribute — non-stacking if true
@export var xp_percent: float                  # [original]
@export var per_resource_percent: Dictionary = {}  # [original] { resource_id: float }
```

---

## 3. Production Recipes

Backs `GAME_SYSTEMS.md` §2. Two distinct recipe kinds, matching the two original
mechanics (mine vs shop) rather than forcing one shape on both.

```gdscript
class_name GatherRecipe
extends Resource

@export var output_resource_id: int            # [original]
@export var max_output_stack_size: float       # [original]
@export var worker_type_label: String          # [original] flavor only ("Wood Cutter", "Quarryman", ...)
@export var worker_max: int                    # [original]
@export var hauler_max: int                    # [original]
@export var resources_per_hour_passive: float  # [original] observed 0 in every sample; kept for fidelity
@export var villager_resources_per_hour: float # [original] worker-driven rate
@export var mayor_resources: float             # [original] direct mayor action yield (energy-gated)
@export var mayor_resources_no_energy: float   # [original] direct mayor action yield when out of energy
                                                 #            (0 in every sample — original data itself
                                                 #             flags this as a likely placeholder, see
                                                 #             MISSING_INFORMATION.md; keep faithful, don't "fix")
@export var hurry_cost: float                  # [original]
```

```gdscript
class_name CraftRecipe
extends Resource

@export var id: int                            # [original] Items.xml id, referenced by BuildingDef.shop_recipes
@export var name: String                       # [original]
@export var time_seconds: float                # [original]
@export var cost: CostBundle                   # [original] input resource(s) consumed
@export var reward: CostBundle                 # [original] xp + gold (occasionally other resources) output
@export var prerequisites: PrerequisiteSet     # [original]
@export var hurry_cost_per_interval: float     # [original]
@export var hurry_interval_seconds: float      # [original]
@export var compatible_lands: Array[String]    # [original]
@export var menu_icon: String                  # [original]
@export var float_menu_icon: String            # [original]
```

```gdscript
class_name LandUpgradeDef
extends Resource

@export var id: int                            # [original] Items.xml id
@export var name: String                       # [original]
@export var new_land_size: int                 # [original] `value` attribute — side length in tiles
@export var cost: CostBundle                   # [original] gold-path cost
@export var alternate_cost: CostBundle         # [original] magic-beans-path cost
@export var prerequisites: PrerequisiteSet     # [original] chains to previous land-upgrade id
@export var compatible_land: String            # [original] "Vanilla" | "Frontier"
```

---

## 4. Worker (Villager) Definitions

Backs `GAME_SYSTEMS.md` §5.

```gdscript
class_name VillagerSimConstants                 # town-wide constants, not per-instance
extends Resource

@export var speed: float                       # [original] Settings.xml <Villager speed>
@export var haul_speed: float                  # [original]
@export var work_rate: float                   # [original]
@export var homeless_modifier: float           # [original] productivity multiplier while homeless
@export var eat_time_seconds: float            # [original]
@export var hunger_length_min: float           # [original] unit not confirmed — treat as hours [new: verify]
@export var hunger_length_max: float           # [original]
@export var adopt_cost: CostBundle             # [original] AdoptedVillagers cost (15, currency unconfirmed)
@export var carry_amount: float                # [original] Settings.xml <Energy carryamount> — max haul per trip
```

```gdscript
class_name Villager                             # per-instance runtime state, not a static def
extends Resource

enum Role { UNASSIGNED, WORKER, HAULER }        # [original]
enum Gender { MALE, FEMALE }                    # [original] drives VillagerSounds selection + sprite set

@export var villager_id: String                 # [new] unique instance id (save-file scoped)
@export var gender: Gender                      # [original]
@export var role: Role = Role.UNASSIGNED        # [original]
@export var assigned_building_instance_id: String = ""  # [new] links to a placed BuildingInstance
@export var home_instance_id: String = ""       # [new] house providing capacity to this villager
@export var is_homeless: bool = false           # [original, derived]
@export var hunger_timer: float = 0.0           # [original, derived]
@export var is_hungry: bool = false             # [original, derived]
```

---

## 5. Player State

Backs `GAME_SYSTEMS.md` §6 (Land), §8 (Energy), §9 (Currency), §10 (Leveling).

```gdscript
class_name LevelDef
extends Resource

@export var level: int                          # [original] 0..70
@export var xp_to_next: float                   # [original] Settings.xml <XP toNext>
@export var max_building_by_category: Dictionary = {}  # [original] { category: int }
@export var reward: CostBundle                   # [original] typically energy
@export var level_text: String                  # [original] flavor congratulations message
@export var default_free_inventory_slots: int = 0  # [original] level 0 only, see MISSING_INFORMATION.md


class_name PlayerState
extends Resource

@export var player_id: String                   # [new]
@export var mayor_level: int = 0                 # [original, derived from xp via LevelDef table]
@export var xp_total: float = 0.0                # [original, derived]
@export var energy_current: float                # [original]
@export var energy_max: float                    # [new] regen ceiling — exact original cap/rate unrecovered
@export var energy_regen_per_minute: float       # [new] PLACEHOLDER pending evidence, see MISSING_INFORMATION.md

@export var currency_balances: Dictionary = {}   # [original] { "gold": float, "magic_beans": float }
                                                   # Gold ALSO exists as ResourceDef id=1 in the resource
                                                   # ledger below — currency_balances.gold and
                                                   # Inventory.resource_amounts[1] must be kept as ONE
                                                   # source of truth (see Inventory note below), not two.

@export var owned_lands: Dictionary = {}         # [original] { "Vanilla": {size:int}, "Frontier": {size:int} }
@export var active_skins: Dictionary = {}        # [original] { land_name: skin_name }, from Skins.xml

@export var tutorial_progress: TutorialProgress  # [original] see §8 below
@export var achievement_progress: Dictionary = {}  # [new] { achievement_id: current_count }
```

**Note on Gold duality**: the original models Gold both as `Resource id=1` (with
storage caps, sprites, etc.) and implicitly as "the currency." The modern model
resolves this by treating `Inventory.resource_amounts[1]` as the single canonical
Gold balance; `PlayerState.currency_balances["gold"]` is a read-through convenience
accessor, not a second stored value, to avoid state-sync bugs. MagicBeans has no
`Resource` id in the original and is only ever a currency — it stays purely in
`currency_balances`.

---

## 6. Inventory

Backs `GAME_SYSTEMS.md` §6 (Storage).

```gdscript
class_name Inventory
extends Resource

@export var resource_amounts: Dictionary = {}    # [original] { resource_id: float }, Gold always uncapped
@export var resource_capacity: Dictionary = {}   # [original, derived] { resource_id: float(-1=unlimited) },
                                                   #   SUM of StorageDef.capacities across all owned
                                                   #   storage-capable BuildingInstances (design decision,
                                                   #   see GAME_SYSTEMS.md §6 — sum, not max)
@export var item_slots_used: int = 0             # [new] for the DefaultFreeInventorySlots system —
@export var item_slots_max: int = 0              #   schema present, semantics unconfirmed (see
                                                   #   MISSING_INFORMATION.md); do not wire up until resolved
```

---

## 7. World / Building Instances

Not a system in `GAME_SYSTEMS.md` on its own, but required to connect `BuildingDef`
(static data) to an actual placed building in a player's town — needed by Phase 2 of
the roadmap.

```gdscript
class_name BuildingInstance
extends Resource

@export var instance_id: String                  # [new] unique within a save
@export var def_id: int                          # [original] → BuildingDef.id
@export var land: String                         # [original] which land this instance lives on
@export var x: int                                # [original] Layout.xml xPosition
@export var y: int                                # [original] Layout.xml yPosition
@export var flipped: bool = false                # [original] Layout.xml flipObj
@export var construction_started_at: float = -1  # [new] engine-time timestamp, -1 = already built
@export var construction_complete: bool = true   # [new]

@export var stored_resources: Dictionary = {}    # [original] per-instance resource bank, only relevant
                                                   #   for MINE/STORE/SHOP-holding-output types
@export var active_recipe_id: int = -1           # [original] current GatherRecipe or CraftRecipe in progress
@export var recipe_started_at: float = -1        # [new]
@export var assigned_worker_ids: Array[String] = []  # [new] Villager instance ids
@export var assigned_hauler_ids: Array[String] = []  # [new]
```

```gdscript
class_name TownLayout
extends Resource

@export var land: String                         # [original]
@export var resource_tiles: Array[BuildingInstance] = []  # [original] Layout.xml <ResourceTiles>
@export var starting_objects: Array[BuildingInstance] = []  # [original] Layout.xml top-level <Object>
```

---

## 8. Quest / Tutorial Data

Backs `GAME_SYSTEMS.md` §11.

```gdscript
class_name TutorialObjective
extends Resource

enum ObjectiveType {                             # [original] 13-verb vocabulary from Tutorials.xml
    BUILD, ASSIGN, COLLECT, GATHER, TRANSPORT, USE_SHOP,
    MARKET_BUY, MARKET_SELL, LAND_SIZE, MESSAGE,
    HURRY_SHOP, HURRY_BUILDING, SUPPLY, FRIEND_VIEW,
}

@export var type: ObjectiveType                  # [original]
@export var first: int = -1                      # [original] meaning is type-dependent, see GAME_SYSTEMS.md §11
@export var second: int = -1                     # [original]
```

```gdscript
class_name TutorialLock
extends Resource

@export var world_locked: bool = false            # [original]
@export var buildings_locked: bool = false        # [original]
@export var consumables_locked: bool = false      # [original]
@export var energy_locked: bool = false           # [original]
@export var workers_locked: bool = false          # [original]
@export var haulers_locked: bool = false          # [original]
@export var sell_locked: bool = false             # [original]
@export var friend_shop_restricted: bool = false  # [original]

# Allow[building_id] -> per-building exception values; missing key = no exception granted
@export var allow_build_count: Dictionary = {}    # [original] { building_id: int(-1=unlimited) }
@export var allow_energy_count: Dictionary = {}   # [original] { building_id: int(-1=unlimited) }
@export var allow_workers: Dictionary = {}        # [original] { building_id: bool }
@export var allow_haulers: Dictionary = {}        # [original] { building_id: bool }
@export var allow_sell: Dictionary = {}           # [original] { building_id: bool }
@export var allow_messages: Dictionary = {}       # [original] { building_id: String }
@export var allow_consumable_count: Dictionary = {}  # [original] { item_id: int(-1=unlimited) }
@export var allow_consumable_messages: Dictionary = {}  # [original] { item_id: String }
```

```gdscript
class_name TutorialDef
extends Resource

enum TriggerType { ALWAYS, BUILD, SELECT }        # [original]

@export var id: int                               # [original] KEEP STABLE — referenced by other tutorials'
                                                    #            Prerequisite(kind=TUTORIAL)
@export var trigger_type: TriggerType             # [original]
@export var trigger_value: int = -1               # [original] building id, when trigger_type != ALWAYS
@export var name: String                          # [original]
@export var description: String                   # [original]
@export var prerequisites: PrerequisiteSet        # [original]
@export var reward: CostBundle                    # [original]
@export var objectives: Array[TutorialObjective] = []  # [original] all must complete, in order
@export var lock: TutorialLock                    # [original]
```

```gdscript
class_name TutorialProgress                        # per-player runtime state
extends Resource

@export var completed_ids: Array[int] = []        # [original, derived]
@export var active_id: int = -1                    # [new] currently in-progress tutorial
@export var objective_progress: Dictionary = {}    # [new] { objective_index: current_count }
```

---

## 9. Save Data

The top-level container persisted to disk. Composition only — every field type is
defined above.

```gdscript
class_name SaveGame
extends Resource

@export var save_version: int                     # [new] schema version for migrations
@export var created_at_unix: int                   # [new]
@export var last_saved_at_unix: int                 # [new]

@export var player: PlayerState                     # §5
@export var inventory: Inventory                    # §6
@export var town_layouts: Dictionary = {}           # [new] { land_name: TownLayout } — includes placed
                                                     #        BuildingInstances, not just starting layout
@export var villagers: Array[Villager] = []         # §4
@export var tutorial_progress: TutorialProgress     # §8, also referenced from PlayerState — same object,
                                                     #      not duplicated at save time
```

Static content tables (`ResourceDef`, `BuildingDef`, `GatherRecipe`, `CraftRecipe`,
`LandUpgradeDef`, `LevelDef`, `TutorialDef`, `VillagerSimConstants`) are **not** part
of `SaveGame` — they're read-only game data shipped with the build (converted once
from the original XML into `.tres`/`.json` resource files per
`IMPLEMENTATION_ROADMAP.md` Phase 1), loaded fresh every launch, and referenced by id
from save data rather than embedded in it. This mirrors the original architecture,
where `bundle/*.xml` is static content and only player progress was ever meant to be
mutable/persisted.

---

## 10. Open Schema Questions

Tracked in full in `MISSING_INFORMATION.md`; flagged here at the field level so they
travel with the schema:

- `PlayerState.energy_max` / `energy_regen_per_minute` — no original constant found.
- `Inventory.item_slots_max` semantics (`DefaultFreeInventorySlots`) — unconfirmed
  whether this is a separate "goods" inventory (gifts, tradeable finished items) or
  something else.
- `Inventory.resource_capacity` aggregation rule (sum vs max across storage
  buildings) — implemented as sum per a documented design decision, not a recovered
  fact.
- `ResourceDef.score_value` — known value, unknown consuming formula.
- `CurrencyDef` entry for Z2Points — schema stub only, no mechanic defined.
- Achievement definitions — deliberately absent from this data model as *content*;
  the engine-level "counter reaches threshold" achievement schema is a Phase 4/5
  concern once `GAME_SYSTEMS.md` §12's design work is finalized.
