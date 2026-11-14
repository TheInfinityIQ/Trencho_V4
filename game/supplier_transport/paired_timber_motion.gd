extends RefCounted
## Pure synchronized motion data. Receiving owns time, route and custody.
const ROLES: Array[String] = ["FORE","AFT"]
const EPS := 0.00001
const PERSON_RADIUS := 0.25 # Existing rear walking clearance.
const Packages = preload("res://game/warehousing/material_packages.gd")
var error := ""
var clips: Dictionary = {}
var _streams: Dictionary = {}
var _shapes: Dictionary = {}
var _radii: Dictionary = {}
var _source_turn_radius := 0.0
var _last_name := ""
var _last_time := -INF
var _last_sample: Dictionary = {}

func _init(contract: Dictionary, streams: Dictionary) -> void:
	if contract.get("schema","") != "timber_paired_motion_v1":
		error = "Unsupported paired timber motion contract."
		return
	var entries: Variant = contract.get("clips")
	if not entries is Array:
		error = "Paired timber contract lacks its clip list."
		return
	for entry: Variant in entries:
		if not entry is Dictionary or not _decode_clip(entry,streams):
			clips.clear()
			_streams.clear()
			_shapes.clear()
			_radii.clear()
			if error.is_empty(): error = "Invalid paired timber clip descriptor."
			return
	if clips.is_empty(): error = "Paired timber motion has no delivered clips."
	var turns: Dictionary = contract.get("turn",{}).get("source_measured_sweeps",{})
	for take: Dictionary in turns.values():
		var bounds: Array = take.get("bounds_relative_to_pivot_xz_m",[])
		if bounds.size() != 2 or not _numbers(bounds[0],2) or not _numbers(bounds[1],2): continue
		var x: float = maxf(absf(float(bounds[0][0])),absf(float(bounds[1][0])))
		var z: float = maxf(absf(float(bounds[0][1])),absf(float(bounds[1][1])))
		_source_turn_radius = maxf(_source_turn_radius,Vector2(x,z).length())

func _decode_clip(entry: Dictionary, streams: Dictionary) -> bool:
	var name := str(entry.get("name",""))
	var duration := float(entry.get("duration_s",0.0))
	var fps := float(entry.get("fps",0.0))
	var source: Variant = streams.get(name)
	if name.is_empty() or clips.has(name) or not is_finite(duration) or duration <= 0.0 or not is_finite(fps) or fps <= 0.0 or not source is Array or source.size() < 2:
		error = "Missing or invalid actual paired timber samples: "+name
		return false
	if source.size() != int(entry.get("sample_count",0)):
		error = "Paired timber sample count differs from its descriptor: "+name
		return false
	var decoded: Array[Dictionary] = []
	var previous := -INF
	for value: Variant in source:
		if not value is Dictionary or not value.get("time_s") is float and not value.get("time_s") is int:
			error = "Paired timber sample lacks its actual time: "+name
			return false
		var time := float(value.time_s)
		if not is_finite(time) or time <= previous or time < 0.0 or time > duration+EPS:
			error = "Paired timber sample times are not strictly increasing: "+name
			return false
		if not decoded.is_empty() and time-previous > 1.0/fps+EPS:
			error = "Actual paired timber stream has a missing sample interval: "+name
			return false
		var sample := {"time":time}
		var roles: Variant = value.get("roles")
		if not roles is Dictionary:
			error = "Paired timber sample lacks both role roots: "+name
			return false
		for role: String in ROLES:
			var pose: Variant = roles.get(role)
			if not pose is Dictionary or not _numbers(pose.get("floor_root_godot_xyz_m"),3) or not _rotation(pose.get("body_rotation_xyzw")):
				error = "Invalid actual "+role+" root in "+name
				return false
			sample[role] = _transform(pose.floor_root_godot_xyz_m,pose.body_rotation_xyzw)
		var payload: Variant = value.get("payload")
		if not payload is Dictionary or not _numbers(payload.get("position_godot_xyz_m"),3) or not _rotation(payload.get("rotation_xyzw")):
			error = "Invalid actual shared payload in "+name
			return false
		sample.payload = _transform(payload.position_godot_xyz_m,payload.rotation_xyzw)
		var fore: Vector3 = sample.FORE.origin
		var aft: Vector3 = sample.AFT.origin
		if Vector2(fore.x,fore.z).distance_to(Vector2(aft.x,aft.z)) < 1.2-EPS:
			error = "Actual paired roots overlap in "+name
			return false
		decoded.append(sample)
		previous = time
	if absf(float(decoded[0].time)) > EPS or absf(previous-duration) > EPS:
		error = "Paired timber samples must include both clip endpoints: "+name
		return false
	if bool(entry.get("loop",false)) and not _numbers(entry.get("cycle_translation_godot_m"),3):
		error = "Paired timber loop lacks its actual cycle displacement: "+name
		return false
	clips[name] = entry.duplicate(true)
	_streams[name] = decoded
	if name in ["turn_left","turn_right","shoulder_walk_loop","underhand_walk_loop"]: _measure_shape(name,decoded)
	return true

