extends Control
## Review-only metre diagram; the service and terrain own all crossing permission.
var simulation: RefCounted
var bridge_id := ""

func _x(metres: float) -> float:
	return 34.0+(metres-80.5)*(size.x-68.0)/72.0

func _draw() -> void:
	if simulation == null or bridge_id.is_empty(): return
	var rear: RefCounted = simulation.rear
	var bridge: Dictionary = rear.bridges.inspect(bridge_id)
	var left := 34.0
	var right := size.x-34.0
	var top := 20.0
	var bottom := size.y-24.0
	var center_y := (top+bottom)*0.5
	draw_rect(Rect2(Vector2(left,top),Vector2(right-left,bottom-top)),Color("#70865b"))
	draw_rect(Rect2(Vector2(_x(101.0),top),Vector2(_x(131.0)-_x(101.0),bottom-top)),Color("#28799c"))
	draw_line(Vector2(_x(80.5),center_y-35),Vector2(_x(80.5),center_y+35),Color("#e7d37e"),2.0)
	draw_line(Vector2(_x(151.5),center_y-35),Vector2(_x(151.5),center_y+35),Color("#e7d37e"),2.0)
	if bridge.state == "Complete":
		var deck_color := Color("#b3936b") if bridge.health > bridge.max_health/2 else Color("#a66b5d")
		draw_rect(Rect2(Vector2(_x(100.5),center_y-16),Vector2(_x(131.5)-_x(100.5),32)),deck_color)
		draw_line(Vector2(_x(100.5),center_y-16),Vector2(_x(131.5),center_y-16),Color.WHITE,2.0)
		draw_line(Vector2(_x(100.5),center_y+16),Vector2(_x(131.5),center_y+16),Color.WHITE,2.0)
	else:
		draw_dashed_line(Vector2(_x(100.5),center_y),Vector2(_x(131.5),center_y),Color("#f2d290"),3.0,8.0)
	for id in ["review-walker"]:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not person.is_empty() and person.assignment != "Dead":
			draw_circle(Vector2(_x(person.position.x),center_y),7.0,Color("#eaf7f5"))
			draw_arc(Vector2(_x(person.position.x),center_y),8.0,0.0,TAU,20,Color("#173d4b"),2.0)
