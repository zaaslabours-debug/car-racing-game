class_name Showroom
## Premium turntable stage used by Home + Garage (Asphalt Legends vibe):
## sunset sky, glowing podium, neon halo disc, soft shadows.


static func create(parent: Node) -> Dictionary:
	var we := WorldEnvironment.new()
	we.environment = _make_environment()
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -38, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.76, 0.52)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	parent.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 140, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.45, 0.65, 1.0)
	fill.shadow_enabled = false
	parent.add_child(fill)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	plane.material = UiKit.std_mat(Color(0.03, 0.035, 0.07), 0.92, 0.0)
	floor_mi.mesh = plane
	parent.add_child(floor_mi)

	var halo := MeshInstance3D.new()
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = 5.15
	halo_mesh.bottom_radius = 5.15
	halo_mesh.height = 0.05
	halo_mesh.radial_segments = 64
	halo_mesh.material = UiKit.std_mat(Color(0.05, 0.5, 0.7), 0.4, 0.0, Color(0.26, 0.85, 1.0), 2.4)
	halo.mesh = halo_mesh
	halo.position = Vector3(0, 0.025, 0)
	parent.add_child(halo)

	var podium := MeshInstance3D.new()
	var pod_mesh := CylinderMesh.new()
	pod_mesh.top_radius = 4.9
	pod_mesh.bottom_radius = 5.0
	pod_mesh.height = 0.22
	pod_mesh.radial_segments = 64
	pod_mesh.material = UiKit.std_mat(Color(0.045, 0.055, 0.10), 0.28, 0.25)
	podium.mesh = pod_mesh
	podium.position = Vector3(0, 0.11, 0)
	parent.add_child(podium)

	var car_root := Node3D.new()
	car_root.name = "Turntable"
	car_root.position = Vector3(0, 0.22, 0)
	parent.add_child(car_root)

	var camera := Camera3D.new()
	camera.position = Vector3(5.9, 2.25, 5.9)
	camera.fov = 40.0
	parent.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0), Vector3.UP)
	camera.current = true

	return {"car_root": car_root, "camera": camera, "halo": halo}


static func _make_environment() -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.09, 0.30)
	sky_mat.sky_horizon_color = Color(0.98, 0.52, 0.22)
	sky_mat.ground_bottom_color = Color(0.015, 0.015, 0.04)
	sky_mat.ground_horizon_color = Color(0.30, 0.16, 0.10)
	sky_mat.sun_angle_max = 28.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.06, 0.09)
	env.fog_density = 0.011
	env.ambient_light_energy = 0.85
	return env
