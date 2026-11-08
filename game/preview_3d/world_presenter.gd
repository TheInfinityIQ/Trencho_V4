extends Node3D
## Temporary ground adapter. Economy, motion and enemy knowledge stay in services.
class PlacementCamera:
	extends Camera3D
	signal pose_changed(camera: Camera3D)
	var _ray_initialized := false
	var _ray_transform := Transform3D.IDENTITY
	var _ray_projection := Projection()
	func _ready() -> void:
		set_notify_transform(true)
	func _notification(what: int) -> void:
		if what != NOTIFICATION_TRANSFORM_CHANGED or not is_inside_tree(): return
		var at := get_camera_transform()
		var ray_projection := get_camera_projection()
		if _ray_initialized and _ray_transform.is_equal_approx(at) and _ray_projection == ray_projection: return
		_ray_initialized = true
		_ray_transform = at
		_ray_projection = ray_projection
		pose_changed.emit(self)

const RearWorkers = preload("res://game/preview_3d/rear_workers.gd")
const Policy = preload("res://game/battlefield/battlefield_presentation.gd")
const FacilityShells = preload("res://game/preview_3d/facility_shells.gd")
const Farmland = preload("res://game/battlefield/farmland_scenario.gd")
var rear_workers: RearWorkers = RearWorkers.new()
var rear_root := Node3D.new()
var field_root := Node3D.new()
var player := CharacterBody3D.new()
var manager_collision: CollisionShape3D
var player_visual: Node3D
var eye := Node3D.new()
var arm := SpringArm3D.new()
var first := PlacementCamera.new()
var third := PlacementCamera.new()
var rts := Camera3D.new()
var footprint: MeshInstance3D
var door: MeshInstance3D
var stock_label: Label3D
var stock_visuals: Array[Node3D] = []
var rear_ground: StaticBody3D
var simulation: RefCounted
var markers: Dictionary = {}
var marker_rows: Array[Dictionary] = []
var _markers_root := Node3D.new()
var _collision_root := Node3D.new()
var _site_snapshot: Dictionary = {}
var _facility_shells: RefCounted = FacilityShells.new()

func build(model: RefCounted, pose: RefCounted) -> void:
	simulation = model
	name = "PreviewWorld"
	add_child(rear_root)
	add_child(field_root)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("9bb6bd")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e0e7dd")
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	# Rear has flat TR01 ground in the accepted normal Farmland opening.
	var ground := _box(rear_root, Vector3(120,-0.25,90), Vector3(240,0.5,180), Color("70815b"), true)
	rear_ground = ground.get_child(0) as StaticBody3D
	for edge in [Vector3(-0.5,1,90),Vector3(240.5,1,90)]:
		_box(rear_root,edge,Vector3(1,2,182),Color("59664e"),true)
	for edge in [Vector3(120,1,-0.5),Vector3(120,1,180.5)]:
		_box(rear_root,edge,Vector3(240,2,1),Color("59664e"),true)
	var table := _asset("supply_table.glb",1.0)
	rear_root.add_child(table)
	table.position = Vector3(10,0,90)
	_box(rear_root,Vector3(10,0.5,90),Vector3(2.58,1,1.38),Color.TRANSPARENT,true)
	_label(rear_root,"SUPPLY TABLE / ARRIVAL",Vector3(10,2.1,90),0.012)
	for index in 5:
		var stock := _asset("material_box.glb",0.65)
		rear_root.add_child(stock)
		stock_visuals.append(stock)
		stock.position = Vector3(8.6+float(index%3)*0.7,0,92+float(index/3)*0.7)
	stock_label = _label(rear_root,"",Vector3(9,1.4,93),0.009)
	_build_player(pose)
	_build_terrain()
	field_root.add_child(_markers_root)
	rear_root.add_child(_collision_root)
	footprint = _box(rear_root,Vector3.ZERO,Vector3.ONE,Color(0.3,0.9,0.65,0.45))
	door = _box(rear_root,Vector3.ZERO,Vector3(1.5,0.15,1.5),Color("f4cd7c"))
	clear_preview()
	rts.position = Vector3(2000,3400,4800)
	rts.rotation_degrees = Vector3(-65,0,0)
	rts.projection = Camera3D.PROJECTION_ORTHOGONAL
	rts.size = 6200
	rts.far = 14000
	field_root.add_child(rts)
	refresh_rear()
	rear_workers.name = "RearWorkers"
	rear_root.add_child(rear_workers)
	rear_workers.bind(model,_add_human)

