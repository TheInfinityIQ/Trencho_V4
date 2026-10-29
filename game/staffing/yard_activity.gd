extends RefCounted
## One declared owned T01, four finite F11 places, and one clear bounded yard trip.

const Layout = preload("res://game/staffing/rear_layout.gd")
const Records = preload("res://game/identity/identity_records.gd")
const START := Vector2(180, 140)
const FINISH := Vector2(170, 140)
var PARKING_POSITIONS: Array[Vector2] = [START, FINISH, Vector2(190,140), Vector2(180,147)]
var active_parking: Array[bool] = [true,true,true,true]
const ROAD_SPEED := 12.0
const TURN_RADIUS := 10.0
const TURN_SPEED := TURN_RADIUS * PI / 4.0 # T01 hull turns at most 45 degrees/s.
const FUEL_PER_METRE := 0.002

var ledger: RefCounted
var time: float = 0.0
var state := "Parked"
var driver := ""
var deadline: float = INF
var fuel: float = 40.0 # Declared starting tank, not a loose M08 stack.
var burned: float = 0.0
var distance: float = 0.0
var start_time: float = 0.0
var pending_exit := false
var occupied: Array = ["yard-t01", "", "", ""]
var reserved: Array = ["", "", "", ""]
var destination_slot: int = -1


func _init(shared_ledger: RefCounted) -> void:
	ledger = shared_ledger
	ledger.add_place("yard-lane", "Clear eight-metre yard lane and turn area", Vector2.ZERO)
	ledger.add_place("yard-start", "F11 occupied parking place 1", START)
	ledger.add_place("yard-finish", "F11 parking place 2", FINISH)
	ledger.add_carrier("yard-t01", "yard-start", "army-blue", "army-blue", "T01", "Rear")
	ledger.move_entity("yard-t01", "yard-lane", START)


func add_park(center: Vector2) -> Array[int]:
	var slots: Array[int] = []
	for offset in [Vector2(-6,-4),Vector2(6,-4),Vector2(-6,4),Vector2(6,4)]:
		var slot := PARKING_POSITIONS.size()
		PARKING_POSITIONS.append(center+offset)
		occupied.append("")
		reserved.append("")
		active_parking.append(true)
		slots.append(slot)
	return slots

func retire_park(slots: Array) -> bool:
	for slot in slots:
		if slot < 4 or slot >= occupied.size() or not occupied[slot].is_empty() or not reserved[slot].is_empty(): return false
	for slot in slots: active_parking[slot] = false
	return true

func board(person_id: String) -> Dictionary:
	var p: Dictionary = ledger.inspect_entity(person_id)
	if state != "Parked" or not driver.is_empty() or p.get("qualification") != "P08" or p.get("owner") != "army-blue" or p.get("duty_id") != "yard" or not p.position.is_equal_approx(ledger.inspect_entity("yard-t01").position):
		return {"ok": false, "message": "Stationary hull and a physically reported eligible P08 are required."}
	driver = person_id
	state = "Entering station"
	deadline = time + 3.0
	return {"ok": true, "message": "Three seconds of stationary driver-station handling started."}


func start_trip() -> Dictionary:
	if state != "Ready" or driver.is_empty() or ledger.inspect_entity(driver).crew_station != "Driver":
		return {"ok": false, "message": "An actual seated P08 driver is required."}
	if not occupied[1].is_empty() or not reserved[1].is_empty():
		return {"ok": false, "message": "The finite destination parking place is occupied/reserved."}
	if fuel < route_length() * FUEL_PER_METRE * 1.25:
		return {"ok": false, "message": "Insufficient actual tank fuel with the 25 percent yard-route reserve."}
	reserved[1] = "yard-t01"
	destination_slot = 1
	occupied[0] = ""
	state = "Moving to reserved parking"
	start_time = time
	distance = 0.0
	deadline = time + route_seconds()
	return {"ok": true, "message": "T01 moving on the declared clear route to its reserved F11 place."}


