# Trade Nations — Implementation Roadmap

Target engine: **Godot 4.x**. This roadmap sequences work so that each phase produces
something runnable/testable before the next begins, and so that no phase requires
reverse-engineering anything new mid-implementation — all design decisions this
roadmap depends on are already made in `RECONSTRUCTION.md`, `GAME_SYSTEMS.md`, and
`DATA_MODEL.md`. Anything still open is listed in `MISSING_INFORMATION.md`; where a
phase touches an open question, it's called out explicitly with the placeholder
approach to take instead of blocking.

This document plans work. **No gameplay code is written as part of producing this
roadmap** — implementation begins only once this blueprint is reviewed.

---

## Phase 1 — Godot Project Foundation

Goal: an empty-but-structured Godot project that can load every static data table
from `DATA_MODEL.md` and persist/restore a `SaveGame`, with nothing playable yet.

**1.1 Project scaffolding**
- Create the Godot project (folder convention: `res://data/`, `res://systems/`,
  `res://scenes/`, `res://ui/`, `res://art/`, `res://audio/`).
- Set up version control hygiene for the new project (separate from `original/`,
  which stays untouched and read-only forever).
- Decide and document a naming convention mapping original numeric ids (building id,
  resource id, item id) to Godot resource file names — ids must stay stable per
  `DATA_MODEL.md`'s "KEEP STABLE" annotations, since Tutorials/BuildMenu/
  PrerequisiteMappings all cross-reference by id.

**1.2 Core managers (singletons/autoloads)**
- `ContentDB` — loads and indexes all static `Resource` tables
  (`ResourceDef`, `BuildingDef`, `GatherRecipe`, `CraftRecipe`, `LandUpgradeDef`,
  `LevelDef`, `TutorialDef`, `VillagerSimConstants`) by id at startup.
- `SaveManager` — serialize/deserialize `SaveGame` to/from disk, versioned per
  `SaveGame.save_version`.
- `PrerequisiteEvaluator` — generic evaluator for `PrerequisiteSet` against current
  `PlayerState`/owned buildings/completed tutorials. One implementation, reused by
  Buildings, Items, and Tutorials, matching the original's own shared vocabulary
  (`GAME_SYSTEMS.md` "Cross-System Notes").
- `CostLedger` — generic apply/can-afford check for `CostBundle` against
  `PlayerState`/`Inventory`. One implementation for Cost, Sell, Reward,
  AlternateCost.

**1.3 Data conversion pipeline**
- Write (one-time, tooling-only, not shipped gameplay code) conversion scripts that
  parse the original XML/JSON in `original/TradeNations.app/bundle/` and emit
  `.tres`/`.json` resource files matching `DATA_MODEL.md` schemas. Converters are
  throwaway tooling, kept in a `tools/` or `import/` directory, clearly separated
  from runtime game code.
- Convert, in order of dependency: `Resources.xml` → `ResourceDef` table;
  `Objects.xml` manifest + all `Vanilla_*`/`Crossover_*`/event XML → `BuildingDef`
  table; `Items.xml` → `CraftRecipe` + `LandUpgradeDef` tables; `Settings.xml` →
  `LevelDef` table + `VillagerSimConstants` + energy/buff constants;
  `Tutorials.xml` → `TutorialDef` table; `Skins.xml` → skin/reskin table;
  `Layout.xml`/`LayoutTrade.xml` → starting `TownLayout`.
- Validate the conversion by round-tripping every numeric constant called out in
  `GAME_SYSTEMS.md` (spot-check a sample of buildings/recipes against the source XML
  values) before treating the converted tables as ground truth for all future work.

**1.4 Save system**
- Implement `SaveGame` read/write with a fresh-player default (starting resources
  per `ResourceDef.start_value`, starting `TownLayout` from converted `Layout.xml`,
  level 0, tutorial progress empty).
- No UI yet — verified via unit-style tests or a debug console print of loaded
  state.

**Exit criteria**: a script can boot the project, load all content tables, create a
new save with correct starting values, save it, reload it, and get back identical
state.

---

## Phase 2 — Map / World / Placement / Buildings

Goal: a player can see their town, place buildings from the converted data, and
watch construction timers run — no production/economy yet.

**2.1 Map/world**
- Tile-grid world scene sized to the player's current land (`PlayerState.owned_lands`
  → `TownLayout` size). Support the two known lands (`Vanilla`, `Frontier`) as
  separate layouts per `BuildingDef.compatible_lands`.
- Render starting `TownLayout.resource_tiles` and `starting_objects` from the
  converted `Layout.xml` (Forest/Mountain tiles at the fixed border positions, Town
  Hall at the fixed start position — exact original coordinates).
