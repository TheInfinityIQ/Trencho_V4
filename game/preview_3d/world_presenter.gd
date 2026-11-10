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
const UtilityTrucks = preload("res://game/preview_3d/utility_trucks.gd")
const RearT01Trucks = preload("res://game/preview_3d/rear_t01_trucks.gd")
const FieldPersons = preload("res://game/preview_3d/field_persons.gd")
const FieldT01Trucks = preload("res://game/preview_3d/field_t01_trucks.gd")
const FieldObjectives = preload("res://game/preview_3d/field_objectives.gd")
const Policy = preload("res://game/battlefield/battlefield_presentation.gd")
const FacilityShells = preload("res://game/preview_3d/facility_shells.gd")
const ConstructionSiteVisual = preload("res://game/construction/visuals/construction_site_visual.gd")
const Farmland = preload("res://game/battlefield/farmland_scenario.gd")
const PersonalPickup = preload("res://game/player_vehicle/player_pickup.gd")
var personal_pickup: PersonalPickup
var rear_workers: RearWorkers = RearWorkers.new()
var utility_trucks: UtilityTrucks = UtilityTrucks.new()
var rear_t01_trucks: RearT01Trucks = RearT01Trucks.new()
var field_persons: FieldPersons = FieldPersons.new()
var field_t01_trucks: FieldT01Trucks = FieldT01Trucks.new()
var field_objectives: FieldObjectives = FieldObjectives.new()
var rear_root := Node3D.new()
var field_root := Node3D.new()
var player := CharacterBody3D.new()
var manager_collision: CollisionShape3D
var player_visual: Node3D
var eye := Node3D.new()
var arm := SpringArm3D.new()
var first := PlacementCamera.new()
var third := PlacementCamera.new()
var rts := PlacementCamera.new()
var build_camera := PlacementCamera.new()
var build_grid := MeshInstance3D.new()
var supplier_convoys := preload("res://game/preview_3d/supplier_convoys.gd").new()
var footprint: MeshInstance3D
var door: MeshInstance3D
var stock_label: Label3D
var stock_visuals: Array[Node3D] = []
var rear_ground: StaticBody3D
var supply_table_body: StaticBody3D
var simulation: RefCounted
var markers: Dictionary = {}
var marker_rows: Array[Dictionary] = []
var _proxy_rows: Array[Dictionary] = []
var _markers_root := Node3D.new()
var _collision_root := Node3D.new()
var _site_snapshot: Dictionary = {}
var _site_visuals: Dictionary = {}
var _facility_shells: RefCounted = FacilityShells.new()
var _character_speed := -1

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
	for edge in [Vector3(-0.5,1,105),Vector3(240.5,1,105)]:
		_box(rear_root,edge,Vector3(1,2,212),Color("59664e"),true)
	for edge in [Vector3(120,1,-0.5),Vector3(120,1,210.5)]:
		_box(rear_root,edge,Vector3(240,2,1),Color("59664e"),true)
	# Prebuilt service strip is outside construction bounds, with an open rear edge.
	_box(rear_root,Vector3(120,-0.25,195),Vector3(240,0.5,30),Color("8a8d7c"),true)
	_box(rear_root,Vector3(120,0.01,200),Vector3(288,0.02,8),Color("42494a"))
	for x in range(-12,253,12): _box(rear_root,Vector3(x,0.025,200),Vector3(5,0.02,0.15),Color("dfd4a7"))
	_box(rear_root,Vector3(120,0.02,190),Vector3(18,0.03,12),Color("b8b19a"))
	_label(rear_root,"PREBUILT UNLOADING APRON",Vector3(120,3.5,193),0.018)
	var table_at: Vector2 = model.receiving.receiving_position
	var table := _asset("supply_table.glb",1.0)
	rear_root.add_child(table)
	table.position = Vector3(table_at.x,0,table_at.y)
	var table_volume: MeshInstance3D = _box(rear_root,Vector3(table_at.x,0.5,table_at.y),Vector3(2.58,1,1.38),Color.TRANSPARENT,true)
	supply_table_body = table_volume.get_child(0) as StaticBody3D
	_label(rear_root,"SUPPLY TABLE / ARRIVAL",Vector3(table_at.x,2.1,table_at.y),0.012)
	for index in 5:
		var stock := _asset("material_box.glb",0.65)
		rear_root.add_child(stock)
		stock_visuals.append(stock)
		stock.position = Vector3(table_at.x-1.4+float(index%3)*0.7,0,table_at.y+2+float(index/3)*0.7)
	stock_label = _label(rear_root,"",Vector3(table_at.x-1,1.4,table_at.y+3),0.009)
	_build_player(pose)
	_build_terrain()
	field_root.add_child(_markers_root)
	_markers_root.add_child(field_persons)
	field_persons.changed.connect(_field_person_changed)
	field_persons.removing.connect(_field_person_removing)
	field_persons.bind(model.rear.ledger,model.rear.PLAYER,model.rear.combat.world.ground,_add_soldier,model)
	_markers_root.add_child(field_objectives)
	field_objectives.changed.connect(_field_objective_changed)
	field_objectives.removing.connect(_field_objective_removing)
	field_objectives.bind(model.rear.combat.world.ground)
	rear_root.add_child(_collision_root)
	footprint = _box(rear_root,Vector3.ZERO,Vector3.ONE,Color(0.3,0.9,0.65,0.45))
	door = _box(rear_root,Vector3.ZERO,Vector3(1.5,0.15,1.5),Color("f4cd7c"))
	clear_preview()
	_build_grid()
	build_camera.position = Vector3(120,240,105)
	build_camera.rotation_degrees = Vector3(-90,0,0)
	build_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	build_camera.size = 210
	build_camera.far = 500
	rear_root.add_child(build_camera)
	rear_root.add_child(supplier_convoys)
	supplier_convoys.bind(model.receiving)
	rts.position = Vector3(2000,3400,4800)
	rts.rotation_degrees = Vector3(-65,0,0)
	rts.projection = Camera3D.PROJECTION_ORTHOGONAL
	rts.size = 6200
	rts.far = 14000
	field_root.add_child(rts)
	refresh_rear()
	rear_workers.name = "RearWorkers"
	rear_root.add_child(rear_workers)
	rear_workers.bind(model,_add_worker)
	utility_trucks.name = "UtilityTrucks"
	rear_root.add_child(utility_trucks)
	utility_trucks.bind(model)
	rear_t01_trucks.name = "RearT01Trucks"
	rear_root.add_child(rear_t01_trucks)
	rear_t01_trucks.bind(model)
	_markers_root.add_child(field_t01_trucks)
	field_t01_trucks.changed.connect(_field_t01_changed)
	field_t01_trucks.removing.connect(_field_t01_removing)
	field_t01_trucks.bind(model.rear.ledger,model.rear.PLAYER,model.rear.combat.world.ground,rear_t01_trucks.release_if_ineligible)

