# Trade Nations — Technical Architecture Blueprint

This is the engineering design that sits on top of `RECONSTRUCTION.md` (why),
`GAME_SYSTEMS.md` (what the original did), and `DATA_MODEL.md` (the data schemas).
This document defines **how** those schemas get loaded, held, and acted on inside a
Godot 4 project — folder layout, the manager/singleton architecture, the
Resource/Script/Scene split, system dependency order, and the first vertical-slice
milestone. It supersedes nothing in the four prior documents; it implements their
plan.

**No gameplay code is written here.** Systems are specified by responsibility,
public interface (signatures only), signals, and data ownership — not by method
bodies.

---

## 1. Godot Project Structure

```
res://
├── autoload/                      # Singleton scripts registered in Project Settings
│   ├── event_bus.gd
│   ├── data_manager.gd
│   ├── save_manager.gd
│   ├── game_manager.gd
│   ├── time_manager.gd
│   ├── economy_manager.gd
│   ├── currency_manager.gd
│   ├── inventory_manager.gd
│   ├── building_manager.gd
│   ├── worker_manager.gd
│   ├── tutorial_manager.gd
│   └── audio_manager.gd
│
├── data_model/                    # Resource CLASS DEFINITIONS from DATA_MODEL.md
│   ├── defs/                      #   static content schemas (ResourceDef, BuildingDef, ...)
│   ├── runtime/                   #   per-save runtime schemas (PlayerState, Inventory, ...)
│   └── shared/                    #   CostEntry, CostBundle, Prerequisite, PrerequisiteSet
│
├── data/                          # CONTENT — converted from original/TradeNations.app/bundle/
│   ├── resources/                 #   ResourceDef .tres, one per resource id
│   ├── buildings/                 #   BuildingDef .tres, one per building id, mirrors source
│   │   ├── vanilla_to10/          #   file grouping mirrors original XML file grouping,
│   │   ├── vanilla_10plus/        #   so provenance stays traceable (see §3)
│   │   ├── vanilla_decorations/
│   │   ├── crossover/
│   │   ├── seasonal/              #   Halloween, HoityToity, etc.
│   │   └── frontier/
│   ├── recipes/                   #   CraftRecipe .tres (Items.xml shopItem entries)
│   ├── land_upgrades/             #   LandUpgradeDef .tres
│   ├── levels/                    #   LevelDef .tres, id 0..70
│   ├── tutorials/                 #   TutorialDef .tres
│   ├── skins/                     #   skin/reskin tables (Skins.xml)
│   ├── layouts/                   #   TownLayout starting-state .tres per land
│   └── constants/                 #   VillagerSimConstants, energy constants, buff constants
│
├── tools/                         # EDITOR-ONLY tooling, never shipped in exported game
│   └── xml_import/                #   one-time XML→.tres converters (Phase 1.3), run from editor
│
├── systems/                       # Non-autoload support classes used BY the autoloads
│   ├── economy/                   #   recipe execution helpers, buff aggregation
│   ├── building/                  #   placement validation, footprint/collision helpers
│   ├── worker/                    #   assignment rules, hunger/homelessness helpers
│   ├── tutorial/                  #   objective evaluators, lock evaluators
│   └── prerequisite/              #   shared PrerequisiteEvaluator, CostLedger (Phase 1.2)
│
├── scenes/
│   ├── boot/                      #   Boot.tscn — first scene, shows loading, hands off to GameManager
│   ├── main_menu/
│   ├── world/
│   │   ├── World.tscn             #   the town view for ONE land
│   │   ├── Tile.tscn
│   │   ├── BuildingInstanceView.tscn   # visual+input node bound to a BuildingInstance id
│   │   └── VillagerView.tscn            # visual+movement node bound to a Villager id
│   └── ui/
│       ├── hud/
│       ├── build_menu/
│       ├── building_popup/
│       ├── tutorial_overlay/
│       └── dialogs/
│
├── assets/
│   ├── art/                       #   placeholder art now; real art pending format work
│   │   └── placeholder/
│   ├── audio/
│   │   ├── sfx/                   #   converted .caf → .ogg/.wav, keyed by Sounds.xml id
│   │   └── music/
│   └── fonts/
│
└── tests/                         # scene-based / GUT-style tests per system
    ├── test_data_manager.gd
    ├── test_economy_manager.gd
    ├── test_building_manager.gd
    └── ...
```

**Design rules this structure enforces:**

- `data_model/` (class defs) is never mixed with `data/` (content instances) — the
  same separation `DATA_MODEL.md` draws between "schema" and "data."
- `data/buildings/` subfolders mirror the **original XML file boundaries** even
  though the runtime doesn't care — this keeps every converted `.tres` traceable
  back to the exact source file cited in `GAME_SYSTEMS.md`, which matters the day a
  `MISSING_INFORMATION.md` item gets resolved and someone needs to find what to
  regenerate.
