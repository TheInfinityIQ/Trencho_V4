extends RefCounted
## Plan one measured supplier-to-rack action before reserving/lifting cargo.
const GroundPath = preload("res://game/supplier_transport/paired_ground_path.gd")
const Road = preload("res://game/supplier_transport/supplier_road.gd")
const EPS := 0.0001
var _rear_ref: WeakRef
var _motion: RefCounted
var _ground := GroundPath.new()
var _boxes: Array[Rect2] = []
var _bounds := Rect2()
var _commands: Array[Dictionary] = []
var _current: Dictionary = {}
var _radius := INF

func _init(rear: RefCounted, motion: RefCounted) -> void:
	_rear_ref = weakref(rear)
	_motion = motion

func build(order: Dictionary, packet: Dictionary, bay: Dictionary, cell: Dictionary, people: Array) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	_commands.clear()
	_current.clear()
	_radius = float(_motion.turn_radius())
	if not _motion.valid() or not is_finite(_radius): return {}
	_boxes = _obstacles(bay,people)
	_bounds = rear.construction._access_bounds(0.0)
	var truck := Transform3D(Basis(Vector3.UP,deg_to_rad(-90.0-float(order.get("facing_degrees",0.0)))),Vector3(order.world_position.x,0,order.world_position.y))
	var pickup := "pickup_upper" if packet.support == "deck-01" else "pickup_lower"
	if not _append_clip(pickup,truck): return {}
	var pickup_pose: Dictionary = pose(_commands[0],0.0)
	if not _append_aligned("shoulder_transition"): return {}
	if not _append_clip("ramp",truck): return {}
	_commands.back().clear_source = true
	var ramp_pose: Dictionary = _current.duplicate()
	var prefix: Array[Dictionary] = _commands.duplicate()
	var rack := Transform3D(Basis(Vector3.UP,-float(bay.rotation)),Vector3(bay.center.x,0,bay.center.y))
	if float(cell.offset.z) > 0.0: rack = rack*Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)
	var deposit := "deposit_upper" if float(cell.offset.y) > 1.0 else "deposit_lower"
	if not _motion.clips.has(deposit): return {}
	var destination: Dictionary = _world(_motion.sample(deposit,0.0),rack)
	var last: Dictionary = _world(_motion.sample(deposit,float(_motion.clips[deposit].duration_s)),rack)
	var fore_direction: Vector2 = _direction(destination)
	var outward3: Vector3 = rack.basis*Vector3(0,0,-1)
	var module: Dictionary = rear.warehouse.modules[bay.module]
	# Central staging stays in the aisle. The first checkpoint uses forward
	# approaches only; never promise an unreachable opposite rack face.
	var release_end: Vector3 = Vector3(bay.center.x,0,bay.center.y)+outward3*(rear.warehouse.ROW_PITCH/2.0)
	var release: Dictionary = _motion.sample("shoulder_release",float(_motion.clips.shoulder_release.duration_s))
	var release_stage: Transform3D = _align(release,release_end,fore_direction)
	var release_first: Dictionary = _world(_motion.sample("shoulder_release",0.0),release_stage)
	var bank_goal: Vector2 = _anchor(release_first)
	var lateral3: Vector3 = rack.basis*Vector3.RIGHT
	var lateral := Vector2(lateral3.x,lateral3.z)
	var central: Vector2 = bank_goal-lateral*(bank_goal-Vector2(module.center)).dot(lateral)
	var bank_delta := bank_goal-central
	if bank_delta.length() < EPS or bank_delta.normalized().dot(fore_direction) < 0.999: return {}
	var own_fixture: Rect2 = rear.warehouse.fixture_bounds(bay)
	for door: Vector2 in rear.warehouse.exterior_doors(str(bay.module)):
		_commands = prefix.duplicate()
		_current = ramp_pose.duplicate()
		var entrance_out := (door-Vector2(module.center)).normalized()
		var outside: Vector2 = door+entrance_out*_radius
		if absf((central-outside).cross(entrance_out)) > EPS: continue
		var turn_shape: Array[Rect2] = [Rect2(-Vector2.ONE*_radius,Vector2.ONE*_radius*2.0)]
		# This action needs its truck-to-door corridor, not a field-sized graph.
		var search: Rect2 = Rect2(_anchor(_current),Vector2.ZERO).expand(outside).grow(4.0+2.0*_radius).intersection(_bounds)
		var route: Array = _ground.find(_anchor(_current),outside,turn_shape,_boxes,search)
		if route.is_empty(): continue
		var possible := true
		for index in range(1,route.size()):
			var target: Vector2 = route[index]
			var delta: Vector2 = target-_anchor(_current)
			if delta.length() <= EPS: continue
			if not _turn_to(delta.normalized()) or not _ground_leg("shoulder",target):
				possible = false
				break
		if not possible or not _turn_to(-entrance_out): continue
		if not _ground_leg("shoulder",central) or not _turn_to(fore_direction): continue
		if not _ground_leg("shoulder",bank_goal): continue
		if not _append_clip("shoulder_release",release_stage): continue
		if not _ground_leg("underhand",_anchor(destination),own_fixture): continue
		if not _append_clip(deposit,rack): continue
		_commands.back().warehouse_finish = true
		return {"commands":_commands.duplicate(),"pickup":pickup_pose,"stations":[_planar(last.FORE.origin),_planar(last.AFT.origin)],"bay":bay.id,"deposit":deposit}
	return {}

