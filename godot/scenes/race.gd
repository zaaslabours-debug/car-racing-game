extends Node3D
## RACE — builds the world at runtime:
##   1. trimesh collisions for the track (Road layer from material names)
##   2. auto-scales the track so the road is ~13 m wide (measured by raycasts)
##   3. scouts the asphalt on a grid, BFS-plots a sprint route, resamples it
##   4. grid start (player last, Asphalt-style), countdown, AI race, results
## Modes: "sprint" (vs AI, positions, rewards) and "roam" (free drive).

const TRACK_PATH := "res://assets/track/silver-lake.glb"
const GRID_N := 64
const AI_NAMES := ["VEX-9", "NOVA", "RYUZO", "MIKA", "KANE"]
const AI_CAR_ORDER := [1, 2, 0, 2, 1]

var _phase := "loading" # loading | countdown | race | finished
var _mode := "sprint"
var _race_time := 0.0
var _cd_t := 0.0
var _cd_stage := -1
var _finish_delay := -1.0
var _results_shown := false
var _paused := false
var _msg_t := 0.0

var _env: Environment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _track_root: Node3D
var _track_box: AABB
var _space: PhysicsDirectSpaceState3D
var _ray_params: PhysicsRayQueryParameters3D

var _route: Array = []
var _route_cum: Array = []
var _route_curve: Array = []
var _route_total := 1.0

var _player: CarController
var _entries: Array = []
var _cam_mode := 0
var _cam_pos := Vector3.ZERO
var _shake := 0.0
var _fov := 62.0
var _pillar: MeshInstance3D
var _finish_pillar: MeshInstance3D

var _engine_p: AudioStreamPlayer
var _skid_p: AudioStreamPlayer
var _impact_p: AudioStreamPlayer
var _beep_p: AudioStreamPlayer

var _hud_root: Control
var _speed_box: VBoxContainer
var _speed_l: Label
var _nitro_bar: ProgressBar
var _nitro_fill: StyleBoxFlat
var _pos_l: Label
var _time_l: Label
var _msg_l: Label
var _drift_l: Label
var _off_l: Label
var _prog_bar: ProgressBar

var _load_layer: CanvasLayer
var _load_label: Label
var _load_bar: ProgressBar

var _show_touch := false
var _touch_zones := {}
var _touch_visuals := {}
var _active_touches := {}
var _touch := {"left": false, "right": false, "drift": false, "nitro": false, "brake": false, "gas": false}
var _pause_dim: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mode = String(GameState.next_race.get("mode", "sprint"))
	_show_touch = (DisplayServer.is_touchscreen_available() or OS.get_name() in ["Android", "iOS"]) and bool(GameState.settings["touch_ui"])
	_build_environment()
	_build_audio()
	_build_hud()
	_build_loading()
	if _show_touch:
		_build_touch()
		_layout_touch()
	get_tree().root.size_changed.connect(_layout_touch)
	call_deferred("_build_world")


# ================================================================= world build
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.34, 0.62)
	sky_mat.sky_horizon_color = Color(0.99, 0.64, 0.34)
	sky_mat.ground_bottom_color = Color(0.05, 0.04, 0.03)
	sky_mat.ground_horizon_color = Color(0.42, 0.27, 0.16)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.glow_enabled = true
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.94, 0.62, 0.36)
	_env.fog_density = 0.0006
	_env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-30, -58, 0)
	_sun.light_energy = 1.35
	_sun.light_color = Color(1.0, 0.72, 0.45)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 300.0
	_sun.shadow_bias = 0.06
	_sun.shadow_normal_bias = 0.9
	add_child(_sun)

	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 9000.0
	add_child(_camera)
	_camera.current = true
	_camera.global_position = Vector3(0, 40, 80)


func _build_audio() -> void:
	_engine_p = _make_player("res://assets/audio/engine.ogg", true)
	_skid_p = _make_player("res://assets/audio/skid.ogg", true)
	_impact_p = _make_player("res://assets/audio/impact.ogg", false)
	_beep_p = AudioStreamPlayer.new()
	add_child(_beep_p)
	_engine_p.volume_db = -12.0
	_skid_p.volume_db = -80.0


