class_name CarRig
## Builds a drivable/displayable car from a GLB:
##  - rotates the model so the nose faces -Z (cfg.yaw_offset_deg)
##  - scales it to cfg.length_m, re-centers origin at ground center
##  - creates wheel pivots (tagged groups / generic axle detection / none)
## Returns {root, wheels_front, wheels_rear, wheel_radius, half_length, half_width, height}


static func build(cfg: Dictionary, parent: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "CarRoot"
	var align := Node3D.new()
	align.name = "Align"
	root.add_child(align)
	parent.add_child(root)

	var packed := load(cfg["path"]) as PackedScene
	var model := packed.instantiate() as Node3D
	align.add_child(model)
	align.rotation.y = deg_to_rad(float(cfg.get("yaw_offset_deg", 180.0)))
	root.force_update_transform()

	var box := _merged_aabb_local(root, model)
	var length := box.size.z
	if length < 0.01:
		length = 1.0
	var s := float(cfg.get("length_m", 4.55)) / length
	align.scale = Vector3.ONE * s
	root.force_update_transform()

	box = _merged_aabb_local(root, model)
	var center := box.get_center()
	align.position = Vector3(-center.x, -box.position.y, -center.z)
	root.force_update_transform()

	box = _merged_aabb_local(root, model)
	var info := {
		"root": root,
		"wheels_front": [] as Array,
		"wheels_rear": [] as Array,
		"wheel_radius": 0.34,
		"half_length": box.size.z * 0.5,
		"half_width": box.size.x * 0.5,
		"height": box.size.y,
	}

	match String(cfg.get("wheel_mode", "none")):
		"tagged":
			_rig_tagged(root, model, info)
		"axle":
			_rig_axle(root, model, info)
		_:
			pass
	root.force_update_transform()
	return info


static func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)


static func _merged_aabb_local(root: Node3D, subtree: Node) -> AABB:
	var meshes: Array = []
	_collect_meshes(subtree, meshes)
	var inv := root.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for mi in meshes:
		var w: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if first:
			result = w
			first = false
		else:
			result = result.merge(w)
	return result


static func _make_pivot(root: Node3D, pivot_name: String, center_local: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	root.add_child(pivot)
	pivot.position = center_local
	root.force_update_transform()
	return pivot


static func _rig_tagged(root: Node3D, model: Node, info: Dictionary) -> void:
	var groups: Array = []
	_find_named(model, "wheelstock_", groups)
	var radius := 0.0
	for g in groups:
		var tag := String(g.name).right(2).to_upper()
		var box := _merged_aabb_local(root, g)
		var pivot := _make_pivot(root, "WheelPivot_" + tag, box.get_center())
		g.reparent(pivot, true)
		radius = maxf(radius, box.size.y * 0.5)
		if tag == "FL" or tag == "FR":
			info["wheels_front"].append(pivot)
		else:
			info["wheels_rear"].append(pivot)
	if radius > 0.05:
		info["wheel_radius"] = radius
	print("[CarRig] tagged wheels: ", info["wheels_front"].size(), " front, ", info["wheels_rear"].size(), " rear, r=", snappedf(float(info["wheel_radius"]), 0.01))


static func _find_named(node: Node, needle: String, out: Array) -> void:
	if String(node.name).to_lower().contains(needle):
		out.append(node)
	for c in node.get_children():
		_find_named(c, needle, out)


static func _rig_axle(root: Node3D, model: Node, info: Dictionary) -> void:
	# Generic: find round, low, tire-like meshes (already in meters, nose = -Z).
	var meshes: Array = []
	_collect_meshes(model, meshes)
	var inv := root.global_transform.affine_inverse()
	var front: Array = []
	var rear: Array = []
	var radius := 0.0
	for mi in meshes:
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		var d := b.size.y
		if d < 0.26 or d > 1.05:
			continue
		var circ := b.size.z if b.size.x >= b.size.z else b.size.x
		if absf(d - circ) > 0.27:
			continue
		var c := b.get_center()
		if c.y > 0.62:
			continue
		radius = maxf(radius, d * 0.5)
		if c.z < 0.0:
			front.append({"mi": mi, "box": b})
		else:
			rear.append({"mi": mi, "box": b})
	_rig_cluster(root, front, "AxleFront", info["wheels_front"])
	_rig_cluster(root, rear, "AxleRear", info["wheels_rear"])
	if radius > 0.05:
		info["wheel_radius"] = radius
	print("[CarRig] axle wheels: ", front.size(), " front meshes, ", rear.size(), " rear meshes, r=", snappedf(float(info["wheel_radius"]), 0.01))


static func _rig_cluster(root: Node3D, items: Array, pivot_name: String, out_pivots: Array) -> void:
	if items.is_empty():
		return
	var wide := false
	var avg := Vector3.ZERO
	for it in items:
		var b: AABB = it["box"]
		avg += b.get_center()
		if b.size.x > 1.0:
			wide = true
	avg /= float(items.size())
	if wide:
		avg.x = 0.0
		var pivot := _make_pivot(root, pivot_name, avg)
		for it in items:
			(it["mi"] as Node).reparent(pivot, true)
		out_pivots.append(pivot)
	else:
		for it in items:
			var b2: AABB = it["box"]
			var pivot2 := _make_pivot(root, pivot_name + "_W", b2.get_center())
			(it["mi"] as Node).reparent(pivot2, true)
			out_pivots.append(pivot2)
