extends VBoxContainer
## Ordinary player controls for one real T01 delivery and subsequent local issue.
signal result_reported(result: Dictionary)

var simulation: RefCounted
var hull_choice: OptionButton
var freight_choice: OptionButton
var stop_choice: OptionButton
var loader_choice: OptionButton
var unloader_choice: OptionButton
var amount: SpinBox
var route_status: Label
var delivery_rows: ItemList
var delivery_ids: Array[String] = []
var delivery_status: Label
var local_stock_choice: OptionButton
var recipient_choice: OptionButton
var handler_choice: OptionButton
var local_amount: SpinBox
var issue_rows: ItemList
var issue_ids: Array[String] = []
var issue_status: Label


func _init(session: RefCounted) -> void:
	simulation = session


func _ready() -> void:
	_note("Forward delivery uses a staffed military T01, unloaded HQ stock and a declared forward stop. Loading, travel, unloading and return take time.")
	hull_choice = _option("Military T01")
	freight_choice = _option("Available HQ freight")
	stop_choice = _option("Declared forward stop")
	loader_choice = _option("HQ logistics loader")
	unloader_choice = _option("Soldier at destination for unloading")
	amount = _spin("Whole freight units",5000)
	_button("Preview route, load and fuel",_preview)
	_button("Start physical delivery",_start_delivery)
	route_status = _note("Select a real truck, HQ freight and stop to preview the route.")
	_note("Deliveries")
	delivery_rows = _list()
	_button("Pause selected delivery",_pause_delivery)
	_button("Resume selected delivery",_resume_delivery)
	delivery_status = _note("A loaded truck remains physical and visible while travelling.")
	_separator()
	_note("Issue arrived freight to a soldier")
	_note("After the truck unloads, a second active soldier carries actual stock to the selected recipient. Loose rounds still need a real reload.")
	local_stock_choice = _option("Arrived stock at selected stop")
	recipient_choice = _option("Recipient")
	handler_choice = _option("Local handler")
	local_amount = _spin("Whole units to issue",1000)
	_button("Issue at forward stop",_start_issue)
	issue_rows = _list()
	_button("Pause selected local issue",_pause_issue)
	_button("Resume selected carried issue",_resume_issue)
	issue_status = _note("")
	stop_choice.item_selected.connect(func(_index: int) -> void: refresh())
	refresh()


func bind(next_simulation: RefCounted) -> void:
	simulation = next_simulation
	if is_node_ready(): refresh()


func refresh() -> void:
	if not is_node_ready() or simulation == null: return
	var rear: RefCounted = simulation.rear
	var ledger: RefCounted = rear.ledger
	var entities: Array = ledger.snapshot().entities
	var hulls: Array[Dictionary] = []
	var freight: Array[Dictionary] = []
	var soldiers: Array[Dictionary] = []
	for entity in entities:
		if entity.kind == "CARRIER" and entity.owner == rear.PLAYER and entity.design_type == "T01" and entity.fleet_domain == "Military" and rear.military.vehicles.has(entity.id):
			hulls.append({"id":entity.id,"label":"%s | %s | fuel %.1f" % [entity.id,entity.holder_id,entity.fuel]})
		elif entity.kind == "STOCK" and entity.holder_id == "hq-stock" and entity.owner == rear.PLAYER and entity.available > 0:
			freight.append({"id":entity.id,"label":"%s %s | %d available | %.2f kg each" % [entity.id,entity.design_type,entity.available,entity.unit_mass_kg]})
		elif entity.kind == "PERSON" and entity.owner == rear.PLAYER and entity.assignment == "Formation Duty" and entity.health > 0 and entity.pending_assignment == "None" and str(entity.crew_station).is_empty() and ledger.inspect_entity(entity.holder_id).get("kind","") == "PLACE":
			for squad in rear.military.squads.values():
				if squad.state == "Active" and entity.id in squad.roster:
					soldiers.append({"id":entity.id,"label":"%s | %s | %s" % [entity.id,squad.id,str(entity.position)]})
					break
	var stops: Array[Dictionary] = []
	for id in rear.forward_supply.delivery_stops:
		var place: Dictionary = ledger.inspect_entity(id)
		if place.get("kind","") == "PLACE": stops.append({"id":id,"label":"%s | %s" % [id,str(place.position)]})
	_sync(hull_choice,hulls)
	_sync(freight_choice,freight)
	_sync(stop_choice,stops)
	var loaders: Array[Dictionary] = []
	for id in rear.dispatch.free_hq_handlers(4):
		loaders.append({"id":id,"label":id})
	_sync(loader_choice,loaders)
	_sync(unloader_choice,soldiers)
	var stop_id: String = _selected(stop_choice)
	var nearby: Array[Dictionary] = []
	var arrived: Array[Dictionary] = []
	if not stop_id.is_empty():
		var stop: Dictionary = ledger.inspect_entity(stop_id)
		for person in soldiers:
			var actual: Dictionary = ledger.inspect_entity(person.id)
			if actual.position.distance_to(stop.position) <= 20.0: nearby.append(person)
		for entity in entities:
			if entity.kind == "STOCK" and entity.holder_id == stop_id and entity.owner == rear.PLAYER and entity.available > 0:
				arrived.append({"id":entity.id,"label":"%s %s | %d available" % [entity.id,entity.design_type,entity.available]})
	_sync(local_stock_choice,arrived)
	_sync(recipient_choice,nearby)
	_sync(handler_choice,nearby)
	_sync_jobs(delivery_rows,delivery_ids,rear.forward_supply.transport.jobs)
	_sync_jobs(issue_rows,issue_ids,rear.forward_supply.jobs)
	var delivery_id: String = _selected_row(delivery_rows,delivery_ids)
	delivery_status.text = "No delivery selected." if delivery_id.is_empty() else _delivery_detail(rear.forward_supply.transport.jobs[delivery_id],ledger)
	var issue_id: String = _selected_row(issue_rows,issue_ids)
	issue_status.text = "Arrived stock stays at the stop until a real local issue." if issue_id.is_empty() else _issue_detail(rear.forward_supply.jobs[issue_id])
	if stops.is_empty(): route_status.text = "No forward stop has been declared in this session."


