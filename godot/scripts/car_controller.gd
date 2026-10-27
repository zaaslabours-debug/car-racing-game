class_name CarController
extends Node3D
## Arcade car physics (Asphalt-style): bicycle steering, lateral-grip drift,
## nitro boost, terrain following via physics raycasts, wall-step impacts.
## Shared by the player and AI. Inputs are set from race.gd every physics frame:
##   in_steer > 0 = LEFT.  Nose of the rig faces -Z (see CarRig).

signal fell_off

var cfg: Dictionary
var is_player: bool = false
var active: bool = false

var wheels_front: Array = []
var wheels_rear: Array = []
var wheel_radius: float = 0.34
var half_length: float = 2.3
var half_width: float = 0.95

# inputs (set externally)
var in_throttle: float = 0.0
var in_brake: float = 0.0
var in_steer: float = 0.0
var in_drift: bool = false
var in_nitro: bool = false

# state
var heading: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var nitro: float = 60.0
var boosting: bool = false
var sliding: bool = false
var offroad: bool = false
var in_water: bool = false
var speed_kmh: float = 0.0
var crash_strength: float = 0.0 # set on impact, consumed (zeroed) by race.gd

var _steer_smooth: float = 0.0
var _spin: float = 0.0
var _target_y: float = 0.0
var _no_ground_time: float = 0.0
var _space: PhysicsDirectSpaceState3D

var _flames: Array = []
var _brake_glows: Array = []
var _smoke: GPUParticles3D
var _underglow: OmniLight3D


func setup(p_cfg: Dictionary, p_is_player: bool) -> void:
	cfg = p_cfg
	is_player = p_is_player
	var rig := CarRig.build(cfg, self)
	wheels_front = rig["wheels_front"]
	wheels_rear = rig["wheels_rear"]
	wheel_radius = maxf(float(rig["wheel_radius"]), 0.12)
	half_length = float(rig["half_length"])
	half_width = float(rig["half_width"])
	_build_vfx()


func place(p: Vector3, h: float) -> void:
	heading = h
	velocity = Vector3.ZERO
	_steer_smooth = 0.0
	_no_ground_time = 0.0
	_target_y = p.y
	global_transform = Transform3D(Basis(Vector3.UP, h), p)


func forward_vec() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


func right_vec() -> Vector3:
	return Vector3(cos(heading), 0, -sin(heading))


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to, mask)
	return _space.intersect_ray(params)


func _physics_process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if not active:
		_update_vfx(0.0, false, false)
		return

	var f := forward_vec()
	var r := right_vec()
	var vf := velocity.dot(f)
	var vr := velocity.dot(r)
	var spd := absf(vf)

	# ---- speed caps & boost state (uses last frame's surface flags)
	boosting = in_nitro and nitro > 0.5 and vf > -1.0
	var top_speed := float(cfg["boost_speed"]) if boosting else float(cfg["top_speed"])
	if in_water:
		top_speed = 9.0
	elif offroad:
		top_speed *= 0.45

	# ---- steering (positive steer = left, heading+ = left)
	var ratio := clampf(spd / float(cfg["top_speed"]), 0.0, 1.0)
	var max_steer := lerpf(0.55, 0.15, pow(ratio, 0.7))
	_steer_smooth = lerpf(_steer_smooth, clampf(in_steer, -1.0, 1.0), 1.0 - exp(-dt * 9.0))
	var steer_delta := _steer_smooth * max_steer
	heading += (vf / 2.7) * tan(steer_delta) * (1.5 if in_drift else 1.0) * dt

	f = forward_vec()
	r = right_vec()

	# ---- longitudinal / lateral forces
	vr *= exp(-(1.7 if in_drift else 9.0) * dt)
	if in_throttle > 0.01:
		var power := float(cfg["nitro_power"]) if boosting else float(cfg["accel"])
		vf += power * maxf(0.0, 1.0 - vf / top_speed) * in_throttle * dt
	if in_brake > 0.01:
		if vf > 0.4:
			vf -= 30.0 * in_brake * dt
		else:
			vf -= 10.0 * maxf(0.0, 1.0 - absf(vf) / 13.0) * in_brake * dt
	vf *= exp(-(0.85 if offroad else 0.26) * dt)
	if in_throttle <= 0.01 and in_brake <= 0.01:
		vf *= exp(-0.45 * dt)
	if in_drift:
		vf *= exp(-0.32 * dt)
	if absf(vf) < 0.04 and in_throttle <= 0.01 and in_brake <= 0.01:
		vf = 0.0
	velocity = f * vf + r * vr

	# ---- nitro economy
	sliding = absf(vr) > 3.2 and spd > 7.0
	if boosting:
		nitro -= 34.0 * dt
	elif sliding:
		nitro += 17.0 * dt
	elif in_throttle > 0.01:
		nitro += 2.2 * dt
	else:
		nitro += 1.2 * dt
	nitro = clampf(nitro, 0.0, 100.0)

	# ---- integrate XZ with wall-step collision
	var pos := global_position
	var nx := pos.x + velocity.x * dt
	var nz := pos.z + velocity.z * dt
	var from := Vector3(nx, pos.y + 2.0, nz)
	var hit := _ray(from, from + Vector3(0, -60, 0), 3)
	if not hit.is_empty():
		_no_ground_time = 0.0
		var gy: float = hit["position"].y
		if gy - pos.y > 1.05 and spd > 2.0:
			velocity *= 0.3
			crash_strength = clampf(spd / 30.0, 0.1, 1.0)
		else:
			pos.x = nx
			pos.z = nz
			_target_y = gy
			var road := _ray(from, from + Vector3(0, -60, 0), 2)
			offroad = road.is_empty() or absf(float(road["position"].y) - gy) > 0.4
			var col: Object = hit["collider"]
			in_water = col != null and col.has_meta("surface") and String(col.get_meta("surface")) == "water"
	else:
		pos.x = nx
		pos.z = nz
		offroad = true
		_no_ground_time += dt
		if _no_ground_time > 2.5:
			_no_ground_time = 0.0
			fell_off.emit()
	pos.y = lerpf(pos.y, _target_y, 1.0 - exp(-dt * 13.0))

	# ---- orientation: align to averaged ground normal, keep heading
	var n := Vector3.ZERO
	var offsets := [Vector2(0, 0), Vector2(1.7, 0), Vector2(-1.7, 0), Vector2(0, 0.95), Vector2(0, -0.95)]
	for o in offsets:
		var sp := pos + f * o.x + r * o.y + Vector3(0, 2.5, 0)
		var sh := _ray(sp, sp + Vector3(0, -30, 0), 3)
		if not sh.is_empty():
			n += sh["normal"]
	if n.length() < 0.01:
		n = Vector3.UP
	else:
		n = n.normalized()
	if n.y < 0.35:
		n = Vector3.UP
	var back := f.slide(n)
	if back.length() < 0.01:
		back = -f
	else:
		back = -back.normalized()
	var x_axis := n.cross(back).normalized()
	var y_axis := back.cross(x_axis)
	var target_q := Quaternion(Basis(x_axis, y_axis, back).orthonormalized())
	var cur_q := global_transform.basis.get_rotation_quaternion()
	var new_q := cur_q.slerp(target_q, 1.0 - exp(-dt * 11.0))
	global_transform = Transform3D(Basis(new_q), pos)

	# ---- wheels
	_spin += vf * dt / wheel_radius
	for p in wheels_rear:
		(p as Node3D).rotation = Vector3(-_spin, 0, 0)
	for p in wheels_front:
		(p as Node3D).rotation = Vector3(-_spin, steer_delta * 1.05, 0)

	speed_kmh = absf(vf) * 3.6
	_update_vfx(absf(vf), boosting, sliding or (in_drift and spd > 7.0))