func _make_player(path: String, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := load(path) as AudioStreamOggVorbis
	if s != null and loop:
		s.loop_mode = AudioStreamOggVorbis.LOOP_FORWARD
	p.stream = s
	add_child(p)
	return p


func _build_world() -> void:
	_set_loading("LOADING SILVER LAKE...", 0.02)
	await get_tree().process_frame
	await get_tree().process_frame
	var packed := load(TRACK_PATH) as PackedScene
	_track_root = packed.instantiate() as Node3D
	add_child(_track_root)
	await get_tree().physics_frame

	var meshes: Array = []
	_collect_meshes(_track_root, meshes)
	var total := maxi(meshes.size(), 1)
	var i := 0
	for mi in meshes:
		i += 1
		if i % 12 == 0:
			_set_loading("BUILDING TRACK COLLISIONS " + str(i) + "/" + str(total), 0.05 + 0.35 * float(i) / float(total))
			await get_tree().process_frame
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var names := ""
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m := (mi as MeshInstance3D).get_active_material(s)
				if m != null:
					names += String(m.resource_name).to_lower() + " "
		if names.contains("backdrop"):
			continue
		(mi as MeshInstance3D).create_trimesh_collision()
		for child in (mi as Node).get_children():
			if child is StaticBody3D:
				var body := child as StaticBody3D
				body.collision_mask = 0
				if names.contains("water"):
					body.collision_layer = 1
					body.set_meta("surface", "water")
				elif names.contains("asphalt") or names.contains("concrete") or names.contains("road") or names.contains("tarmac") or names.contains("paint"):
					body.collision_layer = 2
				else:
					body.collision_layer = 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = get_world_3d().direct_space_state
	_ray_params = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 3)

	# auto-scale: provisional fit -> measure road -> final scale
	_track_box = _merged_aabb_world(_track_root)
	var fit := 2000.0 / maxf(maxf(_track_box.size.x, _track_box.size.z), 1.0)
	_track_root.scale = Vector3.ONE * fit
	_recenter_track()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_set_loading("MEASURING ROAD WIDTH...", 0.46)
	await get_tree().process_frame
	var w := _measure_road_width()
	print("[race] road width at provisional scale: ", snappedf(w, 0.1))
	if w > 0.8:
		_track_root.scale = _track_root.scale * clampf(13.0 / w, 0.12, 6.0)
		_recenter_track()
		await get_tree().physics_frame
		await get_tree().physics_frame
	_track_box = _merged_aabb_world(_track_root)
	var tsize := maxf(_track_box.size.x, _track_box.size.z)
	_env.fog_density = clampf(3.2 / (tsize * 1.15), 0.00012, 0.002)
	_camera.far = clampf(tsize * 2.0, 2500.0, 16000.0)
	print("[race] track size (m): ", int(tsize))

	_set_loading("SCOUTING THE ROAD...", 0.55)
	var scout := await _scout_grid()
	_set_loading("PLOTTING RACE ROUTE...", 0.78)
	await get_tree().process_frame
	_build_route(scout)

	_set_loading("PLACING CARS...", 0.88)
	await get_tree().process_frame
	_spawn_cars()
	_build_pillars()

	_set_loading("READY!", 1.0)
	await get_tree().create_timer(0.35).timeout
	_load_layer.visible = false
	_engine_p.play()
	_skid_p.play()
	_phase = "countdown"
	_cd_t = 0.0
	_cd_stage = -1


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)


func _merged_aabb_world(node: Node) -> AABB:
	var meshes: Array = []
	_collect_meshes(node, meshes)
	var result := AABB()
	var first := true
	for mi in meshes:
		var w: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		if first:
			result = w
			first = false
		else:
			result = result.merge(w)
	return result


func _recenter_track() -> void:
	_track_root.force_update_transform()
	var b := _merged_aabb_world(_track_root)
	var c := b.get_center()
	_track_root.position -= Vector3(c.x, b.position.y, c.z)
	_track_root.force_update_transform()
	_track_box = _merged_aabb_world(_track_root)


func _cast_down(x: float, z: float, from_y: float, length: float, mask: int) -> Dictionary:
	_ray_params.from = Vector3(x, from_y, z)
	_ray_params.to = Vector3(x, from_y - length, z)
	_ray_params.collision_mask = mask
	return _space.intersect_ray(_ray_params)


func _measure_road_width() -> float:
	var top := _track_box.position.y + _track_box.size.y + 40.0
	var len_down := _track_box.size.y + 220.0
	var p := Vector3.ZERO
	var found := false
	for i in 22:
		if found:
			break
		for j in 22:
			var x := _track_box.position.x + _track_box.size.x * (float(i) + 0.5) / 22.0
			var z := _track_box.position.z + _track_box.size.z * (float(j) + 0.5) / 22.0
			var h := _cast_down(x, z, top, len_down, 2)
			if not h.is_empty():
				p = h["position"]
				found = true
				break
	if not found:
		return 0.0
	var step := maxf(_track_box.size.x, _track_box.size.z) * 0.0016
	var wx := _march(p, Vector2(1, 0), step, top, len_down) + _march(p, Vector2(-1, 0), step, top, len_down)
	var wz := _march(p, Vector2(0, 1), step, top, len_down) + _march(p, Vector2(0, -1), step, top, len_down)
	return minf(wx, wz)


func _march(p: Vector3, dir: Vector2, step: float, top: float, len_down: float) -> float:
	var d := 0.0
	var gaps := 0
	for k in range(1, 420):
		var h := _cast_down(p.x + dir.x * step * float(k), p.z + dir.y * step * float(k), top, len_down, 2)
		if not h.is_empty():
			d = step * float(k)
			gaps = 0
		else:
			gaps += 1
			if gaps > 2:
				break
	return d


func _scout_grid() -> Dictionary:
	var n := GRID_N
	var cells: Array = []
	var top := _track_box.position.y + _track_box.size.y + 40.0
	var len_down := _track_box.size.y + 220.0
	for i in n:
		var row: Array = []
		for j in n:
			var x := _track_box.position.x + _track_box.size.x * (float(i) + 0.5) / float(n)
			var z := _track_box.position.z + _track_box.size.z * (float(j) + 0.5) / float(n)
			var h := _cast_down(x, z, top, len_down, 3)
			var cell := {"road": false, "pos": Vector3(x, 0, z), "flat": 0.0}
			if not h.is_empty():
				var col: Object = h["collider"]
				var is_water := col.has_meta("surface") and String(col.get_meta("surface")) == "water"
				var nrm: Vector3 = h["normal"]
				if nrm.y > 0.7 and not is_water:
					cell["pos"] = h["position"]
					cell["flat"] = nrm.y
					if col is CollisionObject3D and (col as CollisionObject3D).collision_layer == 2:
						cell["road"] = true
			row.append(cell)
		cells.append(row)
		if i % 8 == 0:
			_set_loading("SCOUTING THE ROAD...", 0.55 + 0.2 * float(i) / float(n))
			await get_tree().process_frame

	var best := Vector2i(n / 2, n / 2)
	var best_score := -1.0e9
	for i in range(1, n - 1):
		for j in range(1, n - 1):
			if not bool(cells[i][j]["road"]):
				continue
			var sc := float(cells[i][j]["flat"]) * 10.0
			for a in range(-1, 2):
				for b in range(-1, 2):
					if bool(cells[i + a][j + b]["road"]):
						sc += 4.0
			if sc > best_score:
				best_score = sc
				best = Vector2i(i, j)
	return {"cells": cells, "spawn": best, "n": n}


