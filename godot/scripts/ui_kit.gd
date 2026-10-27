class_name UiKit
## Premium Asphalt-style UI helpers: labels, buttons, panels, chips, popups.
## (ASCII-only texts: Orbitron has a basic Latin glyph set.)

const FONT_BLACK: Font = preload("res://assets/fonts/Orbitron-Black.ttf")
const FONT_BOLD: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const FONT_MED: Font = preload("res://assets/fonts/Orbitron-Medium.ttf")

const COL_ORANGE := Color(1.0, 0.54, 0.12)
const COL_ORANGE_L := Color(1.0, 0.83, 0.30)
const COL_CYAN := Color(0.26, 0.85, 1.0)
const COL_PANEL := Color(0.035, 0.06, 0.14, 0.92)
const COL_PANEL_SOFT := Color(0.05, 0.09, 0.20, 0.78)
const COL_TEXT := Color(0.92, 0.96, 1.0)
const COL_DIM := Color(0.62, 0.72, 0.86)
const COL_GOLD := Color(1.0, 0.80, 0.25)
const COL_GREEN := Color(0.35, 0.95, 0.55)
const COL_RED := Color(1.0, 0.32, 0.28)


static func font_of(weight: String) -> Font:
	match weight:
		"black":
			return FONT_BLACK
		"medium":
			return FONT_MED
		_:
			return FONT_BOLD


static func full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


static func label(text: String, size: int = 20, color: Color = COL_TEXT, weight: String = "bold", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = font_of(weight)
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(2, size / 9)
	ls.outline_color = Color(0, 0, 0, 0.55)
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func style(bg: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.set_content_margin_all(14)
	return s


static func button(text: String, bg: Color, fg: Color = Color(0.05, 0.03, 0.01), font_size: int = 20, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if min_size != Vector2.ZERO:
		b.custom_minimum_size = min_size
	var normal := style(bg, 8, bg.lightened(0.35), 1)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", style(bg.lightened(0.15), 8, bg.lightened(0.5), 1))
	b.add_theme_stylebox_override("pressed", style(bg.darkened(0.15), 8, bg.lightened(0.2), 1))
	b.add_theme_stylebox_override("disabled", style(Color(bg, 0.35), 8))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), 8))
	b.add_theme_font_override("font", FONT_BOLD)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	return b


static func ghost_button(text: String, font_size: int = 18, min_size: Vector2 = Vector2.ZERO) -> Button:
	return button(text, COL_PANEL_SOFT, COL_TEXT, font_size, min_size)


static func chip(title: String, value: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(COL_PANEL, 8, accent, 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var t := label(title, 14, accent, "bold")
	var v := label(value, 18, COL_TEXT, "black")
	v.name = "Value"
	h.add_child(t)
	h.add_child(v)
	p.add_child(h)
	return p


static func top_bar() -> Dictionary:
	var bar := PanelContainer.new()
	var sb := style(Color(0.02, 0.03, 0.09, 0.88), 0)
	sb.border_width_bottom = 2
	sb.border_color = Color(COL_CYAN, 0.55)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)

	# profile
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(52, 52)
	avatar.add_theme_stylebox_override("panel", style(COL_ORANGE, 10, COL_ORANGE_L, 2))
	var av_l := label("SASAN", 17, Color(0.08, 0.03, 0.0), "black", HORIZONTAL_ALIGNMENT_CENTER)
	av_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(av_l)
	h.add_child(avatar)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.add_child(label("Baap_", 19, COL_TEXT, "bold"))
	pv.add_child(label("LEGEND  LV.50", 12, COL_GOLD, "bold"))
	h.add_child(pv)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)

	var cr := chip("CR", GameState.fmt_money(GameState.credits), COL_GOLD)
	var tk := chip("TOKENS", GameState.fmt_money(GameState.tokens), COL_CYAN)
	h.add_child(cr)
	h.add_child(tk)

	var mail := ghost_button("MAIL", 15, Vector2(84, 44))
	var gear := ghost_button("MENU", 15, Vector2(84, 44))
	h.add_child(mail)
	h.add_child(gear)

	return {"root": bar, "cr": cr, "tk": tk, "mail": mail, "menu": gear}


