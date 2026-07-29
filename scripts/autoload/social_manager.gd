# scripts/autoload/social_manager.gd
extends Node

## SocialManager (autoload)
## Implements the complete offline simulated social layer:
## 1. Dynamic fluctuating market pricing with supply and demand feedback.
## 2. Simulated friends list with level progression.
## 3. simulated trading board with accepting/expiring trade offers.
## 4. Inbox message system with attachable resource gifts.
## 5. Friend and global leaderboards.

const SaveGame = preload("res://resources/runtime/save_game.gd")

var _tick_timer: float = 0.0
const TICK_INTERVAL = 15.0 # Speed up simulated activity tick to 15 seconds for more responsive offline gameplay

# Base defaults for prices
const BASE_MARKET_PRICES = {
	101: { "buy": 12.0, "sell": 8.0 }, # Wood (101)
	40: { "buy": 18.0, "sell": 12.0 }  # Wheat (40)
}

func _ready() -> void:
	print("[SocialManager] Offline Social & Market simulation initialized.")

func _process(delta: float) -> void:
	# Run a simulation tick periodically
	var save = _get_save()
	if not save:
		return
		
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer = 0.0
		_simulate_social_tick(save)

## Returns the verified and self-healed current save game resource.
func _get_save() -> SaveGame:
	var save = SaveManager.current_save
	if save:
		if save.market_prices.is_empty():
			_initialize_default_prices(save)
		if save.friends_list.is_empty():
			_initialize_default_friends(save)
		if save.active_trades.is_empty():
			_initialize_default_trades(save)
		if save.inbox_messages.is_empty():
			_initialize_default_inbox(save)
		if save.daily_special.is_empty():
			_initialize_default_special(save)
	return save

func _initialize_default_prices(save: SaveGame) -> void:
	save.market_prices = BASE_MARKET_PRICES.duplicate(true)

func _initialize_default_friends(save: SaveGame) -> void:
	save.friends_list = [
		{ "name": "Bob", "level": 4, "xp": 300.0, "seed": 12345 },
		{ "name": "Alice", "level": 6, "xp": 1200.0, "seed": 67890 },
		{ "name": "Charlie", "level": 2, "xp": 80.0, "seed": 11111 },
		{ "name": "Daisy", "level": 10, "xp": 8000.0, "seed": 55555 }
	]

func _initialize_default_trades(save: SaveGame) -> void:
	save.active_trades = [
		{ "id": "trade_1", "friend_name": "Alice", "give_id": 40, "give_amount": 20, "receive_id": 101, "receive_amount": 30, "expiry": 180 },
		{ "id": "trade_2", "friend_name": "Bob", "give_id": 1, "give_amount": 150, "receive_id": 40, "receive_amount": 15, "expiry": 240 },
		{ "id": "trade_3", "friend_name": "Charlie", "give_id": 101, "give_amount": 10, "receive_id": 1, "receive_amount": 50, "expiry": 120 }
	]

func _initialize_default_inbox(save: SaveGame) -> void:
	save.inbox_messages = [
		{
			"id": "mail_1",
			"sender": "Alice",
			"body": "Welcome to the valley, Mayor! I noticed you are setting up your cottage houses. Here is some spare Wood from my logging camp to help you build out faster!",
			"resource_id": 101,
			"resource_amount": 25,
			"claimed": false,
			"read": false
		},
		{
			"id": "mail_2",
			"sender": "Mayor's Guild",
			"body": "Congratulations on your appointment! The town council expects great things. Visit the leaderboard often to see how your mayor level ranks against neighboring towns.",
			"resource_id": -1,
			"resource_amount": 0,
			"claimed": false,
			"read": false
		}
	]

func _initialize_default_special(save: SaveGame) -> void:
	save.daily_special = {
		"def_id": 150, # Fountain (ID 150)
		"name": "Fountain",
		"cost_beans": 5, # Sale price
		"expires": 20
	}

func _spawn_new_special(save: SaveGame) -> void:
	var decorations = []
	for b_def in DataManager.get_all_building_definitions():
		if b_def.type == 5: # DECORATION
			decorations.append(b_def)
			
	if not decorations.is_empty():
		var selected = decorations[randi() % decorations.size()]
		save.daily_special = {
			"def_id": selected.id,
			"name": selected.display_name,
			"cost_beans": int(randf_range(3.0, 15.0)),
			"expires": 20
		}
	else:
		_initialize_default_special(save)

