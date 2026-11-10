extends CharacterBody3D
## One arcade grounded personal vehicle. Only the existing input owner steps it.
const MODEL_PATH := "res://game/player_vehicle/assets/pickup.glb"
const WHEELBASE := 2.62
const WHEEL_RADIUS := 0.34
const BODY_SIZE := Vector3(1.8,1.55,4.5)
var state: RefCounted
var manager: CharacterBody3D
var manager_shape: CollisionShape3D
var manager_pose: RefCounted
var construction: RefCounted
var visual: Node3D
var body_pivot: Node3D
var steering: Array[Node3D] = []
var _steering_rest: Array[Transform3D] = []
var wheels: Array[Node3D] = []
var collider := CollisionShape3D.new()
var view_pivot := Node3D.new()
var first := Camera3D.new()
var third := Camera3D.new()
var spring := SpringArm3D.new()
var steer_angle := 0.0
var _look_yaw := 0.0
var _body_base := Transform3D.IDENTITY
var _seat := Vector3(-0.38,0.85,-0.55)
var _exits: Array[Vector3] = []
var _last_footprint := Rect2()

static func prepare_materials(root: Node3D) -> Array[BaseMaterial3D]:
	# Shared with covered first-use preparation; actual palette/glass variants.
	var shared: Dictionary = {}
	var result: Array[BaseMaterial3D] = []
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			if source == null: continue
			if not shared.has(source):
				var material := source.duplicate() as BaseMaterial3D
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				shared[source] = material
				result.append(material)
			mesh.set_surface_override_material(surface,shared[source])
	return result

func bind(next_state: RefCounted, player: CharacterBody3D, shape: CollisionShape3D, pose: RefCounted, service: RefCounted) -> void:
	state = next_state
	manager = player
	manager_shape = shape
	manager_pose = pose
	construction = service
	name = "PersonalPickup"
	collision_layer = 8
	collision_mask = 3
	floor_snap_length = 0.3
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	collider.shape = box
	collider.position.y = BODY_SIZE.y/2.0
	add_child(collider)
	visual = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	add_child(visual)
	prepare_materials(visual)
	var label := Label3D.new()
	label.text = "Personal pickup · E"
	label.position.y = 2.2
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	body_pivot = visual.find_child("Body_Pivot",true,false) as Node3D
	assert(body_pivot != null,"Pickup requires Artist Body_Pivot")
	_body_base = body_pivot.transform
	for id: String in ["Steer_FL","Steer_FR"]:
		var pivot := visual.find_child(id,true,false) as Node3D
		assert(pivot != null,"Pickup requires "+id)
		steering.append(pivot)
		_steering_rest.append(pivot.transform)
	for id: String in ["Spin_FL","Spin_FR","Spin_RL","Spin_RR"]:
		var wheel := visual.find_child(id,true,false) as Node3D
		assert(wheel != null,"Pickup requires "+id)
		wheels.append(wheel)
	var seat := visual.find_child("Driver_Seat",true,false) as Node3D
	var left_exit := visual.find_child("Driver_Exit_Left",true,false) as Node3D
	var driver_eye := visual.find_child("Driver_Eye",true,false) as Node3D
	assert(seat != null and left_exit != null and driver_eye != null,"Pickup requires Artist seat, eye and adjacent exit markers")
	_seat = visual.to_local(seat.global_position)
	var exit_offset: Vector3 = visual.to_local(left_exit.global_position)
	exit_offset.y = 0.0
	_exits = [exit_offset,Vector3(-exit_offset.x,0,exit_offset.z)]
	add_child(view_pivot)
	view_pivot.position.y = 1.5
	view_pivot.add_child(spring)
	spring.spring_length = 7.5
	spring.rotation.x = -0.24
	spring.margin = 0.2
	spring.collision_mask = 13
	spring.add_excluded_object(get_rid())
	spring.add_child(third)
	third.far = 500
	body_pivot.add_child(first)
	first.position = body_pivot.to_local(driver_eye.global_position)
	first.near = 0.06
	first.far = 500
	global_position = state.position
	global_rotation.y = state.heading
	_publish_footprint()
	if state.occupied: _seat_manager()

func interact(game_speed: int) -> Dictionary:
	if game_speed <= 0: return {"ok":false,"message":"Resume time before entering or exiting the pickup."}
	if not is_zero_approx(state.speed): return {"ok":false,"message":"Stop the pickup before entering or exiting. Space brakes."}
	if state.occupied:
		var point: Variant = _clear_exit()
		if point == null: return {"ok":false,"message":"Both pickup exits are blocked. Move to clear adjacent ground before exiting."}
		state.occupied = false
		manager.global_position = point
		manager.global_rotation.y = global_rotation.y
		manager_pose.publish_resolved(point,global_rotation.y)
		manager_shape.set_deferred("disabled",false)
		remove_collision_exception_with(manager)
		return {"ok":true,"message":"Exited personal pickup. WASD walks; E interacts."}
	if manager.global_position.distance_to(global_position) > 4.0: return {"ok":false,"message":"Walk closer to the personal pickup to enter."}
	state.occupied = true
	_seat_manager()
	return {"ok":true,"message":"Personal pickup: WASD drive/reverse/steer · Space brake · E exit when stopped · V view. Prototype fuel is unmetered."}

