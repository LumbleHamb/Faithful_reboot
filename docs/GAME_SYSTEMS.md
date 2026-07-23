# Trade Nations — Game Systems Reference

For each system: **original behavior** (what the data says it did), **source
evidence** (exact file/tag), **dependencies** (other systems it needs), and
**planned recreation approach**. Read `RECONSTRUCTION.md` first for the philosophy
governing "faithful" vs "modern equivalent" calls made below.

All file paths are relative to `original/TradeNations.app/bundle/` unless stated
otherwise.

---

## 1. Resources

**Original behavior**

Two tiers of materials plus Gold:

- **Gold** (id 1) — universal currency, `startValue="75"`, `scoreValue="1"`,
  effectively infinite storage (every building's `<Resources>` block lists Gold as
  `qty="unlimited"`).
- **Tier 1 (raw, gathered directly)**: Wood (id 10), Rock (id 20), Wheat (id 40),
  Wool (id 50).
- **Tier 2 (refined, produced from tier 1)**: Lumber (id 11, from Wood), Cut Stone
  (id 21, from Rock), Cloth (id 51, from Wool). Wheat has no tier-2 refinement listed.
- Each resource has: a `scoreValue` (used in some net-worth/score calculation we don't
  have the formula for), a `startValue` (starting inventory), sprite refs for a
  stacked-pile visual and a single-item visual, a "hauler" carry animation id, big and
  small menu icons, a compact icon font glyph (for space-constrained UI, e.g. `~` for
  Wood, `&` for Rock), and a collect sound effect id.
- A commented-out `Ore` resource (id 30) exists in the file but is disabled —
  evidence of a cut/unfinished resource.

**Source evidence**

- `Resources.xml` — full resource table (lines 1–71 read in full).

**Dependencies**

- Feeds: Production Chains, Buildings (storage `<Resources qty=.../>`), Shop Items
  (recipes consume resources), Market (buy/sell), Land Upgrades / Item costs, Tutorial
  objectives (`collect`, `gather`, `transport`, `marketBuy`, `marketSell`).

**Planned recreation approach**

Faithful. Model as a `ResourceDef` resource (Godot `Resource` script) per id, load
straight from a converted `resources.json`/`.tres` table (see `DATA_MODEL.md`). Keep
ids stable to match all other XML cross-references. Reintroduce the disabled `Ore`
only if a specific reason arises (e.g. a new production chain); otherwise omit it but
leave the id gap documented so it's clear it's deliberate.

---

## 2. Production Chains

**Original behavior**

Two distinct production mechanics coexist:

1. **Mine-style single-resource gathering** (`type="mine"`): a building
   (Logging Camp, Quarry, Farm, Pen, later Gold Panner) has one `<Produce>` block:
   - `hurryCost` — energy/currency cost to instantly finish current production.
   - `<Output resource_id maxOutputStackSize>` — what it makes and the max it can
     bank before a hauler must clear it.
   - `<Rate resourcesPerHour villagerResourcesPerHour mayorResources
     mayorResourcesNoEnergy>` — passive production rate is 0 in every sampled
     example; production only happens via an assigned villager
     (`villagerResourcesPerHour`) or a direct mayor action
     (`mayorResources`/`mayorResourcesNoEnergy`, energy-gated vs free).
   - Example (Logging Camp, id 8): `villagerResourcesPerHour="50.0"`,
     `mayorResources="50"`, `mayorResourcesNoEnergy="0"` (comment notes this should be
     5 "once energy works" — i.e. even the shipped data has an acknowledged
     placeholder/bug).
   - Requires a `WorkerType` (flavor label, e.g. "Wood Cutter") and
     `<Workers workerMax haulerMax>` slot counts (every sampled mine: 1 worker + 1
     hauler max).
2. **Shop-style multi-recipe crafting** (`type="shop"`, e.g. Baker Shop id 35, Flower
   Shop id 199, Book Shop id 165): the building itself has no `<Produce>` block.
   Instead it lists `<Item>` references (e.g. Baker Shop → items 40, 41, 33, 42, 44,
   43, 45) pointing at `type="shopItem"` entries in `Items.xml`. Each shop item is a
   full recipe:
   - `time` (seconds to complete)
   - `<Cost><Resource id=X>qty</Resource></Cost>` — input resource(s) consumed
     (usually a tier-1 or tier-2 resource matching the shop's theme, e.g. Wheat for
     the Bakery)
   - `<Reward xp="N"><Resource id="1">gold</Resource></Reward>` — XP and Gold output
   - `<HurryCost timeInterval="S">N</HurryCost>` — cost (implied currency/energy) to
     skip `timeInterval` seconds of remaining time
   - `Prerequisite type="level"` gating which recipes are available yet
   - Confirmed example chain (Baker Shop): Cookies (45s, 1 Wheat → 5 XP + 10 Gold),
     Tarts (300s, 4 Wheat → 15 XP + 25 Gold), Donuts (3600s, 30 Wheat → 60 XP + 110
     Gold), Cupcakes (14400s, 200 Wheat → 200 XP + 200 Gold), Eclair (43200s, 350
     Wheat → ...). Reward scales sub-linearly with cost as time increases — a
     deliberate idle-game pacing curve, not a fixed ratio.
   - This is the actual "trade nations" economic engine: shops are where raw/refined
     resources convert into Gold and XP, and decorations buff this conversion (see
     Decorations/Buffs below).

