extends Control
## Shows one decision from detached known facts; no live simulation or truth feed.
const Example = preload("res://game/example_map.gd")
const Commander = preload("res://game/commander.gd")
var snapshot: Dictionary
var decision: Dictionary
var _map: MapView

class MapView extends Control:
	var data: Dictionary = {}
	var result: Dictionary = {}
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("172a32"))
		var nodes: Dictionary = data.get("nodes",{})
		var route: Array = result.get("route",{}).get("edges",[])
		for edge: Dictionary in data.get("connections",[]):
			var a: Vector2 = nodes[edge.from].position
			var b: Vector2 = nodes[edge.to].position
			var selected: bool = edge.id in route
			draw_line(a,b,Color("e5c47a") if selected else Color("506e76"),5.0 if selected else 2.0,true)
		for id: String in nodes:
			var pos: Vector2 = nodes[id].position
			draw_circle(pos,7.0,Color("83c7ce") if id != data.destination else Color("e39e86"))
			draw_string(ThemeDB.fallback_font,pos+Vector2(10,-8),str(nodes[id].label),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
		var question_id := str(result.get("question_at",""))
		if nodes.has(question_id):
			draw_arc(nodes[question_id].position,22.0,0,TAU,32,Color("e5c47a"),2.0,true)
			draw_string(ThemeDB.fallback_font,nodes[question_id].position+Vector2(-5,6),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("e5c47a"))

func _ready() -> void:
	snapshot = Example.snapshot()
	decision = Commander.decide(snapshot.duplicate(true))
	_build_view()

func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color("101b23")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(side,24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "COMMANDER  /  FIRST DECISION"
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Known geography · friendly knowledge · 00:00 simulation time"
	subtitle.modulate = Color("a9c3c8")
	column.add_child(subtitle)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",20)
	column.add_child(row)
	_map = MapView.new()
	_map.custom_minimum_size = Vector2(680,440)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.data = snapshot
	_map.result = decision
	row.add_child(_map)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	var detail := Label.new()
	detail.custom_minimum_size.x = 450
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",17)
	detail.text = _explanation()
	scroll.add_child(detail)
	var footer := Label.new()
	footer.text = "Intent only: no scout order, movement, contact or combat has occurred."
	footer.modulate = Color("d6be86")
	column.add_child(footer)

func _explanation() -> String:
	if not decision.get("ok",false): return "No decision: "+str(decision.get("reason","Unknown"))
	var event: Dictionary = decision.journal[0]
	var element: Dictionary = snapshot.elements[0]
	var lines: Array[String] = ["MISSION",str(snapshot.mission),"", "OWN COMMAND",str(snapshot.commander)+" → "+str(element.id)+" → "+", ".join(element.individuals),"", "DESIRED EFFECT",str(decision.effect),"", "SELECTED ROUTE",_route_label(decision.route),str(event.reason),"", "ALTERNATIVE"]
	for route: Dictionary in decision.alternatives: lines.append(_route_label(route)+" · longer under the current distance criterion")
	lines.append_array(["", "UNANSWERED QUESTION",str(decision.question),"The opposing HQ coordinate is known; its garrison and the crossing's enemy presence are unknown.","", "DECISION RECORD", "#%d · %.1f s · %s · %s" % [event.sequence,event.time_seconds,event.side,event.actor],"Cause: mission and known map; no prior observation.","Location: %s · %s" % [str(event.position),snapshot.coordinates],"Inputs: "+", ".join(event.input_refs),"Question location: "+str(event.uncertainty_location)])
	return "\n".join(lines)

func _route_label(route: Dictionary) -> String:
	var labels: Array[String] = []
	for id: String in route.nodes: labels.append(str(snapshot.nodes[id].label))
	return " → ".join(labels)+" · %.0f m" % float(route.metres)