- `tools/xml_import/` is excluded from the exported build (Godot export filters) —
  it depends on `original/` only existing in the dev repo, never in a shipped
  product.
- No manager script lives outside `autoload/`; no support class lives inside
  `autoload/` — an autoload is a thin orchestrator that delegates to `systems/`.
  This keeps the autoload scripts short enough to review at a glance and keeps
  business logic unit-testable without the autoload singleton machinery.

---

## 2. Core Systems Architecture

### Architectural principle: Managers own state, Scenes render it

Every manager below is a **Godot autoload (singleton)**, alive for the whole
process lifetime, holding the authoritative `SaveGame` sub-state from
`DATA_MODEL.md`. Scenes (`World.tscn`, UI) never own gameplay state themselves —
they query managers and listen to `EventBus` signals, then render. This means:

- The simulation keeps running correctly even if no `World.tscn` is currently
  loaded (e.g., player is on a menu screen) — critical for an idle/production game
  where `TimeManager` must be able to fast-forward offline progress without a
  visual scene existing at all.
- Only one land's `World.tscn` is ever instantiated at a time, but `BuildingManager`
  / `WorkerManager` hold state for **all** lands the player owns, so switching lands
  is a scene swap, not a state reload.
- UI and world-view scenes are disposable/rebuildable from manager state at any
  time — this is what makes `SaveManager` reload deterministic (see §2.3).

`EventBus` (autoload, no dependencies) is a pure signal-relay singleton — managers
emit domain events here (`building_placed`, `resource_changed`,
`recipe_completed`, `level_up`, `tutorial_objective_progressed`, ...) instead of
holding direct references to each other or to scenes. This decouples, e.g.,
`BuildingManager` from needing to know `TutorialManager` exists at all — Tutorial
just listens.

---

### 2.1 GameManager

**Responsibility**: overall game/app state machine and scene transitions. The
single entry point that decides "what is the player looking at right now" and
"is there an active game session."

**State machine** (`GameManager.State` enum): `BOOT → MAIN_MENU → LOADING_SAVE →
IN_GAME → PAUSED → (back to MAIN_MENU on quit-to-menu)`.

**Owns**:
- `current_state: State`
- `active_land: String` — which land's `World.tscn` is currently displayed (not
  which lands exist — that's `SaveGame.town_layouts`, owned by `BuildingManager`).

**Public interface (signatures only)**:
```gdscript
func start_new_game() -> void
func continue_game(slot: int) -> void
func switch_active_land(land: String) -> void
func pause_game() -> void
func resume_game() -> void
func quit_to_main_menu() -> void
```

**Depends on**: `DataManager` (must be loaded first — new game needs content
defaults), `SaveManager` (load/create the save being entered).

**Emits** (`EventBus`): `game_state_changed(old, new)`, `active_land_changed(land)`.