**Source evidence**

- Mine pattern: `Vanilla_BuildingsTo10.xml` lines 120–204 (Logging Camp, Quarry, Pen),
  `Frontier_Launch.xml` lines 10–35 (Gold Panner).
- Shop pattern: `Vanilla_BuildingsTo10.xml` lines 724–782 (Baker Shop, Flower Shop
  `<Item>` lists); `Items.xml` lines 373–432 (`type="shopItem"` Cookies/Tarts/
  Donuts/Cupcakes/Eclair full definitions).

**Dependencies**

- Resources (inputs/outputs), Workers/Haulers (mine production requires an assigned
  worker; output requires a hauler to move it to storage), Buildings (recipes are
  attached to a specific shop building), Energy (mayor-direct actions cost energy),
  Decorations/Buffs (modify XP/Gold reward), Progression (`Prerequisite type="level"`
  gates recipe/building availability).

**Planned recreation approach**

Faithful for both patterns. Model as two recipe kinds sharing a base "Recipe" schema
(see `DATA_MODEL.md`): `GatherRecipe` (mine, single output, worker/mayor driven) and
`CraftRecipe` (shop item, resource-cost → time-gated → XP+Gold reward, hurry-able).
Carry over every numeric constant we have. Where `mayorResourcesNoEnergy="0"` looks
like an unfinished/placeholder value in the original, keep it as-is for faithfulness
but flag it in `MISSING_INFORMATION.md` rather than "fixing" it silently.

---

## 3. Buildings

**Original behavior**

A building (`<Object>`) is the universal placeable-entity schema, used for
town halls, mines, shops, houses, decorations, storage, market, and even
non-building set-pieces (skin-switch triggers, resource tiles). Common attributes
across all observed types:

- `id`, `name`, `width`/`height` (footprint in tiles), `type` (see type list below),
  `availableFromStore` (0/1 — sellable via `TownhallStore`/`ItemOfTheDay`?),
  `upgradeID`, `xpValue` (one-time XP granted on construction).
- `category` (optional; e.g. `category="shop"`, used for level-up `MaxBuilding`
  caps).
- `<Prerequisite type="level|building|tutorial|rewardUnlockable">` — one or more
  gating conditions, ANDed together.
- `<Cost>` — one or more `<Resource id>` amounts and/or `<MagicBeans>` (premium
  currency cost, used for some late-game/DLC buildings like the Warehouse).
- `<BuildTime>` (seconds; `fadeAnim="y"` attribute on some, purpose unconfirmed —
  likely controls a visual fade-in vs scaffold animation).
- `<Sell>` — either resource refund amounts, or literally `false` for buildings that
  can never be sold (all Town Hall tiers).
