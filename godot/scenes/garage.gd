extends Node3D
## Garage — turntable car browser with stats, buy/select, Asphalt-style cards.

var _show: Dictionary
var _idx: int = 0
var _rig_root: Node3D
var _ui_root: Control
var _top: Dictionary
var _name_l: Label
var _class_l: Label
var _desc_l: Label
var _price_l: Label
var _action_btn: Button
var _race_btn: Button
var _rows := {}
var _t: float = 0.0


func _ready() -> void:
	_show = Showroom.create(self)
	_idx = GameState.selected_car
	_build_ui()
	_show_car(_idx)


func _process(delta: float) -> void:
	_t += delta
	(_show["car_root"] as Node3D).rotation.y += delta * 0.35
	var halo := _show["halo"] as MeshInstance3D
	(halo.mesh.material as StandardMaterial3D).emission_energy_multiplier = 2.3 + sin(_t * 2.0) * 0.5


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui_root = Control.new()
	UiKit.full(_ui_root)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui_root)

	_top = UiKit.top_bar()
	_ui_root.add_child(_top["root"])
	(_top["menu"] as Button).pressed.connect(func() -> void: UiKit.settings_popup(_ui_root))
	(_top["mail"] as Button).pressed.connect(func() -> void:
		UiKit.popup(_ui_root, "MAIL", "No new messages.\nWin sprints, earn CR, grow the collection."))

	var title := UiKit.label("GARAGE", 34, UiKit.COL_ORANGE_L, "black")
	title.position = Vector2(28, 86)
	_ui_root.add_child(title)

	var back := UiKit.ghost_button("< BACK", 17, Vector2(150, 50))
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 28
	back.offset_top = -78
	back.offset_right = 178
	back.offset_bottom = -28
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home.tscn"))
	_ui_root.add_child(back)

	var prev := UiKit.ghost_button("<", 36, Vector2(72, 110))
	prev.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	prev.offset_left = 24
	prev.offset_top = -55
	prev.offset_right = 96
	prev.offset_bottom = 55
	prev.pressed.connect(func() -> void: _show_car(_idx - 1))
	_ui_root.add_child(prev)

	var next := UiKit.ghost_button(">", 36, Vector2(72, 110))
	next.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	next.offset_left = -96
	next.offset_top = -55
	next.offset_right = -24
	next.offset_bottom = 55
	next.pressed.connect(func() -> void: _show_car(_idx + 1))
	_ui_root.add_child(next)

	# Info panel (bottom center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.style(UiKit.COL_PANEL, 14, Color(UiKit.COL_CYAN, 0.5), 1))
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -342
	panel.offset_bottom = -24
	_ui_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_name_l = UiKit.label("-", 29, Color.WHITE, "black")
	head.add_child(_name_l)
	_class_l = UiKit.label("-", 17, UiKit.COL_GOLD, "black")
	head.add_child(_class_l)
	v.add_child(head)

	_desc_l = UiKit.label("-", 14, UiKit.COL_DIM, "medium")
	_desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_desc_l)

	_rows["speed"] = UiKit.stat_row("TOP SPEED", 0, UiKit.COL_CYAN)
	_rows["accel"] = UiKit.stat_row("ACCELERATION", 0, UiKit.COL_GREEN)
	_rows["handling"] = UiKit.stat_row("HANDLING", 0, UiKit.COL_ORANGE_L)
	_rows["nitro"] = UiKit.stat_row("NITRO", 0, Color(0.65, 0.5, 1.0))
	for k in _rows.keys():
		v.add_child(_rows[k])

	_price_l = UiKit.label("-", 17, UiKit.COL_GOLD, "black", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_price_l)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	_action_btn = UiKit.button("SELECT", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 20, Vector2(0, 56))
	_action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_btn.pressed.connect(_on_action)
	btns.add_child(_action_btn)
	_race_btn = UiKit.ghost_button("RACE NOW", 19, Vector2(190, 56))
	_race_btn.pressed.connect(_on_race)
	btns.add_child(_race_btn)
	v.add_child(btns)


func _show_car(i: int) -> void:
	_idx = wrapi(i, 0, GameState.CARS.size())
	if _rig_root != null:
		_rig_root.queue_free()
		_rig_root = null
	var cfg := GameState.car_cfg(_idx)
	var rig := CarRig.build(cfg, _show["car_root"])
	_rig_root = rig["root"]

	_name_l.text = String(cfg["name"])
	_class_l.text = "CLASS " + String(cfg["class"])
	_desc_l.text = String(cfg["desc"])
	var stats: Dictionary = cfg["stats"]
	for k in _rows.keys():
		var val := int(stats[k])
		(_rows[k].get_node("Bar") as ProgressBar).value = val
		(_rows[k].get_node("Val") as Label).text = str(val)

	if GameState.owned[_idx]:
		_price_l.text = "OWNED"
		_price_l.add_theme_color_override("font_color", UiKit.COL_GREEN)
		if GameState.selected_car == _idx:
			_action_btn.text = "SELECTED"
			_action_btn.disabled = true
		else:
			_action_btn.text = "SELECT"
			_action_btn.disabled = false
		_race_btn.disabled = false
	else:
		_price_l.text = "PRICE  " + GameState.fmt_money(int(cfg["price"])) + " CR"
		_price_l.remove_theme_color_override("font_color")
		_action_btn.text = "BUY CAR"
		_action_btn.disabled = false
		_race_btn.disabled = true


func _on_action() -> void:
	if GameState.owned[_idx]:
		GameState.selected_car = _idx
		GameState.save()
		_show_car(_idx)
		return
	var cfg := GameState.car_cfg(_idx)
	if GameState.try_buy_car(_idx):
		GameState.selected_car = _idx
		GameState.save()
		UiKit.refresh_top_bar(_top)
		_show_car(_idx)
		UiKit.popup(_ui_root, "NEW CAR UNLOCKED!", String(cfg["name"]) + " is now in your garage.\nTime to burn some nitro, Legend!")
	else:
		UiKit.popup(_ui_root, "NOT ENOUGH CR", "You need " + GameState.fmt_money(int(cfg["price"])) + " CR for this car.\nWin sprints and career events to earn more.")


func _on_race() -> void:
	if not GameState.owned[_idx]:
		return
	GameState.selected_car = _idx
	GameState.save()
	GameState.next_race = {
		"mode": "sprint", "title": "QUICK SPRINT",
		"reward": 6000, "ai_count": 5, "ai_speed": 0.97, "career_idx": -1,
	}
	get_tree().change_scene_to_file("res://scenes/race.tscn")