func _seat_manager() -> void:
	manager_shape.set_deferred("disabled",true)
	add_collision_exception_with(manager)
	manager.velocity = Vector3.ZERO
	manager.global_position = to_global(_seat)
	manager.global_rotation.y = global_rotation.y
	manager_pose.publish_resolved(manager.global_position,global_rotation.y)

func _clear_exit() -> Variant:
	# Only a deliberate exit command queries adjacent grounded capsule clearance.
	for offset: Vector3 in _exits:
		var candidate: Vector3 = to_global(offset)
		if not Rect2(0.6,0.6,238.8,208.8).has_point(Vector2(candidate.x,candidate.z)): continue
		var ray := PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*2.5,candidate-Vector3.UP*1.0,1)
		var ground: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if ground.is_empty() or ground.normal.y < 0.9 or absf(ground.position.y) > 0.2: continue
		candidate.y = ground.position.y+0.01
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = manager_shape.shape
		query.transform = Transform3D(Basis.IDENTITY,candidate+Vector3(0,0.92,0))
		query.collision_mask = 15
		query.exclude = [get_rid(),manager.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return candidate
	return null

func camera(first_person: bool) -> Camera3D:
	return first if first_person else third

func look(relative: Vector2) -> void:
	_look_yaw = clampf(_look_yaw-relative.x*0.003,-1.25,1.25)
	first.rotation.y = _look_yaw
	view_pivot.rotation.y = _look_yaw
	first.rotation.x = clampf(first.rotation.x-relative.y*0.003,-0.7,0.55)
	spring.rotation.x = clampf(spring.rotation.x-relative.y*0.003,-0.7,0.1)

func step(delta: float, game_speed: int, controls: Vector2, brake: bool, enabled: bool) -> bool:
	if game_speed <= 0: return false
	if is_zero_approx(state.speed) and (not enabled or controls.is_zero_approx()) and is_zero_approx(steer_angle) and body_pivot.rotation.is_equal_approx(_body_base.basis.get_euler()): return false
	var dt := delta*float(game_speed)
	var previous: Vector3 = global_position
	var old_speed: float = state.speed
	var throttle: float = -controls.y if enabled and state.occupied else 0.0
	var stopping: bool = brake or not enabled or not state.occupied
	var target: float = throttle*(10.0 if throttle >= 0.0 else 4.0)
	state.speed = move_toward(state.speed,0.0 if stopping else target,(12.0 if stopping else (6.0 if not is_zero_approx(throttle) else 3.0))*dt)
	steer_angle = move_toward(steer_angle,controls.x*0.48 if enabled and not stopping else 0.0,2.5*dt)
	var yaw_step: float = -state.speed*tan(steer_angle)/WHEELBASE*dt
	var actual_yaw_rate := 0.0
	if not is_zero_approx(yaw_step):
		var proposed := global_transform.rotated_local(Vector3.UP,yaw_step)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		var clearance_transform := proposed*collider.transform
		clearance_transform.origin.y += 0.01 # Ignore resting floor contact for angular clearance.
		query.transform = clearance_transform
		query.collision_mask = 3
		query.exclude = [get_rid(),manager.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			global_transform = proposed
			actual_yaw_rate = yaw_step/dt
	velocity = -global_basis.z*state.speed*float(game_speed)
	velocity.y = -2.0
	move_and_slide()
	var travel: float = (global_position-previous).dot(-global_basis.z)
	if absf(state.speed) > 0.1 and absf(travel) < absf(state.speed)*dt*0.2: state.speed = 0.0
	for index in steering.size(): steering[index].transform = _steering_rest[index].rotated_local(Vector3.UP,-steer_angle)
	for wheel: Node3D in wheels: wheel.rotate_object_local(Vector3.RIGHT,-travel/WHEEL_RADIUS)
	var acceleration: float = (float(state.speed)-old_speed)/maxf(dt,0.0001)
	var tilt := _body_base.basis.get_euler()+Vector3(clampf(acceleration*0.009,-0.07,0.07),0,clampf(-state.speed*actual_yaw_rate*0.012,-0.09,0.09))
	body_pivot.rotation = body_pivot.rotation.lerp(tilt,1.0-exp(-7.0*dt))
	if absf(state.speed) < 0.001 and body_pivot.rotation.distance_to(_body_base.basis.get_euler()) < 0.0001: body_pivot.rotation = _body_base.basis.get_euler()
	state.position = global_position
	state.heading = global_rotation.y
	_publish_footprint()
	if state.occupied and (not global_position.is_equal_approx(previous) or not is_zero_approx(yaw_step)):
		manager.global_position = to_global(_seat)
		manager.global_rotation.y = global_rotation.y
		manager_pose.publish_resolved(manager.global_position,global_rotation.y)
	return not global_position.is_equal_approx(previous)

func _publish_footprint() -> void:
	var half: Vector3 = global_basis.x.abs()+global_basis.z.abs()*2.35
	var footprint := Rect2(Vector2(global_position.x-half.x,global_position.z-half.z),Vector2(half.x*2,half.z*2))
	if footprint == _last_footprint: return
	_last_footprint = footprint
	construction.dynamic_occupants["personal-pickup"] = footprint

func _exit_tree() -> void:
	if construction != null: construction.dynamic_occupants.erase("personal-pickup")
