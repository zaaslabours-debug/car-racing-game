extends Node3D
## HOME — premium Asphalt Legends Unite style:
## rotating hero car, top bar, side menu, car card, giant PLAY, bottom nav.
## Shows the owner popup once per app launch.

var _show: Dictionary
var _rig_root: Node3D
var _disp: int = 0
var _ui_root: Control
var _top: Dictionary
var _card_name: Label
var _card_class: Label
var _card_status: Label
var _t: float = 0.0


func _ready() -> void:
	_show = Showroom.create(self)
	_disp = GameState.selected_car
	_build_ui()
	_show_car(_disp)
	get_tree().create_timer(0.55).timeout.connect(_show_owner_popup)


func _process(delta: float) -> void:
	_t += delta
	(_show["car_root"] as Node3D).rotation.y += delta * 0.38
	var halo := _show["halo"] as MeshInstance3D
	(halo.mesh.material as StandardMaterial3D).emission_energy_multiplier = 2.3 + sin(_t * 2.0) * 0.5
	var cam := _show["camera"] as Camera3D
	cam.position.y = 2.25 + sin(_t * 0.6) * 0.12


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_show_mode_popup()


# ------------------------------------------------------------------- UI
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
		UiKit.popup(_ui_root, "MAIL", "Welcome to Silver Lake GP, Legend!\n\nYour Saba V12 is polished and ready.\nWin sprints to earn CR and unlock the FORMULA LP-830 SDC and the P72 GRAN TURISMO.\n\n- Team SASAN"))

	# logo top-center
	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", 10)
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.offset_left = -200
	logo.offset_right = 200
	logo.offset_top = 76
	logo.offset_bottom = 108
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(UiKit.label("SILVER LAKE", 26, Color.WHITE, "black"))
	logo.add_child(UiKit.label("GP", 26, UiKit.COL_ORANGE_L, "black"))
	_ui_root.add_child(logo)

	# left menu
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	menu.offset_left = 28
	menu.offset_right = 308
	menu.offset_top = -168
	menu.offset_bottom = 168
	_ui_root.add_child(menu)

	var b_career := UiKit.button("CAREER", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 20, Vector2(280, 56))
	b_career.pressed.connect(_show_career)
	menu.add_child(b_career)
	var b_garage := UiKit.ghost_button("GARAGE", 20, Vector2(280, 56))
	b_garage.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/garage.tscn"))
	menu.add_child(b_garage)
	var b_events := UiKit.ghost_button("EVENTS", 20, Vector2(280, 56))
	b_events.pressed.connect(func() -> void: _soon("EVENTS"))
	menu.add_child(b_events)
	var b_shop := UiKit.ghost_button("SHOP", 20, Vector2(280, 56))
	b_shop.pressed.connect(func() -> void: _soon("SHOP"))
	menu.add_child(b_shop)
	var b_mp := UiKit.ghost_button("MULTIPLAYER", 20, Vector2(280, 56))
	b_mp.pressed.connect(func() -> void: _soon("MULTIPLAYER"))
	menu.add_child(b_mp)

	# car card bottom-left
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.style(UiKit.COL_PANEL, 12, Color(UiKit.COL_CYAN, 0.45), 1))
	card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card.offset_left = 28
	card.offset_right = 440
	card.offset_top = -212
	card.offset_bottom = -84
	_ui_root.add_child(card)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 18)
	cm.add_theme_constant_override("margin_right", 18)
	cm.add_theme_constant_override("margin_top", 12)
	cm.add_theme_constant_override("margin_bottom", 12)
	card.add_child(cm)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cm.add_child(cv)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 12)
	var prev := UiKit.ghost_button("<", 24, Vector2(52, 52))
	prev.pressed.connect(func() -> void: _show_car(_disp - 1))
	crow.add_child(prev)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	_card_name = UiKit.label("-", 23, Color.WHITE, "black", HORIZONTAL_ALIGNMENT_CENTER)
	mid.add_child(_card_name)
	_card_class = UiKit.label("-", 13, UiKit.COL_GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	mid.add_child(_card_class)
	crow.add_child(mid)
	var next := UiKit.ghost_button(">", 24, Vector2(52, 52))
	next.pressed.connect(func() -> void: _show_car(_disp + 1))
	crow.add_child(next)
	cv.add_child(crow)
	_card_status = UiKit.label("-", 14, UiKit.COL_GREEN, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(_card_status)

	# PLAY block bottom-right
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pv.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pv.offset_left = -428
	pv.offset_right = -28
	pv.offset_top = -216
	pv.offset_bottom = -84
	_ui_root.add_child(pv)
	pv.add_child(UiKit.label("QUICK SPRINT | SILVER LAKE", 15, UiKit.COL_CYAN, "bold", HORIZONTAL_ALIGNMENT_RIGHT))
	var play := UiKit.button("PLAY", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 38, Vector2(0, 88))
	play.add_theme_font_override("font", UiKit.FONT_BLACK)
	play.pressed.connect(_show_mode_popup)
	pv.add_child(play)
	pv.add_child(UiKit.label("VS 5 RIVALS | NITRO + DRIFT", 13, UiKit.COL_DIM, "bold", HORIZONTAL_ALIGNMENT_RIGHT))

	# bottom nav
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 8)
	nav.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	nav.offset_left = -340
	nav.offset_right = 340
	nav.offset_top = -62
	nav.offset_bottom = -12
	_ui_root.add_child(nav)
	var n_home := UiKit.button("HOME", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 15, Vector2(122, 46))
	nav.add_child(n_home)
	var n_garage := UiKit.ghost_button("GARAGE", 15, Vector2(122, 46))
	n_garage.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/garage.tscn"))
	nav.add_child(n_garage)
	var n_career := UiKit.ghost_button("CAREER", 15, Vector2(122, 46))
	n_career.pressed.connect(_show_career)
	nav.add_child(n_career)
	var n_events := UiKit.ghost_button("EVENTS", 15, Vector2(122, 46))
	n_events.pressed.connect(func() -> void: _soon("EVENTS"))
	nav.add_child(n_events)
	var n_shop := UiKit.ghost_button("SHOP", 15, Vector2(122, 46))
	n_shop.pressed.connect(func() -> void: _soon("SHOP"))
	nav.add_child(n_shop)


func _show_car(i: int) -> void:
	_disp = wrapi(i, 0, GameState.CARS.size())
	if _rig_root != null:
		_rig_root.queue_free()
		_rig_root = null
	var cfg := GameState.car_cfg(_disp)
	var rig := CarRig.build(cfg, _show["car_root"])
	_rig_root = rig["root"]
	_card_name.text = String(cfg["name"])
	_card_class.text = "CLASS " + String(cfg["class"])
	if GameState.owned[_disp]:
		GameState.selected_car = _disp
		GameState.save()
		_card_status.text = "SELECTED - READY TO RACE"
		_card_status.add_theme_color_override("font_color", UiKit.COL_GREEN)
	else:
		_card_status.text = "BUY IN GARAGE - " + GameState.fmt_money(int(cfg["price"])) + " CR"
		_card_status.add_theme_color_override("font_color", UiKit.COL_GOLD)


# ------------------------------------------------------------------- popups
func _show_owner_popup() -> void:
	if not is_inside_tree() or GameState.popup_shown_this_launch:
		return
	GameState.popup_shown_this_launch = true
	var parts := UiKit.popup_shell(_ui_root, "WELCOME, LEGEND")
	var dim: ColorRect = parts["dim"]
	var vbox: VBoxContainer = parts["vbox"]
	var body := UiKit.label("This game is made by sab ka baap Ahad Shaikh.\nThe owner of this game is Ahad Shaikh.", 19, UiKit.COL_TEXT, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)
	vbox.add_child(UiKit.label("SILVER LAKE GP - burn nitro, chase legends.", 14, UiKit.COL_DIM, "medium", HORIZONTAL_ALIGNMENT_CENTER))
	var center := CenterContainer.new()
	var b := UiKit.button("LET'S RACE", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 21, Vector2(240, 56))
	center.add_child(b)
	vbox.add_child(center)
	b.pressed.connect(func() -> void: dim.queue_free())


func _show_mode_popup() -> void:
	var parts := UiKit.popup_shell(_ui_root, "RACE MODE")
	var dim: ColorRect = parts["dim"]
	var vbox: VBoxContainer = parts["vbox"]
	var sprint := UiKit.button("QUICK SPRINT - VS 5 RIVALS", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 19, Vector2(0, 58))
	sprint.pressed.connect(func() -> void:
		GameState.next_race = {
			"mode": "sprint", "title": "QUICK SPRINT",
			"reward": 6000, "ai_count": 5, "ai_speed": 0.97, "career_idx": -1,
		}
		get_tree().change_scene_to_file("res://scenes/race.tscn")
	)
	vbox.add_child(sprint)
	var roam := UiKit.ghost_button("FREE ROAM - JUST DRIVE", 19, Vector2(0, 58))
	roam.pressed.connect(func() -> void:
		GameState.next_race = {
			"mode": "roam", "title": "FREE ROAM",
			"reward": 0, "ai_count": 0, "ai_speed": 1.0, "career_idx": -1,
		}
		get_tree().change_scene_to_file("res://scenes/race.tscn")
	)
	vbox.add_child(roam)
	var center := CenterContainer.new()
	var cancel := UiKit.ghost_button("CANCEL", 16, Vector2(170, 46))
	cancel.pressed.connect(func() -> void: dim.queue_free())
	center.add_child(cancel)
	vbox.add_child(center)


func _show_career() -> void:
	var parts := UiKit.popup_shell(_ui_root, "CAREER - SILVER LAKE CUP")
	(parts["panel"] as PanelContainer).custom_minimum_size = Vector2(840, 0)
	var vbox: VBoxContainer = parts["vbox"]
	for idx in GameState.CAREER_EVENTS.size():
		var ev: Dictionary = GameState.CAREER_EVENTS[idx]
		var locked: bool = idx > 0 and not bool(GameState.career_done[idx - 1])
		var done: bool = bool(GameState.career_done[idx])

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.style(UiKit.COL_PANEL_SOFT, 10, Color(UiKit.COL_CYAN, 0.35), 1))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)

		var banner := TextureRect.new()
		banner.texture = load(String(ev["banner"]))
		banner.custom_minimum_size = Vector2(210, 104)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(banner)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		info.add_child(UiKit.label(String(ev["title"]), 20, Color.WHITE, "bold"))
		info.add_child(UiKit.label(String(ev["subtitle"]), 14, UiKit.COL_DIM, "medium"))
		var status := ""
		if done:
			status = "CLEARED | BEST " + GameState.fmt_time(float(GameState.best_times[idx]))
		elif locked:
			status = "LOCKED - CLEAR THE PREVIOUS EVENT"
		else:
			status = "REWARD " + GameState.fmt_money(int(ev["reward"])) + " CR | FINISH ON THE PODIUM"
		info.add_child(UiKit.label(status, 13, UiKit.COL_GREEN if done else (UiKit.COL_RED if locked else UiKit.COL_GOLD), "bold"))
		h.add_child(info)

		var race_b := UiKit.button("RACE", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 18, Vector2(140, 54))
		race_b.disabled = locked
		race_b.pressed.connect(_on_career_race.bind(idx))
		h.add_child(race_b)
		vbox.add_child(card)

	var center := CenterContainer.new()
	var close_b := UiKit.ghost_button("CLOSE", 16, Vector2(170, 46))
	var dim: ColorRect = parts["dim"]
	close_b.pressed.connect(func() -> void: dim.queue_free())
	center.add_child(close_b)
	vbox.add_child(center)


func _on_career_race(idx: int) -> void:
	var ev: Dictionary = GameState.CAREER_EVENTS[idx]
	GameState.next_race = {
		"mode": "sprint", "title": String(ev["title"]),
		"reward": int(ev["reward"]), "ai_count": int(ev["ai_count"]),
		"ai_speed": float(ev["ai_speed"]), "career_idx": idx,
	}
	get_tree().change_scene_to_file("res://scenes/race.tscn")


func _soon(feature: String) -> void:
	UiKit.popup(_ui_root, feature, "This feature is coming in the next update.\nStay tuned, Legend!")
