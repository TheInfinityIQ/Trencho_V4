extends AnimatableBody3D
## Metric supplier model and cosmetic activity; never owns inventory or routes.
const Assets = preload("res://game/warehousing/warehouse_assets.gd")
const Packages = preload("res://game/warehousing/material_packages.gd")
const ActorView = preload("res://game/supplier_transport/supplier_actor_view.gd")
const ShelfView = preload("res://game/supplier_transport/supplier_shelf_view.gd")
const ROOT := "res://game/supplier_transport/assets/"
const SHELVES := {"S2":"s2_crateshelf_v01.glb","S3":"s3_restraintrack_v01.glb","S4":"s4_protectedcargo_v01.glb"}
static var _scenes: Dictionary = {}
var _receiving: RefCounted
var _model: RefCounted
var _art: Node3D
var _pivot: Node3D
var _animator: AnimationPlayer
var _mechanism := ""
var _mechanism_started := 0.0
var _spins: Array[Node3D] = []
var _steers: Array[Node3D] = []
var _cargo: Dictionary = {}
var _racks: Dictionary = {}
var _cargo_floor: Node3D
var _last_position := Vector2.ZERO
var _last_time := 0.0
var _last_speed := 0.0
var _last_heading := 0.0
var _roll_target := 0.0
var _pitch_target := 0.0
var _moving := false
var _exhaust: CPUParticles3D
var _driver: ActorView
var _driver_action: StringName = &""
var _driver_speed := -1.0
var _wheelbase := 3.0

static func model(file: String) -> Node3D:
	var path := ROOT+file
	if not _scenes.has(path): _scenes[path] = load(path) as PackedScene
	var node := (_scenes[path] as PackedScene).instantiate() as Node3D
	Assets.prepare(node)
	return node

func bind(receiving: RefCounted, simulation: RefCounted, row: Dictionary) -> void:
	_receiving = receiving
	_model = simulation
	collision_layer = 5
	collision_mask = 0
	sync_to_physics = true
	set_meta("hull_id",str(row.id))
	_art = model("materials_truck.glb" if row.kind == "Freight" else "civilian_carrier.glb")
	add_child(_art)
	_pivot = _art.find_child("Body_Pivot",true,false) as Node3D
	_cargo_floor = _art.find_child("Cargo_Floor",true,false) as Node3D
	_animator = _art.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if _animator != null:
		_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for suffix: String in ["FL","FR","ML","MR","RL","RR"]:
		_spins.append(_art.find_child("Spin_"+suffix,true,false) as Node3D)
	for suffix: String in ["FL","FR"]: _steers.append(_art.find_child("Steer_"+suffix,true,false) as Node3D)
	_wheelbase = _spins[0].global_position.distance_to(_spins[4].global_position)
	var shape := CollisionShape3D.new()
	shape.name = "SupplierHull"
	var box := BoxShape3D.new()
	box.size = Vector3(2.435,3.39004,5.83) if row.kind == "Freight" else Vector3(2.435,2.50504,6.53)
	shape.shape = box
	shape.position = Vector3(0,box.size.y/2.0,0.365 if row.kind == "Freight" else 0.715)
	add_child(shape)
	var label := Label3D.new()
	label.name = "TruckState"
	label.position.y = 3.7
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_create_exhaust()
	_bind_driver(str(row.driver_id))
	_last_position = row.position
	_last_heading = deg_to_rad(float(row.get("facing_degrees",0.0)))
	_last_time = float(_receiving._time)
	apply_pose(row.position)
	refresh(row)

