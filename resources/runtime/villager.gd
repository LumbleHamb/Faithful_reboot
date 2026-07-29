# resources/runtime/villager.gd
# Per-instance runtime state for a single villager.
# Based on docs/DATA_MODEL.md §4
class_name Villager
extends Resource

# [original] Roles observed in video analysis. WORKER/HAULER are generic fallbacks.
enum Role { UNASSIGNED, WORKER, HAULER, WOOD_CUTTER, WOOD_HAULER, FARMER, WHEAT_HAULER }
enum Gender { MALE, FEMALE } # [original] drives VillagerSounds selection + sprite set

@export var villager_id: String = ""            # [new] unique instance id (save-file scoped)
@export var villager_name: String = ""          # [new] display name
@export var gender: Gender = Gender.MALE        # [original]
@export var role: Role = Role.UNASSIGNED        # [original]
@export var assigned_building_instance_id: String = ""  # [new] links to a placed BuildingInstance
@export var home_instance_id: String = ""       # [new] house providing capacity to this villager
@export var is_homeless: bool = false           # [original, derived]
@export var hunger_timer: float = 0.0           # [original, derived]
@export var is_hungry: bool = false             # [original, derived]