func pose(command: Dictionary, elapsed: float) -> Dictionary:
	var time := clampf(elapsed,0.0,float(command.duration))
	if not bool(command.get("loop",false)): time += float(command.get("from",0.0))
	var result: Dictionary = _world(_motion.sample(str(command.name),time),command.stage)
	if command.has("goal"):
		var progress := clampf(elapsed/float(command.duration),0.0,1.0)
		var wanted: Vector2 = Vector2(command.origin).lerp(command.goal,progress)
		var correction := wanted-_anchor(result)
		for key: String in ["FORE","AFT","payload"]:
			var transform: Transform3D = result[key]
			transform.origin += Vector3(correction.x,0,correction.y)
			result[key] = transform
	return result

func _append_clip(name: String, stage: Transform3D, first: float = 0.0, last: float = -1.0) -> bool:
	if not _motion.clips.has(name): return false
	var end: float = float(_motion.clips[name].duration_s) if last < 0.0 else last
	if end <= first: return false
	var row := {"name":name,"stage":stage,"duration":end-first,"from":first,"to":end,"loop":false}
	_commands.append(row)
	_current = pose(row,float(row.duration))
	return true

func _append_aligned(name: String, first: float = 0.0, last: float = -1.0) -> bool:
	var start: Dictionary = _motion.sample(name,first)
	if start.is_empty() or _current.is_empty(): return false
	return _append_clip(name,_align(start,_center3(_current),_direction(_current)),first,last)

func _ground_leg(kind: String, target: Vector2, interaction_fixture: Rect2 = Rect2()) -> bool:
	var origin: Vector2 = _anchor(_current)
	if origin.distance_to(target) <= EPS: return true
	var name := kind+"_walk_loop"
	var start: Dictionary = _motion.sample(name,0.0)
	if start.is_empty(): return false
	var stage: Transform3D = _align(start,_center3(_current),_direction(_current))
	var raw: Array = _motion.clips[name].cycle_translation_godot_m
	var step: Vector3 = stage.basis*Vector3(raw[0],raw[1],raw[2])
	var direction := Vector2(step.x,step.z).normalized()
	if direction.dot((target-origin).normalized()) < 0.999: return false
	var shapes: Array[Rect2] = _rotate_shapes(_motion.footprints(name),stage.basis)
	if not _segment_clear(origin,target,shapes,interaction_fixture): return false
	var take := "shoulder_ground_travel" if kind == "shoulder" else "underhand_walk"
	var marks: Dictionary = _motion.clips[take].contact_landmarks
	var settle: Array = marks.settle_s
	var stand: Array = marks.stand_s
	if not _append_aligned(take,float(settle[0]),float(settle[1])): return false
	origin = _anchor(_current)
	stage = _align(start,_center3(_current),_direction(_current))
	var speed := Vector2(step.x,step.z).length()/float(_motion.clips[name].duration_s)
	if speed <= 0.0: return false
	var row := {"name":name,"stage":stage,"duration":origin.distance_to(target)/speed,"from":0.0,"to":float(_motion.clips[name].duration_s),"loop":true,"origin":origin,"goal":target}
	_commands.append(row)
	_current = pose(row,float(row.duration))
	return _append_aligned(take,float(stand[0]),float(stand[1]))