- `<Resources>` — per-resource storage capacity for this specific building instance
  (`qty="unlimited"` or a number or `qty="0"` meaning "does not store this
  resource"). This is how Town Hall/Stockpile/Warehouse storage-tier upgrades work
  (see Storage section).
- `<UpgradeOf upgradeOnly="true|absent">id</UpgradeOf>` — marks this as an in-place
  upgrade of another building id; `upgradeOnly="true"` means it can never be
  freshly built, only reached via upgrade.
- `<Limit>N</Limit>` — max count of this building the player may ever own (seen as
  `1` on Town Hall tiers and unique decorations).
- `<CompatibleLand>Vanilla|Frontier|All</CompatibleLand>` — which land(s) this
  building is valid on.
- Visual/audio hooks: `<IdleAnim>`, `<BuildMenuAnim>`, `<ConstructionAnim>`,
  `<BuildingWorkAnim male= female= maleIdle= femaleIdle=>`, `<Sounds select=
  buy= sell=>`.
- `<MaxTouchAreaExtension>` — touch-hit-testing tweak for tall buildings.
- `<Info>` / `<Description>` — player-facing flavor and instructional text.

**Observed `type` values** (from a grep across all bundle XML): `townhall`, `mine`,
`shop`, `store` (stockpile/warehouse), `market`, `decoration`, `house`,
`resourcetile` (non-buildable terrain feature, e.g. Forest/Mountain/Mountain Lake),
`present` (holiday gift box with a real-world unlock date, see `FinishTime` below),
`misc`, `skinswitch` (Frosty the Snowman — triggers a land-wide reskin),
`entertainer`, `river`, `hotairballoon`, `tree`.

**Building progression chain example (Town Hall line)**: Town Hall (id 1, free,
starting building) → Tower (id 2, level 4) → Keep (id 3, level 6) → Fort (id 4, level
10) → ... each strictly gated by `Prerequisite type="level"` + `type="building"`
(must own the previous tier) and each `<UpgradeOf upgradeOnly="true">` so it replaces
rather than adds to the town hall count. The Frontier land has a parallel chain
(Ridge Post id 303 → Mountain Fort id 304 → ...) that `Settings.xml`
`<PrerequisiteMappings>` aliases 1:1 against the Vanilla chain, so cross-land
prerequisite checks treat "Fort" and "Mountain Fort" equivalently.

**Time-locked content**: some Objects have `<FinishTime>` as a Unix epoch (e.g. the
"Holiday Gift" object, `FinishTime="1324800000"` = Dec 25, 2011) — a real-world-clock
gated unlock, separate from `BuildTime`. This is a live-event mechanic tied to
calendar dates, not player progress.

**Source evidence**

- Schema: `Vanilla_BuildingsTo10.xml`, `Vanilla_Buildings10Plus.xml` (full building
  roster, levels 1 through observed level 26+), `Crossover_Buildings.xml`,
  `Frontier_Launch.xml`, `Halloween.xml`, `HoityToity.xml`, `401_Update.xml`
  (event/DLC building packs), all indexed by `Objects.xml`.
- Build menu categorization: `BuildMenu.xml` (Categories: Buildings, Decorations,
  Upgrades, Land — 566 lines, ~130 building/decoration entries visible with inline
  level-tier comments).

**Dependencies**

- Resources (cost/sell/storage), Progression (level/building prerequisites), Land
  system (`CompatibleLand`), Skins (visual reskin per land/season), Workers (mines
  and shops need assigned villagers), Buffs (decorations modify shop output).

**Planned recreation approach**

Faithful. One `BuildingDef` schema covers every type via optional fields (see
`DATA_MODEL.md`); type-specific behavior (mine production, shop recipes, storage
capacity, market, skin-switch trigger) is composed via optional sub-resources rather
than subclassing, mirroring how the original XML overloads one `<Object>` tag for
everything. Preserve exact ids so all cross-references (BuildMenu, Tutorials,
PrerequisiteMappings, Skins) continue to resolve. Calendar-locked content
(`FinishTime`) is deferred to a later phase — flagged as a "live event" system, not
core to the base game loop.

---

## 4. Decorations

**Original behavior**

Decorations are `<Object type="decoration">` (or `misc`/`skinswitch` for special
cases) with no production role — their entire function is either (a) pure
cosmetic/XP-on-purchase, or (b) a **passive economic buff**: a `<Buffer
onlyOne="0|1" category="shops">` block containing `<Resources xpPercent="N">` and
per-resource `<Resource id percent="N"/>` bonuses, which increase the XP and/or Gold
yield of matching shop categories town-wide. Example: "Lily" (a cat decoration)
grants +25% XP/Gold to all Shops; "Crates" grants +0.3%. Bonuses are small
individually but stack, capped by `Settings.xml`'s `<BuffSystem><MaxBuffer
xpPercent="500.0">` (500% ceiling per land). `<Buffable>` (different tag, on
production buildings) marks which buff `<Category>` a building belongs to and can
receive bonuses from (categories seen: `school`, `carnival`, `wheat`, `shops`,
`inn`).

Decorations also carry standard placement metadata: `<Decoration type="misc"
select="yes|no" reposition="yes|no" blockVillager="yes|no" hasPadding="yes|no"/>` —
governing whether it's user-repositionable, whether villagers path around it, etc.

**Source evidence**

- `Halloween.xml`, `401_Update.xml`, `ItemOfTheDay.xml` (Crates, Sheep, Treehouse,
  Blue Doghouse, Chicken Coop, Lake, Gabbo, Poochie, Lily — all with explicit buff
  percentages in their `<Info>`/`desc` text and matching `<Buffer>` blocks).
- Buff system ceiling and category list: `Settings.xml` `<BuffSystem>` block (lines
  132–166 read in full).

**Dependencies**

- Buildings (decorations are a building subtype), Production Chains (buff target),
  Progression (level-gated availability), Currency (Gold/MagicBeans cost),
  Land/Skins (`skinswitch` decorations like Frosty the Snowman change the active
  season skin for the whole land).

**Planned recreation approach**

Faithful. Decorations share the `BuildingDef` schema with an optional `BuffDef`
component (category + per-resource-or-global percent). Buff aggregation is a
straightforward "sum active buffs per category, clamp at land cap" calculation
applied at shop-completion time.

---

## 5. Workers / Haulers (Villagers)

**Original behavior**

Villagers are the labor pool. Each production mine has `<Workers workerMax
haulerMax>` slots (every sampled example: 1 worker + 1 hauler). A **worker**
generates resources at `villagerResourcesPerHour`; a **hauler** carries the
accumulated stack (up to `carryamount`, a global constant) from the building to
storage — without a hauler assigned, output presumably backs up against
`maxOutputStackSize` and halts. Global villager constants (`Settings.xml`
`<Villager>`):

- `speed="2.0"`, `haulspeed="1.5"` — movement speed multipliers.
- `workrate="65.0"` — base rate affecting hauler throughput (worker rate is
  overridden per-building by `villagerResourcesPerHour`).
- `homelessmodifier="0.5"` — a homeless villager (no house capacity assigned) works
  at half productivity, implying houses cap total villager count and unhoused
  villagers are penalized rather than blocked outright.
- `eattime="2.0"`, `hungerlengthmin="4.0"`, `hungerlengthmax="12.0"` — villagers
  periodically need to eat (random interval between 4–12 [hours? in-game time units —
  unit not explicit in the XML]), consuming `eattime` performing the action, implying
  a hunger/needs loop layered on top of the job assignment.
- `<VillagerSounds>` — weighted random idle-voice barks per gender (male: sounds 28,
  18; female: 23–27), used for flavor when villagers are interacted with.
- `<AdoptedVillagers><Villager cost="15"/>` — a fixed cost (currency unspecified,
  presumed Gold given the placement in the general Settings block, but not proven) to
  adopt an additional villager beyond natural house-driven growth.

**Source evidence**

- `Settings.xml` lines 22–68 (Villager, VillagerSounds), lines 128–130
  (AdoptedVillagers).
- Per-building slot counts throughout `Vanilla_BuildingsTo10.xml`/
  `Vanilla_Buildings10Plus.xml` `<Workers>` tags.
- Job-type flavor labels (`<WorkerType>Wood Cutter</WorkerType>`, `Quarryman`,
  `Shearer`, `Gold Panner`) — cosmetic job titles per building, not separate
  mechanical types.

**Dependencies**

- Buildings (slots, job type), Production Chains (worker/hauler drive output),
  Housing (villager population cap — houses are `Objects` too, capacity value not
  yet located, see `MISSING_INFORMATION.md`), Energy (only for direct mayor actions,
  not standard worker/hauler labor, which appears to be passive/real-time).

**Planned recreation approach**

Faithful for the constants we have. Model villagers as lightweight simulation agents
(not full pathfinding actors initially — see Roadmap Phase 3) with a job assignment
(worker or hauler at a specific building instance), a home reference, and a hunger
timer. Homelessness penalty and hunger/eat cycle are real mechanics to reproduce, not
cosmetic. The exact house capacity-per-tier number is an open gap (see
`MISSING_INFORMATION.md`) — implement the *system* now with a placeholder capacity
table to be corrected once found.

---

## 6. Storage (Resource Capacity Tiers)

**Original behavior**

Storage capacity is per-building, per-resource, via the `<Resources>` block present
on every `Object` (not just dedicated storage buildings) — Gold is always
`unlimited`; every other resource has an explicit per-building cap. Dedicated storage
buildings raise the *town-wide* effective cap (presumed additive across all owned
storage buildings, though the exact aggregation rule — sum vs max — is not stated in
XML and should be treated as a design decision, see `MISSING_INFORMATION.md`):

| Building | Level req. | Cap per resource (non-gold) |
|---|---|---|
| Town Hall (id 1) | start | 0 (stores nothing but Gold) |
| Stockpile (id 25) | 1 | 1,000 |
| Large Stockpile (id 26, upgrade of 25) | 6 (+ own Tower) | 3,500 |
| Warehouse (id 163, upgrade of 25/26) | 18 (+ Fort) | 20,000 |

Each tier is a strict `<UpgradeOf>` of the previous, and the Warehouse's `<Cost>` is
paid entirely in `MagicBeans` (30) rather than resources — the first observed
resource-tier building gated behind premium currency instead of a resource cost.

**Source evidence**

- `Vanilla_BuildingsTo10.xml` lines 525–585 (Stockpile, Large Stockpile).
- `Vanilla_Buildings10Plus.xml` lines 291–318 (Warehouse).

**Dependencies**

- Resources (what's being stored), Buildings (storage is a building subtype),
  Production Chains (output blocked once storage is full — implied by
  `maxOutputStackSize` on individual mines plus town-wide caps here).

**Planned recreation approach**

Faithful numbers. Recreate as a `StorageDef` component on `BuildingDef` plus a
player-level aggregate inventory that sums capacity contributions from all owned
storage-capable buildings (explicit design decision: **sum**, not max, matching the
observed cap-doubling pattern between tiers and the general "more buildings = more
capacity" idiom of the genre) — document this choice as a filled gap in
`MISSING_INFORMATION.md` once decided/implemented.

---

## 7. Land Expansion

**Original behavior**

The buildable town area expands via `Items.xml` `type="landUpgrade"` purchases (not
via `LandExpands.xml`, which is empty — see `RECONSTRUCTION.md` §3). Each land
upgrade item has:

- `value` — the new land-size dimension after purchase (progression: 56 → 64 → 72 →
  80 → 88 → 104 → 112 → 120 ... increments of 8, occasionally jumping to +16),
  implying land is square and `value` is the side length in tiles (consistent with
  building footprints being small integers like 6–14 and the starting `Layout.xml`
  town spanning roughly 120+ units).
- `<Prerequisite type="level">` and `<Prerequisite type="landUpgrade">previous_id`
  chaining — must own the prior upgrade and be the right mayor level (every sampled
  entry requires level 4, except the first at level 1).
- Dual-cost: `<Cost><Resource id="1">gold_amount</Resource></Cost>` **or**
  `<AlternateCost><MagicBeans>bean_amount</MagicBeans></AlternateCost>` — the player
  can pay with either currency (gold cost scales 50 → 1,000,000+; MagicBeans
  alternate scales 5 → 60+), a classic "pay grind-time or pay money" dual path.
- `<CompatibleLand>Vanilla</CompatibleLand>` — separate land-upgrade tracks exist (or
  are needed) per land; Frontier almost certainly has its own equivalent chain not
  yet located/confirmed exhaustively (see `MISSING_INFORMATION.md`).

**Source evidence**

- `Items.xml` lines 1–80+ (`type="landUpgrade"` ids 1–8 read in full, chain
  continues further in the file beyond what was sampled).

**Dependencies**

- Currency (dual gold/beans cost), Progression (level gating + chained
  prerequisites), Buildings (larger land unlocks more placement area, and some
  buildings/decorations have their own separate level gates independent of land
  size).

**Planned recreation approach**

Faithful. Model as a linear `LandUpgradeDef` chain per land, each with two valid cost
options; player chooses which currency to spend. Land size is stored as a single
integer (side length) per land the player owns.

---

## 8. Energy System

**Original behavior**

The Mayor (player avatar) has an energy pool that gates "direct" gather/mill actions
(the `mayorResources` field on mine `<Produce>` blocks) as opposed to passive
worker-driven output. Constants (`Settings.xml` `<Energy>`):

- `worktime="3.0"` — seconds a direct gather/mill action takes.
- `carryamount="300"` — max resources a hauler carries per trip (this lives on the
  Energy tag but is really a hauler/logistics constant, not energy-specific — an
  original-data quirk worth preserving as-is rather than "fixing" the grouping).
- `buildingHurryCost="2"` — energy cost to hurry a building's construction.
- `buildingHurryInterval="8640"` — seconds of build-time skipped per hurry unit
  (implies hurry cost scales with remaining time / interval, similar to the
  per-shop-item `HurryCost timeInterval` pattern in §2).
- `iconFontEnergy="}"` — compact icon-font glyph, UI-only.
- Energy is replenished over time (rate not found in this pass — likely tied to real
  time, common in this genre, e.g. 1 point per N minutes) and via level-up rewards
  (`<Reward energy="11">` seen repeatedly in `<User><XP>` entries) and via
  `TownhallStore.xml` real-money purchase (`type="energy" value="10" cost="1000"`).

**Source evidence**

- `Settings.xml` lines 14–19 (`<Energy>` tag, full).
- `Settings.xml` `<User><XP>` entries showing energy rewards on level-up.
- `TownhallStore.xml` (energy purchase item).

**Dependencies**

- Progression (energy rewards on level-up), Production Chains (mayor-direct actions
  cost energy), Buildings (hurry-building costs energy), Currency (real-money energy
  purchase).

**Planned recreation approach**

Faithful for known constants; the passive energy-regeneration rate is an open gap
(`MISSING_INFORMATION.md`) — implement with a placeholder regen rate (e.g. common
genre default of 1 point per few minutes) clearly marked as a guess until better
evidence surfaces.

---

## 9. Currency System

**Original behavior**

Three currencies are evidenced:

1. **Gold** (`Resources.xml` id 1) — soft currency, earned from shops/mining/selling,
   spent on everything. Effectively the "resource that is also money."
2. **MagicBeans** — premium/hard currency. Never appears in `Resources.xml`'s id
   table; instead it's a distinct XML tag (`<MagicBeans>N</MagicBeans>`) usable
   wherever a `<Cost>`/`<AlternateCost>`/`<Reward>` block allows it (land upgrades,
   Warehouse, some decorations/skins like Frosty's `<Cost><MagicBeans>65</MagicBeans
   ></Cost>`). Sold for real money via a shop UI referenced in the strings dump
   ("Get More Coins", "Spending Beans" — `tradenations.xml` textpool entries) and
   `currency_en.json`'s `currency_tn_description` string: *"Use Magic Beans to buy
   exclusive items, hurry shop production, and hurry building construction."*
   Confirms Beans are also the hurry-currency, not just a land/building cost.
3. **Z2Points** (`Settings.xml` `<Z2Points icon="_"/>`) — a third currency/points
   type with only an icon glyph defined in this pass; purpose unconfirmed (likely a
   cross-game loyalty or achievement-point system common to Z2Live's titles). See
   `MISSING_INFORMATION.md`.

Note: `currency_en.json` and `achievements_en.json` are **shared multi-game files** —
several entries (`currency_bn_description`, `currency_ms_description`) describe
Battle Nations' "Nanopods" and another title's "Coins", not Trade Nations. Only
`currency_tn_description` (Magic Beans) is confirmed relevant.

**Source evidence**

- `Resources.xml` (Gold).
- `Items.xml` (`<MagicBeans>` usage throughout landUpgrade and some building costs).
- `Settings.xml` (`<Z2Points>`).
- `currency_en.json`, `tradenations.xml` textpool ("Get More Coins", "Spending
  Beans").
- `TownhallStore.xml` (real-money → Gold/energy/building conversion item types).

**Dependencies**

- Everything with a cost: Buildings, Land Upgrades, Decorations, Energy hurry,
  Building hurry.

**Planned recreation approach**

Faithful for Gold and MagicBeans (dual soft/hard currency, exactly as costed in the
XML). Z2Points is out of scope until its purpose is confirmed — do not invent a
mechanic for it; track it as a known-unknown. Real-money purchases
(`TownhallStore.xml`) become a stubbed/no-op "premium store" screen for a
single-player-first build (no real payment processing), or a self-hosted mock economy
if a multiplayer/live-service mode is pursued later.

---

## 10. Leveling / Progression

**Original behavior**

The Mayor levels via XP earned from building construction (`xpValue` on every
Object) and shop-item completion (`Reward xp=` on every shop item), up to
`maxlevel="70"`. Per level (`<XP level="N" toNext="M">`):

- `toNext` — XP required to reach level N+1 (0 → 1: 550 XP; 1 → 2: 750 XP; 2 → 3:
  1100 XP — a roughly linear-then-accelerating curve based on the samples read).
- `<MaxBuilding category="house|shop">N</MaxBuilding>` — hard caps on how many
  buildings of a given `category` the player may own at this level (starts at 4
  houses / 1 shop at level 0, expanding as the player levels).
- `<Reward energy="N">` — one-time energy grant on reaching this level (11 energy
  observed at levels 1 and 2).
- `<LevelText>` — flavor congratulations message shown on level-up, describing what
  was just unlocked (some entries commented-out/replaced, suggesting iterative
  copywriting during development — an interesting authenticity detail, not a bug).
- `<DefaultFreeInventorySlots>` — appears at level 0, suggesting a
  separate item-inventory system (distinct from resource storage) with its own slot
  count, likely for finished/tradeable goods or gifts. Not yet cross-referenced with
  a full inventory schema — see `MISSING_INFORMATION.md`.

**Source evidence**

- `Settings.xml` `<User maxlevel="70">` block, `<XP>` entries for levels 0–3 read in
  full (lines 171–199); pattern continues to level 70 in the file.

**Dependencies**

- Buildings (xpValue source), Production Chains (shop reward xp source), Storage
  (MaxBuilding caps gate how many storage/shop buildings can be owned), Energy
  (level-up energy rewards).

**Planned recreation approach**

Faithful. A single `LevelDef` table (id 0–70) drives XP thresholds, building caps,
and rewards. XP awarded on construction completion and on shop-item collection,
summed into a running player XP total; level derived by threshold lookup rather than
stored redundantly.

---

## 11. Tutorials

**Original behavior**

A fully data-driven onboarding FSM. Each `<Tutorial id triggerType triggerValue name
description>`:

- `triggerType`: `always` (fires immediately once prerequisites are met), `build`
  (fires when a building of `triggerValue` type is built), `select` (fires when such
  a building is selected/tapped) — both `build`/`select` re-check on every relevant
  event until prerequisites pass, per the inline documentation comment.
- `<Reward>` — optional reward on completion (resources, energy, etc. — schema
  shared with other reward blocks).
- One or more `<Objective first= second=>type</Objective>` entries, of type: `build`,
  `assign`, `collect`, `gather`, `transport`, `useShop`, `marketBuy`, `marketSell`,
  `landSize`, `message` (simple dismissable text), `hurryShop`, `hurryBuilding`,
  `supply`, `friendView` — a 13-verb vocabulary covering essentially every player
  action in the game. `first`/`second` parameters are contextually typed per
  objective (e.g. for `build`: first=building id, second=quantity required).
- A `<Lock>` block that can disable, town-wide, any combination of: `world` (map
  view), `buildings` (construction), `consumables` (land upgrades etc.), `energy`
  (energy-spending actions), `workers`, `haulers` (assignment), `sell`, `friendShop`
  (caps friend-shop interaction to lowest tier) — this is how the early game funnels
  the player through a strict linear script.
- `<Allow>` entries create per-building exceptions to an active lock (e.g. "you may
  still build up to N of building X" or "you may still spend energy at building X"),
  each with its own optional override `message` shown once the exception is
  exhausted. `<AllowConsumable>` is the equivalent for consumable-type items.
- `Prerequisite type="tutorial"` lets tutorials chain off each other (and off
  building/level/item prerequisites via the same shared prerequisite vocabulary used
  everywhere else in the data).

**Source evidence**

- `Tutorials.xml` — full authoring documentation comment (lines 1–53) plus first
  tutorial entry ("Welcome!", id 1, `triggerType="always"`, a `message` objective)
  read in full; file continues for 486 lines total covering the full onboarding
  sequence.

**Dependencies**

- Buildings, Resources, Market, Shops, Workers/Haulers, Land — tutorials reference
  and gate nearly every other system, making this a genuinely cross-cutting
  controller system, not a leaf feature.

**Planned recreation approach**

Faithful. This is rich enough, data-driven enough, and self-documenting enough (the
original authors left a full spec comment in the file) that it should be ported
close to verbatim: one `TutorialDef` resource type with the same
trigger/objective/lock/allow vocabulary, evaluated by a generic `TutorialManager`
that the rest of the game consults before permitting any locked action. This is
explicitly called out as **Phase 4** work (`IMPLEMENTATION_ROADMAP.md`) since it
depends on essentially every other system existing first.

---

## 12. Achievements

**Original behavior**

**Unrecoverable as Trade-Nations-specific data.** `achievements_en.json` (and other
locale variants) contain only localized *display strings* (name + description pairs,
keyed by a slug), and cross-checking the slugs shows most are combat/military themed
("Assault and Battery," "Chessmaster General," "Deadly Dozen," "First Blood," "One
bunk at a time") — these belong to **Battle Nations**, a different Z2Live title
sharing the same localization-bundle format/pipeline. No XML file defining
Trade-Nations achievement *trigger conditions*, *ids*, or a *confirmed
Trade-Nations-relevant subset* of the JSON strings was found in this pass.

**Source evidence**

- `achievements_en.json` (and `_de`, `_es`, `_fr`, `_ja`, `_zh-Hans`, `_enpl`
  variants) — string pairs only, no logic, mixed-game content confirmed by slug
  content mismatch with Trade Nations' theme.

**Dependencies**

- Would depend on nearly every other system (building counts, resource totals,
  friend counts, trade counts — inferable from generic string patterns like
  `FIVE_FARMS.RAW`, `TEN_FRIENDS.RAW`, `TEN_TRADES.RAW` asset names in `bundle/`,
  which *do* look Trade-Nations-specific and hint at count-based achievement tiers:
  own 5 Farms, 5 Logging Camps, 5 Pens, 5 Quarries, 5 Friends; complete 1/10 Trades;
  etc. — these asset names are the best surviving evidence of what Trade Nations
  achievements actually tracked, even without formal trigger XML).

**Planned recreation approach**

**Modern equivalent, explicitly labeled as new design.** Use the count-style asset
names (`FIVE_FARMS`, `FIVE_FRIENDS`, `FIVE_LOGGING_CAMPS`, `FIVE_PENS`,
`FIVE_QUARRIES`, `ONE_FRIEND`, `ONE_TRADE`, `TEN_FRIENDS`, `TEN_TRADES`,
`BOOKWORM`, `DIVERSITY`, `WEALTHY_1000/5000/10000/25000/1M`) as a starting design
brief for an original achievement list (building-count milestones, gold-net-worth
milestones, social milestones), built with a generic "counter reaches threshold"
achievement engine. Do not present this list as recovered original data in any
player-facing text — it's inspired-by, not recreated-from.

---

## 13. Trading / Social Systems

**Original behavior**

Client-observable pieces only; the server-side protocol and business rules are gone:

- **Market** (`Objects.xml` id 27, `type="market"`) — a building with distinct
  buy/sell sound cues (`<Sounds select="-1" buy="17" sell="17"/>`) and UI text
  (`Market Buy`, `Market Sell`, `Market Buy Fail`, `Market Sell Fail`,
  `Market Storage Full`, `Market Awaiting Rates` — implying the market has
  fluctuating, possibly server-synced buy/sell rates, not fixed prices) — pricing
  formula not present in any XML.
- **Peer-to-peer trading** — UI text only (`Trade Request`, `Trade Accept/Reject`,
  `Trade Expired`, `Trade Declined`, `Trade Done`, `Trade Time`, `Trade Reward`,
  `Trade Returned`) plus a dedicated town layout variant (`LayoutTrade.xml`) implying
  trading has its own view/mode of the town. No protocol, no offer-composition
  schema, no rate limits survive.
- **Friends** — Facebook-integrated (`FBConnect.bundle`, defunct pre-Graph-API SDK)
  plus in-game friend list/invite/add-friend UI (`Z2/*.nib` screens:
  `AddFriend`, `FriendsAddFriend`, `FriendsRequestItem`, etc.). Friend-shop
  interaction is referenced by the Tutorial `friendShop` lock type (§11) — visiting a
  friend's town lets you use their lowest-tier shop items, presumably for a shared
  reward.
- **Leaderboards** — the one social system with actual client **logic**, not just UI:
  `Z2/Scripts/Leaderboard/LeaderboardService.lua` implements a full request/response
  cycle against a `"lb"` service (`getLeaderboards`, `getGlobalScores`/
  `getFriendScores`, `getMyGlobalScore`), with local persistence of the player's
  last-selected timespan/friend-filter/leaderboard-index
  (`self:persistObject_forKey(...)`). This is our best-documented networked system,
  but it still requires a server to answer those RPCs — none exists.
- **Mail/gifting** — `IncomingMail*.nib` screens, `MailCompose`, `MailFriendSelect`
  imply an in-game mail system used for gifting resources between friends (a very
  common genre mechanic — send a friend a resource, they collect it). No packet
  schema recovered.

**Source evidence**

- `Objects.xml`/`Vanilla_BuildingsTo10.xml` (Market building definition).
- `tradenations.xml` textpool (Market/Trade UI strings, lines 96–142).
- `LayoutTrade.xml` (dedicated trade-mode layout).
- `Z2/Scripts/Leaderboard/*.lua` (only fully-implemented networked system in the
  surviving Lua).
- `Info.plist` (dead server hostnames, confirming nothing here is locally
  resolvable).

**Dependencies**

- Resources (what's traded/gifted), Currency, Progression (friend-shop tutorial
  lock), a self-hosted backend if implemented at all.

**Planned recreation approach**

**Modern equivalent, phased and optional.** Base game (Phases 1–4) is
single-player-only: Market becomes a simple fixed or algorithmic (e.g.
supply-tracking) buy/sell system with no live rate sync needed. Trading, friends,
leaderboards, and mail are explicitly deferred to Phase 5 as an opt-in self-hosted
service layer (see `IMPLEMENTATION_ROADMAP.md`) — reusing the Leaderboard Lua's
request/response *shape* as inspiration for our own API contract, since it's the one
place we have real client-side protocol logic to imitate, but backed entirely by
infrastructure we own.

---

## Cross-System Notes

- **Shared prerequisite vocabulary**: `level`, `building`, `tutorial`,
  `rewardUnlockable`, `landUpgrade` all compose the same way across Objects, Items,
  and Tutorials — worth implementing as one generic `PrerequisiteSet` type used
  everywhere rather than one-off per system (this mirrors the original's own design).
- **Shared cost vocabulary**: `<Cost>`/`<Sell>`/`<Reward>`/`<AlternateCost>` all wrap
  the same `{Resource id qty}` + optional `{MagicBeans qty}` shape — one
  `CostBundle` type should back all of them.
- **Land/skin duality**: "Land" (Vanilla vs Frontier, a gameplay expansion with its
  own building tree) is a different axis from "Skin" (Winter/Fall, a pure reskin of
  the active land's assets via `Skins.xml` `<Skin>` + `<Anim prefix>`). Both must be
  modeled, but they are not the same system — don't conflate them.