func refresh(row: Dictionary) -> void:
	var was_moving := _moving
	_moving = bool(row.get("moving",false))
	var driver_action: StringName = &"supplier_driver_drive" if _moving else &"supplier_driver_idle"
	if _driver != null and driver_action != _driver_action:
		_driver_action = driver_action
		_driver.set_activity(driver_action,float(row.get("state_started",_receiving._time)),_driver.clip_duration(driver_action),true)
	if not _moving:
		_roll_target = 0.0
		if was_moving:
			_pitch_target = clampf(_pitch_target-_last_speed*0.004,-0.04,0.04)
			_last_speed = 0.0
	var phase: String = str(row.get("mechanism",""))
	if phase != _mechanism:
		_mechanism = phase
		_mechanism_started = float(row.get("mechanism_started",0.0))
		_sync_mechanism()
	_sync_racks(row.get("racks",[]))
	for id: String in row.get("shelves",{}):
		if _racks.has(id) and _racks[id] is ShelfView: _racks[id].refresh(row.shelves[id])
	for packet: Dictionary in row.get("packages",[]):
		var id: String = str(packet.stock)
		var quantity: int = int(row.get("aboard",{}).get(id,0))
		if quantity <= 0:
			if _cargo.has(id):
				_cargo[id].queue_free()
				_cargo.erase(id)
			continue
		if not _cargo.has(id): _create_packet(packet,quantity)
	(get_node("TruckState") as Label3D).text = "%s · %s\n%s" % [row.id,row.kind,phase if not phase.is_empty() else row.state]
	sync_speed()

func _bind_driver(id: String) -> void:
	var marker := _art.find_child("Driver_Seat",true,false) as Node3D
	assert(marker != null and marker.get_parent() == _pivot,"Supplier driver requires its retained Body_Pivot seat marker")
	var path := ROOT+"supplier_driver.glb"
	if not _scenes.has(path): _scenes[path] = load(path) as PackedScene
	_driver = ActorView.new()
	_driver.name = "ActualSupplierDriver"
	_pivot.add_child(_driver)
	assert(_driver.bind(_receiving,_model,id,_scenes[path] as PackedScene),"Accepted supplier driver export failed to bind")
	# Driver_Seat is the hip marker. The authored actor root is floor-relative;
	# apply the raw-worker visual correction exactly once below the truck pivot.
	_driver.set_root(marker.transform*Transform3D(Basis(Vector3.UP,PI),Vector3(0,-0.407,0)))

func _sync_racks(rows: Array) -> void:
	for row: Dictionary in rows:
		if not SHELVES.has(str(row.family)): continue # S1 remains a separate unfinished handoff.
		var id: String = str(row.id)
		if not _racks.has(id):
			assert(_cargo_floor != null and _cargo_floor.get_parent() == _pivot,"Static racks require the actual retained Cargo_Floor marker")
			var rack: Node3D = ShelfView.new() if row.get("manual_bale",false) else model(str(SHELVES[str(row.family)]))
			_cargo_floor.add_child(rack)
			if rack is ShelfView: (rack as ShelfView).bind(_receiving,_model)
			var dimensions: Vector3 = row.size
			var at: Vector3 = Vector3(row.origin)+Vector3(dimensions.x/2.0,-_pivot.position.y,dimensions.z/2.0)
			var basis := Basis(Vector3.UP,PI if int(row.side) < 0 else 0.0)
			rack.transform = _cargo_floor.transform.affine_inverse()*Transform3D(basis,at)
			_racks[id] = rack
		# Static restraints are prepared once access is unlocked, before pickup;
		# they are not an invented worker animation or an inventory authority.
		var secured: bool = _mechanism not in ["unloading","ramp_stow","door_close","closed"]
		if _racks[id].has_meta("secured") and bool(_racks[id].get_meta("secured")) == secured: continue
		_racks[id].set_meta("secured",secured)
		for child: Node in _racks[id].find_children("Restraint_*","",true,false):
			if child is Node3D: child.visible = secured

func _create_packet(packet: Dictionary, quantity: int) -> void:
	var node := Node3D.new()
	node.name = str(packet.id)
	_pivot.add_child(node)
	# Plans use truck-root metres; Body_Pivot's rest height is1m.
	node.position = Vector3(packet.position)-Vector3(0,1,0)
	node.rotation.y = PI/2.0 if packet.quarter_turn else 0.0
	var visual := Assets.model(Packages.model_file(str(packet.code)))
	node.add_child(visual)
	for label_name: String in ["Quantity_Label_Front","Quantity_Label_Back"]:
		var marker := visual.find_child(label_name,true,false) as Node3D
		if marker == null: continue
		var label := Label3D.new()
		label.text = Packages.label(str(packet.code),quantity)
		label.pixel_size = 0.0015
		label.font_size = 24
		marker.add_child(label)
	_cargo[str(packet.stock)] = node