- Camera/scroll/zoom sufficient to navigate a land up to the largest confirmed size
  (`Items.xml` land-upgrade `value` progression tops out over 120+ tiles per side in
  observed data — confirm full ceiling during Phase 1 conversion).

**2.2 Placement**
- Build-menu UI stub (functional, not styled) listing `BuildingDef` entries filtered
  by `BuildMenu.xml`'s four categories (Buildings/Decorations/Upgrades/Land) and
  gated by `PrerequisiteEvaluator`.
- Placement validation: footprint (`width`/`height`) collision against occupied
  tiles and land bounds; `owned_limit` enforcement; `CostLedger` deduction on
  confirm.
- Building instance creation → `BuildingInstance` with `construction_started_at` set,
  `construction_complete = false` until `build_time_seconds` elapses.
- Selling: reverse of placement, refunding `sell` `CostBundle`, blocked when
  `sell` is empty/false (Town Hall tiers) per `GAME_SYSTEMS.md` §3.

**2.3 Buildings (structural, not economic yet)**
- Upgrade flow: selecting an owned building with a matching `upgrade_of_id` target
  replaces the instance in place once prerequisites + cost are met; enforce
  `upgrade_only` (some buildings, e.g. Tower/Keep/Fort, can never be freshly built).
- Land-upgrade flow: purchasing a `LandUpgradeDef` (gold or magic-beans path per
  `DATA_MODEL.md` §3) grows the active land's `TownLayout` size and re-renders
  bounds.
- Basic skin application: `active_skins` swaps which sprite-name prefix set is used
  per `Skins.xml` — since original art isn't decoded yet (see
  `MISSING_INFORMATION.md`), use placeholder art keyed the same way, so the system is
  provably wired correctly ahead of real assets.

**Exit criteria**: player can start a new game, see the starting town, place/sell/
upgrade buildings with correct cost/prerequisite/footprint enforcement, purchase a
land upgrade and see the buildable area grow, all against placeholder art.

---

## Phase 3 — Economy Simulation / Production / Workers

Goal: the actual "trade nations" loop — resources flow, shops convert them to
gold/XP, villagers do the work — running correctly against a placeholder UI.

**3.1 Resource & storage simulation**
- `Inventory.resource_amounts` updates from production, purchases, sales; capacity
  enforcement from `Inventory.resource_capacity` (summed `StorageDef.capacities`
  across owned storage buildings, per the documented design decision in
  `DATA_MODEL.md` §6).
- Overflow behavior when storage is full: block further production accumulation
  past `GatherRecipe.max_output_stack_size` / capacity, matching the original's
  implied "resources full" state (referenced by the `Resources Full` /
  `Need Resource` tutorial-lock UI strings).

**3.2 Villagers**
- Population derived from housing capacity (house `BuildingDef` instances) — **the
  exact per-house capacity number is an open gap** (see `MISSING_INFORMATION.md`);
  implement the system generically against a `house_capacity` field on
  `BuildingDef` sourced from Phase 1's conversion, with a clearly-flagged placeholder
  value until the real number is found, so the mechanic (not just the constant) is
  validated now.
- Assignment UI stub: assign an idle villager as worker or hauler to a specific
  `BuildingInstance`, respecting `GatherRecipe.worker_max`/`hauler_max`.
- Homelessness penalty (`homeless_modifier`) and hunger cycle
  (`eat_time_seconds`/`hunger_length_min`/`max`) implemented per
  `VillagerSimConstants`, affecting worker output rate.

**3.3 Production**
- `GatherRecipe` execution: worker-driven passive accumulation at
  `villager_resources_per_hour`; direct mayor action consuming energy at
  `worktime` seconds per Settings.xml `<Energy>`, yielding `mayor_resources` (or
  `mayor_resources_no_energy` when energy is exhausted — kept faithful to the
  original's apparent 0-value placeholder per `GAME_SYSTEMS.md` §2, flagged rather
  than "fixed").
- `CraftRecipe` execution (shops): start recipe (consume input `Cost`), run
  `time_seconds`, on completion grant `reward` (XP + Gold), support `hurry_cost` /
  `hurry_interval` early-completion.
- Buff aggregation: sum active `BuffDef` bonuses by category (per
  `GAME_SYSTEMS.md` §4), clamp at the 500% `MaxBuffer` ceiling from `Settings.xml`,
  apply to shop XP/Gold rewards at completion time.

**3.4 Energy & progression wiring**
- Energy pool spend/regen (regen rate is a **placeholder** pending
  `MISSING_INFORMATION.md` resolution), building-hurry energy cost
  (`buildingHurryCost`/`buildingHurryInterval`).
- XP accrual from construction (`xp_value`) and shop completion (`reward.xp`) driving
  `mayor_level` via the `LevelDef` threshold table; apply `max_building_by_category`
  caps and level-up `reward` (typically energy) automatically on level-up.

