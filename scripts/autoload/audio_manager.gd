# scripts/autoload/audio_manager.gd
extends Node

## AudioManager (autoload)
## Manages SFX pools, background music (BGM), and maps sound IDs 
## from res://original/TradeNations.app/bundle/Sounds.xml.
## Automatically connects to UI buttons and EventBus signals for a highly immersive audio experience.

const SoundsParser = preload("res://tools/xml_import/parse_sounds.gd")

var _sounds: Dictionary = {} # id: int -> Dictionary
var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer

const MAX_SFX_PLAYERS = 8

func _ready() -> void:
	# Parse sounds from original database
	var parsed_sounds = SoundsParser.parse()
	for s in parsed_sounds:
		_sounds[s["id"]] = s
		
	# Create BGM player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.process_mode = PROCESS_MODE_ALWAYS
	add_child(_bgm_player)
	
	# Create SFX pool
	for i in range(MAX_SFX_PLAYERS):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer_%d" % i
		sfx_player.process_mode = PROCESS_MODE_ALWAYS
		add_child(sfx_player)
		_sfx_players.append(sfx_player)
		
	print("[AudioManager] Loaded %d sound definitions, initialized SFX pool of size %d." % [_sounds.size(), MAX_SFX_PLAYERS])
	
	# Wire up EventBus and UI signals
	_connect_game_signals()
	
	# Play background theme music (Sound ID 0 is theme_tune)
	play_music(0)

func play_sfx(sound_id: int) -> void:
	if not _sounds.has(sound_id):
		return
		
	var sound_def = _sounds[sound_id]
	var path = "res://assets/audio/%s.wav" % sound_def["filename"]
	if not FileAccess.file_exists(path):
		return
		
	var stream = load(path) as AudioStream
	if stream:
		var played = false
		for player in _sfx_players:
			if not player.playing:
				player.stream = stream
				player.volume_db = linear_to_db(sound_def["volume"])
				player.play()
				played = true
				break
		# If pool is exhausted, override the first player
		if not played and not _sfx_players.is_empty():
			var player = _sfx_players[0]
			player.stream = stream
			player.volume_db = linear_to_db(sound_def["volume"])
			player.play()

func play_music(sound_id: int) -> void:
	if not _sounds.has(sound_id):
		return
		
	var sound_def = _sounds[sound_id]
	var path = "res://assets/audio/%s.wav" % sound_def["filename"]
	if not FileAccess.file_exists(path):
		return
		
	var stream = load(path) as AudioStream
	if stream:
		if _bgm_player.stream == stream and _bgm_player.playing:
			return
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(sound_def["volume"])
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm_player.play()

func stop_music() -> void:
	_bgm_player.stop()

func _connect_game_signals() -> void:
	# Listen to global SceneTree for any new buttons added to play click sounds automatically!
	get_tree().node_added.connect(_on_node_added)
	
	# Recursively search current tree for any existing buttons
	_connect_buttons_recursive(get_tree().root)
	
	# Connect to EventBus signals
	EventBus.building_selected_for_placement.connect(_on_building_selected_for_placement)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_instance_selected.connect(_on_building_instance_selected)
	EventBus.worker_assigned.connect(_on_worker_assigned)
	EventBus.hauler_assigned.connect(_on_hauler_assigned)
	EventBus.recipe_completed.connect(_on_recipe_completed)
	EventBus.level_up.connect(_on_level_up)

func _on_node_added(node: Node) -> void:
	if node is Button:
		_connect_button(node)

func _connect_buttons_recursive(node: Node) -> void:
	if node is Button:
		_connect_button(node)
	for child in node.get_children():
		_connect_buttons_recursive(child)

func _connect_button(button: Button) -> void:
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_pressed(button: Button) -> void:
	if button.name == "CloseButton" or button.text.to_lower() == "close" or button.text.to_lower() == "cancel":
		play_sfx(1) # menu_back
	else:
		play_sfx(3) # menu_select

func _on_building_selected_for_placement(_building_def: BuildingDefinition) -> void:
	play_sfx(3) # menu_select

func _on_building_placed(building_instance: BuildingInstance) -> void:
	play_sfx(17) # buy_sell_buttons
	_play_building_sound(building_instance.def_id)

func _on_building_instance_selected(building_instance: BuildingInstance) -> void:
	play_sfx(29) # message pop-up
	_play_building_sound(building_instance.def_id)

func _on_worker_assigned(villager: Villager, _building_instance: BuildingInstance) -> void:
	_play_random_bark(villager.gender)

func _on_hauler_assigned(villager: Villager, _building_instance: BuildingInstance) -> void:
	_play_random_bark(villager.gender)

func _on_recipe_completed(_building_instance_id: int, recipe_id: int, _reward: CostBundle) -> void:
	if recipe_id == 1: # wood
		play_sfx(31) # 05_stock_pile_wood
	else:
		play_sfx(17) # generic complete

func _on_level_up(_new_level: int) -> void:
	play_sfx(4) # level_up iconic SFX

func _play_building_sound(def_id: int) -> void:
	match def_id:
		1: # Town Hall
			play_sfx(29) # pop-up
		101: # Small Cottage
			play_sfx(15) # house / cottage select sfx
		201: # Logging Camp
			play_sfx(31) # wood camp sfx

func _play_random_bark(gender: int) -> void:
	if gender == Villager.Gender.FEMALE:
		var female_sfx_ids = [23, 24, 25, 26, 27]
		var rand_id = female_sfx_ids[randi() % female_sfx_ids.size()]
		play_sfx(rand_id)
	else:
		var male_sfx_ids = [18, 28]
		var rand_id = male_sfx_ids[randi() % male_sfx_ids.size()]
		play_sfx(rand_id)