func _turn_to(direction: Vector2) -> bool:
	for _step in 2:
		var current := _direction(_current)
		var difference := angle_difference(atan2(current.x,current.y),atan2(direction.x,direction.y))
		if absf(difference) < EPS: return true
		if absf(absf(difference)-PI/2.0) > EPS and absf(absf(difference)-PI) > EPS: return false
		var shape: Array[Rect2] = [Rect2(-Vector2.ONE*_radius,Vector2.ONE*_radius*2.0)]
		if not _segment_clear(_anchor(_current),_anchor(_current),shape): return false
		if not _append_aligned("turn_right" if difference > 0.0 else "turn_left"): return false
	return _direction(_current).dot(direction) > 0.999

func _segment_clear(start: Vector2, finish: Vector2, shapes: Array[Rect2], interaction_fixture: Rect2 = Rect2()) -> bool:
	for shape: Rect2 in shapes:
		var swept := Rect2(start+shape.position,shape.size).merge(Rect2(finish+shape.position,shape.size))
		if not _bounds.encloses(swept): return false
		for box: Rect2 in _boxes:
			# Only the final straight, source-fitted rack engagement may reach
			# its opening. Other fixtures/walls/people remain obstacles.
			if interaction_fixture.has_area() and box == interaction_fixture: continue
			if box.intersects(swept): return false
	return true

func _obstacles(bay: Dictionary, people: Array) -> Array[Rect2]:
	var rear: RefCounted = _rear_ref.get_ref()
	var boxes: Array[Rect2] = rear.warehouse.obstacles().duplicate()
	for row: Dictionary in rear.construction.instances.values():
		if row.kind == "park" or row.state in ["Cancelled","Dismantled"] or rear.warehouse.modules.has(row.id): continue
		boxes.append(Rect2(row.center-row.size/2.0,row.size))
	boxes.append(Rect2(rear.SUPPLY_TABLE-Vector2(1.29,0.69),Vector2(2.58,1.38)))
	var candidate: Rect2 = rear.warehouse.fixture_bounds(bay)
	if candidate not in boxes: boxes.append(candidate)
	for row: Dictionary in rear.ledger.rear_worker_views(rear.actors.keys(),rear.PLAYER):
		if row.id not in people: boxes.append(Rect2(row.position-Vector2.ONE*0.25,Vector2.ONE*0.5))
	for supplier: Dictionary in rear.receiving._active_suppliers.values():
		boxes.append(Rect2(Vector2(supplier.world_position)-Vector2.ONE*Road.RADIUS,Vector2.ONE*Road.RADIUS*2.0))
	return boxes

static func _world(value: Dictionary, stage: Transform3D) -> Dictionary:
	if value.is_empty(): return {}
	return {"FORE":stage*value.FORE,"AFT":stage*value.AFT,"payload":stage*value.payload}

static func _align(source: Dictionary, center: Vector3, direction: Vector2) -> Transform3D:
	var axis: Vector2 = _direction(source)
	var rotation := Basis(Vector3.UP,atan2(direction.x,direction.y)-atan2(axis.x,axis.y))
	return Transform3D(rotation,center-rotation*_center3(source))

static func _center3(value: Dictionary) -> Vector3:
	return (value.FORE.origin+value.AFT.origin)*0.5

static func _anchor(value: Dictionary) -> Vector2:
	return _planar(_center3(value))

static func _direction(value: Dictionary) -> Vector2:
	return _planar(value.FORE.origin-value.AFT.origin).normalized()

static func _planar(value: Vector3) -> Vector2:
	return Vector2(value.x,value.z)

static func _rotate_shapes(shapes: Array, rotation: Basis) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for shape: Rect2 in shapes:
		var points: Array[Vector2] = [shape.position,Vector2(shape.end.x,shape.position.y),shape.end,Vector2(shape.position.x,shape.end.y)]
		var box := Rect2()
		for index in points.size():
			var point: Vector3 = rotation*Vector3(points[index].x,0,points[index].y)
			if index == 0: box = Rect2(_planar(point),Vector2.ZERO)
			else: box = box.expand(_planar(point))
		result.append(box)
	return result