func _measure_shape(name: String, values: Array) -> void:
	var parts: Array[Rect2] = []
	var first: Vector2 = anchor(values[0])
	var radius := 0.0
	for value: Dictionary in values:
		var center: Vector2 = anchor(value)
		var current: Array[Rect2] = []
		for role: String in ROLES:
			var root: Vector3 = value[role].origin
			current.append(Rect2(Vector2(root.x,root.z)-Vector2.ONE*PERSON_RADIUS,Vector2.ONE*PERSON_RADIUS*2.0))
		current.append(_payload_bounds(value.payload))
		for index in current.size():
			var box: Rect2 = current[index]
			for corner: Vector2 in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
				radius = maxf(radius,corner.distance_to(first))
			box.position -= center
			if parts.size() <= index: parts.append(box)
			else: parts[index] = parts[index].merge(box)
	_shapes[name] = parts
	_radii[name] = radius

func footprints(name: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.assign(_shapes.get(name,[]))
	return result

func turn_radius() -> float:
	return maxf(_source_turn_radius,maxf(float(_radii.get("turn_left",INF)),float(_radii.get("turn_right",INF))))

static func anchor(value: Dictionary) -> Vector2:
	var fore: Vector3 = value.FORE.origin
	var aft: Vector3 = value.AFT.origin
	return Vector2(fore.x+aft.x,fore.z+aft.z)*0.5

static func _payload_bounds(pose: Transform3D) -> Rect2:
	var size: Vector3 = Packages.TYPES.M04.size
	var result := Rect2()
	var first := true
	for x: float in [-size.x/2.0,size.x/2.0]:
		for y: float in [0.0,size.y]:
			for z: float in [-size.z/2.0,size.z/2.0]:
				var point: Vector3 = pose*Vector3(x,y,z)
				var planar := Vector2(point.x,point.z)
				if first:
					result = Rect2(planar,Vector2.ZERO)
					first = false
				else: result = result.expand(planar)
	return result

func valid() -> bool:
	return error.is_empty() and not clips.is_empty()

func sample(name: String, elapsed: float) -> Dictionary:
	# Empty means unavailable, never a default origin that teleports real people.
	if not valid() or not clips.has(name) or not is_finite(elapsed): return {}
	if name == _last_name and elapsed == _last_time: return _last_sample.duplicate()
	var descriptor: Dictionary = clips[name]
	var duration := float(descriptor.duration_s)
	var time := maxf(0.0,elapsed)
	var cycles := 0
	if bool(descriptor.get("loop",false)):
		cycles = int(floor(time/duration))
		time = fposmod(time,duration)
	else: time = minf(time,duration)
	var values: Array = _streams[name]
	var low := 0
	var high := values.size()-1
	while high-low > 1:
		var middle := (low+high) >> 1
		if float(values[middle].time) <= time: low = middle
		else: high = middle
	var before: Dictionary = values[low]
	var after: Dictionary = values[high]
	var weight := clampf((time-float(before.time))/(float(after.time)-float(before.time)),0.0,1.0)
	var poses := {"FORE":_interpolate(before.FORE,after.FORE,weight),"AFT":_interpolate(before.AFT,after.AFT,weight),"payload":_interpolate(before.payload,after.payload,weight),"time":time,"cycles":cycles}
	if cycles > 0:
		var raw: Array = descriptor.cycle_translation_godot_m
		var offset := Vector3(raw[0],raw[1],raw[2])*float(cycles)
		for key: String in ["FORE","AFT","payload"]:
			var pose: Transform3D = poses[key]
			pose.origin += offset
			poses[key] = pose
	_last_name = name
	_last_time = elapsed
	_last_sample = poses
	return poses.duplicate()

static func _interpolate(before: Transform3D, after: Transform3D, weight: float) -> Transform3D:
	return Transform3D(Basis(before.basis.get_rotation_quaternion().slerp(after.basis.get_rotation_quaternion(),weight)),before.origin.lerp(after.origin,weight))

static func _transform(position: Array, rotation: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(rotation[0],rotation[1],rotation[2],rotation[3]).normalized()),Vector3(position[0],position[1],position[2]))

static func _rotation(value: Variant) -> bool:
	if not _numbers(value,4): return false
	var length := 0.0
	for number: Variant in value: length += float(number)*float(number)
	return is_finite(length) and length > EPS

static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for number: Variant in value:
		if not number is float and not number is int: return false
		if not is_finite(float(number)): return false
	return true