func _build_player(pose: RefCounted) -> void:
	player.name = "Manager"
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.3
	rear_root.add_child(player)
	player.global_position = pose.scene_position()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	manager_collision = collider
	player_visual = _add_human(player)
	var identity: Label3D = _label(player_visual,"You · controlled manager",Vector3(0,2.15,0),0.012)
	identity.name = "ManagerIdentity"
	identity.modulate = Color("f4cd7c")
	identity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	player.add_child(eye)
	eye.position.y = 1.62
	eye.rotation.x = -0.18
	eye.add_child(first)
	first.near = 0.06
	first.far = 500
	eye.add_child(arm)
	arm.spring_length = 5.5
	arm.margin = 0.2
	arm.collision_mask = 5
	arm.add_excluded_object(player.get_rid())
	arm.add_child(third)
	third.near = 0.15
	third.far = 500
	third.current = true

func _add_human(parent: Node3D) -> Node3D:
	# Keep the existing manager's import, skin and post-attachment idle binding.
	var visual: Node3D = _asset("manager.fbx",1.8)
	parent.add_child(visual)
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_texture = load("res://game/preview_3d/assets/manager_skin.png")
	skin.roughness = 1.0
	for child: Node in visual.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		mesh.material_override = skin
	_bind_idle(visual)
	return visual

