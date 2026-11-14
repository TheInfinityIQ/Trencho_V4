extends Control
## Shows one decision from detached known facts; no live simulation or truth feed.
const Example = preload("res://game/example_map.gd")
const Commander = preload("res://game/commander.gd")
const ScoutWorld = preload("res://game/scout_world.gd")
const ScoutOperation = preload("res://game/scout_operation.gd")
var snapshot: Dictionary
var decision: Dictionary
var _map: MapView
var _world: RefCounted
var _scout: RefCounted
var _detail: Label
var _footer: Label

class MapView extends Control:
	var data: Dictionary = {}
	var result: Dictionary = {}
	var people: Dictionary = {}
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
		for id: String in people:
			var person: Dictionary = people[id]
			draw_circle(person.position,4.0,Color("a8e7ab"))

func _ready() -> void:
	snapshot = Example.snapshot()
	decision = Commander.decide(snapshot.duplicate(true))
	_world = ScoutWorld.new(snapshot,Example.physical_fixture())
	_scout = ScoutOperation.new(snapshot,decision,_world)
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
	_map.people = _world.people
	row.add_child(_map)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	_detail = Label.new()
	_detail.custom_minimum_size.x = 450
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size",17)
	_detail.text = _explanation()
	scroll.add_child(_detail)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	var issue := Button.new()
	issue.text = "Issue scout task"
	issue.pressed.connect(_issue_scout)
	controls.add_child(issue)
	var advance := Button.new()
	advance.text = "Advance 5 seconds"
	advance.pressed.connect(_advance_scout)
	controls.add_child(advance)
	_footer = Label.new()
	_footer.text = "Intent only: no scout order, movement, contact or combat has occurred."
	_footer.modulate = Color("d6be86")
	column.add_child(_footer)

func _issue_scout() -> void:
	_scout.issue()
	_refresh_scout()

func _advance_scout() -> void:
	_scout.advance(5.0)
	_refresh_scout()

func _refresh_scout() -> void:
	decision = _scout.decision
	_map.result = decision
	_map.queue_redraw()
	_detail.text = _explanation()
	_footer.text = "Scout task: %s · %.1f s · no combat simulated" % [_scout.phase,_scout.now]

func _explanation() -> String:
	if not decision.get("ok",false): return "No decision: "+str(decision.get("reason","Unknown"))
	var event: Dictionary = decision.journal[0]
	var element: Dictionary = snapshot.elements[0]
	var lines: Array[String] = ["MISSION",str(snapshot.mission),"", "OWN COMMAND",str(snapshot.commander)+" → "+str(element.id)+" → "+", ".join(element.individuals),"", "DESIRED EFFECT",str(decision.effect),"", "SELECTED ROUTE",_route_label(decision.route),str(event.reason),"", "ALTERNATIVE"]
	for route: Dictionary in decision.alternatives: lines.append(_route_label(route)+" · longer under the current distance criterion")
	lines.append_array(["", "ORIGINAL QUESTION",str(decision.question),"The opposing HQ coordinate is known; its garrison is unknown.","", "DECISION RECORD", "#%d · %.1f s · %s · %s" % [event.sequence,event.time_seconds,event.side,event.actor],"Cause: mission and known map; no prior observation.","Location: %s · %s" % [str(event.position),snapshot.coordinates],"Inputs: "+", ".join(event.input_refs),"Question location: "+str(event.uncertainty_location)])
	if not _scout.task.is_empty():
		lines.append_array(["", "SCOUT TASK",str(_scout.task.element)+" · "+str(_scout.phase),"Actual people: "+", ".join(_scout.task.individuals),"Position: "+str(_world.people[_scout.task.individuals[0]].position)])
	if not _scout.observation.is_empty():
		var observed: Dictionary = _scout.observation
		lines.append_array(["", "LOCAL OBSERVATION", "At %.1f s, %s observed within %.0f m at %s." % [observed.observed_at,observed.observer,observed.radius_m,str(observed.position)],str(observed.scope),"Detected classes: "+("none in this area" if observed.detected_classes.is_empty() else ", ".join(observed.detected_classes))])
	if not _scout.delivered.is_empty():
		lines.append_array(["", "COMMAND RECEIPT", "Received at %.1f s; observed at %.1f s." % [_scout.delivered.received_at,_scout.delivered.observed_at],str(decision.reassessment)])
	elif not _scout.observation.is_empty(): lines.append("Commander has not received the local observation.")
	if _scout.events.size() > 1:
		lines.append_array(["", "EVENT HISTORY"])
		for history: Dictionary in _scout.events.slice(1):
			lines.append("#%d · %.1f s · %s · causes %s" % [history.sequence,history.time_seconds,history.kind,str(history.causes)])
	return "\n".join(lines)

func _route_label(route: Dictionary) -> String:
	var labels: Array[String] = []
	for id: String in route.nodes: labels.append(str(snapshot.nodes[id].label))
	return " → ".join(labels)+" · %.0f m" % float(route.metres)
