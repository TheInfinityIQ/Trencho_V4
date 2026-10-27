extends RefCounted
## GDD 9, 12 and 14 catalogue. Speed columns use cross-country bases exactly once.

const SURFACES := {
	"TR01": {"name": "Open field", "speed": [1.0, 1.0, 1.0], "hit": 1.0, "sight": 0.0, "fuel": 1.0},
	"TR02": {"name": "Road", "speed": [1.1, 1.5, 1.5], "hit": 1.0, "sight": 0.0, "fuel": 1.0},
	"TR03": {"name": "Farm / harvested crop", "speed": [0.95, 0.85, 0.95], "hit": 0.85, "sight": 0.2, "fuel": 1.1},
	"TR04": {"name": "Tall crop", "speed": [0.85, 0.7, 0.85], "hit": 0.8, "sight": 0.5, "fuel": 1.3},
	"TR05": {"name": "Light forest", "speed": [0.8, 0.45, 0.65], "hit": 0.65, "sight": 1.0, "fuel": 1.8},
	"TR06": {"name": "Dense forest", "speed": [0.65, 0.0, 0.4], "hit": 0.5, "sight": 3.0, "fuel": 2.5},
	"TR07": {"name": "Rocky field", "speed": [0.75, 0.4, 0.65], "hit": 0.5, "sight": 0.0, "fuel": 2.0},
	"TR08": {"name": "Town street", "speed": [1.0, 1.1, 1.1], "hit": 1.0, "sight": 0.0, "fuel": 1.2},
	"TR09": {"name": "Shallow swamp", "speed": [0.5, 0.0, 0.35], "hit": 0.8, "sight": 1.5, "fuel": 3.0},
	"TR10": {"name": "Marked shallow ford", "speed": [0.35, 0.4, 0.5], "hit": 1.0, "sight": 0.0, "fuel": 2.5},
	"TR11": {"name": "Deep water / pond", "speed": [0.0, 0.0, 0.0], "hit": 1.0, "sight": 0.0, "fuel": 0.0},
	"TR12": {"name": "Cliff / deep bog", "speed": [0.0, 0.0, 0.0], "hit": 1.0, "sight": 0.0, "fuel": 0.0},
	"TR13": {"name": "Rubble", "speed": [0.7, 0.35, 0.5], "hit": 0.6, "sight": 0.0, "fuel": 2.0},
}
const VEHICLES := {
	"T01": {"class": 1, "base": 8.0, "rate": 2.0, "tank": 40.0, "size": Vector2(7, 2.7)},
	"T02": {"class": 1, "base": 10.0, "rate": 2.0, "tank": 40.0, "size": Vector2(6.8, 2.5)},
	"T03": {"class": 1, "base": 12.0, "rate": 1.5, "tank": 30.0, "size": Vector2(5.2, 2.1)},
	"T04": {"class": 1, "base": 8.0, "rate": 4.0, "tank": 80.0, "size": Vector2(7.5, 3)},
	"T05": {"class": 2, "base": 6.0, "rate": 6.0, "tank": 120.0, "size": Vector2(8.5, 3.5)},
}
const ROLES := {
	"ordinary": {"eye": 1.7, "range": 220.0},
	"binocular_ready": {"eye": 1.7, "range": 350.0},
	"driver": {"eye": 2.0, "range": 220.0},
	"technical_gunner": {"eye": 2.0, "range": 250.0},
	"apc_commander": {"eye": 3.0, "range": 450.0},
	"tank_commander": {"eye": 3.0, "range": 700.0},
	"lookout_staffed": {"eye": 6.0, "range": 500.0},
	"field_gun_deployed": {"eye": 1.7, "range": 650.0},
	"drone": {"eye": 40.0, "range": 350.0},
}
const STRUCTURES := {
	"S01": {"hit": 0.4, "blast": 0.5},
	"S02": {"hit": 0.65, "blast": 1.0},
	"S03": {"hit": 0.25, "blast": 0.25},
}


static func slope_factor(degrees: float, movement_class: int) -> float:
	# Vector2 ground gradients use engine float precision; retain inclusive edges.
	if degrees <= 10.0 + 0.00001: return 1.0
	if degrees <= 15.0 + 0.00001: return [0.8, 0.6, 0.8][movement_class]
	if degrees <= 25.0 + 0.00001: return [0.65, 0.0, 0.5][movement_class]
	if degrees <= 40.0 + 0.00001: return [0.4, 0.0, 0.0][movement_class]
	return 0.0
