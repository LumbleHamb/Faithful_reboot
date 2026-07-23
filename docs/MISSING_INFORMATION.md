# Trade Nations — Missing Information / Open Investigations

Every gap referenced from `RECONSTRUCTION.md`, `GAME_SYSTEMS.md`,
`DATA_MODEL.md`, and `IMPLEMENTATION_ROADMAP.md`, consolidated here as a single
investigation backlog. Each entry states what's missing, why it matters, what
evidence might resolve it, and what to do in the meantime.

---

### 1. `Discoveries.xml` and `LandExpands.xml` are 0 bytes
- **Why it matters**: `AI_INSTRUCTIONS.md` names these as expected systems; no
  client-side data survives for either.
- **Possible leads**: check for other IPA versions/updates of Trade Nations that
  might ship non-empty copies; check `research/TradeNations_strings.txt` for any
  "discovery"/"discoveries" string clusters not yet cross-referenced.
- **Interim approach**: treat as lost. Do not invent a "Discoveries" system and
  present it as recovered; if built at all, design it fresh and label it as new.

### 2. Native binary logic is unrecoverable (FairPlay-encrypted)
- **Why it matters**: market pricing formula, exact hurry-cost curve beyond the flat
  per-item constants, anti-cheat/validation rules, and any logic not expressed in
  XML all live here.
- **Possible leads**: none within this repo; would require a decrypted/jailbroken
  binary dump, which is out of scope for this project's stated approach.
- **Interim approach**: redesign these systems fresh (see `GAME_SYSTEMS.md` §13,
  Market pricing) rather than attempting decompilation.

### 3. `.RAW` sprite format is undocumented
- **Why it matters**: 737 files, the largest single asset category — most building/
  UI art ships this way. Format is proprietary; no header spec found in this pass.
- **Possible leads**: file-size heuristics against known sprite dimensions (e.g.
  compare `.RAW` byte counts against plausible width×height×bytes-per-pixel
  combinations); check whether any `.png` counterpart of the same name exists to
  derive dimensions by comparison (some assets, e.g. `20_MOREBARREL`, ship as both
  `.RAW` and `.png`).
- **Interim approach**: Phase 5 concern. Ship with placeholder/redrawn art until
  resolved; do not block Phases 1–4 on this.

### 4. `.z2raw` + `*_Timeline.bin` + `*_TimelineFormatIndex.json` animation format
- **Why it matters**: 113 `.z2raw` + 35 `.bin` files drive every character/building
  animation (walk cycles, hauler carries, seasonal building idle animations).
- **Possible leads**: the paired `_TimelineFormatIndex.json` files are extremely
  small (e.g. `26_TimelineFormatIndex.json` = `{"0":"z2raw"}`) — likely just a
  frame-source-type index, not the actual keyframe data; the real animation timing
  must be inside `_Timeline.bin`. A binary-diff across multiple `_Timeline.bin`
  files of known-different frame counts could reveal a fixed record stride.
- **Interim approach**: Phase 5 concern, same as `.RAW`.

### 5. Server protocol for trading/friends/mail/leaderboards
- **Why it matters**: all social features were server-authoritative; servers
  (`tradenations.z2live.com`, `myz2.net`) are gone.
- **Possible leads**: `Z2/Scripts/Leaderboard/LeaderboardService.lua` is the one
  fully-implemented client-side networked flow and shows the RPC *shape*
  (`ZPRequestMessage:requestToService_command_data_target_action`, service code
  `"lb"`); no equivalent Lua exists for trading/mail/friends in the extracted
  `Z2/Scripts/` (only `NavigationBar.lua`, `class.lua`, `init.lua`, and the
  Leaderboard subfolder are present — trading/mail/friends UI is native-code-driven,
  not scripted, so no Lua evidence for their protocol exists at all).
- **Interim approach**: design a new self-hosted protocol (Phase 5), using the
  Leaderboard shape only as loose inspiration, never as a literal spec to match.

