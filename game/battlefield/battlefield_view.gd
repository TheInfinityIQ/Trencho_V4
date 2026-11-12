extends Control
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
## Read-only strategic view of the same identities and clock used by the rear.

const WORLD_SIZE := Vector2(4000.0, 6000.0)
const Presentation = preload("res://game/battlefield/battlefield_presentation.gd")
const SelectedEngagement = preload("res://game/battlefield/selected_engagement.gd")
const Farmland = preload("res://game/battlefield/farmland_scenario.gd")
const TRUCK_ART: Texture2D = preload("res://game/test_art/tiny_battle/tile_0132.png")
const PANEL_WIDTH := 350.0
var session: Node
var simulation: RefCounted
var zoom := 1.0
var pan := Vector2.ZERO
var selected_id := ""
var _dragging := false
var _refresh_queued := false
var _displayed_time := -INF
var _displayed_speed := -1
var _displayed_planning_revision := -1
var _inspector: Label
var _stop_stock_ledger: RefCounted
var _stop_stock_id := ""
var _stop_selection_id := ""
var _stop_stock_dirty := true
var _stop_stock: Dictionary = {}

func bind(next_simulation: RefCounted) -> void:
	simulation = next_simulation
	_bind_stop_stock()
	if is_node_ready():
		_request_refresh()
		queue_redraw()

func _default_objective() -> String:
	var objectives: Dictionary = simulation.rear.objectives.objectives
	for id in ["resource-centre-blue","resource-central"]:
		if objectives.has(id): return id
	return str(objectives.keys()[0]) if not objectives.is_empty() else ""

func _ready() -> void:
	if session != null:
		simulation = session.simulation
		session.simulation_changed.connect(bind)
		session.state_changed.connect(_request_refresh)
		session.time_advanced.connect(_request_refresh)
	_bind_stop_stock()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree(): _request_refresh())
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDTH
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	_inspector = Label.new()
	_inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)
	_refresh()


func _request_refresh() -> void:
	CallLog.record(&"battlefield/battlefield_view.gd::_request_refresh")
	if _refresh_queued or not is_node_ready() or not is_visible_in_tree(): return
	_refresh_queued = true
	_refresh.call_deferred()


func _map_rect() -> Rect2:
	return Rect2(Vector2(12, 12), Vector2(maxf(300.0, size.x - PANEL_WIDTH - 24.0), maxf(200.0, size.y - 24.0)))


func _scale() -> float:
	var area := _map_rect()
	return minf((area.size.x - 32.0) / WORLD_SIZE.x, (area.size.y - 72.0) / WORLD_SIZE.y) * zoom


func _screen(point: Vector2) -> Vector2:
	var area := _map_rect()
	return area.get_center() + (point - WORLD_SIZE / 2.0) * _scale() + pan


func _world(point: Vector2) -> Vector2:
	return (point - _map_rect().get_center() - pan) / _scale() + WORLD_SIZE / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _world(event.position)
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.7, 16.0)
			pan += event.position - _screen(before)
			queue_redraw()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _map_rect().has_point(event.position):
			_select_nearest(event.position)
	if event is InputEventMouseMotion and _dragging:
		pan += event.relative
		queue_redraw()


func _select_nearest(point: Vector2) -> void:
	if simulation == null: return
	var distance := 14.0
	for entity in Presentation.markers(simulation.rear):
		if entity.kind == "PERSON" and entity.get("aboard",false): continue
		var measure: float = _screen(entity.position).distance_to(point)
		if measure < distance:
			distance = measure
			selected_id = entity.id
	_refresh()
	queue_redraw()

func focus_entity(id: String) -> bool:
	if simulation == null: return false
	var marker: Dictionary = Presentation.inspect(simulation.rear,id)
	if marker.is_empty() or marker.get("kind","") != "PERSON" or marker.get("owner","") != simulation.rear.PLAYER: return false
	var position: Vector2 = marker.get("position",Vector2.INF)
	if not position.is_finite(): return false
	selected_id = id
	zoom = maxf(zoom,8.0)
	pan = -(position-WORLD_SIZE/2.0)*_scale()
	_request_refresh()
	queue_redraw()
	return true