func _build_route(scout: Dictionary) -> void:
	var cells: Array = scout["cells"]
	var n: int = int(scout["n"])
	var spawn: Vector2i = scout["spawn"]

	var dist := {}
	var parent := {}
	var queue: Array = [spawn]
	dist[spawn] = 0
	var far := spawn
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if int(dist[cur]) > int(dist[far]):
			far = cur
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.y < 0 or nb.x >= n or nb.y >= n:
				continue
			if dist.has(nb):
				continue
			if not bool(cells[nb.x][nb.y]["road"]):
				continue
			dist[nb] = int(dist[cur]) + 1
			parent[nb] = cur
			queue.append(nb)

	var path: Array = []
	var c := far
	while true:
		path.append(cells[c.x][c.y]["pos"])
		if c == spawn:
			break
		c = parent[c]
	path.reverse()
	print("[race] BFS route cells: ", path.size())
	if path.size() < 6:
		var sp: Vector3 = cells[spawn.x][spawn.y]["pos"]
		path = [sp, sp + Vector3(0, 0, -60)]

	for pass_i in 2:
		var sm: Array = []
		for k in path.size():
			if k == 0 or k == path.size() - 1:
				sm.append(path[k])
			else:
				sm.append(((path[k - 1] as Vector3) + (path[k] as Vector3) * 2.0 + (path[k + 1] as Vector3)) * 0.25)
		path = sm

	# resample every ~8 m
	var lens: Array = [0.0]
	var total_len := 0.0
	for k in range(1, path.size()):
		total_len += (path[k - 1] as Vector3).distance_to(path[k] as Vector3)
		lens.append(total_len)
	var resampled: Array = []
	var target := 0.0
	var seg_i := 1
	while target <= total_len and seg_i < lens.size():
		while seg_i < lens.size() - 1 and float(lens[seg_i]) < target:
			seg_i += 1
		var seg_start := float(lens[seg_i - 1])
		var seg_end := float(lens[seg_i])
		var fr := 0.0
		if seg_end > seg_start:
			fr = (target - seg_start) / (seg_end - seg_start)
		resampled.append((path[seg_i - 1] as Vector3).lerp(path[seg_i] as Vector3, fr))
		target += 8.0
	if resampled.size() < 2:
		resampled = path.duplicate()
	elif (resampled[resampled.size() - 1] as Vector3).distance_to(path[path.size() - 1] as Vector3) > 4.0:
		resampled.append(path[path.size() - 1])

	_route.clear()
	for p in resampled:
		_route.append(_snap(p as Vector3))
	_route_cum = [0.0]
	for k in range(1, _route.size()):
		_route_cum.append(float(_route_cum[k - 1]) + (_route[k - 1] as Vector3).distance_to(_route[k] as Vector3))
	_route_total = maxf(float(_route_cum[_route_cum.size() - 1]), 1.0)
	_route_curve.clear()
	for k in _route.size():
		var i0 := clampi(k - 3, 0, _route.size() - 1)
		var i1 := clampi(k + 3, 0, _route.size() - 1)
		var i2 := clampi(k + 9, 0, _route.size() - 1)
		var v1: Vector3 = (_route[i1] as Vector3) - (_route[i0] as Vector3)
		var v2: Vector3 = (_route[i2] as Vector3) - (_route[i1] as Vector3)
		var ang := 0.0
		if v1.length() > 0.5 and v2.length() > 0.5:
			ang = v1.normalized().angle_to(v2.normalized())
		_route_curve.append(ang)
	print("[race] route points: ", _route.size(), " length (m): ", int(_route_total))


func _snap(p: Vector3) -> Vector3:
	var h := _cast_down(p.x, p.z, p.y + 30.0, 120.0, 3)
	return h["position"] if not h.is_empty() else p


func _ground_at(p: Vector3) -> Vector3:
	var h := _cast_down(p.x, p.z, p.y + 4.0, 90.0, 3)
	return (h["position"] as Vector3) + Vector3(0, 0.05, 0) if not h.is_empty() else p


