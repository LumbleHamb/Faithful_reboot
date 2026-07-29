# resources/runtime/tutorial_progress.gd
# Per-player runtime state for tutorial progression.
# Based on docs/DATA_MODEL.md §8
class_name TutorialProgress
extends Resource

@export var completed_ids: Array[int] = []        # [original, derived]
@export var active_id: int = -1                    # [new] currently in-progress tutorial
@export var objective_progress: Dictionary = {}    # [new] { objective_index: current_count }