func _simulate_social_tick(save: SaveGame) -> void:
	# 1. Fluctuate Market Prices slightly
	for res_id in save.market_prices.keys():
		var data = save.market_prices[res_id]
		# Random walk multiplier between -5% and +5%
		var change = randf_range(0.95, 1.05)
		data["buy"] = clamp(data["buy"] * change, 5.0, 50.0)
		data["sell"] = clamp(data["sell"] * change, 3.0, 40.0)
		# Ensure sell is always slightly lower than buy to prevent instant arbitrage exploit
		if data["sell"] >= data["buy"]:
			data["sell"] = data["buy"] * 0.7
			
	# 2. Advance Virtual Friends XP/Levels
	for friend in save.friends_list:
		var xp_gain = randf_range(5.0, 30.0)
		friend["xp"] += xp_gain
		var level = friend["level"]
		var threshold = ProgressionManager.XP_THRESHOLDS.get(level, 99999)
		if friend["xp"] >= threshold:
			friend["xp"] -= threshold
			friend["level"] += 1
			print("[SocialManager] Virtual friend %s leveled up to Level %d!" % [friend["name"], friend["level"]])

	# 3. Handle active trades timers and replacement
	var trades_to_keep = []
	for trade in save.active_trades:
		trade["expiry"] -= 1
		if trade["expiry"] > 0:
			trades_to_keep.append(trade)
	save.active_trades = trades_to_keep

	# Randomly spawn a new trade if we have space (max 5 active)
	if save.active_trades.size() < 5 and randf() < 0.25:
		_spawn_random_trade(save)

	# 4. Randomly spawn an inbox gift message (10% chance per tick)
	if randf() < 0.1:
		_spawn_random_gift(save)
		
	# 5. Tick down Daily Special offer
	if save.daily_special.has("expires"):
		save.daily_special["expires"] -= 1
		if save.daily_special["expires"] <= 0:
			_spawn_new_special(save)

func _spawn_random_trade(save: SaveGame) -> void:
	var friends = ["Bob", "Alice", "Charlie", "Daisy"]
	var friend = friends[randi() % friends.size()]
	
	# Alternate giving wood and receiving wheat, or vice versa
	var give_wood = randf() < 0.5
	var give_id = 101 if give_wood else 40
	var give_qty = int(randf_range(10.0, 40.0))
	var receive_id = 40 if give_wood else 101
	var receive_qty = int(randf_range(8.0, 35.0))
	
	# Give or receive gold instead sometimes
	if randf() < 0.3:
		if randf() < 0.5:
			give_id = 1
			give_qty = int(randf_range(100.0, 400.0))
		else:
			receive_id = 1
			receive_qty = int(randf_range(100.0, 400.0))

	var new_trade = {
		"id": "trade_%d" % int(TimeManager.now() + randi()),
		"friend_name": friend,
		"give_id": give_id,
		"give_amount": give_qty,
		"receive_id": receive_id,
		"receive_amount": receive_qty,
		"expiry": int(randf_range(60.0, 300.0))
	}
	save.active_trades.append(new_trade)

func _spawn_random_gift(save: SaveGame) -> void:
	var friends = ["Bob", "Alice", "Charlie", "Daisy"]
	var sender = friends[randi() % friends.size()]
	
	var res_id = 101 if randf() < 0.5 else 40
	var res_name = "Wood" if res_id == 101 else "Wheat"
	var qty = int(randf_range(10.0, 30.0))
	
	var bodies = [
		"Hey! I had an abundant harvest at my town today. Thought you could use some extra %s for your inventory. Have a great day!",
		"Greetings, fellow Mayor! Here is a token of appreciation from my villagers. Keep up the amazing work!",
		"Hello! Visited your town layout earlier and it looks fantastic. Here are some %s supplies to help with your progression."
	]
	var body = bodies[randi() % bodies.size()] % res_name

	var new_mail = {
		"id": "mail_%d" % int(TimeManager.now() + randi()),
		"sender": sender,
		"body": body,
		"resource_id": res_id,
		"resource_amount": qty,
		"claimed": false,
		"read": false
	}
	save.inbox_messages.append(new_mail)

# --- Public API called by UI ---

## Gets the dynamic market rates: { resource_id -> { "buy": float, "sell": float } }
func get_market_prices() -> Dictionary:
	var save = _get_save()
	if save:
		return save.market_prices
	return BASE_MARKET_PRICES