func _spawn_cars() -> void:
	var start: Vector3 = _route[0]
	var ahead: Vector3 = _route[mini(3, _route.size() - 1)]
	var dirv: Vector3 = ahead - start
	dirv.y = 0
	if dirv.length() < 0.1:
		dirv = Vector3(0, 0, -1)
	dirv = dirv.normalized()
	var heading := atan2(-dirv.x, -dirv.z)
	var right := Vector3(-dirv.z, 0, dirv.x)

	var ai_count := 0 if _mode == "roam" else int(GameState.next_race.get("ai_count", 5))

	_player = CarController.new()
	add_child(_player)
	_player.setup(GameState.car_cfg(), true)
	var p_back := 5.0 + float((ai_count + 1) / 2) * 7.0 + 2.0
	_player.place(_ground_at(start - dirv * p_back + Vector3(0, 1.5, 0)), heading)
	_player.fell_off.connect(_on_player_fell)
	_entries.append({"id": 0, "ctrl": _player, "name": "YOU", "is_player": true, "idx": 0, "prog": 0.0, "finished": false, "ftime": 0.0, "lane": 0.0, "stuck": 0.0})

	for i in ai_count:
		var ctrl := CarController.new()
		add_child(ctrl)
		ctrl.setup(GameState.car_cfg(AI_CAR_ORDER[i % AI_CAR_ORDER.size()]), false)
		var back := 5.0 + float(i / 2) * 7.0
		var lat := -2.8 if i % 2 == 0 else 2.8
		ctrl.place(_ground_at(start - dirv * back + right * lat + Vector3(0, 1.5, 0)), heading)
		_entries.append({"id": i + 1, "ctrl": ctrl, "name": AI_NAMES[i % AI_NAMES.size()], "is_player": false, "idx": 0, "prog": 0.0, "finished": false, "ftime": 0.0, "lane": randf_range(-2.5, 2.5), "stuck": 0.0})

	_cam_pos = _player.global_position - dirv * 10.0 + Vector3(0, 3.5, 0)
	print("[race] cars on grid: ", _entries.size())


func _build_pillars() -> void:
	_pillar = _make_pillar(Color(0.26, 0.85, 1.0, 0.32), 0.55)
	_finish_pillar = _make_pillar(Color(1.0, 0.6, 0.15, 0.4), 0.9)
	var fp: Vector3 = _route[_route.size() - 1]
	_finish_pillar.global_position = fp + Vector3(0, 4, 0)
	var show := _mode == "sprint"
	_pillar.visible = show
	_finish_pillar.visible = show
	_prog_bar.visible = show


