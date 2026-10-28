extends Control
## Splash screen — hero art, animated loading bar, rotating tips.
## Preloads the Home scene on a thread (min. display 2.4 s, Asphalt-style).

const HOME_PATH := "res://scenes/home.tscn"
const TIPS := [
	"TIP: DRIFT (SPACE) TO REFILL YOUR NITRO",
	"TIP: HOLD SHIFT FOR NITRO BOOST",
	"TIP: TOUCHDRIVE AUTO-ACCELERATES ON MOBILE",
	"TIP: PRESS C TO CHANGE CAMERA",
	"TIP: WIN SPRINTS TO BUY THE FORMULA LP-830",
]

var _bar: ProgressBar
var _tip_label: Label
var _pct_label: Label
var _elapsed: float = 0.0
var _thread_p: float = 0.0
var _done: bool = false
var _tip_t: float = 0.0
var _tip_i: int = 0


func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/hero_art.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UiKit.full(bg)
	add_child(bg)

	var shade := TextureRect.new()
	shade.texture = UiKit.gradient_tex(Color(0, 0, 0, 0.05), Color(0.01, 0.01, 0.05, 0.94))
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.full(shade)
	add_child(shade)

	var top := UiKit.label("A GAME BY Ahad Shaikh", 17, UiKit.COL_DIM, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 24
	add_child(top)

	# Title
	var center := CenterContainer.new()
	UiKit.full(center)
	add_child(center)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	center.add_child(tv)
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 18)
	th.add_child(UiKit.label("SILVER LAKE", 78, Color.WHITE, "black"))
	th.add_child(UiKit.label("GP", 78, UiKit.COL_ORANGE_L, "black"))
	tv.add_child(th)
	tv.add_child(UiKit.label("L E G E N D S   A R E   M A D E   H E R E", 18, UiKit.COL_CYAN, "bold", HORIZONTAL_ALIGNMENT_CENTER))

	# Loading block
	var bot := VBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 320
	bot.offset_right = -320
	bot.offset_top = -128
	bot.offset_bottom = -34
	bot.add_theme_constant_override("separation", 10)
	add_child(bot)

	_tip_label = UiKit.label(TIPS[0], 15, UiKit.COL_TEXT, "medium", HORIZONTAL_ALIGNMENT_CENTER)
	bot.add_child(_tip_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.add_theme_stylebox_override("background", UiKit.style(Color(0.1, 0.12, 0.22, 0.9), 4, Color(UiKit.COL_CYAN, 0.5), 1))
	_bar.add_theme_stylebox_override("fill", UiKit.style(UiKit.COL_ORANGE, 4))
	bot.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_child(UiKit.label("LOADING...", 13, UiKit.COL_DIM, "bold"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	_pct_label = UiKit.label("0%", 13, UiKit.COL_DIM, "bold")
	row.add_child(_pct_label)
	bot.add_child(row)

	var credit := UiKit.label("MADE BY SAB KA BAAP Ahad Shaikh", 13, Color(UiKit.COL_GOLD, 0.85), "bold", HORIZONTAL_ALIGNMENT_CENTER)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -28
	add_child(credit)

	ResourceLoader.load_threaded_request(HOME_PATH)
	ResourceLoader.load_threaded_request(String(GameState.car_cfg()["path"]))


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(HOME_PATH, prog)
	if prog.size() > 0:
		_thread_p = maxf(_thread_p, float(prog[0]))
	var shown := minf(_thread_p, clampf(_elapsed / 2.4, 0.0, 1.0))
	_bar.value = shown * 100.0
	_pct_label.text = str(int(shown * 100.0)) + "%"

	_tip_t += delta
	if _tip_t > 1.15:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		_tip_label.text = TIPS[_tip_i]

	if st == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= 2.4:
		_done = true
		var ps := ResourceLoader.load_threaded_get(HOME_PATH) as PackedScene
		get_tree().change_scene_to_packed(ps)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		get_tree().change_scene_to_file(HOME_PATH)