**Scene transition mechanic**: `GameManager` owns a single `CanvasLayer`/
`Node` "view root" in `Boot.tscn` (the one scene that's never unloaded) and
swaps children under it (`MainMenu`, `World` instance for `active_land`, plus a
persistent UI overlay layer). This avoids ever reloading autoloads mid-session.

---

### 2.2 DataManager

**Responsibility**: load every static content table (the `_Def`/`Recipe` classes
from `DATA_MODEL.md`) at boot, index by id, and expose read-only lookup. This is
the runtime counterpart to the Phase 1.3 XML→`.tres` conversion tooling — the
converters write `data/`, `DataManager` only ever reads it.

**Owns** (all read-only after boot):
```gdscript
var resources: Dictionary        # { id: ResourceDef }
var buildings: Dictionary        # { id: BuildingDef }
var gather_recipes: Dictionary   # { building_id: GatherRecipe }
var craft_recipes: Dictionary    # { id: CraftRecipe }
var land_upgrades: Dictionary    # { id: LandUpgradeDef }
var levels: Dictionary           # { level: LevelDef }
var tutorials: Dictionary        # { id: TutorialDef }
var skins: Dictionary            # { name: SkinDef }
var starting_layouts: Dictionary # { land: TownLayout }
var villager_constants: VillagerSimConstants
```

**Public interface**:
```gdscript
func load_all() -> void                       # called once by GameManager during BOOT
func get_building(id: int) -> BuildingDef
func get_resource(id: int) -> ResourceDef
func get_craft_recipe(id: int) -> CraftRecipe
func get_level(level: int) -> LevelDef
func is_loaded() -> bool
```

**Depends on**: nothing (filesystem only). Must finish `load_all()` before any
other manager initializes — see §4.

**Validation on load**: cross-reference integrity checks run once at boot (every
`BuildingDef.shop_recipes` id resolves to a real `CraftRecipe`; every
`Prerequisite.target_id` resolves to a real building/tutorial/land-upgrade id;
every `BuildMenu` category reference resolves). Fail loudly (blocking error
screen, not silent skip) if content is malformed — this is a data-integrity gate,
not a gameplay concern, and malformed content should never reach `IN_GAME` state.

---

### 2.3 SaveManager

**Responsibility**: serialize/deserialize `SaveGame` (per `DATA_MODEL.md` §9) to
and from disk; owns save-slot management; owns save-format versioning/migration.

**Save format**: Godot's native `ResourceSaver`/`ResourceLoader` with a custom
binary/text `.tres`-based `SaveGame` resource is the default choice **for
development** (trivially inspectable in text mode, diffable in version control for
debugging). For shipped builds, switch the same `SaveGame` tree to
`ResourceSaver.FLAG_COMPRESS` binary output — same schema, no code change, purely
an export-time flag. JSON is deliberately *not* the primary format: `SaveGame`
already IS a typed `Resource` tree per `DATA_MODEL.md`, and Godot's resource
serializer round-trips typed Resources (including nested `Dictionary`/`Array[T]`
fields) without a hand-written (de)serializer to maintain. A JSON export path can
still be offered later purely as a manual debug/support tool, generated by walking
the same `SaveGame` tree — not the authoritative format.

**Owns**:
```gdscript
var current_save: SaveGame
```

**Public interface**:
```gdscript
func create_new_save() -> SaveGame            # builds default PlayerState/Inventory/
                                                #   TownLayout from DataManager tables
func save_to_slot(slot: int) -> void
func load_from_slot(slot: int) -> SaveGame
func list_slots() -> Array[SaveSlotSummary]    # for a save-select UI
func delete_slot(slot: int) -> void
func migrate_if_needed(save: SaveGame) -> SaveGame   # version-gated upgrades
```

**Depends on**: `DataManager` (defaults for new-game creation).

**What's covered**: everything in `SaveGame` — `PlayerState` (level, XP, energy,
currency, owned lands, active skins, tutorial progress), `Inventory` (resource
amounts/capacity), `town_layouts` → all `BuildingInstance`s per land (including
`active_recipe_id` / `recipe_started_at`, so **in-progress construction and
production timers persist across a save/reload**, not just completed state), and
`villagers` array.

**Timer persistence design**: no manager stores a running countdown as "seconds
remaining." Every timer-bearing field (`construction_started_at`,
`recipe_started_at`) is stored as an **absolute timestamp** against
`TimeManager`'s game clock (§2.4). On load, remaining time is always
`recomputed` as `duration - (TimeManager.now() - started_at)`, which is what makes
offline-progress catch-up (player was away, production kept running) a
side-effect of normal load logic rather than a special case.

---

### 2.4 TimeManager

**Responsibility**: the single game clock every other timer-based system reads
from. Original data (`GAME_SYSTEMS.md`) gives every duration in real seconds
(`BuildTime`, shop-item `time`, `worktime`, `hungerlength`) — there is no evidence
of an accelerated "game day" cycle distinct from real time, so `TimeManager`'s
default clock **is** wall-clock time, not a scaled simulation tick.

**Owns**:
```gdscript
var game_time_unix: int          # authoritative "now", persisted as
                                  #   SaveGame.last_saved_at_unix on save
var is_paused: bool
```

**Public interface**:
```gdscript
func now() -> int
func pause() -> void
func resume() -> void
func seconds_until(started_at: int, duration: float) -> float
func is_elapsed(started_at: int, duration: float) -> bool
```

**Offline catch-up**: on `SaveManager.load_from_slot`, `TimeManager` computes the
gap between `last_saved_at_unix` and real "now," and every manager with
timer-bearing state (`BuildingManager`, `EconomyManager`) is given a single
`catch_up(elapsed_seconds)` pass to resolve anything that would have completed
while offline (construction finishing, gather-recipe output accumulating up to
`max_output_stack_size`, shop recipes completing) **before** the world scene ever
renders a frame — this avoids a visible "everything suddenly finishes" pop after
load.