### 6. Achievement trigger conditions (Trade-Nations-specific)
- **Why it matters**: `achievements_*.json` files are shared with Battle Nations and
  contain no Trade-Nations trigger logic, only a mix of both games' display strings.
- **Possible leads**: count-style asset filenames in `bundle/` look
  Trade-Nations-specific and hint at real milestones: `FIVE_FARMS.RAW`,
  `FIVE_FRIENDS.RAW`, `FIVE_LOGGING_CAMPS.RAW`, `FIVE_PENS.RAW`,
  `FIVE_QUARRIES.RAW`, `ONE_FRIEND.RAW`, `ONE_TRADE.RAW`, `TEN_FRIENDS.RAW`,
  `TEN_TRADES.RAW`, `BOOKWORM.RAW`, `DIVERSITY.RAW`, `WEALTHY_1000/5000/10000/
  25000/1M.RAW`. These are badge-icon assets, not proof of exact thresholds/names,
  but are the best lead available.
- **Interim approach**: build a generic threshold-achievement engine (Phase 4),
  seed content from the asset-name hints, document explicitly as new design.

### 7. Full localized string *values*
- **Why it matters**: `tradenations.xml`/`.btp`/`.btpl`/`.txtmaster` give string
  *keys* (`Textpool` ids) with confirmed English *key labels* (e.g. "Trade Request1")
  but it hasn't been confirmed whether the actual displayed strings for every key,
  in every locale, have been extracted from the compiled `.btp`/`.btpl`/
  `.txtmaster` binary tables.