func request_exit() -> void:
	pending_exit = true
	if state == "Ready":
		state = "Leaving station"
		deadline = time + 3.0


func cancel_entry(person_id: String) -> bool:
	if state != "Entering station" or driver != person_id:
		return false
	driver = ""
	deadline = INF
	state = "Parked"
	return true


func advance_to(next_time: float) -> void:
	if state == "Moving to reserved parking":
		var next_distance := distance_at_time(next_time - start_time)
		var use := (next_distance - distance) * FUEL_PER_METRE
		fuel -= use
		burned += use
		distance = next_distance
		ledger.move_entity("yard-t01", "yard-lane", route_position(distance))
	time = next_time


func complete_due() -> bool:
	if deadline > time + 0.000001:
		return false
	deadline = INF
	match state:
		"Entering station":
			var result: Dictionary = ledger.complete_driver_entry(driver, "yard-t01")
			if not result.ok:
				push_error(str(result))
				return false
			state = "Ready"
			if pending_exit:
				request_exit()
		"Moving to reserved parking":
			ledger.move_entity("yard-t01", "yard-lane", FINISH)
			occupied[destination_slot] = "yard-t01"
			reserved[destination_slot] = ""
			state = "Ready"
			if pending_exit:
				request_exit()
		"Leaving station":
			var exit_place := "yard-finish" if destination_slot == 1 else "yard-start"
			var result: Dictionary = ledger.complete_driver_exit(driver, exit_place)
			if not result.ok:
				push_error(str(result))
			driver = ""
			pending_exit = false
			state = "Parked"
	return true


func snapshot() -> Dictionary:
	return {"id": "yard-t01", "type": "T01", "owner": "army-blue", "state": state,
		"position": ledger.inspect_entity("yard-t01").position, "driver": driver,
		"deadline": deadline, "pending_exit": pending_exit, "occupied_parking": occupied.duplicate(),
		"reserved_parking": reserved.duplicate(), "active_parking":active_parking.duplicate(), "fuel": fuel, "burned": burned,
		"distance": distance, "route_length": route_length(), "footprint": Vector2(7, 2.7),
		"road_speed": ROAD_SPEED, "turn_radius": TURN_RADIUS, "facing": route_facing(distance)}


static func route_facing(metres: float) -> Vector2:
	if metres <= 70.0: return Vector2.UP
	metres -= 70.0
	if metres <= PI * TURN_RADIUS: return Vector2.from_angle(-metres / TURN_RADIUS - PI / 2.0)
	metres -= PI * TURN_RADIUS
	if metres <= 60.0: return Vector2.DOWN
	metres -= 60.0
	return Vector2.from_angle(PI / 2.0 - metres / TURN_RADIUS)


static func route_seconds() -> float:
	return 130.0 / ROAD_SPEED + PI * TURN_RADIUS * 1.5 / TURN_SPEED


static func distance_at_time(seconds: float) -> float:
	var distance: float = 0.0
	for section in [[70.0, ROAD_SPEED], [PI * TURN_RADIUS, TURN_SPEED], [60.0, ROAD_SPEED], [PI * TURN_RADIUS / 2.0, TURN_SPEED]]:
		var duration: float = section[0] / section[1]
		if seconds <= duration:
			return distance + maxf(0.0, seconds) * section[1]
		distance += section[0]
		seconds -= duration
	return route_length()


static func route_length() -> float:
	return 70.0 + PI * TURN_RADIUS + 60.0 + PI * TURN_RADIUS / 2.0


static func route_position(metres: float) -> Vector2:
	if metres <= 70.0:
		return START + Vector2(0, -metres)
	metres -= 70.0
	if metres <= PI * TURN_RADIUS:
		return Vector2(170, 70) + Vector2.from_angle(-metres / TURN_RADIUS) * TURN_RADIUS
	metres -= PI * TURN_RADIUS
	if metres <= 60.0:
		return Vector2(160, 70 + metres)
	metres -= 60.0
	return Vector2(170, 130) + Vector2.from_angle(PI - metres / TURN_RADIUS) * TURN_RADIUS