func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
	for x in 241:
		mesh.surface_set_color(Color("b6caa3") if x%5 == 0 else Color("7e9469"))
		mesh.surface_add_vertex(Vector3(x,0.04,0))
		mesh.surface_add_vertex(Vector3(x,0.04,180))
	for z in 181:
		mesh.surface_set_color(Color("b6caa3") if z%5 == 0 else Color("7e9469"))
		mesh.surface_add_vertex(Vector3(0,0.04,z))
		mesh.surface_add_vertex(Vector3(240,0.04,z))
	mesh.surface_end()
	build_grid.mesh = mesh
	build_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rear_root.add_child(build_grid)
	build_grid.hide()

func _build_player(pose: RefCounted) -> void:
	player.name = "Manager"
	player.collision_layer = 2
	player.collision_mask = 9
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
	var identity: Label3D = _label(player_visual,"You\nManager",Vector3(0,2.15,0),0.012)
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

func _add_human(parent: Node3D, animated: bool = true) -> Node3D:
	# Keep the existing manager's import, skin and post-attachment idle binding.
	var visual: Node3D = _asset("manager.fbx",1.8)
	parent.add_child(visual)
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_texture = load("res://game/preview_3d/assets/manager_skin.png")
	skin.roughness = 1.0
	for child: Node in visual.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		mesh.material_override = skin
	if animated: _bind_idle(visual)
	return visual

func _add_worker(parent: Node3D) -> Node3D:
	return _add_character(parent,"worker")

func _add_soldier(parent: Node3D) -> Node3D:
	return _add_character(parent,"soldier")

func _add_character(parent: Node3D, kind: String) -> Node3D:
	var visual: Node3D = (load("res://game/characters/"+kind+".tscn") as PackedScene).instantiate()
	visual.simulation = simulation
	visual.animation_enabled = kind != "soldier"
	parent.add_child(visual)
	return visual