func _make_pillar(color: Color, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 8.0
	cyl.radial_segments = 20
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cyl.material = m
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ================================================================= runtime
func _physics_process(delta: float) -> void:
	if _paused or _phase == "loading" or _player == null:
		return
	if _phase == "countdown":
		_tick_countdown(delta)
		_update_audio()
		return

	if _phase == "race":
		_race_time += delta
	_feed_player_input()
	for e in _entries:
		if not bool(e["is_player"]):
			_feed_ai_input(e)
	for e in _entries:
		_update_progress(e)
	if _phase == "race":
		_check_finish()
	elif _phase == "finished" and _finish_delay > 0.0:
		_finish_delay -= delta
		if _finish_delay <= 0.0 and not _results_shown:
			_results_shown = true
			_show_results()
	if _pillar != null and _pillar.visible:
		var pe := _player_entry()
		var tp := _point_at_dist(float(pe["prog"]) + 130.0, int(pe["idx"]))
		_pillar.global_position = tp + Vector3(0, 4, 0)
	_sun.global_position = _player.global_position + Vector3(50, 90, 30)
	_update_hud()
	_update_audio()


func _tick_countdown(dt: float) -> void:
	_cd_t += dt
	var stages := [[0.1, "3", 440.0], [0.85, "2", 440.0], [1.6, "1", 440.0], [2.35, "GO!", 880.0]]
	for i in stages.size():
		if _cd_t >= float(stages[i][0]) and _cd_stage < i:
			_cd_stage = i
			_show_msg(String(stages[i][1]), 0.7)
			_beep(float(stages[i][2]), 0.35 if i == 3 else 0.13)
			if i == 3:
				_phase = "race"
				_race_time = 0.0
				for e in _entries:
					(e["ctrl"] as CarController).active = true


func _feed_player_input() -> void:
	if _phase != "race":
		_player.in_throttle = 0.0
		_player.in_brake = 0.4 if _phase == "finished" else 0.0
		_player.in_steer = 0.0
		_player.in_drift = false
		_player.in_nitro = false
		return
	var steer := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	if bool(_touch["left"]):
		steer += 1.0
	if bool(_touch["right"]):
		steer -= 1.0
	if bool(GameState.settings["tilt"]):
		steer += clampf(Input.get_accelerometer().y / 4.0, -1.0, 1.0)
	_player.in_steer = clampf(steer, -1.0, 1.0)

	var gas := Input.get_action_strength("accelerate")
	if bool(_touch["gas"]):
		gas = 1.0
	var brake := Input.get_action_strength("brake")
	if bool(_touch["brake"]):
		brake = 1.0
	if bool(GameState.settings["touchdrive"]) and _show_touch:
		gas = 1.0 if brake < 0.5 else 0.0
	_player.in_throttle = gas
	_player.in_brake = brake
	_player.in_drift = Input.is_action_pressed("drift") or bool(_touch["drift"])
	_player.in_nitro = Input.is_action_pressed("nitro") or bool(_touch["nitro"])


func _feed_ai_input(e: Dictionary) -> void:
	var ctrl := e["ctrl"] as CarController
	var pos := ctrl.global_position
	var f := ctrl.forward_vec()
	var vf := ctrl.velocity.dot(f)
	var look := clampf(7.0 + absf(vf) * 0.55, 8.0, 42.0)
	var t_idx := _idx_at_dist(float(e["prog"]) + look, int(e["idx"]))
	var target: Vector3 = _route[t_idx]
	var nxt_i := mini(t_idx + 1, _route.size() - 1)
	var seg: Vector3 = (_route[nxt_i] as Vector3) - target
	seg.y = 0
	if seg.length() > 0.1:
		var sd := seg.normalized()
		target += Vector3(-sd.z, 0, sd.x) * float(e["lane"])
	var to: Vector3 = target - pos
	to.y = 0
	var ang := 0.0
	if to.length() > 0.1:
		ang = f.signed_angle_to(to.normalized(), Vector3.UP)
	ctrl.in_steer = clampf(ang * 2.4, -1.0, 1.0)

	var curve := float(_route_curve[mini(int(e["idx"]) + 6, _route_curve.size() - 1)])
	var pe := _player_entry()
	var band := clampf(1.0 + (float(pe["prog"]) - float(e["prog"])) * 0.00012, 0.9, 1.12)
	var desired := float(ctrl.cfg["top_speed"]) * float(GameState.next_race.get("ai_speed", 0.97)) * band
	desired *= clampf(1.06 - curve * 1.5, 0.36, 1.0)
	if bool(e["finished"]):
		desired = 16.0
	ctrl.in_throttle = 1.0 if vf < desired else 0.0
	ctrl.in_brake = 0.7 if vf > desired * 1.18 else 0.0
	ctrl.in_drift = curve > 0.55 and absf(vf) > 22.0
	ctrl.in_nitro = curve < 0.05 and ctrl.nitro > 30.0 and not bool(e["finished"])

	if _phase == "race" and not bool(e["finished"]):
		if absf(vf) < 1.0:
			e["stuck"] = float(e["stuck"]) + get_physics_process_delta_time()
			if float(e["stuck"]) > 2.5:
				e["stuck"] = 0.0
				var pi := _idx_at_dist(float(e["prog"]) + 10.0, int(e["idx"]))
				var pp: Vector3 = _route[pi]
				var d2: Vector3 = (_route[mini(pi + 2, _route.size() - 1)] as Vector3) - pp
				d2.y = 0
				if d2.length() > 0.05:
					d2 = d2.normalized()
					ctrl.place(pp + Vector3(0, 0.3, 0), atan2(-d2.x, -d2.z))
		else:
			e["stuck"] = 0.0


func _update_progress(e: Dictionary) -> void:
	var ctrl := e["ctrl"] as CarController
	var pos := ctrl.global_position
	var lo := maxi(0, int(e["idx"]) - 3)
	var hi := mini(_route.size() - 1, int(e["idx"]) + 16)
	var best_i := int(e["idx"])
	var best_d := 1.0e18
	for k in range(lo, hi + 1):
		var d := pos.distance_squared_to(_route[k] as Vector3)
		if d < best_d:
			best_d = d
			best_i = k
	e["idx"] = best_i
	var nxt := mini(best_i + 1, _route.size() - 1)
	var seg: Vector3 = (_route[nxt] as Vector3) - (_route[best_i] as Vector3)
	var frac := 0.0
	if seg.length() > 0.01:
		frac = (pos - (_route[best_i] as Vector3)).dot(seg.normalized())
	e["prog"] = float(_route_cum[best_i]) + clampf(frac, -25.0, 25.0)


func _idx_at_dist(d: float, hint: int) -> int:
	var i := clampi(hint, 0, _route.size() - 1)
	while i < _route.size() - 1 and float(_route_cum[i]) < d:
		i += 1
	return i


func _point_at_dist(d: float, hint: int) -> Vector3:
	return _route[_idx_at_dist(d, hint)]


func _player_entry() -> Dictionary:
	for e in _entries:
		if bool(e["is_player"]):
			return e
	return {}


func _cmp_entries(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["finished"]) != bool(b["finished"]):
		return bool(a["finished"])
	if bool(a["finished"]):
		return float(a["ftime"]) < float(b["ftime"])
	return float(a["prog"]) > float(b["prog"])


func _sorted_entries() -> Array:
	var s := _entries.duplicate()
	s.sort_custom(_cmp_entries)
	return s


func _rank_of(entry: Dictionary) -> int:
	var s := _sorted_entries()
	for i in s.size():
		if int(s[i]["id"]) == int(entry["id"]):
			return i + 1
	return s.size()


func _check_finish() -> void:
	if _mode != "sprint":
		return
	for e in _entries:
		if not bool(e["finished"]) and float(e["prog"]) >= _route_total - 10.0:
			e["finished"] = true
			e["ftime"] = _race_time
			if bool(e["is_player"]):
				_phase = "finished"
				_finish_delay = 1.1
				_show_msg("FINISH!", 1.2)
				_beep(880.0, 0.4)


func _on_player_fell() -> void:
	_reset_player(false)


func _reset_player(advance: bool) -> void:
	if _player == null or _phase == "loading":
		return
	var pe := _player_entry()
	var idx := int(pe["idx"])
	if advance:
		idx = _idx_at_dist(float(pe["prog"]) + 120.0, idx)
	var p: Vector3 = _route[idx]
	var d2: Vector3 = (_route[mini(idx + 2, _route.size() - 1)] as Vector3) - p
	d2.y = 0
	var h := _player.heading
	if d2.length() > 0.05:
		d2 = d2.normalized()
		h = atan2(-d2.x, -d2.z)
	_player.place(p + Vector3(0, 0.3, 0), h)
	_cam_pos = p - _player.forward_vec() * 10.0 + Vector3(0, 3.5, 0)


# ================================================================= camera / process
func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0 and _msg_l != null:
			_msg_l.visible = false
	if _player == null or _paused:
		return
	var dt := minf(delta, 0.05)
	var pos := _player.global_position
	_shake *= exp(-dt * 3.0)

	if _phase == "countdown":
		var t := Time.get_ticks_msec() / 1000.0 * 0.16
		_camera.global_position = pos + Vector3(sin(t) * 9.5, 3.0, cos(t) * 9.5)
		_camera.look_at(pos + Vector3(0, 1, 0), Vector3.UP)
		return

	var f := _player.forward_vec()
	if _cam_mode == 2:
		_camera.global_position = _player.to_global(Vector3(0, 1.06, -0.2))
		_camera.look_at(_player.to_global(Vector3(0, 0.9, -9)), Vector3.UP)
	else:
		var dist := 9.8 if _cam_mode == 0 else 6.9
		var hgt := 3.4 if _cam_mode == 0 else 2.35
		var desired: Vector3 = pos - f * dist + Vector3(0, hgt, 0)
		_cam_pos = _cam_pos.lerp(desired, 1.0 - exp(-dt * 5.2))
		if _space != null:
			var gh := _cast_down(_cam_pos.x, _cam_pos.z, _cam_pos.y + 10.0, 40.0, 3)
			if not gh.is_empty() and _cam_pos.y < float(gh["position"].y) + 0.55:
				_cam_pos.y = float(gh["position"].y) + 0.55
		_camera.global_position = _cam_pos
		_camera.look_at(pos + f * 6.5 + Vector3(0, 1.15, 0), Vector3.UP)
	if _shake > 0.003:
		_camera.global_position += Vector3((randf() - 0.5) * _shake * 0.35, (randf() - 0.5) * _shake * 0.3, 0)

	var ratio := clampf(_player.speed_kmh / (float(_player.cfg["top_speed"]) * 3.6), 0.0, 1.0)
	var target_fov := 62.0 + ratio * 7.0 + (9.0 if _player.boosting else 0.0)
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-dt * 5.0))
	_camera.fov = _fov

	# touch visual feedback
	for zname in _touch_visuals.keys():
		var panel := _touch_visuals[zname] as PanelContainer
		panel.modulate.a = 1.0 if bool(_touch.get(zname, false)) else 0.55


