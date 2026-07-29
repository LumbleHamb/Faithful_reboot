# resources/shared/prerequisite_entry.gd
extends Resource
class_name PrerequisiteEntry

enum PrerequisiteKind {
    PLAYER_LEVEL,
    BUILDING_COUNT,
    TUTORIAL_COMPLETED
}

@export var kind: PrerequisiteKind
@export var target_id: int = -1 # PlayerLevel: level, BuildingCount: def_id, TutorialCompleted: tutorial_id
@export var required_count: int = 1 # for BUILDING_COUNT