## Purchases a resource from the market
func buy_from_market(resource_id: int, quantity: int) -> bool:
	var save = _get_save()
	if not save:
		return false
		
	var prices = save.market_prices.get(resource_id)
	if not prices:
		return false
		
	var cost = int(prices["buy"] * quantity)
	
	# Check affordability
	if InventoryManager.amount(1) < cost:
		return false
		
	# Check space
	if not InventoryManager.can_add(resource_id, quantity):
		return false
		
	# Transaction
	InventoryManager.remove(1, cost) # Remove gold
	InventoryManager.add(resource_id, quantity) # Add resource
	
	# Supply decreases -> price increases slightly!
	prices["buy"] = clamp(prices["buy"] * 1.03, 5.0, 50.0)
	prices["sell"] = clamp(prices["sell"] * 1.03, 3.0, 40.0)
	
	AudioManager.play_sfx(17) # buy_sell_buttons sfx
	return true

## Sells a resource to the market
func sell_to_market(resource_id: int, quantity: int) -> bool:
	var save = _get_save()
	if not save:
		return false
		
	# Check inventory
	if InventoryManager.amount(resource_id) < quantity:
		return false
		
	var prices = save.market_prices.get(resource_id)
	if not prices:
		return false
		
	var payout = int(prices["sell"] * quantity)
	
	# Transaction
	InventoryManager.remove(resource_id, quantity) # Remove resource
	InventoryManager.add(1, payout) # Add gold
	
	# Supply increases -> price decreases slightly!
	prices["buy"] = clamp(prices["buy"] * 0.97, 5.0, 50.0)
	prices["sell"] = clamp(prices["sell"] * 0.97, 3.0, 40.0)
	
	AudioManager.play_sfx(17) # buy_sell_buttons sfx
	return true

## Gets active trade offers on the trade board
func get_active_trades() -> Array:
	var save = _get_save()
	if save:
		return save.active_trades
	return []

## Accepts a trade offer on the board
func accept_trade(trade_id: String) -> bool:
	var save = _get_save()
	if not save:
		return false
		
	var found_trade = null
	for t in save.active_trades:
		if t["id"] == trade_id:
			found_trade = t
			break
			
	if not found_trade:
		return false
		
	var receive_id = found_trade["receive_id"]
	var receive_amount = found_trade["receive_amount"]
	var give_id = found_trade["give_id"]
	var give_amount = found_trade["give_amount"]
	
	# Verify player can afford what the friend wants
	if InventoryManager.amount(receive_id) < receive_amount:
		return false
		
	# Verify player has space for what the friend is giving
	if not InventoryManager.can_add(give_id, give_amount):
		return false
		
	# Perform trade
	InventoryManager.remove(receive_id, receive_amount)
	InventoryManager.add(give_id, give_amount)
	
	# Remove trade from board
	save.active_trades.erase(found_trade)
	AudioManager.play_sfx(17) # buy_sell_buttons / generic complete
	return true

## Gets the list of virtual friends
func get_friends_list() -> Array:
	var save = _get_save()
	if save:
		return save.friends_list
	return []

## Gets the dynamic leaderboard ranked entries
func get_leaderboard() -> Array:
	var save = _get_save()
	if not save:
		return []
		
	# Compile rankings: AI Friends + Player
	var entries = []
	
	# Add player
	var player_level = 1
	var player_xp = 0.0
	if save.player_state:
		player_level = save.player_state.mayor_level
		player_xp = save.player_state.xp_total
		
	entries.append({
		"name": "You (Mayor)",
		"level": player_level,
		"xp": player_xp,
		"is_player": true
	})
	
	# Add virtual friends
	for friend in save.friends_list:
		entries.append({
			"name": friend["name"],
			"level": friend["level"],
			"xp": friend["xp"],
			"is_player": false
		})
		
	# Sort by level (descending), then XP (descending)
	entries.sort_custom(func(a, b):
		if a["level"] != b["level"]:
			return a["level"] > b["level"]
		return a["xp"] > b["xp"]
	)
	
	return entries

## Gets the inbox messages
func get_inbox_messages() -> Array:
	var save = _get_save()
	if save:
		return save.inbox_messages
	return []

