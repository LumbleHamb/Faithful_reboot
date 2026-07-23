## WorkerDefinition
## Static content schema for villager/worker simulation constants and job
## types. Mirrors Settings.xml <Villager>/<VillagerSounds>/<AdoptedVillagers>.
## See docs/GAME_SYSTEMS.md §5 and docs/DATA_MODEL.md §4 (VillagerSimConstants).
##
## Phase 1: schema only. No .tres instances exist yet in data/workers/ — no
## gameplay content has been authored (see docs/IMPLEMENTATION_STATUS.md).
##
## This is the STATIC content-definition counterpart only. Per-instance
## runtime villager state (assignment, hunger timer, homeless flag) belongs
## to save data, not content data — that's a Phase 2+ concern once
## BuildingDefinition placement exists to assign villagers to (see
## docs/DATA_MODEL.md §4 "Villager", distinct from this class).
class_name WorkerDefinition
extends Resource

## e.g. "default", or a job-type key. Original data has one global constant
## set (Settings.xml <Villager>) rather than per-job-type variants, but this
## is modeled as an id-keyed table in case that changes.
@export var id: String = ""

## Flavor-only job title (e.g. "Wood Cutter"), for display purposes only.
@export var job_label: String = ""

@export var speed: float = 1.0
@export var haul_speed: float = 1.0
@export var work_rate: float = 1.0

## Productivity multiplier applied while a villager is homeless.
@export var homeless_modifier: float = 1.0

@export var eat_time_seconds: float = 0.0
@export var hunger_length_min: float = 0.0
@export var hunger_length_max: float = 0.0

## Max resources a hauler carries per trip.
@export var carry_amount: float = 0.0

## { resource_id: int -> amount: float } cost to adopt an additional
## villager beyond natural house-driven growth.
@export var adopt_cost: Dictionary = {}
