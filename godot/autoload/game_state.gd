extends Node
## Silver Lake GP — global game state (autoload "GameState")
## Save data, car catalogue, career events, input map, tiny synth SFX.

const SAVE_PATH := "user://silver_lake_gp.cfg"

# ---------------------------------------------------------------- cars
# yaw_offset_deg: rotation so the model nose faces -Z (verified offline):
#   Saba V12   nose = +X in file  ->  90
#   Formula    nose = +Z in file  -> 180   (wheels merged per-axle: "axle")
#   P72 GT     nose = +Z in file  -> 180   (single merged body: "none")
const CARS := [
	{
		"name": "SABA V12 '95", "class": "A",
		"path": "res://assets/cars/saba-v12.glb",
		"yaw_offset_deg": 90.0, "wheel_mode": "tagged", "length_m": 4.55,
		"top_speed": 62.0, "boost_speed": 84.0, "accel": 19.0, "nitro_power": 30.0,
		"price": 0,
		"stats": {"speed": 78, "accel": 74, "handling": 80, "nitro": 72},
		"desc": "The sunset wedge. Balanced Italian-style V12 hero car.",
	},
	{
		"name": "FORMULA LP-830 SDC", "class": "S",
		"path": "res://assets/cars/formula-lp830.glb",
		"yaw_offset_deg": 180.0, "wheel_mode": "axle", "length_m": 5.0,
		"top_speed": 69.0, "boost_speed": 94.0, "accel": 25.0, "nitro_power": 33.0,
		"price": 45000,
		"stats": {"speed": 92, "accel": 95, "handling": 88, "nitro": 80},
		"desc": "Open-wheel missile. Brutal launch, scalpel handling.",
	},
	{
		"name": "P72 GRAN TURISMO", "class": "A",
		"path": "res://assets/cars/de-tomaso-p72.glb",
		"yaw_offset_deg": 180.0, "wheel_mode": "none", "length_m": 4.6,
		"top_speed": 64.0, "boost_speed": 88.0, "accel": 20.0, "nitro_power": 38.0,
		"price": 30000,
		"stats": {"speed": 82, "accel": 70, "handling": 76, "nitro": 90},
		"desc": "Retro-future royalty with endless nitro breath.",
	},
]

const CAREER_EVENTS := [
	{
		"title": "SILVER LAKE SPRINT I", "subtitle": "First blood at the lake",
		"banner": "res://assets/ui/banner-silver-lake.jpg",
		"reward": 8000, "ai_count": 5, "ai_speed": 0.94,
	},
	{
		"title": "SILVER LAKE SPRINT II", "subtitle": "Rivals get serious",
		"banner": "res://assets/ui/banner-coastal.jpg",
		"reward": 14000, "ai_count": 5, "ai_speed": 1.0,
	},
	{
		"title": "LEGEND OF THE LAKE", "subtitle": "Beat the best. Become the baap.",
		"banner": "res://assets/ui/banner-city.jpg",
		"reward": 25000, "ai_count": 5, "ai_speed": 1.06,
	},
]

const POSITION_REWARDS := [1.0, 0.7, 0.5, 0.35, 0.25, 0.15]

# ---------------------------------------------------------------- state
var credits: int = 60000
var tokens: int = 150
var selected_car: int = 0
var owned: Array = [true, false, false]
var career_done: Array = [false, false, false]
var best_times: Array = [0.0, 0.0, 0.0]

var settings := {
	"sfx": 0.9,
	"touchdrive": true,   # auto-accelerate (Asphalt TouchDrive style)
	"tilt": false,         # tilt steering on mobile
	"touch_ui": true,      # show on-screen controls when a touchscreen exists
}

# Filled by menus before loading the race scene.
var next_race := {
	"mode": "sprint",      # "sprint" | "roam"
	"title": "QUICK SPRINT",
	"reward": 6000,
	"ai_count": 5,
	"ai_speed": 0.97,
	"career_idx": -1,
}

var popup_shown_this_launch: bool = false

var _click_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_load()
	_setup_input()
	apply_audio_settings()
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = make_tone(1350.0, 0.06, 0.3)
	add_child(_click_player)


# ---------------------------------------------------------------- save
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "credits", credits)
	cfg.set_value("player", "tokens", tokens)
	cfg.set_value("player", "selected_car", selected_car)
	cfg.set_value("player", "owned", owned)
	cfg.set_value("career", "done", career_done)
	cfg.set_value("career", "best_times", best_times)
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	credits = int(cfg.get_value("player", "credits", credits))
	tokens = int(cfg.get_value("player", "tokens", tokens))
	selected_car = int(cfg.get_value("player", "selected_car", 0))
	owned = cfg.get_value("player", "owned", owned)
	career_done = cfg.get_value("career", "done", career_done)
	best_times = cfg.get_value("career", "best_times", best_times)
	for k in settings.keys():
		settings[k] = cfg.get_value("settings", k, settings[k])
	if selected_car < 0 or selected_car >= CARS.size():
		selected_car = 0
	while owned.size() < CARS.size():
		owned.append(false)
	while career_done.size() < CAREER_EVENTS.size():
		career_done.append(false)
	while best_times.size() < CAREER_EVENTS.size():
		best_times.append(0.0)
	owned[0] = true


# ---------------------------------------------------------------- helpers
func car_cfg(i: int = -1) -> Dictionary:
	return CARS[selected_car if i < 0 else i]


func fmt_money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func fmt_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.---"
	var m := int(t) / 60
	var s := int(t) % 60
	var ms := int((t - floor(t)) * 1000.0)
	return "%d:%02d.%03d" % [m, s, ms]


func try_buy_car(i: int) -> bool:
	if owned[i]:
		return true
	var price := int(CARS[i]["price"])
	if credits < price:
		return false
	credits -= price
	owned[i] = true
	save()
	return true


func play_click() -> void:
	if _click_player:
		_click_player.play()


func apply_audio_settings() -> void:
	var v := float(settings["sfx"])
	AudioServer.set_bus_mute(0, v <= 0.01)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))


func make_tone(freq: float, dur: float, volume: float = 0.5) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var frames := int(dur * 22050.0)
	var data := PackedByteArray()
	data.resize(frames)
	for i in frames:
		var t := float(i) / 22050.0
		var env := 1.0 - float(i) / float(maxi(frames, 1))
		var s := sin(TAU * freq * t) * volume * env
		data[i] = int(clampf(128.0 + s * 127.0, 0.0, 255.0))
	stream.data = data
	return stream


# ---------------------------------------------------------------- input
func _setup_input() -> void:
	_add_keys("accelerate", [KEY_W, KEY_UP])
	_add_keys("brake", [KEY_S, KEY_DOWN])
	_add_keys("steer_left", [KEY_A, KEY_LEFT])
	_add_keys("steer_right", [KEY_D, KEY_RIGHT])
	_add_keys("drift", [KEY_SPACE])
	_add_keys("nitro", [KEY_SHIFT])
	_add_keys("camera", [KEY_C])
	_add_keys("reset_car", [KEY_R])
	_add_keys("teleport", [KEY_T])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	# Gamepad
	_add_joy_motion("accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_motion("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_motion("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("nitro", JOY_BUTTON_A)
	_add_joy_button("drift", JOY_BUTTON_B)
	_add_joy_button("camera", JOY_BUTTON_Y)
	_add_joy_button("reset_car", JOY_BUTTON_X)
	_add_joy_button("pause", JOY_BUTTON_START)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _add_joy_motion(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)
