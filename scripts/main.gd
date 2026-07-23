## Main
## Root scene script. All boot work already happened in GameManager's
## autoload _ready() (autoloads initialize before the main scene enters the
## tree), so this just confirms boot succeeded and hosts the empty
## containers Phase 2+ will populate. See docs/ARCHITECTURE.md §2.1 and
## docs/IMPLEMENTATION_STATUS.md.
extends Node


func _ready() -> void:
	print("[Main] Scene ready. GameManager state = %s" % GameManager.State.keys()[GameManager.current_state])