# ------------------------------------------------------------------ VFX
func _build_vfx() -> void:
	# nitro flames (cones at the rear, rear = +Z)
	var outer_mat := StandardMaterial3D.new()
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.albedo_color = Color(1.0, 0.48, 0.12, 0.85)
	outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	outer_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var core_mat := outer_mat.duplicate() as StandardMaterial3D
	core_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.95)

	for sx in [-0.36, 0.36]:
		var grp := Node3D.new()
		grp.position = Vector3(sx * (half_width / 0.95), 0.4, half_length)
		add_child(grp)
		var outer := MeshInstance3D.new()
		var oc := CylinderMesh.new()
		oc.top_radius = 0.01
		oc.bottom_radius = 0.11
		oc.height = 1.05
		oc.radial_segments = 10
		oc.material = outer_mat
		outer.mesh = oc
		outer.rotation_degrees = Vector3(90, 0, 0)
		outer.position = Vector3(0, 0, 0.5)
		outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grp.add_child(outer)
		var core := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.01
		cc.bottom_radius = 0.06
		cc.height = 0.7
		cc.radial_segments = 8
		cc.material = core_mat
		core.mesh = cc
		core.rotation_degrees = Vector3(90, 0, 0)
		core.position = Vector3(0, 0, 0.33)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grp.add_child(core)
		grp.visible = false
		_flames.append(grp)

	# brake glows
	var glow_tex := UiKit.radial_tex()
	for sx in [-0.6, 0.6]:
		var sp := Sprite3D.new()
		sp.texture = glow_tex
		sp.modulate = Color(1.0, 0.15, 0.08, 0.0)
		sp.pixel_size = 0.0045
		sp.position = Vector3(sx * (half_width / 0.95), 0.62, half_length + 0.06)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		_brake_glows.append(sp)

	# drift smoke
	_smoke = GPUParticles3D.new()
	_smoke.amount = 42
	_smoke.lifetime = 0.9
	_smoke.explosiveness = 0.0
	_smoke.local_coords = false
	_smoke.emitting = false
	_smoke.position = Vector3(0, 0.25, half_length * 0.72)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0
	pm.gravity = Vector3(0, 1.2, 0)
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.6
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.88, 0.92, 0.34))
	grad.set_color(1, Color(0.85, 0.88, 0.92, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	_smoke.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.albedo_texture = UiKit.radial_tex()
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = qmat
	_smoke.draw_pass_1 = quad
	add_child(_smoke)

	if is_player:
		_underglow = OmniLight3D.new()
		_underglow.light_color = Color(0.2, 0.75, 1.0)
		_underglow.light_energy = 0.0
		_underglow.omni_range = 6.0
		_underglow.position = Vector3(0, 0.5, 0)
		add_child(_underglow)


func _update_vfx(speed_fwd: float, is_boosting: bool, is_sliding: bool) -> void:
	for g in _flames:
		(g as Node3D).visible = is_boosting
		if is_boosting:
			(g as Node3D).scale = Vector3(1, 1, 0.85 + randf() * 0.55)
	if _underglow:
		_underglow.light_energy = 2.4 if is_boosting else 0.0
	for sp in _brake_glows:
		var a := 0.12
		if in_brake > 0.01 and speed_fwd > 1.0:
			a = 0.95
		elif speed_fwd > 1.0:
			a = 0.3
		(sp as Sprite3D).modulate.a = a
	if _smoke:
		_smoke.emitting = is_sliding
