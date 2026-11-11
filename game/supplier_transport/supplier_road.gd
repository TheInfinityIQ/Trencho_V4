extends RefCounted
## Event-woken bounded supplier traffic; Receiving owns committed motion.
const RADIUS := 4.3 # Crew rear reachesZ3.98 from this asymmetric root; include sway.
const GAP := 0.3
const PASS_Y := 212.0
var external: Dictionary = {}
var _dirty := false
var _receiving_ref: WeakRef

func _init(receiving: RefCounted) -> void:
	_receiving_ref = weakref(receiving)
	receiving.ledger.entity_moved.connect(_entity_moved)

func invalidate() -> void:
	_dirty = true

func set_external(id: String, at: Vector2, radius: float) -> void:
	if not at.is_finite() or not is_finite(radius) or radius <= 0.0: return
	if at.y < 192.0 or at.y > 220.0 or at.x < -20.0 or at.x > 270.0:
		if external.erase(id): invalidate()
		return
	var row := {"position":at,"radius":radius}
	if external.get(id,{}) == row: return
	external[id] = row
	invalidate()

func _entity_moved(id: String, _start: Vector2, finish: Vector2) -> void:
	var service: RefCounted = _receiving_ref.get_ref()
	# Supplier motion already has a route reservation. Only actual foreign
	# vehicles can alter this obstacle cache; no per-frame identity inspection.
	if service.ledger.entity_owner(id) == service.SUPPLIER or service.ledger.entity_kind(id) != "CARRIER": return
	var footprint: Vector2 = service.ledger.carrier_footprint(id)
	set_external(id,finish,maxf(RADIUS,footprint.length()/2.0))

func settle() -> bool:
	if not _dirty: return false
	_dirty = false
	var service: RefCounted = _receiving_ref.get_ref()
	var changed := false
	for order: Dictionary in service._active_suppliers.values():
		if not order.motion.is_empty() and not _clear(order,_remaining(order.motion),float(order.motion.get("speed",service._speed(order)))):
			order.traffic_resume = {"state":str(order.state),"destination":Vector2(order.motion.path.back()),"path":_remaining(order.motion),"speed":float(order.motion.get("speed",service._speed(order)))}
			order.motion = {}
			order.next_at = INF
			service._set_state(order,"Traffic hold")
			changed = true
	for order: Dictionary in service._active_suppliers.values():
		if order.state != "Traffic hold": continue
		var resume: Dictionary = order.traffic_resume
		var path: Array = resume.get("path",[])
		if path.is_empty(): path = plan(order,Vector2(resume.destination))
		var speed: float = float(resume.get("speed",speed_for(order,path)))
		if not path.is_empty() and _clear(order,path,speed):
			service._start_vehicle_motion(order,str(resume.state),Vector2(resume.destination),path,speed)
			changed = true
	return changed

func plan(order: Dictionary, destination: Vector2) -> Array:
	var start: Vector2 = order.world_position
	var direct: Array = [start,destination]
	if _clear(order,direct): return direct
	if destination.x < start.x+20.0: return []
	# Smooth lateral arcs stay outside the protected rear work zone. The
	# body-circle test covers every intermediate straight segment and bend.
	for run: float in [26.0,32.0]:
		if destination.x-start.x < run*2.0+6.0: continue
		var path: Array = [start,start+Vector2(2,0)]
		for step in range(1,13):
			var t := float(step)/12.0
			var blend := t*t*(3.0-2.0*t)
			path.append(Vector2(start.x+2.0+run*t,lerpf(start.y,PASS_Y,blend)))
		path.append(Vector2(destination.x-4.0-run,PASS_Y))
		for step in range(1,13):
			var t := float(step)/12.0
			var blend := t*t*(3.0-2.0*t)
			path.append(Vector2(destination.x-4.0-run+run*t,lerpf(PASS_Y,destination.y,blend)))
		path.append(destination) # Finish aligned with the actual rear-access frame.
		if _clear(order,path): return path
	return []

