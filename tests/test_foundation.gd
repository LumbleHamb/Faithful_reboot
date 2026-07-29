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
	_test_building_art_loading()
	_test_social_manager_features()

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
	_check(AudioManager != null, "AudioManager autoload is present")
	_check(SocialManager != null, "SocialManager autoload is present")
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


func _test_building_art_loading() -> void:
	var BuildingScene = load("res://scenes/building.tscn")
	var BuildingInstance = load("res://resources/runtime/building_instance.gd")
	
	var building_node = BuildingScene.instantiate()
	var instance = BuildingInstance.new()
	instance.def_id = 101 # Small Cottage
	
	building_node.set_building(instance)
	
	var sprite: Sprite2D = building_node.get_node("Sprite2D")
	_check(sprite != null, "Building scene contains a Sprite2D child")
	
	if sprite != null:
		_check(sprite.texture != null, "Building Sprite2D loaded Cottage icon texture successfully")
		_check(sprite.visible, "Building Sprite2D is visible when valid texture is loaded")
		
		var color_rect: ColorRect = building_node.get_node("ColorRect")
		_check(color_rect.color.a < 1.0, "Footprint ColorRect opacity is reduced for a texture-loaded building")
	
	building_node.queue_free()


func _test_social_manager_features() -> void:
	# Create a mock save game and attach it to SaveManager so SocialManager can execute
	var original_save = SaveManager.current_save
	var test_save = SaveManager.create_new_save()
	
	# Give the player initial Gold, Wood, Wheat
	test_save.inventory.resource_amounts[1] = 500.0 # 500 Gold
	test_save.inventory.resource_amounts[101] = 50.0 # 50 Wood
	test_save.inventory.resource_capacity[101] = 100.0
	test_save.inventory.resource_amounts[40] = 50.0 # 50 Wheat
	test_save.inventory.resource_capacity[40] = 100.0
	
	# Verify pricing loaded and initialized
	var prices = SocialManager.get_market_prices()
	_check(prices.has(101) and prices.has(40), "SocialManager initialized market prices correctly")
	
	# Test buy from market
	var prev_gold = test_save.inventory.resource_amounts[1]
	var prev_wood = test_save.inventory.resource_amounts[101]
	var buy_ok = SocialManager.buy_from_market(101, 10)
	_check(buy_ok, "SocialManager.buy_from_market() executed successfully")
	_check(test_save.inventory.resource_amounts[101] == prev_wood + 10, "Inventory added purchased resource")
	_check(test_save.inventory.resource_amounts[1] < prev_gold, "Inventory deducted Gold for market purchase")
	
	# Test sell to market
	prev_gold = test_save.inventory.resource_amounts[1]
	prev_wood = test_save.inventory.resource_amounts[101]
	var sell_ok = SocialManager.sell_to_market(101, 5)
	_check(sell_ok, "SocialManager.sell_to_market() executed successfully")
	_check(test_save.inventory.resource_amounts[101] == prev_wood - 5, "Inventory removed sold resource")
	_check(test_save.inventory.resource_amounts[1] > prev_gold, "Inventory added Gold for market sale")
	
	# Test friends list
	var friends = SocialManager.get_friends_list()
	_check(friends.size() == 4, "SocialManager loaded exactly 4 simulated virtual friends")
	
	# Test leaderboard compilation
	var leaderboard = SocialManager.get_leaderboard()
	_check(leaderboard.size() == 5, "SocialManager constructed leaderboard with 5 ranked participants (4 friends + player)")
	_check(leaderboard[0].has("name") and leaderboard[0].has("level"), "Leaderboard entries are formatted correctly")
	
	# Test accepting trades
	var trades = SocialManager.get_active_trades()
	_check(trades.size() > 0, "SocialManager generated simulated trades on trade board")
	if trades.size() > 0:
		var trade = trades[0]
		# Mock player inventory so they can afford the trade
		test_save.inventory.resource_amounts[trade["receive_id"]] = trade["receive_amount"] + 10
		test_save.inventory.resource_amounts[trade["give_id"]] = 0.0
		var accept_ok = SocialManager.accept_trade(trade["id"])
		_check(accept_ok, "SocialManager.accept_trade() processed valid trade offer successfully")
	
	# Test inbox claiming
	var messages = SocialManager.get_inbox_messages()
	_check(messages.size() == 2, "SocialManager initialized 2 startup inbox messages")
	var mail_with_gift = messages[0] # mail_1 has wood
	test_save.inventory.resource_amounts[101] = 0.0
	var claim_ok = SocialManager.claim_gift(mail_with_gift["id"])
	_check(claim_ok, "SocialManager.claim_gift() claimed resource attachment successfully")
	_check(test_save.inventory.resource_amounts[101] == 25.0, "Resource attachment deposited into player inventory")
	
	# Restore original save game
	SaveManager.current_save = original_save