**Day/night cycle**: no evidence in `GAME_SYSTEMS.md`/original data of a
day/night mechanic (only real-world calendar-locked content like the Holiday
Gift's `FinishTime`, which is a live-event system, not a day/night cycle). Treat
day/night as **purely cosmetic** if implemented at all (a lighting overlay driven
by real device time, for atmosphere) — it must not gate or affect any production
rate, since nothing in the data supports that. This is flagged in §6 as an
architectural assumption, not a recovered mechanic.

**Depends on**: `SaveManager` (to read `last_saved_at_unix` on load).

**Emits**: `time_tick(delta)` (per-frame or throttled, for UI countdown displays
only — never for authoritative completion checks, which are always the
`is_elapsed()` absolute-timestamp comparison above, so a paused/backgrounded game
can never desync from a dropped tick).

---

### 2.5 EconomyManager

**Responsibility**: executes `GatherRecipe` and `CraftRecipe` per
`GAME_SYSTEMS.md` §2, applies buffs (§4), and is the single place resources are
minted/consumed — no other manager mutates `Inventory.resource_amounts` directly.

**Public interface**:
```gdscript
func can_afford(cost: CostBundle) -> bool
func apply_cost(cost: CostBundle) -> void            # atomic; asserts can_afford first
func grant_reward(reward: CostBundle) -> void
func start_gather(building_instance_id: String) -> void
func start_craft(building_instance_id: String, recipe_id: int) -> void
func mayor_direct_action(building_instance_id: String) -> void   # energy-gated, GAME_SYSTEMS.md §2/§8
func hurry(building_instance_id: String) -> void
func collect_output(building_instance_id: String) -> void        # requires an assigned hauler, §5
func active_buff_percent(category: String, resource_id: int = -1) -> float
func catch_up(elapsed_seconds: float) -> void                     # see TimeManager offline catch-up
```

**Owns**: no state of its own beyond transient computation caches — it *operates
on* `SaveManager.current_save.inventory` and `BuildingManager`'s
`BuildingInstance`s, keeping a single source of truth rather than a shadow copy.

**Depends on**: `DataManager` (recipe/building defs), `SaveManager` (inventory,
player XP/level), `TimeManager` (elapsed-time checks), `InventoryManager` (capacity
checks/writes), `CurrencyManager` (Gold/MagicBeans costs route through here).

**Emits**: `resource_changed(resource_id, new_amount)`,
`recipe_started(instance_id, recipe_id)`,
`recipe_completed(instance_id, recipe_id, reward)`, `xp_gained(amount)`,
`level_up(new_level)`.

---

### 2.6 CurrencySystem (`CurrencyManager`)

**Responsibility**: Gold and MagicBeans balances, and the `TownhallStore`/
`ItemOfTheDay` purchase flow (`GAME_SYSTEMS.md` §9). Kept as its own autoload
(rather than folded fully into `EconomyManager`) because it has a distinct
concern — **premium-currency purchases are the one place real-money/mock-payment
integration will eventually hook in**, and isolating it keeps that integration
point small and auditable.

**Public interface**:
```gdscript
func gold() -> float
func magic_beans() -> float
func can_afford_bundle(cost: CostBundle) -> bool
func spend(cost: CostBundle) -> void
func grant(reward: CostBundle) -> void
func purchase_store_item(item_id: int) -> void   # TownhallStore.xml gold/energy/building items
func purchase_featured_item(item_id: int) -> void # ItemOfTheDay.xml
```

**Depends on**: `SaveManager` (`PlayerState.currency_balances`,
`Inventory.resource_amounts[1]` for Gold — see the Gold-duality note in
`DATA_MODEL.md` §5, resolved here: `CurrencyManager.gold()` reads through to
`Inventory`, never a separate stored value).

**Emits**: `currency_changed(currency_id, new_amount)`,
`purchase_completed(item_id)`, `purchase_failed(item_id, reason)`.

**Real-money purchases**: per `RECONSTRUCTION.md` §6, this ships as a **stubbed
no-op store** for the single-player-first build — `purchase_store_item` for a
real-money SKU always succeeds against a mock ledger in early phases, with the
actual payment-processor integration explicitly out of scope until a store/
platform target is chosen.

---

### 2.7 BuildingSystem (`BuildingManager`)

**Responsibility**: placement, construction timing, upgrades, and requirement
checks for every `BuildingInstance` across every owned land
(`GAME_SYSTEMS.md` §3).

**Owns**: no shadow copy — operates on `SaveManager.current_save.town_layouts`.

**Public interface**:
```gdscript
func can_place(def_id: int, land: String, x: int, y: int, flipped: bool) -> PlacementResult
func place_building(def_id: int, land: String, x: int, y: int, flipped: bool) -> String  # returns instance_id
func can_upgrade(instance_id: String) -> bool
func upgrade_building(instance_id: String) -> void
func sell_building(instance_id: String) -> void
func is_construction_complete(instance_id: String) -> bool   # TimeManager.is_elapsed() against
                                                                #   construction_started_at + build_time
func hurry_construction(instance_id: String) -> void
func get_instances_for_land(land: String) -> Array[BuildingInstance]
func catch_up(elapsed_seconds: float) -> void
```

**`PlacementResult`** is a small struct/enum (`OK`, `BLOCKED_COLLISION`,
`BLOCKED_BOUNDS`, `BLOCKED_PREREQUISITE`, `BLOCKED_LIMIT_REACHED`,
`BLOCKED_COST`) — placement UI always calls `can_place` before showing a confirm
affordance, so the player never reaches a paid `place_building` call that then
fails.

**Depends on**: `DataManager` (`BuildingDef`), `SaveManager` (town layouts),
`EconomyManager`/`CurrencyManager` (cost application),
`PrerequisiteEvaluator` (shared support class, §1 `systems/prerequisite/`).

**Emits**: `building_placed(instance_id)`, `construction_completed(instance_id)`,
`building_upgraded(instance_id, new_def_id)`, `building_sold(instance_id)`.

**Animations**: `BuildingManager` never touches a `Node`/`AnimationPlayer`
directly — it only emits the events above. `BuildingInstanceView.tscn` (a scene,
not a manager) listens for the relevant instance id and plays
`BuildingDef.construction_anim`/`idle_anim`/`work_anim_*` locally. This keeps
animation entirely a presentation concern, consistent with §3's Resource/Script/
Scene split.

---

### 2.8 WorkerSystem (`WorkerManager`)

**Responsibility**: villager population, job assignment, and the
homelessness/hunger simulation (`GAME_SYSTEMS.md` §5). Movement/pathfinding is
split out as a *view-layer* concern (see below) since it's presentation, not
authoritative state.

**Public interface**:
```gdscript
func total_population() -> int
func housing_capacity() -> int                 # sum over owned house BuildingInstances;
                                                #   PLACEHOLDER per-house value, MISSING_INFORMATION.md #8
func idle_villagers() -> Array[Villager]
func assign_worker(villager_id: String, instance_id: String) -> bool
func assign_hauler(villager_id: String, instance_id: String) -> bool
func unassign(villager_id: String) -> void
func adopt_villager() -> bool                   # CostBundle spend via CurrencyManager, GAME_SYSTEMS.md §5
func effective_output_multiplier(villager_id: String) -> float   # applies homeless_modifier
func tick_hunger(delta: float) -> void
func catch_up(elapsed_seconds: float) -> void
```

**Depends on**: `DataManager` (`VillagerSimConstants`), `SaveManager`
(`villagers` array), `BuildingManager` (assignment target validity, house
capacity), `CurrencyManager` (adoption cost).

**Emits**: `villager_adopted(villager_id)`, `villager_assigned(villager_id,
instance_id, role)`, `villager_became_homeless(villager_id)`,
`villager_became_hungry(villager_id)`.

**Movement/logistics split**: `WorkerManager` tracks **assignment state**
(who's a worker/hauler where) and **the numbers that state produces**
(output multiplier, hauler throughput feeding `EconomyManager.collect_output`).
It does **not** track villager (x, y) world position or walk animation — that's
owned by the `VillagerView.tscn` node instantiated per visible villager in the
current `World.tscn`, which reads assignment state from `WorkerManager` and
animates toward the target building using `VillagerSimConstants.speed`/
`haul_speed` purely as a visual simulation. This split matters because it means
hauler throughput (an economy number) never depends on whether the player is
currently looking at the world (a rendering concern) — matching the "managers own
state, scenes render it" principle in §2.

---

### 2.9 InventorySystem (`InventoryManager`)

**Responsibility**: the resource ledger and capacity system
(`GAME_SYSTEMS.md` §6). Deliberately thin — most of its job is being the single
place `resource_amounts`/`resource_capacity` are read and written, so
`EconomyManager` and `BuildingManager` don't each maintain their own view of
storage state.

**Public interface**:
```gdscript
func amount(resource_id: int) -> float
func capacity(resource_id: int) -> float          # -1 == unlimited (Gold)
func free_space(resource_id: int) -> float
func can_add(resource_id: int, qty: float) -> bool
func add(resource_id: int, qty: float) -> float    # returns actual amount added (may be
                                                     #   less than qty if capacity-limited)
func remove(resource_id: int, qty: float) -> bool
func recalculate_capacity() -> void                 # re-sums StorageDef across owned buildings;
                                                     #   called on building_placed/sold/upgraded
```

**Depends on**: `SaveManager` (`Inventory`), `BuildingManager` (listens for
`building_placed`/`sold`/`upgraded` via `EventBus` to trigger
`recalculate_capacity`, rather than being polled).

**Emits**: `resource_amount_changed(resource_id, new_amount)`,
`resource_capacity_changed(resource_id, new_capacity)`,
`resource_storage_full(resource_id)`.

---

### 2.10 TutorialSystem (`TutorialManager`)

**Responsibility**: the onboarding FSM and the town-wide feature-lock gate
(`GAME_SYSTEMS.md` §11). This is the most cross-cutting system in the game — by
design, it is built **last** among the core managers (see §4) because it consults
nearly all of them.

**Public interface**:
```gdscript
func active_tutorial() -> TutorialDef
func is_locked(lock_kind: String, building_id: int = -1) -> bool   # single choke-point every
                                                                     #   other manager calls before
                                                                     #   permitting a locked action
func notify_event(event_name: String, params: Dictionary) -> void  # generic hook: build/assign/
                                                                     #   collect/gather/transport/
                                                                     #   useShop/marketBuy/marketSell/
                                                                     #   landSize/hurryShop/
                                                                     #   hurryBuilding/supply/friendView
func dismiss_message() -> void
```

**Depends on**: `DataManager` (`TutorialDef` table), `SaveManager`
(`TutorialProgress`), and — via `is_locked()` being called *into* it, not the
reverse — `BuildingManager`, `EconomyManager`, `WorkerManager`, `CurrencyManager`
all gate their mutating actions through a single `TutorialManager.is_locked(...)`
check before proceeding. This is the one sanctioned exception to "managers don't
depend on each other's internals" — every other manager depends on
`TutorialManager` being a pure yes/no gate, never the reverse.

**Emits**: `tutorial_started(id)`, `tutorial_objective_progressed(id, index,
current, required)`, `tutorial_completed(id)`, `tutorial_message_shown(text)`.

**Event wiring**: rather than `TutorialManager` polling other systems, every
manager above calls `TutorialManager.notify_event(...)` at the natural point an
action completes (e.g. `BuildingManager.place_building` calls
`notify_event("build", {building_id: def_id})` right after emitting its own
`building_placed` signal). This keeps `TutorialManager` as a passive observer
that never needs bespoke hooks into each other manager's internals.

---

## 3. Data-Driven Architecture: Resource vs Script vs Scene

This is the concrete answer to "what goes where," extending `DATA_MODEL.md`'s
schema definitions with a rule for every future content addition:

| Belongs in a **Resource** (`.tres`, `data/`) | Belongs in a **Script** (`systems/`, `autoload/`) | Belongs in a **Scene** (`scenes/`) |
|---|---|---|
| Every numeric/text constant recovered from XML: costs, times, XP, capacities, rates, prerequisites, text | The *rules* that interpret those constants: "how a recipe resolves," "how placement validity is computed," "how buffs stack and clamp" | The *visual/input* representation of one instance: a placed building's sprite + `AnimationPlayer`, a villager's walk animation, a popup's layout |
| `ResourceDef`, `BuildingDef`, `GatherRecipe`, `CraftRecipe`, `LandUpgradeDef`, `LevelDef`, `TutorialDef`, `VillagerSimConstants` (all from `DATA_MODEL.md`) | `EconomyManager`, `BuildingManager`, `WorkerManager`, `TutorialManager`, and their `systems/` support classes | `World.tscn`, `BuildingInstanceView.tscn`, `VillagerView.tscn`, all `ui/` scenes |
| Adding a new building = **author a new `.tres`**, zero code changes | Changing how construction validation works = **edit one script**, zero content changes | Changing how a building *looks* while under construction = **edit one scene**, zero rule changes |

**Test for any new field**: *"If this value changed, would a designer change it or
would a programmer change it?"* Designer-changeable → Resource. Programmer-only →
Script. *"Does this only exist to be looked at/clicked, with no bearing on whether
the player can afford or complete anything?"* → Scene.

This is the same separation the original game itself used (XML content vs. native
code vs. `.nib` UI layout, per `RECONSTRUCTION.md` §2) — we're not inventing a new
philosophy, we're reproducing the one already validated by the source material,
in Godot-native terms.

**Runtime state is the one exception worth naming explicitly**: `PlayerState`,
`Inventory`, `BuildingInstance`, `Villager`, `TutorialProgress` are *also*
`Resource`-derived classes (per `DATA_MODEL.md`), but they are never authored by a
designer and never shipped in `data/` — they're created empty by
`SaveManager.create_new_save()` and mutated only through manager methods, then
serialized to a save slot. Same base class (`Resource`), completely different
lifecycle and folder (`data_model/runtime/`, never `data/`).

---

## 4. Dependency Order

```
Foundation
  (Godot project scaffolding, autoload registration order, EventBus)
 ↓
Data loading
  (DataManager.load_all() — every _Def/Recipe table, validated)
 ↓
Save system
  (SaveManager — needs DataManager for new-game defaults;
   TimeManager — needs SaveManager for last_saved_at_unix)
 ↓
World system
  (World.tscn can render SaveGame.town_layouts + starting_layouts;
   no interactivity yet — pure read-and-display)
 ↓
Buildings
  (BuildingManager — placement/construction/upgrade against DataManager +
   SaveManager + a stub PrerequisiteEvaluator/CostLedger;
   InventoryManager needed alongside it for capacity checks)
 ↓
Economy
  (EconomyManager + CurrencyManager — recipe execution needs Buildings to exist
   first, since recipes run ON building instances;
   WorkerManager can come immediately after or alongside Economy, since gather
   recipes are worker-driven — Economy and Workers are co-dependent and are
   built as a pair, not strictly sequential)
 ↓
Workers
  (WorkerManager — assignment, homelessness/hunger, adoption;
   requires Buildings for assignment targets and Economy for output routing)
 ↓
UI
  (Build menu, HUD, popups — requires every manager above to have a stable
   public interface to call into; UI is the first layer that requires ALL
   prior systems, which is why it comes this late)
 ↓
Content
  (TutorialManager — the most cross-cutting system, requires every manager
   above to expose the notify_event/is_locked hooks; full content volume
   (every building/recipe/tutorial from the original) is only meaningful
   once the interpreter for that content — everything above — is proven
   correct against a small sample)
```

This matches `IMPLEMENTATION_ROADMAP.md`'s five phases exactly:
Foundation+Data loading+Save = **Phase 1**; World+Buildings = **Phase 2**;
Economy+Workers = **Phase 3**; UI+Content(Tutorials) = **Phase 4**; full content
volume + presentation + social = **Phase 5**. This document adds the
system-to-system dependency detail the roadmap's phases didn't need at that
level.

**Why this exact order and not another**: every arrow above is a genuine data
dependency, not a preference —
- `SaveManager` cannot create a default save without `DataManager`'s tables
  (starting resources, starting layout).
- `BuildingManager` cannot validate a placement cost without
  `SaveManager`/`InventoryManager` existing to check against.
- `EconomyManager` cannot execute a recipe without a `BuildingInstance` to attach
  it to, hence Buildings before Economy.
- `TutorialManager.is_locked()` is called *by* every other manager, so it must be
  the last one built — building it earlier would mean building it against
  interfaces that don't exist yet.

---

## 5. First Implementation Milestone — "Walking Skeleton"

The smallest slice that proves the architecture end-to-end, not the smallest
slice that's fun. Every box below must be true simultaneously; the milestone is
not done until all of them are, on the same run, in this order:

1. **Boot** — `DataManager.load_all()` succeeds loading a **minimal data set**:
   one `ResourceDef` (Wood, id 10), one `BuildingDef` (Logging Camp, id 8, with
   its real `GatherRecipe` per `GAME_SYSTEMS.md` §2), one `BuildingDef` for the
   starting Town Hall (id 1), and the real `starting_layouts["Vanilla"]` from
   `Layout.xml`. (Not the full ~1,800-line content set — that's Phase 5. The
   milestone proves the *pipeline*, not full content coverage.)
2. **New game** — `SaveManager.create_new_save()` produces a `SaveGame` with
   `Inventory.resource_amounts` seeded from `ResourceDef.start_value` for every
   loaded resource, and `town_layouts["Vanilla"]` populated from
   `starting_layouts["Vanilla"]` (the real fixed Town Hall + resource-tile
   positions from the original `Layout.xml`).
3. **Map renders** — `GameManager` transitions to `IN_GAME`, instantiates
   `World.tscn` for land `"Vanilla"`, and it renders the starting Town Hall plus
   the border resource tiles at their correct grid coordinates, sourced entirely
   from `SaveGame.town_layouts`, not hardcoded in the scene.
4. **Place one building** — through a minimal build-menu affordance (a single
   button is enough, full `BuildMenu.xml` categorization is not required yet),
   the player places a Logging Camp on a Forest resource tile.
   `BuildingManager.can_place`/`place_building` runs the real footprint,
   prerequisite (`level >= 1`), and cost (10 Gold, per `GAME_SYSTEMS.md` §2)
   checks against real `DataManager`/`SaveManager` state — not stubbed.
5. **Construction** — the Logging Camp instance shows a real
   `construction_started_at`; after its real `BuildTime` (3 seconds,
   `fadeAnim="y"`, per the source data) elapses per `TimeManager.is_elapsed()`,
   `BuildingManager` marks it complete and `EventBus` fires
   `construction_completed`.
6. **Produce one resource** — a stub `Villager` (does not need full
   `WorkerManager` assignment UI; a debug call to `WorkerManager.assign_worker`
   is acceptable here) is assigned as worker to the Logging Camp.
   `EconomyManager.start_gather` runs the real `GatherRecipe`
   (`villager_resources_per_hour = 50.0`), and Wood visibly accumulates in
   `InventoryManager` up to `max_output_stack_size` (150), gated correctly by
   `InventoryManager.capacity` (Town Hall's storage — 0 for Wood per its
   `<Resources>` block — meaning **this milestone must also prove the "storage
   full" block**, since the Town Hall alone cannot hold any Wood; either the
   milestone includes placing a Stockpile too, or explicitly demonstrates the
   correct "resource capped at 0, hauler has nowhere to deliver" failure state as
   proof the capacity system is real, not bypassed).
7. **Save/reload** — `SaveManager.save_to_slot` then `load_from_slot` on a fresh
   process reproduces **identical** state: same Wood amount, same Logging Camp
   `instance_id`/completion state/assigned worker, same Gold spent, with
   `TimeManager` correctly fast-forwarding any elapsed real time between save and
   reload (i.e., killing the game, waiting 30 real seconds, and reloading must
   show 30 seconds' worth of additional Wood production if a hauler path exists,
   proving the offline catch-up design in §2.4 works, not just that a
   `RESOURCE_SAVE_TYPE` file round-trips).

**Explicitly out of scope for this milestone** (deferred to later Phase 2–4
work, not needed to prove the architecture): full building roster, upgrade
chains, shop/craft recipes, land upgrades, buffs, tutorials, energy, currency
purchases, achievements, any UI polish, any real art/audio. The milestone's only
job is to prove every arrow in §4's dependency graph actually holds at runtime,
against real (if minimal) data, with a real save round-trip — everything else is
additive from here.

---

## 6. Assumptions Required Due to Missing Original Binary/Server

These are **architecture-level** assumptions (distinct from the **content-level**
gaps already tracked in `MISSING_INFORMATION.md` — cross-referenced below where
they overlap). Each is a deliberate design decision made because the native
binary or the live server cannot be consulted, stated here so it's never
mistaken for recovered fact.

1. **Wall-clock time, not a scaled game-day cycle.** Every original duration is
   in real seconds with no evidence of a day/night or accelerated-calendar
   system (§2.4). Assumption: `TimeManager`'s clock is real time; day/night, if
   built at all, is cosmetic only.
2. **Offline catch-up is computed at load, not simulated tick-by-tick while the
   app is closed.** The original was a live, server-synced game and may have
   computed offline progress server-side on next login; we have no way to
   observe that. Assumption: a deterministic `elapsed_seconds → catch_up()` pass
   per manager at load time is an equivalent, self-consistent replacement.
3. **Storage capacity aggregates by summing all owned storage buildings**
   (`MISSING_INFORMATION.md` #13) — an explicit BuildingManager/
   InventoryManager design decision with no server logic to confirm it against.
4. **Single active save/session model.** The original was a mobile,
   single-account, always-online game; nothing in the data implies multiple
   simultaneous towns per account beyond the two lands (Vanilla/Frontier), which
   this architecture already supports natively via `town_layouts` keyed by land.
   Assumption: one `SaveGame` = one player = both lands, no additional
   multi-account layer needed at the architecture level.
5. **Energy regeneration rate and max cap are invented placeholders**
   (`MISSING_INFORMATION.md` #9) — `EconomyManager`/`CurrencyManager` must not
   hardcode a "final" number; the constant lives in `data/constants/` precisely
   so it can be swapped without a code change once/if real evidence surfaces.
6. **Housing capacity per house tier is a placeholder table**
   (`MISSING_INFORMATION.md` #8) — `WorkerManager.housing_capacity()` sums a
   `house_capacity` field on `BuildingDef` that Phase 1's conversion tooling
   populates with a guessed value, isolated in data, not code, for the same
   reason as (5).
7. **Market pricing and hurry-cost curves beyond the flat sampled constants are
   original design**, not recovered — `EconomyManager`'s recipe-hurry and any
   future Market buy/sell implementation must be built as clearly-labeled new
   systems (per `RECONSTRUCTION.md` §6), not presented as faithfully recreated.
8. **Achievement engine is generic and content-seeded from inference, not from
   recovered trigger data** (`GAME_SYSTEMS.md` §12) — architecturally this means
   `TutorialManager`'s `notify_event` hook is deliberately reused/extended for a
   future `AchievementManager` (same event stream, different consumer) rather
   than achievements requiring their own bespoke instrumentation throughout every
   manager.
9. **No server-authoritative validation layer exists or is assumed.** Every
   manager above performs its own authoritative checks locally (cost, placement,
   prerequisites) because there is no external server to defer to and no anti-
   cheat model is in scope — this is a single-player-first architecture by
   construction (`RECONSTRUCTION.md` §6), and the Phase 5 social layer, if built,
   is explicitly additive on top rather than a redesign of this trust model.
10. **Save format choice (Godot native Resource serialization over JSON) is an
    implementation convenience**, not something dictated by the original (which
    used its own opaque, server-synced save format we have zero visibility into)
    — flagged so a future contributor doesn't go looking for a "correct" format
    to match; there isn't one to recover.

---

## Related Documents

- `docs/RECONSTRUCTION.md` — why, and the faithful-vs-modern-equivalent line
- `docs/GAME_SYSTEMS.md` — per-system original behavior and evidence
- `docs/DATA_MODEL.md` — the schemas this architecture loads and operates on
- `docs/IMPLEMENTATION_ROADMAP.md` — the five build phases this architecture
  implements
- `docs/MISSING_INFORMATION.md` — content-level open questions; §6 above lists
  only the architecture-level decisions layered on top of them