func _show_msg(txt: String, dur: float) -> void:
	_msg_l.text = txt
	_msg_l.visible = true
	_msg_t = dur


func _beep(freq: float, dur: float) -> void:
	_beep_p.stream = GameState.make_tone(freq, dur, 0.45)
	_beep_p.play()


func _update_audio() -> void:
	if _player == null:
		return
	var ratio := clampf(_player.speed_kmh / (float(_player.cfg["top_speed"]) * 3.6), 0.0, 1.15)
	_engine_p.pitch_scale = lerpf(_engine_p.pitch_scale, 0.62 + ratio * 1.85, 0.1)
	_engine_p.volume_db = -11.0 + ratio * 3.0
	_skid_p.volume_db = linear_to_db(0.38) if _player.sliding else -80.0
	if _player.crash_strength > 0.0:
		_impact_p.volume_db = linear_to_db(clampf(0.15 + 0.85 * _player.crash_strength, 0.01, 1.0))
		_impact_p.play()
		_shake = minf(0.7, _shake + _player.crash_strength * 0.55)
		_player.crash_strength = 0.0
	if _player.boosting and _player.speed_kmh > 60.0:
		_shake = maxf(_shake, 0.06)


# ================================================================= HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_hud_root = Control.new()
	UiKit.full(_hud_root)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud_root)

	var pos_box := VBoxContainer.new()
	pos_box.add_theme_constant_override("separation", 2)
	pos_box.position = Vector2(24, 16)
	_hud_root.add_child(pos_box)
	_pos_l = UiKit.label("POS -/-", 40, UiKit.COL_ORANGE_L, "black")
	pos_box.add_child(_pos_l)
	pos_box.add_child(UiKit.label(String(GameState.next_race.get("title", "RACE")), 14, UiKit.COL_DIM, "bold"))

	_time_l = UiKit.label("0:00.000", 30, Color.WHITE, "black", HORIZONTAL_ALIGNMENT_CENTER)
	_time_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_l.offset_left = -140
	_time_l.offset_right = 140
	_time_l.offset_top = 14
	_time_l.offset_bottom = 52
	_hud_root.add_child(_time_l)

	_prog_bar = ProgressBar.new()
	_prog_bar.min_value = 0
	_prog_bar.max_value = 100
	_prog_bar.value = 0
	_prog_bar.show_percentage = false
	_prog_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prog_bar.offset_left = -170
	_prog_bar.offset_right = 170
	_prog_bar.offset_top = 56
	_prog_bar.offset_bottom = 66
	_prog_bar.add_theme_stylebox_override("background", UiKit.style(Color(0.1, 0.13, 0.24, 0.9), 3))
	_prog_bar.add_theme_stylebox_override("fill", UiKit.style(UiKit.COL_CYAN, 3))
	_hud_root.add_child(_prog_bar)

	_off_l = UiKit.label("OFF TRACK", 20, UiKit.COL_RED, "black", HORIZONTAL_ALIGNMENT_CENTER)
	_off_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_off_l.offset_left = -140
	_off_l.offset_right = 140
	_off_l.offset_top = 74
	_off_l.offset_bottom = 102
	_off_l.visible = false
	_hud_root.add_child(_off_l)

	var pause_b := UiKit.ghost_button("II", 20, Vector2(58, 52))
	pause_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_b.offset_left = -84
	pause_b.offset_right = -24
	pause_b.offset_top = 16
	pause_b.offset_bottom = 68
	pause_b.pressed.connect(func() -> void: _toggle_pause(true))
	_hud_root.add_child(pause_b)

	_speed_box = VBoxContainer.new()
	_speed_box.add_theme_constant_override("separation", 4)
	_speed_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed_box.offset_left = -324
	_speed_box.offset_right = -24
	_speed_box.offset_top = -196
	_speed_box.offset_bottom = -20
	_hud_root.add_child(_speed_box)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_END
	srow.add_theme_constant_override("separation", 8)
	_speed_l = UiKit.label("0", 64, Color.WHITE, "black")
	srow.add_child(_speed_l)
	srow.add_child(UiKit.label("KM/H", 16, UiKit.COL_DIM, "bold"))
	_speed_box.add_child(srow)
	_speed_box.add_child(UiKit.label("NITRO", 13, UiKit.COL_CYAN, "bold", HORIZONTAL_ALIGNMENT_RIGHT))
	_nitro_bar = ProgressBar.new()
	_nitro_bar.min_value = 0
	_nitro_bar.max_value = 100
	_nitro_bar.value = 60
	_nitro_bar.show_percentage = false
	_nitro_bar.custom_minimum_size = Vector2(0, 18)
	_nitro_bar.add_theme_stylebox_override("background", UiKit.style(Color(0.1, 0.13, 0.24, 0.95), 4, Color(UiKit.COL_CYAN, 0.5), 1))
	_nitro_fill = UiKit.style(UiKit.COL_CYAN, 4)
	_nitro_bar.add_theme_stylebox_override("fill", _nitro_fill)
	_speed_box.add_child(_nitro_bar)

	_drift_l = UiKit.label("DRIFT!", 34, UiKit.COL_CYAN, "black", HORIZONTAL_ALIGNMENT_CENTER)
	_drift_l.set_anchors_preset(Control.PRESET_CENTER)
	_drift_l.offset_left = -150
	_drift_l.offset_right = 150
	_drift_l.offset_top = 100
	_drift_l.offset_bottom = 150
	_drift_l.visible = false
	_hud_root.add_child(_drift_l)

	_msg_l = UiKit.label("", 96, Color.WHITE, "black", HORIZONTAL_ALIGNMENT_CENTER)
	_msg_l.set_anchors_preset(Control.PRESET_CENTER)
	_msg_l.offset_left = -420
	_msg_l.offset_right = 420
	_msg_l.offset_top = -100
	_msg_l.offset_bottom = 40
	_msg_l.visible = false
	_hud_root.add_child(_msg_l)


