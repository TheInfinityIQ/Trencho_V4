extends RefCounted
## Real passenger activities; animation and custody share committed boundaries.
signal changed(person_id: String)
const Seating = preload("res://game/supplier_transport/supplier_seating.gd")
const PATHS := "res://game/supplier_transport/assets/passenger_paths_v02.json"
static var _paths: Dictionary = {}
var rows: Dictionary = {}
var _owner: WeakRef
var _waiting: Dictionary = {}

func _init(receiving: RefCounted) -> void:
	_owner = weakref(receiving)
	if _paths.is_empty():
		_paths = JSON.parse_string(FileAccess.get_file_as_string(PATHS)).seats
	receiving.ledger.entity_moved.connect(_access_changed)

func register(order: Dictionary) -> void:
	for id: String in order.aboard_people:
		var index: int = int(order.aboard_people[id])
		var seat := "%s%02d" % ["Left" if index < 4 else "Right",index%4+1]
		rows[id] = {"id":id,"order":order,"phases":_paths[seat],"index":0,"started":float(_owner.get_ref()._time),"duration":2.0,"walk":{}}
		changed.emit(id)

func begin(order: Dictionary) -> void:
	order.exit_active = ""
	for id: String in order.aboard_people: _phase(rows[id],1)
	order.next_at = float(_owner.get_ref()._time)+1.0

func settle(order: Dictionary) -> void:
	var active: String = str(order.get("exit_active",""))
	if not active.is_empty():
		var row: Dictionary = rows[active]
		var index: int = int(row.index)
		if index == 8:
			# End of flight: the same actual passenger reaches ground. Workforce
			# admission still waits for the independent walk to Personnel.
			var receiving: RefCounted = _owner.get_ref()
			var at := pose(active).origin
			receiving._must(receiving.ledger.move_entity(active,"rear-lane",Vector2(at.x,at.z)))
			order.aboard_people.erase(active)
			order.people_exited += 1
		if index == 10:
			_start_arrival(row)
			order.exit_active = ""
			_next(order)
			return
		_phase(row,index+1)
		order.next_at = float(row.started)+float(row.duration)
		return
	for id: String in order.aboard_people:
		if int(rows[id].index) == 1: _phase(rows[id],2)
	_next(order)

func _next(order: Dictionary) -> void:
	var receiving: RefCounted = _owner.get_ref()
	for seat_index: int in Seating.EXIT_ORDER:
		if seat_index >= order.passenger_ids.size(): continue
		var id: String = str(order.passenger_ids[seat_index])
		if not order.aboard_people.has(id): continue
		var destination: Vector2 = receiving.work_point.call(id,"personnel") if receiving.work_point.is_valid() else receiving.personnel_position
		var last: Array = rows[id].phases[10].samples[-1].godot_xyz
		var clear: Vector3 = frame(order)*Vector3(float(last[0]),float(last[1]),float(last[2]))
		var path: Array = receiving._worker_path(Vector2(clear.x,clear.z),destination) if destination.is_finite() else []
		if path.is_empty():
			_waiting[order.id] = order
			order.next_at = INF
			return
		_waiting.erase(order.id)
		rows[id].arrival_path = path
		order.exit_active = id
		_phase(rows[id],3)
		order.next_at = float(rows[id].started)+float(rows[id].duration)
		return
	_waiting.erase(order.id)
	order.next_at = INF
	order.rear_cleared = true

func _phase(row: Dictionary, index: int) -> void:
	row.index = index
	row.started = float(_owner.get_ref()._time)
	row.duration = float(row.phases[index].samples[-1].seconds)
	changed.emit(str(row.id))

func _start_arrival(row: Dictionary) -> void:
	var receiving: RefCounted = _owner.get_ref()
	var path: Array = row.arrival_path
	row.walk = {"order_id":row.order.id,"person_id":row.id,"path":path,"started_at":receiving._time,"ends_at":float(receiving._time)+maxf(0.001,receiving._path_length(path)/1.5)}
	receiving._walks.append(row.walk)
	row.index = 11
	row.started = float(receiving._time)
	row.duration = 2.0/3.0
	changed.emit(str(row.id))

func finish(id: String) -> void:
	if not rows.has(id): return
	rows.erase(id)
	changed.emit(id)

func debug_clear(order: Dictionary) -> void:
	_waiting.erase(order.id)
	for id: String in order.passenger_ids: finish(id)
	order.exit_active = ""
	order.rear_cleared = true

func advance_poses() -> void:
	var receiving: RefCounted = _owner.get_ref()
	for id: String in rows:
		var row: Dictionary = rows[id]
		# Transit occupants move with their hull; standing/exit roots need actual
		# planar positions as well as the read-only visual support height.
		if int(row.index) < 3 or int(row.index) == 11: continue
		var at := pose(id).origin
		if row.order.aboard_people.has(id):
			receiving._must(receiving.ledger.position_supplier_occupant(id,str(row.order.id),Vector2(at.x,at.z)))
		else: receiving._must(receiving.ledger.move_entity(id,"rear-lane",Vector2(at.x,at.z)))

func pose(id: String, attached_frame: Transform3D = Transform3D.IDENTITY) -> Transform3D:
	var row: Dictionary = rows[id]
	var receiving: RefCounted = _owner.get_ref()
	if int(row.index) == 11:
		var at: Vector2 = receiving._motion_position(row.walk)
		var path: Array = row.walk.path
		var direction: Vector2 = Vector2(path[-1])-at
		if direction.is_zero_approx(): direction = Vector2(path[-1])-Vector2(path[maxi(0,path.size()-2)])
		return Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.y)),Vector3(at.x,0,at.y))
	var samples: Array = row.phases[int(row.index)].samples
	var seconds := maxf(0.0,float(receiving._time)-float(row.started))
	if int(row.index) in [0,2]: seconds = fposmod(seconds,float(row.duration))
	seconds = minf(seconds,float(row.duration))
	var index := mini(int(floor(seconds*30.0)),samples.size()-2)
	var a: Dictionary = samples[index]
	var b: Dictionary = samples[index+1]
	var weight := clampf((seconds-float(a.seconds))/(float(b.seconds)-float(a.seconds)),0.0,1.0)
	var x: Array = a.godot_xyz
	var y: Array = b.godot_xyz
	var at := Vector3(float(x[0]),float(x[1]),float(x[2])).lerp(Vector3(float(y[0]),float(y[1]),float(y[2])),weight)
	var yaw := lerpf(float(a.actor_yaw_unwrapped),float(b.actor_yaw_unwrapped),weight)+PI
	var base := frame(row.order)
	if attached_frame != Transform3D.IDENTITY and int(row.index) < 8:
		base = attached_frame*Transform3D(Basis.IDENTITY,Vector3(0,-1,0))
	return base*Transform3D(Basis(Vector3.UP,yaw),at)

static func frame(order: Dictionary) -> Transform3D:
	var at: Vector2 = order.world_position
	return Transform3D(Basis(Vector3.UP,-PI/2.0-deg_to_rad(float(order.get("facing_degrees",0.0)))),Vector3(at.x,0,at.y))

func _access_changed(_id: String, _from: Vector2, _to: Vector2) -> void:
	# Only blocked access listens for clearance; no periodic standing-point probe.
	for order: Dictionary in _waiting.values(): order.next_at = float(_owner.get_ref()._time)