func apply_pose(at: Vector2) -> void:
	var time: float = float(_receiving._time)
	var delta := at-_last_position
	var distance := delta.length()
	var elapsed := time-_last_time
	if distance > 0.000001:
		var heading := atan2(delta.y,delta.x)
		var yaw := angle_difference(_last_heading,heading)
		var speed: float = distance/elapsed if elapsed > 0.000001 else _last_speed
		var curvature := yaw/distance
		_roll_target = clampf(-curvature*speed*speed*0.035,-0.07,0.07)
		_pitch_target = clampf(_pitch_target+(speed-_last_speed)*0.004,-0.04,0.04)
		for spin: Node3D in _spins: spin.rotation.x -= distance/0.43
		for steer: Node3D in _steers: steer.rotation.y = clampf(-atan(_wheelbase*curvature),-0.45,0.45)
		_last_heading = heading
		_last_speed = speed
	global_transform = Transform3D(Basis(Vector3.UP,-PI/2.0-_last_heading),Vector3(at.x,0,at.y))
	_last_position = at
	_last_time = time
	sync_speed()

func _sync_mechanism() -> void:
	if _animator == null: return
	var clip_name := "ramp_deploy" if _mechanism == "unloading" else "door_close" if _mechanism == "closed" else _mechanism
	var chosen: StringName = &""
	for name: StringName in _animator.get_animation_list():
		if str(name).get_file() == clip_name: chosen = name; break
	if chosen.is_empty(): return
	if _animator.current_animation != chosen: _animator.play(chosen)
	var seconds: float = maxf(0.0,float(_receiving._time)-_mechanism_started)
	if _mechanism in ["unloading","closed"]: seconds = _animator.get_animation(chosen).length
	_animator.seek(minf(seconds,_animator.get_animation(chosen).length),true,true)

func sync_speed() -> void:
	var speed := float(_model.speed)
	for rack: Node3D in _racks.values():
		if rack is ShelfView: (rack as ShelfView).sync_speed()
	if _driver != null and not is_equal_approx(speed,_driver_speed):
		_driver_speed = speed
		_driver.sync_speed()
	if _exhaust != null:
		_exhaust.speed_scale = speed
		_exhaust.emitting = _moving and speed > 0.0
	set_process(speed > 0.0 and (_moving or _mechanism in ["door_open","ramp_deploy","ramp_stow","door_close"] or absf(_pitch_target)+absf(_pivot.rotation.x)+absf(_pivot.rotation.z)>0.0001))

func _process(delta: float) -> void:
	# Only active cosmetic work runs here; no source/worker/route inspection.
	_sync_mechanism()
	var weight := 1.0-exp(-7.0*delta*float(_model.speed))
	_pivot.rotation.x = lerpf(_pivot.rotation.x,_pitch_target,weight)
	_pivot.rotation.z = lerpf(_pivot.rotation.z,_roll_target,weight)
	_pitch_target = lerpf(_pitch_target,0.0,1.0-exp(-3.0*delta*float(_model.speed)))
	sync_speed()

func _create_exhaust() -> void:
	var marker := _art.find_child("Exhaust_Emitter",true,false) as Node3D
	if marker == null: return
	_exhaust = CPUParticles3D.new()
	_exhaust.amount = 8
	_exhaust.lifetime = 0.7
	_exhaust.direction = Vector3.UP
	_exhaust.gravity = Vector3(0,0.5,0)
	_exhaust.initial_velocity_min = 0.3
	_exhaust.initial_velocity_max = 0.6
	_exhaust.scale_amount_min = 0.6
	_exhaust.scale_amount_max = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3,0.32,0.31,0.4)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	_exhaust.mesh = mesh
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.45,0.45,0.45,0.4),Color(0.6,0.6,0.6,0)])
	_exhaust.color_ramp = gradient
	marker.add_child(_exhaust)