func _update_hud() -> void:
	if _player == null:
		return
	_speed_l.text = str(int(_player.speed_kmh))
	_nitro_bar.value = _player.nitro
	_nitro_fill.bg_color = UiKit.COL_ORANGE if _player.boosting else UiKit.COL_CYAN
	_time_l.text = GameState.fmt_time(_race_time)
	if _mode == "sprint":
		var pe := _player_entry()
		_pos_l.text = "POS " + str(_rank_of(pe)) + "/" + str(_entries.size())
		_prog_bar.value = clampf(float(pe["prog"]) / _route_total * 100.0, 0.0, 100.0)
	else:
		_pos_l.text = "FREE ROAM"
	_drift_l.visible = _player.sliding and _phase == "race"
	_off_l.visible = _player.offroad and _player.speed_kmh > 12.0 and _phase == "race"


func _build_loading() -> void:
	_load_layer = CanvasLayer.new()
	_load_layer.layer = 20
	_load_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_load_layer)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/hero_art.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UiKit.full(bg)
	_load_layer.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.78)
	UiKit.full(dim)
	_load_layer.add_child(dim)

	var center := CenterContainer.new()
	UiKit.full(center)
	_load_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 12)
	th.add_child(UiKit.label("SILVER LAKE", 44, Color.WHITE, "black"))
	th.add_child(UiKit.label("GP", 44, UiKit.COL_ORANGE_L, "black"))
	v.add_child(th)
	_load_label = UiKit.label("LOADING...", 16, UiKit.COL_TEXT, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_load_label)
	_load_bar = ProgressBar.new()
	_load_bar.min_value = 0
	_load_bar.max_value = 100
	_load_bar.value = 0
	_load_bar.show_percentage = false
	_load_bar.custom_minimum_size = Vector2(540, 14)
	_load_bar.add_theme_stylebox_override("background", UiKit.style(Color(0.1, 0.12, 0.22, 0.9), 4, Color(UiKit.COL_CYAN, 0.5), 1))
	_load_bar.add_theme_stylebox_override("fill", UiKit.style(UiKit.COL_ORANGE, 4))
	v.add_child(_load_bar)


func _set_loading(txt: String, frac: float) -> void:
	if _load_label != null:
		_load_label.text = txt
		_load_bar.value = frac * 100.0


