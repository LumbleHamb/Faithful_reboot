## TestRunner
## Entry point for Phase 1 foundation tests. Open tests/TestRunner.tscn in
## the Godot editor and press F6 ("Run Current Scene") to execute — do NOT
## set this as the project's main scene (project.godot's run/main_scene
## stays Main.tscn). Quits automatically so it can also be run headlessly.
extends Node


func _ready() -> void:
	var tests := FoundationTests.new()
	var all_passed := tests.run_all()
	if all_passed:
		print("[TestRunner] Phase 1 foundation verified successfully.")
	else:
		print("[TestRunner] Phase 1 foundation has failures — see log above.")
	get_tree().quit(0 if all_passed else 1)
