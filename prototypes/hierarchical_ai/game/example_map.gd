extends RefCounted
## One explicit known-map example. Enemy presence and strength are not provided.

static func physical_fixture() -> Dictionary:
	# Actual experiment state stays separate from the commander's known snapshot.
	return {"hostiles":[]}

static func snapshot() -> Dictionary:
	return {
		"side":"blue", "time_seconds":0.0, "commander":"blue-commander",
		"mission":"Preserve a feasible approach toward the known opposing headquarters.",
		"origin":"blue-hq", "destination":"red-hq",
		"nodes":{
			"blue-hq":{"label":"Friendly HQ", "position":Vector2(70,230)},
			"bridge":{"label":"River bridge", "position":Vector2(310,140)},
			"ford":{"label":"Southern ford", "position":Vector2(310,350)},
			"red-hq":{"label":"Known opposing HQ", "position":Vector2(590,230)}
		},
		"connections":[
			{"id":"west-bridge", "from":"blue-hq", "to":"bridge", "metres":260.0, "movement":["foot"], "constraint":"approach"},
			{"id":"east-bridge", "from":"bridge", "to":"red-hq", "metres":300.0, "movement":["foot"], "constraint":"crossing"},
			{"id":"west-ford", "from":"blue-hq", "to":"ford", "metres":340.0, "movement":["foot"], "constraint":"approach"},
			{"id":"east-ford", "from":"ford", "to":"red-hq", "metres":360.0, "movement":["foot"], "constraint":"crossing"}
		],
		"elements":[{"id":"blue-squad-1", "kind":"squad", "movement":"foot", "individuals":["blue-person-1","blue-person-2"]}],
		"coordinates":"Metres; x east, y south; positions are map coordinates."
	}
