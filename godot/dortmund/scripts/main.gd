extends Node3D

const CITY_PATH := "res://assets/dortmund.glb"
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")

var player
var hud
var map_camera: Camera3D
var map_mode := true
var city_root: Node3D
var city_size_xz := Vector2(1336.0, 1140.0)

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_city()
	_build_player()
	_build_map_camera()
	_build_hud()

func _process(_delta: float) -> void:
	if map_mode and map_camera and player:
		map_camera.global_position.x = player.global_position.x
		map_camera.global_position.z = player.global_position.z

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.43, 0.67, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.76, 0.92)
	env.ambient_light_energy = 1.25
	env.fog_enabled = false
	world_environment.environment = env
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.94, 0.83)
	sun.shadow_enabled = false
	add_child(sun)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1500.0, 0.2, 1500.0)
	shape.shape = box
	shape.position.y = -0.12
	ground.add_child(shape)

	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500.0, 1500.0)
	mesh_instance.mesh = plane
	mesh_instance.position.y = -0.01
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.16, 0.18)
	mat.roughness = 1.0
	mesh_instance.material_override = mat
	ground.add_child(mesh_instance)
	add_child(ground)

func _build_city() -> void:
	if ResourceLoader.exists(CITY_PATH):
		var city_resource := load(CITY_PATH)
		if city_resource is PackedScene:
			city_root = (city_resource as PackedScene).instantiate()
			city_root.name = "DortmundOriginal"
			add_child(city_root)
			_center_city_to_origin(city_root)
			return
	push_error("FULL MODEL MISSING: assets/dortmund.glb")
	_build_placeholder_city()

func _build_placeholder_city() -> void:
	city_root = Node3D.new()
	city_root.name = "DortmundPlaceholder_DEV_ONLY"
	add_child(city_root)
	var block_mat := StandardMaterial3D.new()
	block_mat.albedo_color = Color(0.46, 0.50, 0.56)
	block_mat.roughness = 0.95
	for x in range(-4, 5):
		for z in range(-4, 5):
			if (x + z) % 3 == 0:
				continue
			var mesh_instance := MeshInstance3D.new()
			var box := BoxMesh.new()
			var height := 7.0 + float(abs((x * 13 + z * 7) % 18))
			box.size = Vector3(8.0, height, 8.0)
			mesh_instance.mesh = box
			mesh_instance.position = Vector3(float(x) * 14.0, height * 0.5, float(z) * 14.0)
			mesh_instance.material_override = block_mat
			city_root.add_child(mesh_instance)

func _build_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.25, 0.0)
	add_child(player)

func _build_map_camera() -> void:
	map_camera = Camera3D.new()
	map_camera.name = "MapCamera"
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	map_camera.position = Vector3(0.0, 900.0, 0.0)
	map_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(map_camera)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / max(viewport_size.y, 1.0)
	var required_height := max(city_size_xz.y, city_size_xz.x / max(aspect, 0.1))
	map_camera.size = required_height * 1.08
	map_camera.current = true
	if player:
		player.controls_enabled = false
		if player.camera:
			player.camera.current = false

func _build_hud() -> void:
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.move_changed.connect(player.set_touch_move)
	hud.jump_pressed.connect(player.jump)
	hud.sprint_changed.connect(player.set_touch_sprint)
	hud.map_pressed.connect(toggle_map)
	hud.reset_pressed.connect(player.reset_to_spawn)
	player.coordinates_changed.connect(hud.update_position)
	hud.set_map_mode(true)

func toggle_map() -> void:
	map_mode = not map_mode
	player.controls_enabled = not map_mode
	player.set_touch_move(Vector2.ZERO)
	player.set_touch_sprint(false)
	if player.camera:
		player.camera.current = not map_mode
	if map_camera:
		map_camera.current = map_mode
	if hud:
		hud.set_map_mode(map_mode)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_map()
		elif event.keycode == KEY_R and player:
			player.reset_to_spawn()

func _center_city_to_origin(root: Node3D) -> void:
	var bounds := _collect_mesh_bounds(root)
	if bounds.size == Vector3.ZERO:
		return
	city_size_xz = Vector2(bounds.size.x, bounds.size.z)
	var center_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5
	root.global_position += Vector3(-center_x, -bounds.position.y, -center_z)

func _collect_mesh_bounds(root: Node3D) -> AABB:
	var found := false
	var combined := AABB()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var local_box := mi.get_aabb()
				var corners := [
					local_box.position,
					local_box.position + Vector3(local_box.size.x, 0, 0),
					local_box.position + Vector3(0, local_box.size.y, 0),
					local_box.position + Vector3(0, 0, local_box.size.z),
					local_box.position + Vector3(local_box.size.x, local_box.size.y, 0),
					local_box.position + Vector3(local_box.size.x, 0, local_box.size.z),
					local_box.position + Vector3(0, local_box.size.y, local_box.size.z),
					local_box.position + local_box.size
				]
				for c in corners:
					var p := mi.global_transform * c
					if not found:
						combined = AABB(p, Vector3.ZERO)
						found = true
					else:
						combined = combined.expand(p)
		for child in node.get_children():
			stack.append(child)
	return combined