## Claims the attached resource gift from an inbox message
func claim_gift(mail_id: String) -> bool:
	var save = _get_save()
	if not save:
		return false
		
	for mail in save.inbox_messages:
		if mail["id"] == mail_id:
			if mail["claimed"] or mail["resource_id"] == -1:
				return false
				
			var res_id = mail["resource_id"]
			var qty = mail["resource_amount"]
			
			# Check space
			if not InventoryManager.can_add(res_id, qty):
				return false
				
			# Claim it!
			InventoryManager.add(res_id, qty)
			mail["claimed"] = true
			mail["read"] = true
			AudioManager.play_sfx(17) # generic collect
			return true
			
	return false

## Sends a resource gift of Wood or Wheat to a virtual friend
func send_gift_to_friend(friend_name: String, resource_id: int, amount: int) -> bool:
	var save = _get_save()
	if not save:
		return false
		
	# Check player inventory
	if InventoryManager.amount(resource_id) < amount:
		return false
		
	# Deduct
	InventoryManager.remove(resource_id, amount)
	
	# Add simulated log feedback
	print("[SocialManager] Gift of %d resource %d sent to %s!" % [amount, resource_id, friend_name])
	
	# Friendly reply with a small XP reward as return!
	var rand_xp = amount * 2.0
	ProgressionManager.add_xp(rand_xp)
	
	var reply_mail = {
		"id": "mail_reply_%d" % int(TimeManager.now() + randi()),
		"sender": friend_name,
		"body": "Thanks for the generous gift of %s! My villagers are super grateful, so here's a small return of XP favor!" % ("Wood" if resource_id == 101 else "Wheat"),
		"resource_id": -1,
		"resource_amount": 0,
		"claimed": true,
		"read": false
	}
	save.inbox_messages.append(reply_mail)
	
	AudioManager.play_sfx(3) # menu_select
	return true

## Purchases Magic Beans using gathered raw resources (Gold, Wood, Wheat) to balance the economy
func buy_magic_beans(tier: int) -> bool:
	var save = _get_save()
	if not save or not save.player_state:
		return false
		
	var gold_cost = 0.0
	var wood_cost = 0.0
	var wheat_cost = 0.0
	var beans_granted = 0.0
	
	match tier:
		1:
			gold_cost = 500.0
			wood_cost = 100.0
			wheat_cost = 50.0
			beans_granted = 5.0
		2:
			gold_cost = 900.0
			wood_cost = 180.0
			wheat_cost = 90.0
			beans_granted = 10.0
		3:
			gold_cost = 2000.0
			wood_cost = 400.0
			wheat_cost = 200.0
			beans_granted = 25.0
		_:
			return false
			
	# Validate affordability
	if InventoryManager.amount(1) < gold_cost:
		return false
	if InventoryManager.amount(101) < wood_cost:
		return false
	if InventoryManager.amount(40) < wheat_cost:
		return false
		
	# Deduct costs
	InventoryManager.remove(1, gold_cost)
	InventoryManager.remove(101, wood_cost)
	InventoryManager.remove(40, wheat_cost)
	
	# Add Magic Beans
	save.player_state.currency_magic_beans += beans_granted
	
	# Emit event
	EventBus.resource_changed.emit(1, InventoryManager.amount(1))
	
	AudioManager.play_sfx(17) # buy/sell chime sfx
	return true

## Purchases the active Daily Special item using premium Magic Beans
func buy_daily_special() -> bool:
	var save = _get_save()
	if not save or not save.player_state or save.daily_special.is_empty():
		return false
		
	var special = save.daily_special
	var cost = special["cost_beans"]
	
	# Validate Magic Beans
	if save.player_state.currency_magic_beans < cost:
		return false
		
	# Deduct premium currency
	save.player_state.currency_magic_beans -= cost
	
	# Instantly place this decoration into their town layout starting_objects
	var new_instance = BuildingInstance.new()
	new_instance.instance_id = "special_%d" % int(TimeManager.now() + randi())
	new_instance.def_id = special["def_id"]
	new_instance.x = int(randf_range(2.0, 10.0))
	new_instance.y = int(randf_range(2.0, 10.0))
	new_instance.rotation_degrees = 0.0
	new_instance.construction_complete = true # Instant build!
	
	save.town_layouts["Vanilla"].starting_objects.append(new_instance)
	
	# Instantiates it on the screen immediately
	EventBus.building_placed.emit(new_instance)
	
	print("[SocialManager] Daily special purchased: %s!" % special["name"])
	
	# Select a new special
	_spawn_new_special(save)
	
	AudioManager.play_sfx(4) # fanfare level up sfx
	return true

