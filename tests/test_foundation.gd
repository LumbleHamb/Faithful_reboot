## FoundationTests
## Manual verification checklist for Phase 1: managers loaded, data system
## works, save round-trip works, time system advances. Run via
## tests/TestRunner.tscn (open it in the editor and press F6 / "Run Current
## Scene", or run headlessly — see docs/IMPLEMENTATION_STATUS.md for the
## exact command used to verify this phase). This is a developer diagnostic,
## not player-facing UI and not an automated CI suite (no assertion
## framework dependency) — see docs/ARCHITECTURE.md §1 tests/.
class_name FoundationTests
extends RefCounted

var _failures: Array[String] = []


func run_all() -> bool:
	_failures.clear()
	_test_managers_present()
	_test_data_manager_loads()
	_test_save_round_trip()
	_test_time_advances()

	if _failures.is_empty():
		print("[FoundationTests] ALL TESTS PASSED")
	else:
		print("[FoundationTests] %d FAILURE(S):" % _failures.size())
		for failure in _failures:
			print("  - %s" % failure)
	return _failures.is_empty()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("[FoundationTests] PASS: %s" % description)
	else:
		_failures.append(description)
		print("[FoundationTests] FAIL: %s" % description)


func _test_managers_present() -> void:
	_check(DataManager != null, "DataManager autoload is present")
	_check(SaveManager != null, "SaveManager autoload is present")
	_check(TimeManager != null, "TimeManager autoload is present")
	_check(GameManager != null, "GameManager autoload is present")
	_check(
		GameManager.current_state == GameManager.State.MAIN_MENU,
		"GameManager reached MAIN_MENU after boot"
	)


func _test_data_manager_loads() -> void:
	DataManager.load_all()
	_check(DataManager.is_loaded(), "DataManager.load_all() completes and sets is_loaded()")
	_check(DataManager.resource_definitions is Dictionary, "resource_definitions index exists")
	_check(DataManager.building_definitions is Dictionary, "building_definitions index exists")
	_check(DataManager.production_recipes is Dictionary, "production_recipes index exists")
	_check(DataManager.worker_definitions is Dictionary, "worker_definitions index exists")


func _test_save_round_trip() -> void:
	var test_slot := 999

	var new_save := SaveManager.create_new_save()
	new_save.player_state.mayor_level = 3
	new_save.player_state.xp_total = 1234.5
	new_save.inventory.resource_amounts[10] = 42.0  # Wood, per Resources.xml id=10

	var saved_ok := SaveManager.save_to_slot(test_slot)
	_check(saved_ok, "SaveManager.save_to_slot() writes without error")

	SaveManager.current_save = null
	var loaded := SaveManager.load_from_slot(test_slot)
	_check(loaded != null, "SaveManager.load_from_slot() reads a save back")

	if loaded != null:
		_check(loaded.player_state.mayor_level == 3, "Loaded PlayerState.mayor_level round-trips")
		_check(is_equal_approx(loaded.player_state.xp_total, 1234.5), "Loaded PlayerState.xp_total round-trips")
		_check(loaded.inventory.resource_amounts.get(10) == 42.0, "Loaded InventoryState.resource_amounts round-trips")

	SaveManager.delete_slot(test_slot)


func _test_time_advances() -> void:
	var t0 := TimeManager.now()
	_check(t0 > 0, "TimeManager.now() returns a positive Unix timestamp")

	var started_at := t0
	_check(not TimeManager.is_elapsed(started_at, 999999.0), "is_elapsed() is false for a duration far in the future")
	_check(TimeManager.is_elapsed(started_at - 100, 10.0), "is_elapsed() is true once duration has passed")

	var remaining := TimeManager.seconds_remaining(started_at, 60.0)
	_check(remaining > 0.0 and remaining <= 60.0, "seconds_remaining() returns a sane in-range value")