func _asset(file: String, height: float) -> Node3D:
	var model: PackedScene = load("res://game/preview_3d/assets/"+file)
	var wrapper := Node3D.new()
	# Keep normalization outside imported nodes and their animation tracks.
	var normalizer := Node3D.new()
	wrapper.add_child(normalizer)
	var instance: Node3D = model.instantiate()
	normalizer.add_child(instance)
	var bounds := AABB()
	var found := false
	for mesh in instance.find_children("*","MeshInstance3D",true,false):
		var transform_to_root := Transform3D.IDENTITY
		var cursor: Node3D = mesh
		while cursor != normalizer:
			transform_to_root = cursor.transform * transform_to_root
			cursor = cursor.get_parent()
		var box: AABB = transform_to_root * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if found and bounds.size.y > 0.00001:
		var factor := height / bounds.size.y
		normalizer.scale = Vector3.ONE*factor
		normalizer.position = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	return wrapper

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, colour: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	if colour.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = dimensions
		collision.shape = box
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func _label(parent: Node3D, value: String, at: Vector3, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.pixel_size = pixels
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _build_terrain() -> void:
	# Split at authoritative parcel edges, so roads/height steps never overlap.
	# This bounded rectangle mesh is not a cell-per-metre node world.
	var world: RefCounted = simulation.rear.combat.world
	var x_edges: Dictionary = {0:true,4000:true}
	var z_edges: Dictionary = {0:true,6000:true}
	for region in world.base_regions:
		x_edges[region.area.position.x] = true
		x_edges[region.area.end.x] = true
		z_edges[region.area.position.y] = true
		z_edges[region.area.end.y] = true
	var xs: Array = x_edges.keys()
	var zs: Array = z_edges.keys()
	xs.sort()
	zs.sort()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in range(zs.size()-1):
		for xi in range(xs.size()-1):
			var a := Vector2(xs[xi],zs[zi])
			var c := Vector2(xs[xi+1],zs[zi+1])
			var tile: Dictionary = world.cell(Vector2i((a+c)/2.0))
			surface.set_color(Color(Farmland.COLOURS.get(tile.terrain,"71875a")))
			# Godot front faces use clockwise winding when seen from above.
			for point in [a,Vector2(c.x,a.y),c,a,c,Vector2(a.x,c.y)]:
				var height: float = float(tile.get("height",0.0))+Vector2(tile.get("gradient",Vector2.ZERO)).dot(point)
				surface.add_vertex(Vector3(point.x,height,point.y))
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material_override = material
	field_root.add_child(mesh)
	for obstacle in world.obstacles:
		var rect: Rect2 = obstacle.rect
		_box(field_root,Vector3(rect.get_center().x,(obstacle.bottom+obstacle.top)/2.0,rect.get_center().y),Vector3(rect.size.x,obstacle.top-obstacle.bottom,rect.size.y),Color("8a8b7b"))

func refresh_rear() -> bool:
	var contents: Dictionary = simulation.rear.ledger.loose_stock_summary("receiving",simulation.rear.PLAYER).contents
	var count: int = int(contents.get("M11",{}).get("quantity",0))
	stock_label.text = "%d M11 · representative bundles" % count
	for index in stock_visuals.size(): stock_visuals[index].visible = index < mini(5,ceili(float(count)/100.0))
	# Committed site geometry only; unrelated economy/combat events must not
	# replace physics bodies or perpetually invalidate a stationary candidate.
	var next: Dictionary = {}
	for row in simulation.rear.construction.instances.values():
		var goods: bool = row.state in ["Cancelled","Dismantled"] and simulation.rear.ledger.loose_stock_mass_at(row.id) > 0.000001
		next[row.id] = [row.center,row.size,row.state,goods,row.kind,row.door,row.quarter_turn]
	if next == _site_snapshot: return false
	_site_snapshot = next
	for child in _collision_root.get_children():
		_collision_root.remove_child(child)
		child.queue_free()
	for row in simulation.rear.construction.instances.values():
		if row.state in ["Cancelled","Dismantled"]:
			if bool(next[row.id][3]):
				_box(_collision_root,Vector3(row.center.x,0.04,row.center.y),Vector3(row.size.x,0.08,row.size.y),Color(0.95,0.7,0.3,0.4))
				_label(_collision_root,"%s · %s · goods await hauling" % [row.id,row.state],Vector3(row.center.x,1.5,row.center.y),0.02)
			continue
		var exterior: Dictionary = _facility_shells.build(row)
		var reservation: MeshInstance3D = _box(_collision_root,Vector3(row.center.x,1.5,row.center.y),Vector3(row.size.x,3,row.size.y),Color("8a8b7b"),true)
		var label_at: Vector3 = Vector3(row.center.x,4.5,row.center.y)
		var description: String = "provisional volume"
		if exterior.ok:
			reservation.hide() # Existing layer1 ground reservation still blocks walking.
			var shell: Node3D = exterior.node
			_collision_root.add_child(shell)
			var label_offset: Vector3 = exterior.label_anchor
			_mark_facility_approach(row,exterior.entrance)
			label_at = shell.position + label_offset
			description = str(row.kind) + " · exterior"
		elif row.state == "Complete":
			description += " · " + str(exterior.reason)
		var site_label: Label3D = _label(_collision_root,"%s · %s · %s" % [row.id,row.state,description],label_at,0.02)
		site_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	return true

func _mark_facility_approach(row: Dictionary, entrance: Vector3) -> void:
	var center: Vector2 = row.center
	var size: Vector2 = row.size
	var colour: Color = Color("b3ae91")
	# Thin edge strips show reserved inset space without implying an interior.
	for side: float in [-1.0,1.0]:
		_box(_collision_root,Vector3(center.x+side*size.x/2.0,0.025,center.y),Vector3(0.12,0.05,size.y),colour)
		_box(_collision_root,Vector3(center.x,0.025,center.y+side*size.y/2.0),Vector3(size.x,0.05,0.12),colour)
	var approach: Vector2 = row.door
	var bend: Vector3 = Vector3(approach.x,0.06,center.y+entrance.z)
	var end: Vector3 = Vector3(center.x+entrance.x,0.06,bend.z)
	var start: Vector3 = Vector3(approach.x,0.06,approach.y)
	_box(_collision_root,(start+bend)/2.0,Vector3(0.6,0.08,maxf(absf(start.z-bend.z),0.6)),Color("d6bd82"))
	_box(_collision_root,(bend+end)/2.0,Vector3(maxf(end.x-bend.x,0.6),0.08,0.6),Color("d6bd82"))
	_box(_collision_root,start,Vector3(1.1,0.12,1.1),Color("f4cd7c"))
	var sign: Label3D = _label(_collision_root,"SERVICE APPROACH",start+Vector3(0,0.8,0),0.008)
	sign.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

func refresh_markers() -> void:
	marker_rows = Policy.markers(simulation.rear)
	var present: Dictionary = {}
	for row in marker_rows:
		if row.kind == "PERSON" and row.get("aboard",false): continue
		present[row.id] = true
		if not markers.has(row.id):
			var colour := Color("e49b73") if row.kind == "CONTACT" else Color("81d1e6")
			if row.kind == "PLACE": colour = row.get("ownership_colour",Color("f0c565"))
			var extent := 22.0 if row.kind == "PLACE" else 10.0
			markers[row.id] = _box(_markers_root,Vector3.ZERO,Vector3(extent,extent,extent),colour)
		var marker: MeshInstance3D = markers[row.id]
		var height: float = simulation.rear.combat.world.ground(row.position)
		marker.position = Vector3(row.position.x,height+15,row.position.y)
		# Only legacy rear carriers use this boundary; keep their proxy cached.
		marker.visible = row.kind != "CARRIER" or row.position.x >= 240
	for id in markers.keys():
		if present.has(id): continue
		markers[id].queue_free()
		markers.erase(id)

func show_preview(plan: Dictionary) -> void:
	var rect: Rect2 = plan.footprint
	footprint.visible = true
	footprint.position = Vector3(rect.get_center().x,0.08,rect.get_center().y)
	footprint.scale = Vector3(rect.size.x,0.1,rect.size.y)
	var colour := Color(1,0.3,0.2,0.45)
	if plan.ok: colour = Color(0.95,0.7,0.3,0.45) if plan.get("provisional",false) else Color(0.3,0.9,0.65,0.45)
	footprint.material_override.albedo_color = colour
	door.visible = plan.has("door")
	if door.visible: door.position = Vector3(plan.door.x,0.12,plan.door.y)

func clear_preview() -> void:
	if footprint != null: footprint.hide()
	if door != null: door.hide()

func move_manager(direction: Vector2, speed: int, pose: RefCounted) -> bool:
	var previous := player.global_position
	player.velocity = player.global_basis.orthonormalized() * Vector3(direction.x,0,direction.y).limit_length()*5.0*float(speed)
	player.velocity.y = -2.0
	player.move_and_slide()
	pose.publish_resolved(player.global_position,player.global_rotation.y)
	return not player.global_position.is_equal_approx(previous)

func refresh_marker_positions() -> void:
	# Cached permitted membership only. Read each friendly holder chain once;
	# contacts retain reported coordinates, never the true enemy ledger pose.
	var rear: RefCounted = simulation.rear
	for row in marker_rows:
		if not markers.has(row.id): continue
		if row.kind == "CONTACT":
			var report: Dictionary = rear.orders.contact("army",row.id)
			if report.is_empty() or report.confidence <= 0:
				markers[row.id].hide()
				continue
			row.position = report.position
		else:
			if rear.ledger.entity_kind(row.id).is_empty():
				markers[row.id].hide()
				continue
			# Temporary direct planar-holder adapter, not a second motion owner.
			row.position = rear.ledger._world_position(row.id)
		markers[row.id].visible = row.kind != "CARRIER" or row.position.x >= 240
		markers[row.id].position = Vector3(row.position.x,rear.combat.world.ground(row.position)+15,row.position.y)

func _bind_idle(visual: Node3D) -> void:
	# Kenney's animation-only FBX has no mesh. Bind its bone tracks to the
	# separately imported character, leaving visual normalization untouched.
	var skeletons := visual.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty():
		push_error("Provisional manager model has no imported skeleton.")
		return
	var target: Skeleton3D = skeletons[0]
	var source_scene: PackedScene = load("res://game/preview_3d/assets/manager_idle.fbx")
	var source: Node3D = source_scene.instantiate()
	var animator := AnimationPlayer.new()
	animator.name = "ManagerIdle"
	animator.root_node = NodePath("..")
	visual.add_child(animator)
	var library := AnimationLibrary.new()
	animator.add_animation_library("idle",library)
	for player_source in source.find_children("*","AnimationPlayer",true,false):
		for clip_name in player_source.get_animation_list():
			# The source also includes 0.Targeting Pose; it is not neutral idle.
			if not str(clip_name).to_lower().ends_with("idle"): continue
			var clip: Animation = player_source.get_animation(clip_name).duplicate(true)
			for index in range(clip.get_track_count()-1,-1,-1):
				var path := clip.track_get_path(index)
				var bone := str(path.get_subname(0)) if path.get_subname_count() > 0 else ""
				if bone.is_empty() or target.find_bone(bone) < 0 or clip.track_get_type(index) not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
					clip.remove_track(index)
					continue
				clip.track_set_path(index,NodePath(str(visual.get_path_to(target))+":"+bone))
			if clip.get_track_count() == 0: continue
			clip.loop_mode = Animation.LOOP_LINEAR
			library.add_animation("standing",clip)
			animator.set_meta("source_clip",str(clip_name))
			animator.play("idle/standing")
			# Apply the neutral pose before the first paused opening is rendered.
			animator.advance(0.0)
			source.free()
			return
	source.free()
	push_error("Provisional idle clip has no matching manager bone tracks.")