## Purchases a land size expansion, increasing active buildable bounds
func buy_land_expansion(upgrade_id: int, pay_with_beans: bool = false) -> bool:
	var save = _get_save()
	if not save or not save.player_state:
		return false
		
	var target_size = 0
	var gold_cost = 0.0
	var beans_cost = 0.0
	
	match upgrade_id:
		1:
			target_size = 56
			gold_cost = 1000.0
			beans_cost = 10.0
		2:
			target_size = 64
			gold_cost = 2500.0
			beans_cost = 25.0
		3:
			target_size = 72
			gold_cost = 5000.0
			beans_cost = 50.0
		4:
			target_size = 80
			gold_cost = 8000.0
			beans_cost = 80.0
		5:
			target_size = 88
			gold_cost = 12000.0
			beans_cost = 120.0
		6:
			target_size = 104
			gold_cost = 20000.0
			beans_cost = 200.0
		7:
			target_size = 112
			gold_cost = 30000.0
			beans_cost = 300.0
		8:
			target_size = 120
			gold_cost = 45000.0
			beans_cost = 450.0
		9:
			target_size = 128
			gold_cost = 60000.0
			beans_cost = 600.0
		99:
			target_size = 136
			gold_cost = 80000.0
			beans_cost = 800.0
		115:
			target_size = 144
			gold_cost = 100000.0
			beans_cost = 1000.0
		_:
			return false
			
	# Verify player's current size is smaller than target_size
	if save.player_state.active_land_size >= target_size:
		return false
		
	# Perform transaction
	if pay_with_beans:
		if save.player_state.currency_magic_beans < beans_cost:
			return false
		save.player_state.currency_magic_beans -= beans_cost
	else:
		if InventoryManager.amount(1) < gold_cost:
			return false
		InventoryManager.remove(1, gold_cost)
		
	# Upgrade!
	save.player_state.active_land_size = target_size
	
	# Emit event
	EventBus.resource_changed.emit(1, InventoryManager.amount(1))
	
	print("[SocialManager] Upgraded land boundary footprint to %dx%d!" % [target_size, target_size])
	AudioManager.play_sfx(4) # fanfare level up chime sfx
	return true

## Purchases a seasonal skin theme using gathered raw resources to keep the economy balanced
func buy_skin(skin_name: String) -> bool:
	var save = _get_save()
	if not save or not save.player_state:
		return false
		
	# Check if already unlocked
	if save.player_state.unlocked_skins.has(skin_name):
		return false
		
	var gold_cost = 0.0
	var wood_cost = 0.0
	var wheat_cost = 0.0
	
	match skin_name:
		"Winter":
			gold_cost = 3000.0
			wood_cost = 500.0
			wheat_cost = 200.0
		"Halloween":
			gold_cost = 4000.0
			wood_cost = 600.0
			wheat_cost = 300.0
		"FrontierWinter":
			gold_cost = 5000.0
			wood_cost = 800.0
			wheat_cost = 400.0
		_:
			return false
			
	# Validate players can afford
	if InventoryManager.amount(1) < gold_cost: # Gold (ID 1)
		return false
	if InventoryManager.amount(101) < wood_cost: # Wood (ID 101)
		return false
	if InventoryManager.amount(40) < wheat_cost: # Wheat (ID 40)
		return false
		
	# Deduct costs
	InventoryManager.remove(1, gold_cost)
	InventoryManager.remove(101, wood_cost)
	InventoryManager.remove(40, wheat_cost)
	
	# Unlock skin
	save.player_state.unlocked_skins.append(skin_name)
	
	# Emit event
	EventBus.resource_changed.emit(1, InventoryManager.amount(1))
	
	# Play nice fanfare sound
	print("[SocialManager] Unlocked seasonal skin theme: %s!" % skin_name)
	AudioManager.play_sfx(4) # fanfare sfx
	return true

## Sets the player's active visual skin theme if unlocked
func set_active_skin(skin_name: String) -> bool:
	var save = _get_save()
	if not save or not save.player_state:
		return false
		
	# Verify skin is unlocked
	if not save.player_state.unlocked_skins.has(skin_name) and skin_name != "Vanilla":
		return false
		
	# Set active skin
	save.player_state.active_skin = skin_name
	print("[SocialManager] Active skin theme updated to: %s!" % skin_name)
	
	# Play nice click sound
	AudioManager.play_sfx(17) # complete/buy chime
	return true
