# Trade Nations Faithful Reboot

## Project Goal

Recreate the original Trade Nations mobile game as a modern playable game.

## Original Files

The original game files are located in:

original/TradeNations.app/

Important areas:

- Z2/Scripts/
  - Lua game logic
- bundle/
  - XML configuration
  - buildings
  - resources
  - economy
  - events
- *.json
  - localization and data
- research/
  - extracted text and notes

## AI Tasks

Before writing code:

1. Analyze the original architecture.
2. Document:
   - gameplay loops
   - resource systems
   - buildings
   - production chains
   - economy
   - UI flow
   - player progression
   - networking requirements

3. Create reconstruction plans in docs/.

## Video Analysis Highlights

The `Video_analysis.md` file contains the "holy grail" of information and is now considered the primary source of truth for all implementation details. Its contents must be progressively merged into the core `docs/*.md` files. Key takeaways that must inform all subsequent work are:

*   **Core Loop:** A detailed quest-driven loop: `Quest → Build → Attract Villagers → Assign Jobs → Produce → Store → Earn XP/Gold → Level Up`.
*   **UI & Placement:** The build menu is categorized (Houses, Resources, Shops, etc.). Building placement involves a "ghost" preview, grid-snapping, rotation, and confirmation, with clear visual feedback for valid/invalid locations.
*   **Economy:** Production is driven by assigned workers. Buildings have internal storage, and production halts when full. A global market exists for resource exchange. Premium currency ("Magic Beans") is used to "hurry" timers.
*   **Data Specifics:** The analysis provides concrete data:
    *   **Costs:** e.g., Small Cottage costs 75 Gold, 50 Wood, 25 Wheat.
    *   **Recipes:** e.g., Baker Shop recipes with inputs, outputs, and craft times.
    *   **Leveling:** Specific XP thresholds (e.g., Lvl 6→7 is 2600 XP).
*   **Technical Inferences:** The analysis includes inferred data structures (`TileGrid`, `BuildingData`, `VillagerEntity`), event-driven architecture (`OnBuildingPlaced`, `OnVillagerAssigned`), and villager A* pathfinding.

This information must be used to flesh out the data in `.tres` files and guide the implementation of all gameplay logic.

Do not modify original files.

Use original files as reference only.