# ================================================================= touch + input
func _build_touch() -> void:
	var defs := {"left": "<", "right": ">", "nitro": "NITRO", "drift": "DRIFT", "brake": "BRAKE", "gas": "GAS"}
	for zname in defs.keys():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiKit.style(UiKit.COL_PANEL_SOFT, 16, Color(UiKit.COL_CYAN, 0.6), 1))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.55
		var l := UiKit.label(String(defs[zname]), 26, Color.WHITE, "black", HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_hud_root.add_child(p)
		_touch_visuals[zname] = p


func _layout_touch() -> void:
	if _speed_box != null:
		_speed_box.offset_top = -356 if _show_touch else -196
	if not _show_touch:
		return
	var vp := get_viewport().get_visible_rect().size
	_touch_zones = {
		"left": Rect2(24, vp.y - 190, 132, 132),
		"right": Rect2(172, vp.y - 190, 132, 132),
		"nitro": Rect2(vp.x - 172, vp.y - 196, 146, 146),
		"drift": Rect2(vp.x - 304, vp.y - 178, 116, 116),
		"brake": Rect2(vp.x - 304, vp.y - 306, 116, 104),
		"gas": Rect2(vp.x - 172, vp.y - 322, 146, 104),
	}
	for zname in _touch_visuals.keys():
		var panel := _touch_visuals[zname] as PanelContainer
		var r: Rect2 = _touch_zones[zname]
		panel.position = r.position
		panel.size = r.size
		panel.visible = not (zname == "gas" and bool(GameState.settings["touchdrive"]))


func _touch_down(idx: int, pos: Vector2) -> void:
	var zone := ""
	for zname in _touch_zones.keys():
		if (_touch_zones[zname] as Rect2).has_point(pos):
			zone = zname
			break
	if zone == "gas" and bool(GameState.settings["touchdrive"]):
		zone = ""
	if zone != "":
		_active_touches[idx] = zone
	else:
		_active_touches.erase(idx)
	_recompute_touch()


func _touch_up(idx: int) -> void:
	_active_touches.erase(idx)
	_recompute_touch()


func _recompute_touch() -> void:
	for k in _touch.keys():
		_touch[k] = false
	for z in _active_touches.values():
		_touch[z] = true


func _input(event: InputEvent) -> void:
	if _show_touch:
		if event is InputEventScreenTouch:
			if event.pressed:
				_touch_down(event.index, event.position)
			else:
				_touch_up(event.index)
		elif event is InputEventScreenDrag:
			_touch_down(event.index, event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_down(-1, event.position)
			else:
				_touch_up(-1)
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_touch_down(-1, event.position)
	if _phase == "loading":
		return
	if event.is_action_pressed("camera"):
		_cam_mode = (_cam_mode + 1) % 3
	if event.is_action_pressed("reset_car"):
		_reset_player(false)
	if event.is_action_pressed("teleport"):
		_reset_player(true)
	if event.is_action_pressed("pause"):
		_toggle_pause(not _paused)


func _toggle_pause(on: bool) -> void:
	if _phase == "loading" or on == _paused:
		return
	_paused = on
	get_tree().paused = on
	_engine_p.stream_paused = on
	_skid_p.stream_paused = on
	if on:
		var parts := UiKit.popup_shell(_hud_root, "PAUSED")
		_pause_dim = parts["dim"]
		var vbox: VBoxContainer = parts["vbox"]
		var resume := UiKit.button("RESUME", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 20, Vector2(0, 56))
		resume.pressed.connect(func() -> void: _toggle_pause(false))
		vbox.add_child(resume)
		var restart := UiKit.ghost_button("RESTART RACE", 18, Vector2(0, 52))
		restart.pressed.connect(func() -> void:
			get_tree().paused = false
			get_tree().reload_current_scene()
		)
		vbox.add_child(restart)
		var settings_b := UiKit.ghost_button("SETTINGS", 18, Vector2(0, 52))
		settings_b.pressed.connect(func() -> void: UiKit.settings_popup(_hud_root))
		vbox.add_child(settings_b)
		var quit := UiKit.ghost_button("QUIT TO HOME", 18, Vector2(0, 52))
		quit.pressed.connect(func() -> void:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/home.tscn")
		)
		vbox.add_child(quit)
	else:
		if _pause_dim != null:
			_pause_dim.queue_free()
			_pause_dim = null


func _show_results() -> void:
	var pe := _player_entry()
	var pos := _rank_of(pe)
	var base := int(GameState.next_race.get("reward", 6000))
	var reward := int(base * float(GameState.POSITION_REWARDS[clampi(pos - 1, 0, GameState.POSITION_REWARDS.size() - 1)]))
	GameState.credits += reward
	var cidx := int(GameState.next_race.get("career_idx", -1))
	var cleared := false
	if cidx >= 0:
		if pos <= 3:
			GameState.career_done[cidx] = true
			cleared = true
		var bt := float(GameState.best_times[cidx])
		if bt <= 0.0 or _race_time < bt:
			GameState.best_times[cidx] = _race_time
	GameState.save()
	_player.active = false

	var parts := UiKit.popup_shell(_hud_root, "FINISH - P" + str(pos))
	var vbox: VBoxContainer = parts["vbox"]
	var sorted := _sorted_entries()
	for i in sorted.size():
		var e: Dictionary = sorted[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := UiKit.COL_ORANGE_L if bool(e["is_player"]) else UiKit.COL_TEXT
		row.add_child(UiKit.label("P" + str(i + 1), 18, col, "black"))
		var nm := UiKit.label(String(e["name"]), 17, col, "bold")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var tt := GameState.fmt_time(float(e["ftime"])) if bool(e["finished"]) else str(int(clampf(float(e["prog"]) / _route_total * 100.0, 0.0, 100.0))) + "%"
		row.add_child(UiKit.label(tt, 16, UiKit.COL_DIM, "bold"))
		vbox.add_child(row)

	vbox.add_child(UiKit.label("+" + GameState.fmt_money(reward) + " CR", 24, UiKit.COL_GOLD, "black", HORIZONTAL_ALIGNMENT_CENTER))
	if cleared:
		vbox.add_child(UiKit.label("CAREER EVENT CLEARED!", 17, UiKit.COL_GREEN, "bold", HORIZONTAL_ALIGNMENT_CENTER))

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	var again := UiKit.button("RACE AGAIN", UiKit.COL_ORANGE, Color(0.08, 0.03, 0.0), 18, Vector2(190, 54))
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	btns.add_child(again)
	var gar := UiKit.ghost_button("GARAGE", 18, Vector2(160, 54))
	gar.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/garage.tscn"))
	btns.add_child(gar)
	var home := UiKit.ghost_button("HOME", 18, Vector2(140, 54))
	home.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home.tscn"))
	btns.add_child(home)
	vbox.add_child(btns)