func _routes(hull_id: String, stop_id: String) -> Dictionary:
	var rear: RefCounted = simulation.rear
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id)
	if hull.is_empty() or stop.is_empty(): return {"out":[],"home":[],"name":"No route"}
	var entry: Dictionary = rear.forward_supply.delivery_stops.get(stop_id,{})
	var out: Array = entry.get("outbound_points",[])
	var home: Array = entry.get("return_points",[])
	if out.is_empty():
		return {"out":[hull.position,stop.position],"home":[stop.position,rear.ledger.inspect_entity("hq-berth").position],"name":"Direct candidate"}
	return {"out":out.duplicate(),"home":home.duplicate(),"name":"Scenario route"}


func _preview() -> void:
	var rear: RefCounted = simulation.rear
	var route: Dictionary = _routes(_selected(hull_choice),_selected(stop_choice))
	var preview: Dictionary = rear.forward_supply.preview_delivery(_selected(hull_choice),_selected(freight_choice),int(amount.value),_selected(stop_choice),route.out,route.home,_selected(loader_choice),_selected(unloader_choice))
	if preview.ok:
		route_status.text = "%s: %.0f m round trip, about %.0f s travel plus handling. Fuel %.2f needed with reserve / %.2f in tank. Loaded mass about %.0f kg." % [route.name,preview.distance,preview.seconds,preview.required_fuel,preview.tank_fuel,preview.gross_kg]
	else:
		route_status.text = "%s refused: %s" % [route.name,preview.message]
	_emit(preview)


func _start_delivery() -> void:
	var route: Dictionary = _routes(_selected(hull_choice),_selected(stop_choice))
	_emit(simulation.rear.forward_supply.request_delivery(_selected(hull_choice),_selected(freight_choice),int(amount.value),_selected(stop_choice),route.out,route.home,_selected(loader_choice),_selected(unloader_choice)))


func _pause_delivery() -> void:
	var id: String = _selected_row(delivery_rows,delivery_ids)
	_emit(simulation.rear.forward_supply.interrupt_delivery(id))


