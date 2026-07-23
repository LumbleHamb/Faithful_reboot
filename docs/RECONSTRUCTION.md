# Trade Nations — Reconstruction Charter

This document is the top-level charter for the Faithful Reboot project. It states what
we're building, what we actually know versus what we're inferring, and the ground rules
that every other document and every future implementation decision must follow.

Everything in this document is derived from static inspection of the extracted app
bundle in `original/TradeNations.app/`. No servers were contacted, no binary was
decrypted or disassembled, and no file in `original/` was modified to produce it.

---

## 1. Project Goals

1. **Preserve** the design of the original Trade Nations (Z2Live, Inc., iOS, first
   released 2011-04-20) as accurately as the surviving client-side data allows.
2. **Recreate the gameplay loop** — town building, resource production chains, villager
   logistics, land expansion, mayor progression — as a standalone, modern, playable
   game, engine target **Godot** (see `IMPLEMENTATION_ROADMAP.md`).
3. **Document before implementing.** Every gameplay system gets a design doc
   (`GAME_SYSTEMS.md`) and a concrete data schema (`DATA_MODEL.md`) before any
   gameplay code is written, so implementation is systematic instead of another round
   of reverse engineering.
4. **Do not depend on anything that no longer exists.** The original game was
   server-authoritative for social features (friends, mail, leaderboards, trading).
   Those servers (`tradenations.z2live.com`, `myz2.net`) are gone. The reboot must
   define its own self-hosted or single-player equivalents rather than assuming a
   protocol we can't observe.
5. **Never modify `original/`.** It is the only surviving copy of the source material.
   All reconstruction artifacts live under `docs/`, and (later) a separate
   implementation directory.

## 2. What We Know About the Original Game

This is a summary; full detail with citations lives in `GAME_SYSTEMS.md`.

- **Publisher/date**: Z2Live, Inc.; App Store metadata (`original/tradenations without
  payload/iTunesMetadata.plist`) records first release 2011-04-20, genre
  Games/Adventure/Simulation, rating 12+.
- **Engine**: native Objective-C/UIKit app (compiled `TradeNations` Mach-O binary,
  FairPlay-encrypted per `SC_Info/*.sinf`), with UI screens as compiled `.nib` files,
  and a thin **Lua scripting layer** bridged to Obj-C via **Wax**
  (`original/TradeNations.app/wax/`), used for UI/session glue
  (`Z2/Scripts/NavigationBar.lua`, `Z2/Scripts/Leaderboard/*.lua`). The vast majority
  of gameplay rules are **not** in Lua — they're declarative XML consumed by native
  code.
- **Data-driven ruleset**: buildings, resources, shop production recipes, land layout,
  tutorials, leveling, and buffs are all defined in XML files under
  `original/TradeNations.app/bundle/` (`Objects.xml` manifest,
  `Vanilla_BuildingsTo10.xml`, `Vanilla_Buildings10Plus.xml`,
  `Vanilla_DecorationsTo30.xml`, `Vanilla_Decorations30Plus.xml`, `Items.xml`,
  `Resources.xml`, `Settings.xml`, `Tutorials.xml`, `BuildMenu.xml`, `Skins.xml`,
  `Sounds.xml`, plus event/DLC packs `Crossover_Buildings.xml`,
  `Crossover_Decorations.xml`, `Halloween.xml`, `HoityToity.xml`,
  `Frontier_Launch.xml`, `401_Update.xml`).
