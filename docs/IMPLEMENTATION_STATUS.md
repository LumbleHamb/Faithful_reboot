# Trade Nations — Implementation Status

Tracks what's actually been built, phase by phase, against
`docs/IMPLEMENTATION_ROADMAP.md` and `docs/ARCHITECTURE.md`. This document is
updated at the end of every implementation phase — read it before starting
new work to see exactly where the last phase left off.

---

## Phase 1 — Foundation: COMPLETE

Scope was deliberately narrow: a clean, verified Godot 4 project skeleton
with four core managers, four placeholder data-definition schemas, and a
save round-trip — no gameplay content, no UI, no buildings/economy/assets.
Every item below was verified to actually run (see "Verification," not just
asserted.

### What was completed

- Godot 4 project created at the repository root (`project.godot`), targeting
  Godot **4.7 stable** (confirmed installed and used for verification below).
- Four autoloads registered and working: `DataManager`, `TimeManager`,
  `SaveManager`, `GameManager` (see "Autoload order" below for why that's the
  registration order, not the order you asked for them in).
- Four placeholder content-definition schemas as Godot `Resource` classes:
  `ResourceDefinition`, `BuildingDefinition`, `ProductionRecipe`,
  `WorkerDefinition`.
- Three runtime save-data schemas: `PlayerState`, `InventoryState`,
  `SaveGame`.
- `scenes/Main.tscn` — boots, initializes managers, reaches
  `GameManager.State.MAIN_MENU`, and hosts two empty containers
  (`WorldContainer`, `UILayer`) reserved for Phase 2/4.
- A developer test scene (`tests/TestRunner.tscn` + `test_runner.gd` +
  `test_foundation.gd`, class `FoundationTests`) exercising: manager
  presence, `DataManager.load_all()` against an empty content set,
  `SaveManager` save→load→delete round-trip with real field data, and
  `TimeManager.now()/is_elapsed()/seconds_remaining()`.
- Folder structure exactly as requested (`scenes/`, `scripts/`, `systems/`,
  `data/`, `resources/`, `assets/`, `ui/`, `saves/`, `tests/`), with the
  still-empty ones documented via a `README.md` rather than a silent
  `.gitkeep` (see file list below).
- **An incident found and fixed during this phase**: see "Incident: Godot
  importing `original/`" below — important, read it.

### Files created

```
project.godot

scenes/Main.tscn
scripts/main.gd
scripts/autoload/data_manager.gd
scripts/autoload/time_manager.gd
scripts/autoload/save_manager.gd
scripts/autoload/game_manager.gd

resources/definitions/resource_definition.gd
resources/definitions/building_definition.gd
resources/definitions/production_recipe.gd
resources/definitions/worker_definition.gd
resources/runtime/player_state.gd
resources/runtime/inventory_state.gd
resources/runtime/save_game.gd

tests/TestRunner.tscn
tests/test_runner.gd
tests/test_foundation.gd

systems/README.md
data/resources/README.md
data/buildings/README.md
data/recipes/README.md
data/workers/README.md
assets/art/README.md
assets/audio/README.md
ui/README.md
saves/README.md

original/.gdignore     (empty marker — see Incident below)
research/.gdignore     (empty marker — see Incident below)
tools/.gdignore         (empty marker — see Incident below)
docs/.gdignore          (empty marker — see Incident below)

docs/IMPLEMENTATION_STATUS.md   (this file)
```

`*.gd.uid` files alongside every script are Godot 4.7's own auto-generated
resource-reference sidecars (a stable-id mechanism introduced in Godot
4.4+) — expected, harmless, and meant to be committed alongside their
`.gd` file, same as `.import` files for real assets.

Nothing pre-existing was modified. `original/`, `research/`, `tools/`, and
the prior `docs/*.md` content were only ever added to, never edited.

---

### Incident: Godot importing `original/` — found and fixed

Running Godot's import step for the first time (`godot --headless --path .
--import`) revealed that because the Godot project root **is** the
repository root, Godot's editor filesystem scanner walked into
`original/TradeNations.app/` and generated **151 `.import` sidecar files**
next to the original PNGs — new files inside a directory I was explicitly
told never to modify.

This was caught before it was reported as done, not after:
1. Deleted all 151 generated `.import` files under `original/` (verified via
   `git status --short original` returning clean afterward — they were
   untracked, so nothing to revert, just delete).
2. Added an empty `.gdignore` marker file to `original/`, `research/`,
   `tools/`, and `docs/` — Godot's documented, standard mechanism for
   excluding a directory from editor scanning/import entirely. This is the
   same idiom used to exclude vendored/reference folders in other engines
   (e.g. `node_modules`, `vendor/`) — not a workaround, a first-class
   feature for exactly this situation.
3. Cleared `.godot/` (Godot's own gitignored cache) and re-ran the import
   headlessly. Confirmed **zero** `.import` files appear under
   `original/`/`research/`/`tools/`/`docs/` on a fresh scan, and confirmed
   via `git status` that only the four new `.gdignore` files show up there
   — no other original content touched.

**Why `.gdignore` markers rather than moving the Godot project into its own
subfolder** (the other real fix): `.gdignore` is zero-byte, additive-only,
committed to git so the protection survives every future clone/session
without relying on anyone remembering it, and is Godot's own supported
answer to "this directory exists on disk near my project but isn't part of
it." Moving ~20 just-created project files into a new subfolder was the
more invasive option for the same guarantee. Flagging this choice explicitly
in case a future phase would rather restructure — it's easy to revisit,
nothing depends on the repo-root project location yet.

---

### Verification actually performed (not just claimed)

Godot 4.7.stable was found installed locally and used to genuinely run the
project, headlessly, from this session:

```
godot --headless --path . --import              # clean reimport, confirmed
                                                  #   zero .import files under
                                                  #   original/research/tools/docs
godot --headless --path . tests/TestRunner.tscn  # ran the full FoundationTests suite
```

Result: **all 20 checks passed**, exit code 0 —

```
[GameManager] Boot sequence starting.
[DataManager] Loaded 0 resource defs, 0 building defs, 0 recipes, 0 worker defs.
[GameManager] Boot complete. State = MAIN_MENU.
[FoundationTests] PASS: DataManager autoload is present
[FoundationTests] PASS: SaveManager autoload is present
[FoundationTests] PASS: TimeManager autoload is present
[FoundationTests] PASS: GameManager autoload is present
[FoundationTests] PASS: GameManager reached MAIN_MENU after boot
[FoundationTests] PASS: DataManager.load_all() completes and sets is_loaded()
[FoundationTests] PASS: resource_definitions index exists
[FoundationTests] PASS: building_definitions index exists
[FoundationTests] PASS: production_recipes index exists
[FoundationTests] PASS: worker_definitions index exists
[SaveManager] Saved slot 999 to user://saves/slot_999.tres
[FoundationTests] PASS: SaveManager.save_to_slot() writes without error
[SaveManager] Loaded slot 999 from user://saves/slot_999.tres
[FoundationTests] PASS: SaveManager.load_from_slot() reads a save back
[FoundationTests] PASS: Loaded PlayerState.mayor_level round-trips
[FoundationTests] PASS: Loaded PlayerState.xp_total round-trips
[FoundationTests] PASS: Loaded InventoryState.resource_amounts round-trips
[FoundationTests] PASS: TimeManager.now() returns a positive Unix timestamp
[FoundationTests] PASS: is_elapsed() is false for a duration far in the future
[FoundationTests] PASS: is_elapsed() is true once duration has passed
[FoundationTests] PASS: seconds_remaining() returns a sane in-range value
[FoundationTests] ALL TESTS PASSED
```

Also separately ran the *actual* main scene (`godot --headless --path .`,
no scene argument, so it uses `project.godot`'s `run/main_scene`) and
confirmed the real boot path:

```
[GameManager] Boot sequence starting.
[DataManager] Loaded 0 resource defs, 0 building defs, 0 recipes, 0 worker defs.
[GameManager] Boot complete. State = MAIN_MENU.
[Main] Scene ready. GameManager state = MAIN_MENU
```

(That run was force-terminated afterward via an external timeout since
`Main.tscn` has no quit condition by design; the `ERROR: BUG: Unreferenced
static string...` lines that follow in that log are Godot's own
engine-teardown noise from being killed mid-shutdown, not a defect — they
do not appear in the clean `TestRunner` exit above, which quits itself
normally with exit code 0.)

The `user://saves/slot_999.tres` file created during the test was deleted
by `FoundationTests._test_save_round_trip()` itself (it calls
`SaveManager.delete_slot()` at the end) — nothing was left behind in
Godot's user-data directory, and nothing was ever written under
`res://saves/` (confirmed empty except its `README.md`).

**To re-run this verification yourself**: open the project in Godot 4.7+,
open `tests/TestRunner.tscn`, press F6 ("Run Current Scene"). Or headlessly:
`godot --headless --path . tests/TestRunner.tscn`.

---

### Architecture decisions made this phase

Each of these is a real judgment call made while implementing — flagged here
so a future phase (or you, reviewing) can revisit any of them explicitly
rather than discover them by reading code.

1. **`EventBus` deliberately NOT created this phase**, despite
   `docs/ARCHITECTURE.md` §4 listing it first under "Foundation." It would
   ship with zero declared signals and zero consumers until Phase 2's
   `BuildingManager`/`EconomyManager` exist to emit into it — exactly the
   "placeholder to look finished" you told me to avoid. Deferred to the
   start of Phase 2, when the first real signal is needed.
2. **Folder-naming reconciliation**: your Phase 1 message asked for
   `resources/` where `docs/ARCHITECTURE.md` had called it `data_model/`,
   and asked for `scripts/` where the blueprint had `autoload/`. Mapped as:
   `resources/definitions/` + `resources/runtime/` = the blueprint's
   `data_model/`; `scripts/autoload/` = the blueprint's `autoload/`. No
   functional difference, just a naming reconciliation, done so both your
   literal folder list and the blueprint's structure are simultaneously
   satisfied.
3. **`ProductionRecipe` unifies GATHER and CRAFT** (the two distinct
   original production mechanics from `docs/GAME_SYSTEMS.md` §2) into one
   schema with a `kind` enum, rather than two separate classes — you asked
   for one `ProductionRecipe` placeholder, and this mirrors the same
   one-schema-multiple-kinds pattern already used for `BuildingDefinition`
   (and by the original data itself, which overloads one `<Object>` tag for
   everything).
4. **`WorkerDefinition` maps to the original's static villager *constants*
   and job-type flavor** (`docs/DATA_MODEL.md`'s `VillagerSimConstants`),
   not to a per-instance runtime villager (`docs/DATA_MODEL.md`'s
   `Villager`). Reasoning: it was requested alongside three other
   *content-definition* schemas (Resource/Building/ProductionRecipe), and a
   per-instance runtime villager is save-data, not content — it belongs
   next to `PlayerState`/`InventoryState` once `BuildingSystem`/
   `WorkerSystem` exist to give it something to be assigned to (Phase 2/3).
5. **`BuildingDefinition`/`ProductionRecipe` use plain `Dictionary`/`Array`
   for cost/prerequisite shapes**, not dedicated `CostBundle`/
   `PrerequisiteSet` Resource types from `docs/DATA_MODEL.md` §0. Those
   shared primitives are real infrastructure worth building once **two**
   definition types actually need to share behavior around them (Phase 2,
   when `BuildingSystem`'s placement logic and `EconomyManager`'s recipe
   logic both need real cost/prerequisite evaluation) — building them now,
   against only unused placeholder schemas, would be infrastructure ahead
   of a second real consumer.
6. **Gold-duality resolved exactly per `docs/DATA_MODEL.md` §5**:
   `PlayerState` has no `currency_gold` field. Gold lives only in
   `InventoryState.resource_amounts[<Gold's id>]`; only `MagicBeans` (which
   has no original `Resources.xml` id at all) lives on `PlayerState`.
7. **Save format is Godot native `Resource` serialization (`.tres`)**, not
   JSON — per the reasoning in `docs/ARCHITECTURE.md` §2.3: `SaveGame` is
   already a typed `Resource` tree, so `ResourceSaver`/`ResourceLoader`
   round-trip it with no hand-written (de)serializer. Confirmed working in
   the verification run above.
8. **`saves/` (in the project source tree) is NOT the runtime save
   location** — `SaveManager` targets `user://saves/`, Godot's
   platform-specific writable directory, because `res://` becomes read-only
   in an exported build. `res://saves/` exists only because you asked for
   it in the folder list; it's documented (`saves/README.md`) as reserved,
   not wired to anything, to prevent a real bug (writing into a read-only
   packed path) rather than silently building something that would break
   on export.
9. **Autoload registration order is `DataManager → TimeManager →
   SaveManager → GameManager`**, not the order listed in your message
   (`GameManager, DataManager, SaveManager, TimeManager`). Godot initializes
   autoloads in `project.godot` listing order, and `SaveManager.
   create_new_save()` calls `TimeManager.now()` — so `TimeManager` must be
   registered before `SaveManager`. `GameManager` is last since its own
   `_ready()` immediately drives `DataManager.load_all()`. Purely a
   dependency-correctness fix, no behavioral difference intended.
10. **`GameManager.start_new_game()`/`continue_game()` do not yet
    instantiate a world scene** — there is no `World.tscn` to instantiate
    until Phase 2. Both methods are real (they do drive `SaveManager`
    correctly, as proven by the test's save round-trip going through
    `create_new_save()`), just incomplete by design, with `TODO (Phase 2)`
    comments marking exactly where that hookup goes.

---

### Remaining Phase 1 / immediate next-phase tasks

Not done in this phase, and why:

- **XML → `.tres` conversion tooling** (`docs/IMPLEMENTATION_ROADMAP.md`
  Phase 1.3) — not built yet. `DataManager.load_all()` is proven to work
  correctly against an empty `data/` tree; pointing it at real converted
  content is the natural first task of Phase 2, not Phase 1's foundation
  goal.
- **`CostBundle`/`PrerequisiteSet`/`CostEntry`/`Prerequisite` shared
  primitive Resource types** (`docs/DATA_MODEL.md` §0) — deferred per
  decision #5 above.
- **`EventBus`** — deferred per decision #1 above.
- **`systems/` support classes** (prerequisite evaluator, cost ledger,
  economy/building/worker/tutorial helpers) — nothing to support yet; first
  needed by Phase 2's `BuildingSystem`.
- **World scene / land rendering, building placement, everything in
  `docs/IMPLEMENTATION_ROADMAP.md` Phase 2 onward** — explicitly out of
  scope for this phase per your instructions ("do not add buildings,
  economy, or assets yet").
- **`SaveGame.world_state`** stays an empty `Dictionary` placeholder until
  Phase 2's `BuildingInstance`/`TownLayout`/`Villager` runtime schemas exist
  to populate it.

---

## Phase 2 — Not started

See `docs/IMPLEMENTATION_ROADMAP.md` and `docs/ARCHITECTURE.md` §4 for scope
(World/Placement/Buildings). Do not begin without review of Phase 1 above.
