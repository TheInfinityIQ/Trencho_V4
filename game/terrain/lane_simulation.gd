extends RefCounted
## One declared initialized body in a straight lane, not a produced/deployed army.

const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const World = preload("res://game/terrain/terrain_world.gd")
const EPS := 0.0000001
var world := World.new()
var entity: Dictionary = {}
var destination := Vector2(70, 12)
var time: float = 0.0
var motion: Dictionary = {}
var state := "Ready"
var reason := "Declared fixture body; no crew or combat integration"
var travelled: float = 0.0
var fuel_used: float = 0.0
var last_plan: Dictionary = {}


func initialize(type: String, at: Vector2 = Vector2(10, 12), facing: float = 0.0) -> void:
	assert(type == "person" or Catalog.VEHICLES.has(type))
	var value: Dictionary = {"class": 0, "base": 2.0, "rate": 0.0, "tank": 0.0, "size": Vector2(0.6, 0.6)} if type == "person" else Catalog.VEHICLES[type]
	entity = {"id": "declared-" + type, "type": type, "position": at, "facing": facing, "size": value.size, "movement_class": value.class, "base": value.base, "rate": value.rate, "fuel": value.tank}


func start() -> Dictionary:
	if not motion.is_empty(): return {"ok": false, "reason": "Lane already active"}
	last_plan = world.route(entity, destination)
	if not last_plan.ok:
		state = "Blocked"
		reason = last_plan.reason
		return last_plan.duplicate(true)
	if entity.fuel + EPS < last_plan.fuel * 1.25:
		state = "Blocked"
		reason = "Insufficient fuel for declared leg plus 25% reserve"
		return {"ok": false, "reason": reason}
	motion = {"parts": last_plan.parts.duplicate(true), "index": 0, "elapsed": 0.0, "revision": world.revision}
	state = "Moving"
	reason = "Actual straight-lane traversal"
	return {"ok": true, "reason": reason}


func cancel() -> void:
	motion = {}
	state = "Stopped"
	reason = "Cancelled at actual position; elapsed fuel and distance retained"


func advance(seconds: float) -> void:
	if seconds < 0 or not is_finite(seconds): return
	var remaining := seconds
	if not motion.is_empty() and motion.revision != world.revision:
		var revised := world.route(entity, destination)
		if not revised.ok:
			motion = {}
			state = "Blocked"
			reason = revised.reason
		else:
			motion = {"parts": revised.parts, "index": 0, "elapsed": 0.0, "revision": world.revision}
	while remaining > EPS and not motion.is_empty():
		var part: Dictionary = motion.parts[motion.index]
		var duration: float = minf(remaining, part.seconds - motion.elapsed)
		var per_second: float = part.fuel / part.seconds
		if per_second > 0: duration = minf(duration, entity.fuel / per_second)
		motion.elapsed += duration
		remaining -= duration
		travelled += duration * part.speed
		var used: float = duration * per_second
		fuel_used += used
		entity.fuel = maxf(0.0, entity.fuel - used)
		entity.position = Vector2(part.from).lerp(part.to, clampf(motion.elapsed / part.seconds, 0, 1))
		if motion.elapsed >= part.seconds - EPS:
			entity.position = part.to
			motion.index += 1
			motion.elapsed = 0.0
			if motion.index == motion.parts.size():
				motion = {}
				state = "Arrived"
				reason = "Actual lane endpoint reached"
		if not motion.is_empty() and entity.movement_class != 0 and entity.fuel <= EPS:
			motion = {}
			state = "Fuel Empty"
			reason = "No further physical movement"
	time += seconds


func snapshot() -> Dictionary:
	return {"time": time, "entity": entity.duplicate(true), "destination": destination, "state": state, "reason": reason, "distance": travelled, "fuel_used": fuel_used, "plan": last_plan.duplicate(true), "motion": motion.duplicate(true)}