- **Core loop**: gather raw resources (Wood, Rock, Wheat, Wool) → refine into
  intermediate goods (Lumber, Cut Stone, Cloth) via mines/refineries → feed shops that
  convert resources + time into Gold/XP → spend Gold/XP/MagicBeans on new buildings,
  land, and decorations → decorations grant passive % buffs back into the shop
  economy → mayor levels up, unlocking more buildings, higher house/shop caps, and a
  second "land" (Frontier, a mountain-themed expansion with its own Town Hall chain
  aliased 1:1 to the base chain via `Settings.xml`'s `PrerequisiteMappings`).
- **Progression ceiling**: `Settings.xml` (`<User maxlevel="70">`) — 70 mayor levels,
  each with an XP threshold, optional building-count caps, and optional one-time
  rewards (mostly energy).
- **Monetization pattern**: dual-currency (Gold = soft, MagicBeans = hard/premium),
  energy-gated mayor actions, real-money "TownhallStore" purchases
  (`TownhallStore.xml`: buy gold, buy energy, buy a specific building), and a rotating
  `ItemOfTheDay.xml` featured-decoration shop.
- **Seasonal/event layering**: the `Objects.xml` manifest is literally a load order of
  content packs (base → 10+ → decorations → decorations 30+ → crossover → seasonal →
  update), i.e. the original content pipeline was additive XML drops on top of a
  stable core schema — a pattern worth preserving for our own content additions.

## 3. What Cannot Be Recovered

Be explicit about these gaps everywhere they matter — do not silently paper over them
with invented "canon."

- **The core simulation binary is opaque.** The native `TradeNations` executable is
  FairPlay-encrypted (`SC_Info/TradeNations.sinf`). Any logic not expressed in XML
  (exact XP-to-gold conversion at sale time, market pricing curves, exact hurry-cost
  formulas beyond the flat constants shown, anti-cheat/validation logic) is not
  recoverable from this repo. It must be **redesigned**, not decompiled.
- **`Discoveries.xml` and `LandExpands.xml` are 0 bytes** in the shipped bundle. Any
  "discoveries" or alternate land-expansion system referenced in `AI_INSTRUCTIONS.md`
  has no surviving client data. Treat as lost unless later found elsewhere.
- **No live servers.** `tradenations.z2live.com`, `myz2.net`, and the
  `maintenance.jujuplay.com` endpoints referenced in `Info.plist` are assumed
  non-operational for this project's purposes. Friends, mail, leaderboards, gifting,
  and player-to-player trading were all server-authoritative (`ZPRequestMessage`
  request/response calls in the Lua, e.g. service code `"lb"` for leaderboards). We
  can see the *client's* request shape, never the server's actual business logic,
  rate limits, or anti-abuse rules.
- **Binary asset formats are undeciphered.** `.RAW` (737 files) and `.z2raw` (113
  files, paired with `*_Timeline.bin` + `*_TimelineFormatIndex.json`) are
  custom/proprietary sprite and animation-timeline formats with no in-repo format
  spec. Original art is currently **not usable** until these are reverse-engineered
  or the art is redrawn.
- **Facebook/Twitter integration** relies on a pre-Graph-API Facebook SDK
  (`FBConnect.bundle`) that is defunct. Not portable; must be replaced if social
  login is wanted at all.
- **Server-driven achievements.** `achievements_en.json` (and other locales) only
  contain localized *text* for achievement names/descriptions, and — critically —
  many of those entries are for **Battle Nations**, a different Z2Live title that
  shares the same localization bundle format (e.g. `achievements_assaultbattery_*`,
  "Win 25 Attack Missions" — a combat term with no equivalent in Trade Nations). No
  XML defines Trade-Nations-specific achievement *trigger conditions* anywhere in the
  bundle. Achievement logic must be designed fresh, using only the plausibly-relevant
  subset of strings as flavor inspiration.
- **Full localized string tables.** `tradenations.xml`/`.btp`/`.btpl`/`.txtmaster`
  give us the *keys* used by the UI text pool, but the compiled binary table formats
  (`.btp`, `.btpl`, `.txtmaster`) holding the actual translated strings have not been
  parsed. We have string *IDs*, not confirmed we have all string *values*.

## 4. Reconstruction Philosophy

1. **Evidence over assumption.** Every system description in `GAME_SYSTEMS.md` cites
   the exact file (and, where useful, tag/attribute) it's drawn from. When a number or
   mechanic is genuinely unknown, it's marked as **inferred** or **unknown**, never
   presented as fact.
2. **Numbers are canon where they exist.** Where the original XML gives us exact
   constants (build costs, produce rates, XP thresholds, storage caps, energy costs),
   we keep them. Faithful means faithful — we are not "rebalancing" data we didn't
   design.
3. **Gaps get designed, not guessed at as if original.** Where the original is
   provably missing (`Discoveries.xml`, achievement triggers, server protocol, exact
   sale/market formulas), we design a modern equivalent and *label it as new design*,
   distinct from recovered original data.
4. **Data-driven first.** The original's biggest architectural strength was that
   buildings/items/tutorials are external XML, not hardcoded logic. The reboot
   preserves this: game content lives in data files (`DATA_MODEL.md`), the engine is a
   generic interpreter of that data, and new content (including our own
   "expansion packs") can be added the same additive way the original did it.
5. **No dependency on the dead backend.** Anything that was server-authoritative
   becomes either fully local (single-player-first) or backed by a self-hosted
   service we control end-to-end (see Phase 5 of `IMPLEMENTATION_ROADMAP.md`) — never
   an assumption that a Z2Live-compatible server exists to talk to.
6. **Small, verifiable steps.** Systems are implemented in the order they unlock each
   other in the real game (resources → buildings → production → progression → UI →
   social), matching `IMPLEMENTATION_ROADMAP.md`, so each phase is playable and
   testable before the next begins.

## 5. Systems That Will Be Recreated Faithfully

These have concrete, unambiguous data in the bundle and should be reproduced with the
original's exact numbers and structure:

- Resource list, tiers, and refinement relationships (`Resources.xml`)
- Building roster, footprints, costs, build times, prerequisites, XP values, storage
  capacities (`Objects.xml` + `Vanilla_*`, `Crossover_*`, event XML)
- Shop production recipes: input resources, time, XP/Gold reward, hurry cost
  (`Items.xml` `type="shopItem"`)
- Land-upgrade costs and level gating (`Items.xml` `type="landUpgrade"`)
- Mayor leveling curve: XP thresholds, per-level building caps, energy rewards, level
  maxima (`Settings.xml` `<User>`)
- Energy system constants: work time, carry amount, building hurry cost/interval
  (`Settings.xml` `<Energy>`)
- Villager simulation constants: speed, haul speed, work rate, homelessness penalty,
  hunger timers (`Settings.xml` `<Villager>`)
- Decoration buff system: categories, per-decoration % bonus, 500% land-wide cap
  (`Settings.xml` `<BuffSystem>`, per-building `<Buffer>` tags)
- Tutorial/onboarding sequence: triggers, objectives, feature locks and exceptions
  (`Tutorials.xml`)
- Seasonal skin system (Winter/Fall reskins swapping sprite names via prefix)
  (`Skins.xml`)
- Starting town layout (`Layout.xml`)

## 6. Systems That Require Modern Equivalents (Original Behavior Unrecoverable)

These need original design work, informed by client-visible hints but not dictated by
recovered server logic:

- **Trading between players** — only UI strings and layout survive; the actual
  request/accept/expire protocol and anti-abuse rules must be designed new (proposal:
  simple synchronous trade offers against a self-hosted save-sync service, or dropped
  entirely for a single-player-first release).
- **Friends / mail / leaderboards / gifting** — these were `ZPRequestMessage` RPCs to
  a dead backend. Needs a from-scratch self-hosted service (or local-only stand-ins)
  if kept at all.
- **Achievements** — no trigger-condition data survives for Trade Nations
  specifically; must be authored fresh, optionally reusing flavor text from the
  confirmed-relevant subset of `achievements_en.json`.
- **Discoveries / alternate land-expansion system** — referenced by
  `AI_INSTRUCTIONS.md` but backed by empty files (`Discoveries.xml`,
  `LandExpands.xml`). Either omit, or design a new "discoveries" unlock system
  consistent with the rest of the progression data.
- **Market buy/sell pricing curve** — the Market building exists (`Objects.xml` id 27)
  and has buy/sell sound cues, but the actual price-formation algorithm is native
  code, not XML. Needs a fresh design (e.g. simple fixed or supply-based pricing).
- **Facebook/Twitter social login and sharing** — defunct SDKs; replace with modern
  equivalents or omit.
- **Original sprite/animation asset pipeline** — until `.RAW`/`.z2raw`/`.bin` formats
  are decoded (or the decision is made to redraw art from scratch), all visuals are a
  modern-equivalent concern, not a faithful-recreation one.

## 7. Related Documents

- `docs/GAME_SYSTEMS.md` — per-system behavior, evidence, dependencies, recreation plan
- `docs/DATA_MODEL.md` — concrete modern data schemas for every system above
- `docs/IMPLEMENTATION_ROADMAP.md` — phased build plan (Godot)
- `docs/MISSING_INFORMATION.md` — consolidated open-investigation list