func _resume_delivery() -> void:
	var id: String = _selected_row(delivery_rows,delivery_ids)
	var row: Dictionary = simulation.rear.forward_supply.transport.jobs.get(id,{})
	if row.is_empty(): _emit({"ok":false,"message":"Select an existing delivery."}); return
	var phase: String = str(row.paused_state) if row.state == "Paused" else str(row.get("stopped_phase",""))
	if phase in ["Loading","Unloading"]:
		_emit(simulation.rear.forward_supply.resume_delivery(id))
		return
	var hull: Dictionary = simulation.rear.ledger.inspect_entity(row.hull)
	var stop: Dictionary = simulation.rear.ledger.inspect_entity(row.stop)
	var hq: Vector2 = simulation.rear.ledger.inspect_entity("hq-berth").position
	var next_point: Vector2 = stop.position if phase == "Outbound" else hq
	var candidate: Array = [hull.position,next_point]
	_emit(simulation.rear.forward_supply.resume_delivery(id,candidate,row.return_points) if phase == "Outbound" else simulation.rear.forward_supply.resume_delivery(id,[],candidate))


func _start_issue() -> void:
	_emit(simulation.rear.forward_supply.start_issue(_selected(local_stock_choice),_selected(recipient_choice),_selected(handler_choice),int(local_amount.value),_selected(stop_choice)))


func _pause_issue() -> void:
	_emit(simulation.rear.forward_supply.interrupt(_selected_row(issue_rows,issue_ids)))


func _resume_issue() -> void:
	_emit(simulation.rear.forward_supply.resume_issue(_selected_row(issue_rows,issue_ids)))


func _delivery_detail(row: Dictionary, ledger: RefCounted) -> String:
	var hull: Dictionary = ledger.inspect_entity(row.hull)
	var message := "%s | %s at %s | fuel %.2f | loaded %d/%d | unloaded %d/%d" % [row.id,row.state,str(hull.position),hull.fuel,row.loaded,row.quantity,row.unloaded,row.quantity]
	if row.state in ["Outbound","Returning"]: message += " | route %.0f/%.0f m" % [row.route_distance,row.route_plan.distance]
	if not str(row.blocker).is_empty(): message += "\n" + str(row.blocker)
	return message


func _issue_detail(row: Dictionary) -> String:
	return "%s | %s | %d units from %s to %s via %s%s" % [row.id,row.state,row.quantity,row.stock,row.recipient,row.handler,"\n"+str(row.blocker) if not str(row.blocker).is_empty() else ""]


func _emit(result: Dictionary) -> void:
	result_reported.emit(result)
	refresh()


func _sync(option: OptionButton, entries: Array[Dictionary]) -> void:
	var same_ids: bool = option.item_count == entries.size()
	if same_ids:
		for index in entries.size():
			if str(option.get_item_metadata(index)) != str(entries[index].id): same_ids = false; break
	if same_ids:
		for index in entries.size():
			if option.get_item_text(index) != entries[index].label: option.set_item_text(index,entries[index].label)
		return
	var prior: String = _selected(option)
	option.clear()
	for entry in entries:
		option.add_item(entry.label)
		option.set_item_metadata(option.item_count-1,entry.id)
		if entry.id == prior: option.select(option.item_count-1)
	if option.selected < 0 and option.item_count > 0: option.select(0)


func _sync_jobs(list: ItemList, ids: Array[String], jobs: Dictionary) -> void:
	var keys: Array = jobs.keys()
	if ids == keys:
		for index in ids.size():
			var current: Dictionary = jobs[ids[index]]
			var title := "%s | %s | %s" % [ids[index],str(current.state),str(current.get("blocker",""))]
			if list.get_item_text(index) != title: list.set_item_text(index,title)
		return
	var prior: String = _selected_row(list,ids)
	list.clear()
	ids.clear()
	for id in jobs:
		var row: Dictionary = jobs[id]
		ids.append(id)
		list.add_item("%s | %s | %s" % [id,str(row.state),str(row.get("blocker",""))])
		if id == prior: list.select(ids.size()-1)
	if list.get_selected_items().is_empty() and not ids.is_empty(): list.select(ids.size()-1)


func _selected(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option != null and option.selected >= 0 else ""


func _selected_row(list: ItemList, ids: Array[String]) -> String:
	return ids[list.get_selected_items()[0]] if list != null and not list.get_selected_items().is_empty() else ""


func _option(title: String) -> OptionButton:
	_note(title)
	var choice := OptionButton.new()
	add_child(choice)
	return choice


func _spin(title: String, maximum: int) -> SpinBox:
	_note(title)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = maximum
	spin.step = 1
	spin.value = 10
	add_child(spin)
	return spin


func _button(title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	add_child(button)
	return button


func _list() -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size.y = 90
	add_child(list)
	return list


func _note(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _separator() -> void:
	var line := HSeparator.new()
	add_child(line)