func _draw() -> void:
	CallLog.record(&"battlefield/battlefield_view.gd::_draw")
	var started_usec: int = Time.get_ticks_usec() if CallLog.enabled else 0
	var profile := CallLog.enabled and OS.get_environment("TRENCHO_PROFILE_STAGES") == "1"
	var area := _map_rect()
	draw_rect(area, Color("172633"))
	var world_rect := Rect2(_screen(Vector2.ZERO), WORLD_SIZE * _scale())
	draw_rect(world_rect.intersection(area), Color("395442"))
	if simulation != null:
		for region in simulation.rear.combat.world.base_regions:
			var rect := Rect2(_screen(Vector2(region.area.position)),Vector2(region.area.size)*_scale())
			if rect.intersects(area): draw_rect(rect.intersection(area),Color(Farmland.COLOURS.get(region.tile.terrain,"71875a")))
		for obstacle in simulation.rear.combat.world.obstacles:
			if str(obstacle.id).begins_with("town-shell"):
				var rect := Rect2(_screen(obstacle.rect.position),obstacle.rect.size*_scale())
				if rect.intersects(area): draw_rect(rect.intersection(area),Color("d1c7b0"))
		for project in simulation.rear.field_structures.projects.values():
			if project.get("initial_supply",false) and project.state == "Complete":
				var rect := Rect2(_screen(project.area.position),project.area.size*_scale())
				if rect.intersects(area): draw_rect(rect.intersection(area),Color("d6c49c"))
	draw_rect(world_rect.intersection(area), Color("a5baaa"), false, 2.0)
	var font := ThemeDB.fallback_font
	for x in range(0, 4001, 1000):
		var top := _screen(Vector2(x, 0))
		var bottom := _screen(Vector2(x, 6000))
		if top.x >= area.position.x and top.x <= area.end.x: draw_line(Vector2(top.x,maxf(top.y,area.position.y)),Vector2(bottom.x,minf(bottom.y,area.end.y)),Color("678278",0.45),1.0)
	for y in range(0, 6001, 1000):
		var left := _screen(Vector2(0,y))
		var right := _screen(Vector2(4000,y))
		if left.y >= area.position.y and left.y <= area.end.y: draw_line(Vector2(maxf(left.x,area.position.x),left.y),Vector2(minf(right.x,area.end.x),right.y),Color("678278",0.45),1.0)
	if simulation == null: return
	if profile: CallLog.record_duration(&"battlefield/battlefield_view.gd::_draw/terrain_grid",Time.get_ticks_usec()-started_usec)
	var stage_started: int = Time.get_ticks_usec() if profile else 0
	var markers: Array[Dictionary] = Presentation.markers(simulation.rear)
	if profile: CallLog.record_duration(&"battlefield/battlefield_view.gd::_draw/marker_query",Time.get_ticks_usec()-stage_started)
	if profile: stage_started = Time.get_ticks_usec()
	for entity in markers:
		if entity.kind == "PLACE":
			var colour := Color("f0c565") if simulation.rear.objectives.objectives.has(entity.id) else (Color("73bde4") if entity.id == "hq-berth" else Color("e17c72"))
			var label := _site_label(entity.id)
			if entity.id in ["route-hub-west","route-hub-east"]: colour = Color("8bd5ca")
			elif entity.id == "observation-central": colour = Color("d6b8ef")
			_draw_marker(entity.position, colour, label, font,entity.id,false,entity.get("ownership_colour",Color.TRANSPARENT))
		elif entity.kind == "CONTACT":
			_draw_marker(entity.position, Color("e4a47c"), _contact_label(entity), font,entity.id)
		elif entity.kind == "CARRIER" and entity.design_type in ["T01", "T02", "T03", "T04", "T05"] and entity.position.x >= 240.0:
			var texture: Texture2D = TRUCK_ART if entity.design_type == "T01" and entity.get("affiliation",entity.owner) == "army-blue" else null
			_draw_marker(entity.position, Color("74c8ed") if entity.get("affiliation",entity.owner) == "army-blue" else Color("e48378"), _unit_label(entity) if zoom >= 8 or entity.id == selected_id else "", font,entity.id,true,Color.TRANSPARENT,texture)
		elif entity.kind == "PERSON" and not entity.get("aboard",false) and entity.rear_place != "Occupied" and entity.holder_id not in ["hq-berth", "hq-stock", "hq-reserve"]:
			_draw_marker(entity.position, Color("b8e9fa") if entity.owner == "army-blue" else Color("f2aea0"), _unit_label(entity) if entity.id == selected_id else "", font, entity.id)
	if profile: CallLog.record_duration(&"battlefield/battlefield_view.gd::_draw/marker_draw",Time.get_ticks_usec()-stage_started)
	if profile: stage_started = Time.get_ticks_usec()
	draw_string(font, area.position + Vector2(12, 22), "BATTLEFIELD  •  4,000 × 6,000 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8f2ec"))
	draw_line(area.position + Vector2(16, area.size.y - 24), area.position + Vector2(16 + 1000.0 * _scale(), area.size.y - 24), Color.WHITE, 3.0)
	draw_string(font, area.position + Vector2(16, area.size.y - 30), "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if profile: CallLog.record_duration(&"battlefield/battlefield_view.gd::_draw/legend",Time.get_ticks_usec()-stage_started)
	if CallLog.enabled: CallLog.record_duration(&"battlefield/battlefield_view.gd::_draw",Time.get_ticks_usec()-started_usec)


func _draw_marker(position: Vector2, colour: Color, title: String, font: Font, entity_id: String = "", carrier: bool = false, ownership_colour: Color = Color.TRANSPARENT, texture: Texture2D = null) -> void:
	var point := _screen(position)
	if not _map_rect().grow(-10).has_point(point): return
	var id := entity_id if not entity_id.is_empty() else title
	if ownership_colour.a > 0:
		draw_arc(point,8.0,0.0,TAU,32,Color("172633"),4.0)
		draw_arc(point,8.0,0.0,TAU,32,ownership_colour,2.0)
	if carrier:
		draw_rect(Rect2(point-Vector2(6,4),Vector2(12,8)),colour)
		if texture != null:
			var dimensions := texture.get_size()
			var extent: Vector2 = dimensions*minf(1.0,minf(12.0/dimensions.x,8.0/dimensions.y))
			draw_texture_rect(texture,Rect2(point-extent/2.0,extent),false)
		draw_rect(Rect2(point-Vector2(6,4),Vector2(12,8)),Color("172633"),false,1)
	else: draw_circle(point, 6.0 if id == selected_id else 4.0, colour)
	if id == selected_id: draw_arc(point, 10.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	if not title.is_empty() or id == selected_id: draw_string(font, point + Vector2(8, -6), title if not title.is_empty() else id, HORIZONTAL_ALIGNMENT_LEFT, maxf(0,_map_rect().end.x-point.x-8), 11, Color.WHITE)

func _site_label(id: String) -> String:
	var names := {"hq-berth":"Friendly HQ","enemy-hq":"Enemy HQ","resource-central":"Central resource","route-hub-west":"West hub","route-hub-east":"East hub","observation-central":"Observation","blue-delivery":"Forward supply stop"}
	if names.has(id): return names[id]
	for index in Farmland.OBJECTIVES.size():
		if Farmland.OBJECTIVES[index].id == id: return "Resource %d" % (index+1)
	return id

func _unit_label(entity: Dictionary) -> String:
	if entity.kind == "CARRIER":
		var label := "APC (T04)" if entity.design_type == "T04" else str(entity.design_type)
		if entity.design_type == "T02": label = "Personnel transport (T02)"
		return label+" · "+str(int(str(entity.id).get_slice("-",3))+1) if str(entity.id).begins_with("start-blue-vehicle-") else label
	if str(entity.id).begins_with("start-blue-squad-"):
		var number := int(str(entity.id).get_slice("-",3))
		var role: String = "Rifle %d" % (number+1) if number < 3 else ("Engineer" if number == 3 else "Medical")
		return role+" · "+str(int(str(entity.id).get_slice("-",5))+1)
	return entity.id

func _contact_label(entity: Dictionary) -> String:
	return "Reported "+str(entity.get("class","Unknown")) if zoom >= 8 or entity.id == selected_id else ""


func _refresh() -> void:
	CallLog.record(&"battlefield/battlefield_view.gd::_refresh")
	_refresh_queued = false
	if not is_visible_in_tree(): return
	queue_redraw()
	if _inspector == null or simulation == null: return
	var started_usec: int = Time.get_ticks_usec() if CallLog.enabled else 0
	var rear: RefCounted = simulation.rear
	_displayed_time = rear.time
	_displayed_speed = simulation.speed
	_displayed_planning_revision = simulation.planning_view_revision
	var text := inspection_text()
	if _inspector.text != text: _inspector.text = text
	if CallLog.enabled: CallLog.record_duration(&"battlefield/battlefield_view.gd::_refresh",Time.get_ticks_usec()-started_usec)

func inspection_text() -> String:
	# Shared permitted inspection for both 2D and opt-in 3D observation.
	var rear: RefCounted = simulation.rear
	var selected: Dictionary = Presentation.inspect(rear,selected_id)
	if selected.is_empty():
		selected_id = _default_objective()
		selected = Presentation.inspect(rear,selected_id)
	if _stop_selection_id != selected_id:
		_stop_selection_id = selected_id
		_stop_stock_id = ""
		_stop_stock.clear()
		_stop_stock_dirty = true
	var objective_id := selected_id if rear.objectives.objectives.has(selected_id) else _default_objective()
	var objective: Dictionary = rear.objectives.inspect(objective_id)
	var detail := ""
	if not selected.is_empty():
		var title: String = _site_label(selected.id) if selected.kind == "PLACE" else (_unit_label(selected) if selected.kind in ["PERSON","CARRIER"] else selected.id)
		detail = "%s\nPosition: (%.0f, %.0f) m" % [title, selected.position.x, selected.position.y]
		if selected.kind == "PLACE" and selected.get("friendly_forward_stop",false): detail += _forward_stop_detail(rear,selected.id)
		if selected.kind == "CONTACT": detail += "\nReported %s • %.1f s ago\nPosition uncertainty: %.0f m" % [selected.class,selected.age,selected.uncertainty_m]
		elif selected.kind == "CARRIER": detail += "\n"+_activity_label(selected)
		if selected.kind == "PERSON":
			detail += "\nDuty: %s | Health: %d" % [selected.assignment, selected.health]
			detail += _own_squad_detail(rear,selected)
			var held: Array = rear.ledger.entities_at(selected.id,["STOCK","WEAPON"],false)
			var engagement: Dictionary = SelectedEngagement.project(rear,selected,held)
			if not engagement.is_empty():
				detail += "\nPersonal movement: %s\nPersonal reload: %s" % [engagement.motion,engagement.reload]
				detail += "\nE02 directly held loose (including handled portions): %d · loaded in held weapons: %d" % [engagement.loose_e02,engagement.loaded_e02]
				detail += "\nHandling/assignment: "+_activity_label(selected)
				var receipt: Dictionary = engagement.receipt
				if not receipt.is_empty(): detail += "\nLatest confirmed transfer to this person: %d %s at %.1f s (past event)." % [receipt.quantity,receipt.type,receipt.at]
				else: detail += "\nLatest matching personal transfer: unavailable."
			else: detail += "\nPersonal engagement details unavailable."
			if rear.battlefield_operations != null:
				var collection: Dictionary = rear.battlefield_operations.rifle_collection.get(selected.get("duty_id",""),{})
				if not collection.is_empty():
					detail += "\nSupply collection: %s\nRendezvous: %s\n%s" % [collection.state,collection.stop,collection.blocker]
				var journey: Dictionary = rear.battlefield_operations.supply_travel.journey_status(str(selected.get("duty_id","")))
				if not journey.is_empty():
					var travel_mode := "On foot" if journey.get("mode","") == "Foot" else ("T02 transport: "+str(journey.get("hull","")) if journey.get("mode","") == "Transport" else "Choosing safe travel")
					detail += "\n%s · %s\nTravel destination: %s" % ["Going to supply" if journey.get("leg","") == "Collect" else "Returning to duty",travel_mode,journey.get("destination","")]
					var eta: float = float(journey.get("eta",-1.0))
					if is_finite(eta) and eta >= 0: detail += "\nJourney ETA: %.1f simulation seconds" % eta
					else: detail += "\nArrival estimate updates when the current travel step is ready."
				var motion: Dictionary = rear.battlefield_operations.motions.get(selected.id,{})
				if motion.get("purpose","") in ["Supply","Supply Return"]: detail += "\nCurrent foot-leg ETA: %.1f simulation seconds" % maxf(0,float(motion.deadline)-rear.time)
		if selected.kind == "CARRIER":
			detail += "\nCrew: %d seated | Passengers: %d\nFuel: %.1f | Health: %d" % [selected.get("crew",[]).size(),selected.get("passengers",[]).size(),selected.get("fuel",0),selected.get("health",0)]
			if rear.military.vehicles.has(selected.id):
				var needs: Dictionary = rear.military.vehicle_supply_needs(selected.id,selected)
				for type in needs.get("ammunition",{}):
					var ammo: Dictionary = needs.ammunition[type]
					var ammo_name: String = {"E02":"Rifle/MG rounds","E25":"Tank shells","E26":"Autocannon rounds"}.get(type,"Ammunition")
					var capacity: int = int(selected.vehicle_spec.rack_capacity[type])
					if ammo.target_set:
						detail += "\n%s (%s): %d / %d target · %d maximum\nStill needed: %d%s" % [ammo_name,type,ammo.aboard,ammo.target,capacity,ammo.needed," · Urgent" if ammo.urgent else ""]
					else: detail += "\n%s (%s): %d aboard · %d maximum; no active mission target." % [ammo_name,type,ammo.aboard,capacity]
				if needs.get("fuel_urgent",false): detail += "\nFuel needed for assigned route: %.2f" % float(needs.fuel_needed)
				elif needs.get("fuel_empty",false): detail += "\nFuel needed: tank empty."
			if rear.battlefield_operations != null:
				var action: String = str(rear.battlefield_operations.vehicle_execution.status.get(selected.id,"Waiting for crew, supply and a usable enemy report."))
				if action == "Waiting for a current compatible contact delivered to the actual parent.": action = "Waiting for a usable enemy report."
				detail += "\nMounted action: "+action
			for job in rear.military.troop_transport.jobs.values():
				if job.hull == selected.id:
					var movement: String = str(job.state)
					if movement == "Complete": movement = "Support move: complete" if job.kind == "Reposition" and job.dismount_place == "observation-central" else "Vehicle move: complete"
					detail += "\n%s\nBoarded %d/%d · Dismounted %d\n%s" % [movement,job.boarded,job.people.size(),job.dismounted,job.blocker]
			for station in selected.get("crew_by_station",{}):
				var crew: Dictionary = rear.ledger.inspect_person_status(selected.crew_by_station[station])
				detail += "\n%s · %s · Health %d" % [station,crew.qualification,crew.health]
			for id in selected.get("passengers",[]):
				var passenger: Dictionary = rear.ledger.inspect_person_status(id)
				detail += "\n%s · Health %d · %s" % [_unit_label(passenger),passenger.health,passenger.assignment]
	var objective_detail := "No objective registered."
	if not objective.is_empty():
		objective_detail = "%s · %s\n%s" % [_site_label(objective_id),objective.kind,Presentation.objective_feedback(objective,rear.PLAYER)]
	var declaration := ""
	if not rear.combat.world.scenario.is_empty(): declaration = "%s • Seed %d\n" % [rear.combat.world.scenario.family,rear.combat.world.scenario.seed]
	var text := "BATTLEFIELD\n%s\nTime: %.1f s  •  %s\nRequisition: %.0f\n\n%s\n\nSelected\n%s\n\nObjective rings: blue Friendly, red Enemy, gold Neutral.\n\nWheel: zoom  •  Middle drag: pan\nClick a marker to inspect.\nUse Rear base to manage production and dispatch." % [declaration,rear.time, "Paused" if simulation.speed == 0 else "%dx" % simulation.speed, simulation.receiving.requisition_balance(),objective_detail,detail]
	if not rear.combat.world.scenario.is_empty(): text += "\n\nTERRAIN KEY\nTan: fields and crops\nGreen: forest (dark = dense)\nGrey: rock; pale grey: towns\nBlue: water; teal: swamp\nCream lines: roads"
	if rear.battlefield_operations != null and rear.battlefield_operations.policy != null:
		var opening: Dictionary = rear.battlefield_operations.policy.presentation_view()
		text += "\n\nOPENING\n"+str(opening.status)
		for trip in opening.trips:
			text += "\n"+_unit_label(rear.ledger.inspect_entity(trip.hull,{},false))+": "+("Dismounted" if trip.dismounted else ("Transport active" if trip.started else (trip.blocker if not str(trip.blocker).is_empty() else "Awaiting orders")))
		for deployment in opening.get("deployments",[]):
			text += "\n\nAPC DEPLOYMENT\n%s · %s\nDestination: %s\n%s" % [deployment.hull,deployment.state,_site_label(deployment.stop),deployment.blocker]
			if not str(deployment.get("supply_stop","")).is_empty(): text += "\nSupply rendezvous: "+_site_label(str(deployment.supply_stop))
	return text




func _own_squad_detail(rear: RefCounted, person: Dictionary) -> String:
	if str(person.get("owner","")) != rear.PLAYER: return ""
	var squad_id := str(person.get("duty_id",""))
	var squad: Dictionary = rear.military.squads.get(squad_id,{})
	if squad.is_empty() or str(squad.get("owner","")) != rear.PLAYER or person.id not in squad.get("roster",[]): return "\nSquad: unavailable."
	var detail := "\nFriendly squad: %s · %s" % [squad_id,str(squad.get("kind","Unknown"))]
	var intent: Dictionary = rear.orders.intents.get(squad_id,{})
	if intent.get("state","") == "Acknowledged": detail += "\nAcknowledged squad intent: "+str(intent.get("action","Unavailable"))
	else: detail += "\nAcknowledged squad intent: unavailable or not yet acknowledged."
	var activity: String = str(rear.battlefield_operations.status.get(squad_id,"")) if rear.battlefield_operations != null else ""
	detail += "\nCurrent squad activity: "+(activity if not activity.is_empty() else "Unavailable.")
	return detail


func _bind_stop_stock() -> void:
	if _stop_stock_ledger != null and _stop_stock_ledger.stock_changed.is_connected(_on_stop_stock_changed):
		_stop_stock_ledger.stock_changed.disconnect(_on_stop_stock_changed)
	_stop_stock_ledger = simulation.rear.ledger if simulation != null else null
	_stop_stock_id = ""
	_stop_selection_id = ""
	_stop_stock.clear()
	_stop_stock_dirty = true
	if _stop_stock_ledger != null: _stop_stock_ledger.stock_changed.connect(_on_stop_stock_changed)

func _on_stop_stock_changed(_id: String) -> void:
	_stop_stock_dirty = true
	if not _stop_stock_id.is_empty() and selected_id == _stop_stock_id: _request_refresh()

func _exit_tree() -> void:
	if _stop_stock_ledger != null and _stop_stock_ledger.stock_changed.is_connected(_on_stop_stock_changed):
		_stop_stock_ledger.stock_changed.disconnect(_on_stop_stock_changed)
	_stop_stock_ledger = null


func _forward_stop_detail(rear: RefCounted, id: String) -> String:
	var refresh_stock := _stop_stock_dirty or _stop_stock_id != id
	var view: Dictionary = rear.forward_supply.observe_stop(id,rear.PLAYER,refresh_stock)
	if view.is_empty(): return "\nForward stop details unavailable."
	if refresh_stock:
		_stop_stock = view.get("stock",{}).duplicate(true)
		_stop_stock_id = id
		_stop_stock_dirty = false
	var lines: Array[String] = ["", "FRIENDLY FORWARD SUPPLY", "Loose stock physically held at this stop:"]
	if _stop_stock.is_empty(): lines.append("No friendly loose stock directly held at this stop.")
	else:
		for type in _stop_stock: lines.append("%s: %d" % [type,int(_stop_stock[type].quantity)])
	if not view.opening_available:
		lines.append("Opening freight planning: unavailable.")
	elif view.pending_freight.is_empty(): lines.append("No pending opening freight plan.")
	else: lines.append("Opening freight plan: %s" % str(view.pending_freight.get("message","Status unavailable.")))
	if view.deliveries.is_empty(): lines.append("No active indexed forward delivery at this stop.")
	else:
		for delivery: Dictionary in view.deliveries:
			var text := "Delivery · %s · %d %s requested\nCumulative loaded: %d · unloaded: %d" % [delivery.state,delivery.quantity,delivery.type,delivery.loaded,delivery.unloaded]
			if not str(delivery.blocker).is_empty(): text += "\n"+str(delivery.blocker)
			lines.append(text)
	if view.issues.is_empty(): lines.append("No active indexed local issue at this stop.")
	else:
		for issue: Dictionary in view.issues:
			var text := "%s issue · %s · %d %s requested" % [issue.kind,issue.state,issue.quantity,issue.type]
			if issue.has("issued"): text += " · %d transferred so far" % int(issue.issued)
			if issue.has("custody"): text += " · "+str(issue.custody)
			if not str(issue.blocker).is_empty(): text += "\n"+str(issue.blocker)
			lines.append(text)
	for receipt: Dictionary in view.receipts:
		lines.append("Latest %s transfer · %d %s at %.1f s (job %s, cumulative %d)" % [receipt.kind,receipt.quantity,receipt.type,receipt.at,receipt.job,receipt.count])
	lines.append("Transfers are past events, not current possession or loaded ammunition. Untracked interrupted rack work and earlier history are unavailable.")
	return "\n".join(lines)


func _activity_label(person: Dictionary) -> String:
	var rear: RefCounted = simulation.rear
	if person.kind == "PERSON":
		if person.get("assignment","") == "Dead": return "Dead"
		if person.get("assignment","") in ["Wounded","Recovery"]: return "Incapacitated: "+str(person.assignment)
		if person.get("health",0) <= 0: return "Incapacitated"
	if person.kind == "CARRIER":
		for job in rear.military.troop_transport.jobs.values():
			if job.hull == person.id and job.state != "Complete": return "Military transport: "+str(job.state)
		for job in rear.forward_supply.transport.jobs.values():
			if job.hull == person.id and job.state != "Complete": return "Supply delivery: "+str(job.state)
		return "Stopped"
	for job in rear.forward_supply.jobs.values():
		if job.state in ["Complete","Interrupted"]: continue
		if person.id == job.handler: return "Courier handoff: "+str(job.state)
		if person.id == job.recipient: return "Receiving local issue: "+str(job.state)
	for job in rear.military.troop_transport.jobs.values():
		if person.get("holder_id","") == job.hull and job.state != "Complete": return "Troop transport: "+str(job.state)
		if person.id in job.people and job.state == "Boarding": return "Awaiting physical boarding"
	if not str(person.get("crew_station","")).is_empty(): return "Vehicle crew: "+str(person.crew_station)
	return "At HQ / staging" if str(person.get("holder_id","")).contains("stage") else str(person.get("assignment","Stationary"))
