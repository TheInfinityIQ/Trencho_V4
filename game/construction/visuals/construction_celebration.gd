extends Node3D
## Finite cosmetic bodies/tweens. Nothing here changes stock, routes or capability.
signal cleared
const COSMETIC_GROUND := 1 << 20
const ART := "res://game/construction/assets/"
const EMERGENCE_SECONDS := 1.5
const CUT_SECONDS := 2.0
const AUTHORED_SNIP_SECONDS := 0.4
var simulation: RefCounted
var footprint := Vector2.ONE
var _pylons: Array[Node3D] = []
var _scissors: Array[Node3D] = []
var _scissor_materials: Array = []
var _smoke: Array[Node3D] = []
var _smoke_materials: Array = []
var _players: Array[AnimationPlayer] = []
var _tweens: Array[Tween] = []
var _bodies: Array[RigidBody3D] = []
var _ground: StaticBody3D
var _landed: Dictionary = {}
var _released := false
var _started := false
var _cleaning := false
var _speed := 1.0
var _palette: Dictionary = {}

func _ready() -> void:
	_speed = float(simulation.speed)
	var extent := footprint/2.0+Vector2(0.6,0.6)
	var corners: Array[Vector3] = [Vector3(-extent.x,0,-extent.y),Vector3(extent.x,0,-extent.y),Vector3(extent.x,0,extent.y),Vector3(-extent.x,0,extent.y)]
	_ground = StaticBody3D.new()
	_ground.collision_layer = COSMETIC_GROUND
	_ground.collision_mask = 0
	add_child(_ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(footprint.x+5,0.1,footprint.y+5)
	shape.shape = box
	shape.position.y = -0.05
	_ground.add_child(shape)
	for index in 4:
		var pylon := _prop("pylon.glb")
		pylon.position = corners[index]
		_pylons.append(pylon)
		var start: Vector3 = corners[index]+Vector3.UP*0.72
		var end: Vector3 = corners[(index+1)%4]+Vector3.UP*0.72
		_span(start,end,index)
		var scissors := _prop("scissors.glb")
		scissors.scale = Vector3.ONE*3.0
		scissors.position = (start+end)/2.0
		scissors.rotation.y = atan2(-(end-start).z,(end-start).x)
		var cut := scissors.find_child("Cut_Target",true,false) as Node3D
		assert(cut != null,"Artist scissors require Cut_Target")
		# Align the blade contact, not the hinge, with the actual tape midpoint.
		scissors.position -= to_local(cut.global_position)-scissors.position
		# Zero-alpha meshes remain submitted while unfinished, so OpenGL sees
		# their real skin/fade variant before the completion frame.
		_scissors.append(scissors)
		_scissor_materials.append(_fade_materials(scissors))
		var players := scissors.find_children("*","AnimationPlayer",true,false)
		assert(not players.is_empty(),"Artist scissors require authored clips")
		_players.append(players[0] as AnimationPlayer)
		var puff := _prop("smoke.glb")
		puff.position = scissors.position+Vector3.UP*0.04
		for mesh: MeshInstance3D in _meshes(puff): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smoke.append(puff)
		_smoke_materials.append(_fade_materials(puff))

func _prop(file: String) -> Node3D:
	var scene := load(ART+file) as PackedScene
	assert(scene != null,"Missing Artist construction prop: "+file)
	var node := scene.instantiate() as Node3D
	add_child(node)
	for child: Node in _meshes(node):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null: continue
			var key: int = original.get_instance_id()
			if not _palette.has(key):
				var material := original.duplicate() as BaseMaterial3D
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				_palette[key] = material
			mesh.set_surface_override_material(surface,_palette[key])
	return node

func _meshes(node: Node3D) -> Array[Node]:
	var meshes: Array[Node] = node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: meshes.push_front(node)
	return meshes

func _fade_materials(node: Node3D) -> Array:
	var materials: Array = []
	for child: Node in _meshes(node):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null: continue
			var material := original.duplicate() as BaseMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.vertex_color_use_as_albedo = true
			mesh.set_surface_override_material(surface,material)
			materials.append(material)
	_opacity(0.0,materials)
	return materials

func _opacity(value: float, materials: Array) -> void:
	for material: BaseMaterial3D in materials:
		var color := material.albedo_color
		color.a = value
		material.albedo_color = color

func _span(start: Vector3, end: Vector3, side: int) -> void:
	var delta := end-start
	var length := delta.length()/4.0
	for half in 2:
		var previous: RigidBody3D
		for segment in 2:
			var part := half*2+segment
			var body := RigidBody3D.new()
			body.freeze = true
			body.mass = 0.03
			body.collision_layer = 0
			body.collision_mask = COSMETIC_GROUND
			body.contact_monitor = true
			body.max_contacts_reported = 4
			body.linear_damp = 0.0
			body.angular_damp = 0.1
			body.position = start+delta*(float(part)+0.5)/4.0
			body.rotation.y = atan2(-delta.z,delta.x)
			add_child(body)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(length,0.08,0.018)
			collision.shape = shape
			body.add_child(collision)
			var ribbon := _prop("tape_half.glb")
			remove_child(ribbon)
			body.add_child(ribbon)
			ribbon.scale.x = length/0.5
			ribbon.position.x = -length/2.0
			body.body_entered.connect(_ground_contact.bind(side*2+half))
			_bodies.append(body)
			if previous != null:
				var joint := PinJoint3D.new()
				joint.position = start+delta*float(part)/4.0
				add_child(joint)
				joint.node_a = joint.get_path_to(previous)
				joint.node_b = joint.get_path_to(body)
			previous = body

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	tween.set_speed_scale(maxf(_speed,0.01))
	if _speed == 0: tween.pause()
	# Bounded to this short sequence; retaining finished entries until teardown
	# avoids a closure that captures its own RefCounted tween on cancellation.
	return tween

func start() -> void:
	if _started: return
	_started = true
	for index in _scissors.size():
		_play_clip(_players[index],"open_idle")
		_players[index].advance(0.0)
		var node: Node3D = _scissors[index]
		var target := node.position
		node.position = target+Vector3(0.8,1.6,0.8)
		node.show()
		var swoop := _track(create_tween())
		swoop.set_parallel(true)
		swoop.tween_method(_opacity.bind(_scissor_materials[index]),0.0,1.0,0.5).set_delay(1.0)
		swoop.tween_property(node,"position",target+Vector3(0.2,0.55,0.2),0.75).set_trans(Tween.TRANS_SINE)
		swoop.tween_property(node,"position",target,0.75).from(target+Vector3(0.2,0.55,0.2)).set_delay(0.75).set_trans(Tween.TRANS_SINE)
		var puff: Node3D = _smoke[index]
		puff.scale = Vector3.ONE*0.15
		var cloud := _track(create_tween())
		cloud.set_parallel(true)
		cloud.tween_property(puff,"scale",Vector3.ONE*1.1,EMERGENCE_SECONDS).set_trans(Tween.TRANS_SINE)
		cloud.tween_method(_opacity.bind(_smoke_materials[index]),0.0,0.85,0.2)
		cloud.tween_method(_opacity.bind(_smoke_materials[index]),0.85,0.0,0.5).set_delay(1.0)
	var sequence := _track(create_tween())
	sequence.tween_interval(EMERGENCE_SECONDS)
	sequence.tween_callback(_snip)
	sequence.tween_interval(CUT_SECONDS)
	sequence.tween_callback(_release_tape)
	sequence.tween_callback(_fade_scissors)

func _snip() -> void:
	for player: AnimationPlayer in _players:
		_play_clip(player,"snip")

func _play_clip(player: AnimationPlayer, name: String) -> void:
	for clip: StringName in player.get_animation_list():
		if str(clip).get_file().to_lower() == name:
			player.play(clip)
			var rate: float = AUTHORED_SNIP_SECONDS/CUT_SECONDS if name == "snip" else 1.0
			player.set_meta("clip_rate",rate)
			player.speed_scale = _speed*rate
			return
	assert(false,"Missing Artist scissors clip: "+name)

func _release_tape() -> void:
	_released = true
	for index in _bodies.size():
		var body: RigidBody3D = _bodies[index]
		body.gravity_scale = _speed*_speed
		body.freeze = _speed == 0
		# A small cut recoil lets the jointed ribbon fold rather than translating
		# as a perfectly balanced rigid plank. Native gravity/contact own the fall.
		body.angular_velocity = body.global_basis.z*(0.35 if index%2 == 0 else -0.35)*_speed

func _fade_scissors() -> void:
	for materials: Array in _scissor_materials:
		_track(create_tween()).tween_method(_opacity.bind(materials),1.0,0.0,0.25)

func _ground_contact(body: Node, half: int) -> void:
	if body != _ground or not _released or _cleaning: return
	_landed[half] = true
	if _landed.size() != 8: return
	_cleaning = true
	for pylon: Node3D in _pylons:
		var pulse := _track(create_tween())
		pulse.tween_property(pylon,"scale",Vector3.ONE*1.12,0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(pylon,"scale",Vector3.ONE*0.001,0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var cleanup := _track(create_tween())
	cleanup.tween_interval(0.75)
	cleanup.tween_callback(func() -> void: cleared.emit(); queue_free())

func sync_speed() -> void:
	var next := float(simulation.speed)
	if next == _speed: return
	for tween: Tween in _tweens:
		if not tween.is_valid(): continue
		if next == 0: tween.pause()
		else: tween.set_speed_scale(next); tween.play()
	for player: AnimationPlayer in _players: player.speed_scale = next*float(player.get_meta("clip_rate",1.0))
	if _released:
		for body: RigidBody3D in _bodies:
			if next == 0:
				body.set_meta("paused_linear",body.linear_velocity/maxf(_speed,0.01))
				body.set_meta("paused_angular",body.angular_velocity/maxf(_speed,0.01))
				body.freeze = true
			else:
				var linear: Vector3 = body.get_meta("paused_linear",Vector3.ZERO) if _speed == 0 else body.linear_velocity/_speed
				var angular: Vector3 = body.get_meta("paused_angular",Vector3.ZERO) if _speed == 0 else body.angular_velocity/_speed
				body.freeze = false
				body.linear_velocity = linear*next
				body.angular_velocity = angular*next
				body.gravity_scale = next*next
	_speed = next