func sync_character_playback() -> void:
	if _character_speed == simulation.speed: return
	_character_speed = simulation.speed
	rear_workers.sync_playback()
	field_persons.sync_playback()
	for visual: Node3D in _site_visuals.values():
		if is_instance_valid(visual): visual.sync_speed()

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
		# Earned work/completion do not change the reserved shape. The keyed
		# site visual already receives those states without rebuilding colliders.
		var geometry_state: String = str(row.state) if row.state in ["Cancelled","Dismantled","Clearing","Dismantling"] else "Reserved"
		next[row.id] = [row.center,row.size,geometry_state,goods,row.kind,row.door,row.quarter_turn]
	if next == _site_snapshot: return false
	_site_snapshot = next
	for id: String in _site_visuals.keys():
		var visual: Node3D = _site_visuals[id]
		if next.has(id) and next[id][2] not in ["Cancelled","Dismantled"] and is_instance_valid(visual) and not visual.is_queued_for_deletion(): continue
		if is_instance_valid(visual):
			_collision_root.remove_child(visual)
			visual.queue_free()
		_site_visuals.erase(id)
	for child in _collision_root.get_children():
		if child.has_meta("persistent_site"): continue
		_collision_root.remove_child(child)
		child.queue_free()
	for row in simulation.rear.construction.instances.values():
		if row.state in ["Cancelled","Dismantled"]:
			if bool(next[row.id][3]):
				_box(_collision_root,Vector3(row.center.x,0.04,row.center.y),Vector3(row.size.x,0.08,row.size.y),Color(0.95,0.7,0.3,0.4))
				_label(_collision_root,"%s · %s · goods await hauling" % [row.id,row.state],Vector3(row.center.x,1.5,row.center.y),0.02)
			continue
		var exterior: Dictionary = _site_visuals[row.id].exterior if _site_visuals.has(row.id) else _facility_shells.build(row,true)
		var reservation: MeshInstance3D = _box(_collision_root,Vector3(row.center.x,1.5,row.center.y),Vector3(row.size.x,3,row.size.y),Color("8a8b7b"),row.kind != "park")
		reservation.set_meta("site_id",str(row.id))
		var label_at: Vector3 = Vector3(row.center.x,4.5,row.center.y)
		var description: String = "provisional volume"
		if exterior.ok:
			reservation.hide() # Existing layer1 ground reservation still blocks walking.
			if not _site_visuals.has(row.id):
				var visual := ConstructionSiteVisual.new()
				visual.simulation = simulation
				visual.site_id = str(row.id)
				visual.exterior = exterior
				visual.footprint = row.size
				visual.position = Vector3(row.center.x,0,row.center.y)
				visual.set_meta("persistent_site",true)
				_site_visuals[row.id] = visual
				_collision_root.add_child(visual)
			else: _site_visuals[row.id].reconcile()
			_mark_facility_approach(row,exterior.entrance)
			continue # The persistent visual owns its progress label and ceremony.
		elif row.state == "Complete":
			description += " · " + str(exterior.reason)
		var site_label: Label3D = _label(_collision_root,"%s · %s · %s" % [row.id,row.state,description],label_at,0.02)
		site_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	return true

func is_supply_table_collider(collider: Node) -> bool:
	return is_instance_valid(collider) and collider == supply_table_body and rear_root.is_ancestor_of(collider)

func site_id_from_collider(collider: Node) -> String:
	if not is_instance_valid(collider) or not _collision_root.is_ancestor_of(collider): return ""
	var cursor: Node = collider
	while cursor != _collision_root:
		if cursor.has_meta("site_id"): return str(cursor.get_meta("site_id"))
		cursor = cursor.get_parent()
	return ""

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
	var people: Dictionary = {}
	var carriers: Dictionary = {}
	var objectives: Dictionary = {}
	for row in marker_rows:
		if row.kind == "PERSON" and row.get("aboard",false): continue
		present[row.id] = true
		if row.kind == "PERSON": people[row.id] = row
		else: people.erase(row.id)
		if row.kind == "CARRIER": carriers[row.id] = row
		if row.kind == "PLACE" and row.has("objective_kind"): objectives[row.id] = row
	field_persons.reconcile(people.values())
	field_t01_trucks.reconcile(carriers.values())
	field_objectives.reconcile(objectives.values())
	_proxy_rows.clear()
	for row in marker_rows:
		if row.kind == "PERSON" or people.has(row.id) or field_t01_trucks.bodies.has(row.id) or field_objectives.anchors.has(row.id): continue
		_proxy_rows.append(row)
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

func _field_person_changed(id: String) -> void:
	var anchor: Node3D = field_persons.anchors[id]
	if markers.has(id) and markers[id] != anchor:
		var old: Node3D = markers[id]
		old.get_parent().remove_child(old)
		old.queue_free()
	markers[id] = anchor

func _field_person_removing(id: String, anchor: Node3D) -> void:
	if markers.get(id) == anchor: markers.erase(id)

func _field_t01_changed(id: String) -> void:
	var body: Node3D = field_t01_trucks.bodies[id]
	if markers.has(id) and markers[id] != body:
		var old: Node3D = markers[id]
		old.get_parent().remove_child(old)
		old.queue_free()
	markers[id] = body

func _field_t01_removing(id: String, body: Node3D) -> void:
	if markers.get(id) == body: markers.erase(id)

func _field_objective_changed(id: String) -> void:
	var anchor: Node3D = field_objectives.anchors[id]
	if markers.has(id) and markers[id] != anchor:
		var old: Node3D = markers[id]
		old.get_parent().remove_child(old)
		old.queue_free()
	markers[id] = anchor

func _field_objective_removing(id: String, anchor: Node3D) -> void:
	if markers.get(id) == anchor: markers.erase(id)

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
	# PERSON poses are affected-event owned. Other cached proxies keep the
	# existing adapter; contacts use reports, never the true enemy ledger pose.
	var rear: RefCounted = simulation.rear
	for row in _proxy_rows:
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
