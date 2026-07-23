## ResourceDefinition
## Static content schema for one game resource (Gold, Wood, Rock, Wheat, Wool,
## Lumber, Cut Stone, Cloth, ...). Mirrors Resources.xml in the original game.
## See docs/GAME_SYSTEMS.md §1 and docs/DATA_MODEL.md §1.
##
## Phase 1: schema only. No .tres instances exist yet in data/resources/ —
## no gameplay content has been authored (see docs/IMPLEMENTATION_STATUS.md).
class_name ResourceDefinition
extends Resource

## Original Resources.xml id. Must stay stable — cross-referenced by
## BuildingDefinition costs/storage and ProductionRecipe inputs/outputs.
@export var id: int = -1

@export var display_name: String = ""

## 0 = currency (Gold), 1 = raw/gathered, 2 = refined/produced.
@export var tier: int = 0

## Original scoreValue — consuming formula (net worth? leaderboard score?)
## is not recovered. See docs/MISSING_INFORMATION.md #10.
@export var score_value: float = 0.0

## Starting inventory amount for a new game.
@export var start_value: float = 0.0

## Id of the tier-1 resource this one refines from, or -1 if this resource
## does not refine from another (e.g. Wheat, or any tier-1/currency resource).
@export var refines_from_id: int = -1

## Compact icon-font glyph used by the original's space-constrained UI.
@export var icon_font_char: String = ""