func speed_for(order: Dictionary, path: Array) -> float:
	for point: Vector2 in path:
		if point.y > 206.0: return 4.0
	return float(_receiving_ref.get_ref()._speed(order))

func _clear(order: Dictionary, path: Array, speed: float = -1.0) -> bool:
	var service: RefCounted = _receiving_ref.get_ref()
	if not _external_clear(path,Vector2(path[0])): return false
	var proposed := _segments(path,float(service._time),speed if speed > 0.0 else speed_for(order,path))
	for other: Dictionary in service._active_suppliers.values():
		if other.id == order.id: continue
		if not other.motion.is_empty():
			var moving := _segments(_remaining(other.motion),float(service._time),float(other.motion.get("speed",service._speed(other))))
			if not moving.is_empty():
				var last: Dictionary = moving.back()
				moving.append({"at":Vector2(other.motion.path.back()),"velocity":Vector2.ZERO,"start":float(last.end),"end":INF,"radius":7.5})
			for a: Dictionary in proposed:
				for b: Dictionary in moving:
					if _conflict(a,b,RADIUS+float(b.get("radius",RADIUS))+GAP): return false
		else:
			var at: Vector2 = other.world_position
			var protected := Rect2(at-Vector2(7.2,1.5),Vector2(10.2,3.0))
			# Protect the whole rear ramp/person exit only while actually servicing.
			if other.state not in ["Berthed","Disembarking"]: protected = Rect2(at-Vector2(4.3,1.5),Vector2(8.6,3.0))
			protected = protected.grow(RADIUS+GAP)
			for index in range(1,path.size()):
				if _hits_box(path[index-1],path[index],protected): return false
	return true

func _external_clear(path: Array, _start: Vector2) -> bool:
	for obstacle: Dictionary in external.values():
		for index in range(1,path.size()):
			var a: Vector2 = path[index-1]
			var b: Vector2 = path[index]
			var nearest := Geometry2D.get_closest_point_to_segment(Vector2(obstacle.position),a,b)
			if nearest.distance_to(Vector2(obstacle.position)) < RADIUS+float(obstacle.radius)+GAP: return false
	return true

func _remaining(motion: Dictionary) -> Array:
	var service: RefCounted = _receiving_ref.get_ref()
	var now: Vector2 = service._motion_position(motion)
	var distance: float = service._path_length(motion.path)*clampf((float(service._time)-float(motion.started_at))/maxf(0.000001,float(motion.ends_at)-float(motion.started_at)),0.0,1.0)
	var result: Array = [now]
	for index in range(1,motion.path.size()):
		var length: float = Vector2(motion.path[index-1]).distance_to(Vector2(motion.path[index]))
		if distance < length: result.append(motion.path[index])
		distance -= length
	if result.size() == 1: result.append(now)
	return result

func _segments(path: Array, now: float, speed: float) -> Array:
	var result: Array = []
	for index in range(1,path.size()):
		var a: Vector2 = path[index-1]
		var b: Vector2 = path[index]
		var duration := a.distance_to(b)/speed
		if duration <= 0.000001: continue
		result.append({"at":a,"velocity":(b-a)/duration,"start":now,"end":now+duration})
		now += duration
	return result

func _conflict(a: Dictionary, b: Dictionary, radius: float) -> bool:
	var first := maxf(float(a.start),float(b.start))
	var last := minf(float(a.end),float(b.end))
	if last < first: return false
	var delta: Vector2 = Vector2(a.at)+Vector2(a.velocity)*(first-float(a.start))-Vector2(b.at)-Vector2(b.velocity)*(first-float(b.start))
	var relative: Vector2 = Vector2(a.velocity)-Vector2(b.velocity)
	var offset := clampf(-delta.dot(relative)/maxf(relative.length_squared(),0.000001),0.0,last-first)
	return (delta+relative*offset).length_squared() < radius*radius

func _hits_box(a: Vector2, b: Vector2, box: Rect2) -> bool:
	if box.has_point(a) or box.has_point(b): return true
	var corners: Array = [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[index],corners[(index+1)%4]) != null: return true
	return false