- **Possible leads**: `.btp`/`.btpl` are likely a compiled binary string-table format
  paired with `.txtmaster`; a format-reversal pass parallel to the `.RAW`/`.z2raw`
  work (#3/#4) could recover them.
- **Interim approach**: Phase 4 UI ships placeholder/rewritten strings for any key
  not confirmed recovered; never present unconfirmed guesses as original text.

### 8. Villager housing capacity per house tier
- **Why it matters**: population growth (`GAME_SYSTEMS.md` §5, `DATA_MODEL.md`
  `BuildingDef` needs a `house_capacity` field) depends on this number, and no house
  `Object` definition's full body was read closely enough in this pass to confirm a
  capacity tag/value.
- **Possible leads**: re-read the full `<Object type="house">` entries in
  `Vanilla_BuildingsTo10.xml`/`Vanilla_Buildings10Plus.xml`/`Frontier_Launch.xml`
  for a capacity-like tag (may not be literally named "capacity" — check for
  something like `<Population>`, `<MaxVillagers>`, or a reused `<Resources>`-style
  block).
- **Interim approach**: Phase 3 implements the mechanic against a placeholder
  capacity table (flagged), corrected once this is found.

### 9. Energy regeneration rate
- **Why it matters**: `Settings.xml <Energy>` gives `worktime`, `carryamount`,
  `buildingHurryCost`, `buildingHurryInterval` — no passive regen rate was found in
  the portion read.
- **Possible leads**: re-scan `Settings.xml` in full (only ~200 of 1,422 lines were
  read closely) and `Items.xml`/`TownhallStore.xml` for any energy-per-time constant;
  check the strings dump for "energy" context near numeric values.
- **Interim approach**: Phase 3 uses a placeholder regen rate (documented as a
  guess, common genre default) pending this.

### 10. `Resource.scoreValue` consuming formula
- **Why it matters**: every `Resources.xml` entry has a `scoreValue` (e.g. Gold=1,
  Cut Stone=2.5) whose purpose (net worth score? leaderboard score? something else)
  is named but never used anywhere else we've read.
- **Possible leads**: check `Z2/Scripts/Leaderboard/*.lua` for any "score" formula
  referencing resource values; check strings dump for "net worth"/"score" UI text.
- **Interim approach**: field is preserved in `DATA_MODEL.md` for fidelity; no
  mechanic wired to it until a formula or purpose is confirmed.

### 11. `Z2Points` currency purpose
- **Why it matters**: `Settings.xml` defines `<Z2Points icon="_"/>` with no other
  reference found in this pass — unclear if it's Trade-Nations-relevant at all or a
  cross-game (Z2Live account-wide) system like a loyalty program.
- **Possible leads**: search strings dump for "Z2Points"/"Z2 Points"; check other
  Z2Live titles' bundles if ever available for comparison.
- **Interim approach**: schema stub only (`DATA_MODEL.md` §0 `CurrencyDef`), no
  mechanic implemented.

### 12. `DefaultFreeInventorySlots` / item-inventory system
- **Why it matters**: appears once, at `Settings.xml` level 0, hinting at a
  slot-based inventory separate from resource storage (perhaps for gifts, finished
  goods, or tradeable items) — no further schema found in the portion read.
- **Possible leads**: check `Items.xml` for any items typed as inventory-goods
  rather than `shopItem`/`landUpgrade`; check `IncomingMail*`/gift-related nib and
  string references for an "inventory full" message pattern (a
  `Stash Inventory Full` textpool entry does exist — see `tradenations.xml` line
  105 — supporting that this is a real, separate system worth investigating
  further).
- **Interim approach**: schema field reserved in `DATA_MODEL.md` §6, not wired up.

### 13. Storage-capacity aggregation rule (sum vs. max across buildings)
- **Why it matters**: multiple storage buildings (Stockpile, Large Stockpile,
  Warehouse) can coexist; whether their capacities sum or the highest wins is not
  stated in any XML read so far.
- **Possible leads**: none found client-side; likely a native-code rule.
- **Interim approach**: **design decision made**, not a recovered fact — sum
  capacities across all owned storage-capable buildings (`DATA_MODEL.md` §6).
  Revisit only if evidence surfaces contradicting it.

### 14. Full building/decoration roster consolidation
- **Why it matters**: only representative samples of `Vanilla_BuildingsTo10.xml`
  (833 lines), `Vanilla_Buildings10Plus.xml` (969 lines), `Vanilla_DecorationsTo30/
  30Plus.xml` (1,147 + 388 lines), `Crossover_*`, `Halloween.xml`, `HoityToity.xml`,
  `401_Update.xml`, and `Frontier_Launch.xml` (937 lines) have been read in this
  pass — enough to confirm the schema with high confidence, not enough to guarantee
  every single building/decoration/cost value has been captured.
- **Possible leads**: none needed beyond doing the work — this is a mechanical
  full-read-and-convert task, explicitly scheduled as Phase 1.3 of
  `IMPLEMENTATION_ROADMAP.md`.
- **Interim approach**: N/A — scheduled, not blocked.

### 15. Frontier land's own land-upgrade chain
- **Why it matters**: `Items.xml`'s sampled `landUpgrade` entries are all
  `CompatibleLand=Vanilla`; Frontier almost certainly needs its own size-progression
  chain, not yet confirmed present/located.
- **Possible leads**: re-scan the remainder of `Items.xml` (1,856 lines total, only
  ~80 read) for `CompatibleLand>Frontier` land-upgrade entries.
- **Interim approach**: Phase 1.3 full-XML pass will resolve this; `DATA_MODEL.md`'s
  `LandUpgradeDef.compatible_land` field already supports either land.

### 16. `AdoptedVillagers` cost currency
- **Why it matters**: `Settings.xml`'s `<AdoptedVillagers><Villager cost="15"/>`
  doesn't state which currency the 15 refers to (Gold is a reasonable assumption
  given placement, but unconfirmed).
- **Possible leads**: strings dump search for "Adopt" context; check
  `tradenations.xml` textpool entry "Adopt Villager" (id 53) for any adjacent
  currency-formatting hint.
- **Interim approach**: `DATA_MODEL.md` models it as a generic `CostBundle` so
  either resolution slots in without a schema change; assume Gold until confirmed.

---

## How to use this list

When picking up any implementation task, check this file first for a matching open
question before treating any assumption as settled. When an item here is resolved,
update the relevant `GAME_SYSTEMS.md`/`DATA_MODEL.md` section, mark the field's
`[new]`/placeholder annotation as `[original]` if confirmed, and remove (or mark
resolved, with citation) the entry here.
