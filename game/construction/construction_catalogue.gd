extends RefCounted
## GDD 8.1 physical facility values. F01/F08 are fixed and have no build recipe.
const Layout = preload("res://game/staffing/rear_layout.gd")
const SPECS := {
	"terminal":{"code":"F01","m11":0,"work":0.0,"fixed":true},
	"receiving":{"code":"F02","m11":100,"work":160.0,"output_kg":5000.0},
	"depot":{"code":"F03","m11":100,"work":160.0,"output_kg":10000.0},
	"workshop":{"code":"F04","m11":150,"work":200.0,"input_kg":1000.0,"output_kg":1000.0},
	"munitions":{"code":"F05","m11":180,"work":240.0,"input_kg":1000.0,"output_kg":1000.0},
	"training":{"code":"F06","m11":150,"work":200.0,"student_places":12},
	"dispatch":{"code":"F07","m11":150,"work":200.0,"output_kg":6000.0},
	"personnel":{"code":"F08","m11":0,"work":0.0,"fixed":true},
	"support":{"code":"F09","m11":150,"work":200.0,"input_kg":1000.0,"output_kg":1000.0},
	"vehicle_works":{"code":"F10","m11":400,"work":480.0,"input_kg":5000.0,"heavy_bays":1},
	"park":{"code":"F11","m11":150,"work":160.0,"parking_places":4},
	"construction":{"code":"F12","m11":60,"work":80.0},
	"materials":{"code":"F13","m11":180,"work":240.0,"input_kg":2000.0,"output_kg":3000.0},
}

static func footprint(kind: String, quarter_turn: bool = false) -> Vector2:
	var size: Vector2 = Layout.FACILITIES[kind][2]
	return Vector2(size.y,size.x) if quarter_turn else size