**Exit criteria**: a full gather → haul → store → craft → sell/collect loop runs
correctly end to end with real numbers from the converted data, villagers can be
assigned and show homelessness/hunger effects, and the mayor levels up correctly
from real XP sources.

---

## Phase 4 — UI / Tutorials / Progression

Goal: the game is actually playable start-to-finish by a new player, guided the same
way the original guided players.

**4.1 Tutorial engine**
- Implement `TutorialManager` consuming `TutorialDef`/`TutorialProgress` per
  `DATA_MODEL.md` §8: trigger evaluation (`always`/`build`/`select`), objective
  progress tracking across the 13-verb vocabulary (`GAME_SYSTEMS.md` §11), and lock
  enforcement — gating `buildings`/`energy`/`workers`/`haulers`/`sell`/`world`/
  `consumables`/`friendShop` actions through the same `PrerequisiteEvaluator`-style
  central check used everywhere else, with per-building `Allow` exceptions.
- Since this system gates nearly every other system, build it directly against the
  Phase 2/3 systems already in place rather than mocking them — this is why
  Tutorials is Phase 4, not earlier.

**4.2 UI**
- Real (still simple, not final-art) UI for: build menu, building info/upgrade
  popups, resource bar, market buy/sell, mayor level/XP bar, energy indicator,
  tutorial message/objective display, villager assignment.
- Wire the original's UI text pool content where recoverable (`tradenations.xml`
  textpool keys — full string *values* still pending per
  `MISSING_INFORMATION.md`; use placeholder/rewritten strings where the value table
  isn't available, clearly distinct from any original-string content that is
  confirmed).

**4.3 Progression polish**
- Level-up celebration flow using `LevelDef.level_text`.
- Achievement engine (per `GAME_SYSTEMS.md` §12 — explicitly **new design**, not
  recovered data): generic "counter reaches threshold" system, seeded with an
  original milestone list inspired by surviving asset names
  (`FIVE_FARMS`, `TEN_FRIENDS`, `WEALTHY_*`, etc.), clearly documented as
  reboot-original content in any player-facing changelog/credits.

**Exit criteria**: a new player can start a game, be walked through the original
tutorial sequence, build up a town, level up, and hit an achievement, entirely
through in-game UI with no debug tools required.

---

## Phase 5 — Polish / Animations / Audio / Multiplayer (Self-Hosted Services)

Goal: production quality pass, plus the explicitly-deferred networked/social layer,
built as opt-in and self-hosted rather than assumed.

**5.1 Animations & art**
- Resolve the `.RAW`/`.z2raw`/`.bin` custom formats (see
  `MISSING_INFORMATION.md`) or make the final call to redraw art from scratch;
  either path replaces the Phase 2–4 placeholder art without changing any gameplay
  schema (art is purely a presentation-layer swap against the same `BuildingDef`
  animation-name fields).
- Implement the seasonal skin-swap visuals (`Skins.xml` prefix system) with real
  art once available.

**5.2 Audio**
- Import and wire `.caf` sound effects/music per the converted `Sounds.xml` table
  (id → filename/volume/isMusic), covering UI sounds, building select/buy/sell,
  villager voice barks (`VillagerSounds` weighted gender tables), and the title
  theme.

**5.3 Self-hosted multiplayer/social layer (opt-in, isolated from base game)**
- Design and stand up an original backend (owned end-to-end, no assumption of
  Z2Live-compatible protocol) for: friends list, mail/gifting, leaderboards
  (reusing the request/response *shape* documented from
  `Z2/Scripts/Leaderboard/LeaderboardService.lua` as inspiration, not a literal
  protocol clone), and player-to-player trading (protocol is **new design**, since
  none survives — see `GAME_SYSTEMS.md` §13).
- Market buy/sell rate design: replace the unrecoverable original pricing formula
  with a chosen modern approach (fixed rates, or simple supply-tracking dynamic
  rates) — a deliberate design decision, documented as such, not a recovered fact.
- This phase is explicitly optional/deferrable — the base game (Phases 1–4) must be
  fully playable single-player without it.

**Exit criteria**: full audio/visual presentation pass complete; if pursued, a
working self-hosted social/trading layer that the base game can run entirely
without.

---

## Phase Ordering Rationale

Phases are ordered by dependency, not by original-feature importance:
Foundation → Placement → Economy → Guidance/UI → Presentation/Social, because each
later phase's systems (per `GAME_SYSTEMS.md`'s "Dependencies" sections) require the
previous phase's systems to already exist — most visibly, Tutorials (Phase 4) touch
essentially every system and so must come after Buildings/Economy (Phases 2–3), and
the social layer (Phase 5) is isolated last specifically because it depends on
infrastructure we don't control and must never block the core loop.