static func refresh_top_bar(parts: Dictionary) -> void:
	(parts["cr"] as PanelContainer).get_node("HBoxContainer/Value").text = GameState.fmt_money(GameState.credits)
	(parts["tk"] as PanelContainer).get_node("HBoxContainer/Value").text = GameState.fmt_money(GameState.tokens)


static func stat_row(stat_name: String, value: int, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var n := label(stat_name, 15, COL_DIM, "bold")
	n.custom_minimum_size = Vector2(150, 0)
	h.add_child(n)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = 0
	bar.max_value = 100
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", style(Color(0.10, 0.13, 0.24, 0.95), 4))
	bar.add_theme_stylebox_override("fill", style(color, 4))
	h.add_child(bar)
	var v := label(str(value), 16, COL_TEXT, "black")
	v.name = "Val"
	v.custom_minimum_size = Vector2(42, 0)
	h.add_child(v)
	return h


static func gradient_tex(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 4
	t.height = 256
	return t


static func radial_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


static func std_mat(color: Color, roughness: float = 0.6, metallic: float = 0.0, emission: Color = Color(0, 0, 0, 1), emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


static func popup(parent: Control, title: String, body: String, btn_text: String = "OK") -> ColorRect:
	var parts := popup_shell(parent, title)
	var dim: ColorRect = parts["dim"]
	var vbox: VBoxContainer = parts["vbox"]
	var bl := label(body, 18, COL_TEXT, "medium", HORIZONTAL_ALIGNMENT_CENTER)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(bl)
	var center := CenterContainer.new()
	var b := button(btn_text, COL_ORANGE, Color(0.08, 0.03, 0.0), 20, Vector2(220, 54))
	center.add_child(b)
	vbox.add_child(center)
	b.pressed.connect(func() -> void:
		GameState.play_click()
		dim.queue_free()
	)
	return dim


static func popup_shell(parent: Control, title: String) -> Dictionary:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	full(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)

	var center := CenterContainer.new()
	full(center)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", style(COL_PANEL, 14, COL_CYAN, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var t := label(title, 30, COL_ORANGE_L, "black", HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(t)

	dim.modulate.a = 0.0
	var tw := dim.create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.18)
	return {"dim": dim, "panel": panel, "vbox": vbox}


static func settings_popup(parent: Control) -> ColorRect:
	var parts := popup_shell(parent, "SETTINGS")
	var dim: ColorRect = parts["dim"]
	var vbox: VBoxContainer = parts["vbox"]

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 14)
	var sl := label("SOUND", 16, COL_DIM, "bold")
	sl.custom_minimum_size = Vector2(130, 0)
	row1.add_child(sl)
	var sfx := HSlider.new()
	sfx.min_value = 0.0
	sfx.max_value = 1.0
	sfx.step = 0.05
	sfx.value = float(GameState.settings["sfx"])
	sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx.value_changed.connect(func(v: float) -> void:
		GameState.settings["sfx"] = v
		GameState.apply_audio_settings()
	)
	row1.add_child(sfx)
	vbox.add_child(row1)

	vbox.add_child(_check_row("TOUCHDRIVE (AUTO-ACCELERATE)", "touchdrive"))
	vbox.add_child(_check_row("TILT STEERING (MOBILE)", "tilt"))
	vbox.add_child(_check_row("ON-SCREEN CONTROLS", "touch_ui"))

	var center := CenterContainer.new()
	var b := button("CLOSE", COL_ORANGE, Color(0.08, 0.03, 0.0), 19, Vector2(210, 52))
	center.add_child(b)
	vbox.add_child(center)
	b.pressed.connect(func() -> void:
		GameState.save()
		dim.queue_free()
	)
	return dim


static func _check_row(text: String, key: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(GameState.settings[key])
	c.add_theme_font_override("font", FONT_BOLD)
	c.add_theme_font_size_override("font_size", 16)
	c.add_theme_color_override("font_color", COL_TEXT)
	c.add_theme_color_override("font_hover_color", COL_TEXT)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool) -> void:
		GameState.settings[key] = on
		GameState.save()
	)
	return c
