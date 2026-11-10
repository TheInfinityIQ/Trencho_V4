extends RefCounted
## Reserve distinct physical work points at command boundaries, never per frame.
const GAP := 1.2
const RADIUS := 0.45
const ACCESS_OFFSET := Vector2(0,-3)
var _rear_ref: WeakRef
var _points: Dictionary = {}

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func point(person: String, holder: String, reserve: bool = true, spawn: bool = false) -> Vector2:
	var rear: RefCounted = _rear_ref.get_ref()
	var entity: Dictionary = rear.ledger.inspect_entity(holder,{},false)
	var center: Vector2 = entity.position
	var origin: Vector2 = rear.ledger.inspect_entity(person,{},false).get("position",center)
	if _points.has(holder) and _points[holder].has(person) and _clear(_points[holder][person]) and (spawn or not rear.walk_path(origin,_points[holder][person]).is_empty()):
		return _points[holder][person]
	var occupied: Array[Vector2] = []
	# Retire departed/dead people's reservations only when new space is needed.
	# No recurring scan is attached to movement or animation callbacks.
	var checked: Dictionary = {}
	var stale: Array[String] = []
	for holder_id: String in _points:
		for id: String in _points[holder_id]:
			if checked.has(id): continue
			checked[id] = true
			var status: Dictionary = rear.ledger.inspect_person_status(id)
			if status.is_empty() or float(status.health) <= 0.0 or (status.rear_place != "Occupied" and status.assignment != "Passenger"): stale.append(id)
	for id: String in stale: release(id)
	for row: Dictionary in rear.ledger.rear_worker_views(rear.actors.keys(),rear.PLAYER):
		if row.id != person: occupied.append(row.position)
	for key: String in _points:
		for id: String in _points[key]:
			if id != person: occupied.append(_points[key][id])
	# Four workers fit abreast. Further arrivals use additional clear rows.
	for row in 30:
		for column in [-3.0,-1.0,1.0,3.0,-5.0,5.0,-7.0,7.0]:
			var candidate := center+Vector2(column,ACCESS_OFFSET.y-float(row)*GAP)
			if not _clear(candidate): continue
			var free := true
			for at: Vector2 in occupied:
				if at.distance_squared_to(candidate) < GAP*GAP-0.000001:
					free = false
					break
			if not free: continue
			if not spawn and not person.is_empty() and rear.walk_path(origin,candidate).is_empty(): continue
			if reserve:
				if not _points.has(holder): _points[holder] = {}
				_points[holder][person] = candidate
				rear.ledger.register_handling_point(holder,person,candidate)
			return candidate
	return Vector2.INF

func release(person: String) -> void:
	for holder: String in _points.keys():
		_points[holder].erase(person)
		if _points[holder].is_empty(): _points.erase(holder)
	var rear: RefCounted = _rear_ref.get_ref()
	if rear != null and rear.warehouse != null: rear.warehouse.release_point(person)
	if rear != null: rear.ledger.release_handling_points(person)

func _clear(at: Vector2) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if not Rect2(0,0,240,210).grow(-RADIUS).has_point(at): return false
	if Rect2(rear.SUPPLY_TABLE-Vector2(1.29,0.69),Vector2(2.58,1.38)).grow(RADIUS).has_point(at): return false
	if rear.construction != null:
		if rear.warehouse != null:
			for obstacle: Rect2 in rear.warehouse.obstacles():
				if obstacle.grow(RADIUS).has_point(at): return false
		for site: Dictionary in rear.construction.instances.values():
			if site.kind == "park" or site.state in ["Cancelled","Dismantled"]: continue
			if rear.warehouse != null and rear.warehouse.modules.has(site.id): continue
			if Rect2(site.center-site.size/2.0,site.size).grow(RADIUS).has_point(at): return false
	return true
