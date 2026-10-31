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
var army_issue_status: Label
var manual_issue: VBoxContainer
var issue_diagnostics: CheckButton


func _init(session: RefCounted) -> void:
	simulation = session


func _ready() -> void:
	_note("Forward delivery uses a staffed military T01, unloaded HQ stock and a declared forward stop. Loading, travel, unloading and return take time.")
	hull_choice = _option("Military T01")
	freight_choice = _option("HQ freight type (all available portions)")
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
	army_issue_status = _note("Local army issue waits for actual arrived freight and a safe receipt point.")
	issue_diagnostics = CheckButton.new()
	issue_diagnostics.text = "Diagnostics: individual issue and freight origins"
	add_child(issue_diagnostics)
	var manual_start := get_child_count()
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
	var manual_nodes: Array = get_children().slice(manual_start)
	manual_issue = VBoxContainer.new()
	add_child(manual_issue)
	for node in manual_nodes: node.reparent(manual_issue)
	manual_issue.hide()
	issue_diagnostics.toggled.connect(func(open: bool) -> void:
		manual_issue.visible = open
		refresh())
	stop_choice.item_selected.connect(func(_index: int) -> void: refresh())
	hull_choice.item_selected.connect(func(_index: int) -> void: refresh())
	freight_choice.item_selected.connect(func(_index: int) -> void: refresh())
	refresh()


func bind(next_simulation: RefCounted) -> void:
	simulation = next_simulation
	if is_node_ready():
		route_status.text = "Select a real truck, HQ freight and stop to preview the route."
		refresh()


func refresh() -> void:
	if not is_node_ready() or simulation == null: return
	var rear: RefCounted = simulation.rear
	var ledger: RefCounted = rear.ledger
	var entities: Array = ledger.snapshot().entities
	var hulls: Array[Dictionary] = []
	var freight: Array[Dictionary] = []
	var freight_types := {}
	var soldiers: Array[Dictionary] = []
	var automatic: RefCounted = _automatic_issue()
	for entity in entities:
		if entity.kind == "CARRIER" and entity.owner == rear.PLAYER and entity.design_type == "T01" and entity.fleet_domain == "Military" and rear.military.vehicles.has(entity.id):
			hulls.append({"id":entity.id,"label":"%s | %s | fuel %.1f" % [entity.id,entity.holder_id,entity.fuel]})
		elif entity.kind == "STOCK" and entity.holder_id == "hq-stock" and entity.owner == rear.PLAYER and entity.available > 0:
			if not freight_types.has(entity.design_type): freight_types[entity.design_type] = {"available":0,"portions":0}
			freight_types[entity.design_type].available += int(entity.available)
			freight_types[entity.design_type].portions += 1
		elif entity.kind == "PERSON" and entity.owner == rear.PLAYER and entity.assignment == "Formation Duty" and entity.health > 0 and entity.pending_assignment == "None" and str(entity.crew_station).is_empty() and ledger.inspect_entity(entity.holder_id).get("kind","") == "PLACE":
			for squad in rear.military.squads.values():
				if squad.state == "Active" and entity.id in squad.roster:
					soldiers.append({"id":entity.id,"label":"%s | %s | %s" % [entity.id,squad.id,str(entity.position)]})
					break
	for type in freight_types:
		var stock: Dictionary = freight_types[type]
		freight.append({"id":type,"label":"%s | %d available across %d portions" % [_freight_label(type),stock.available,stock.portions]})
	var stops: Array[Dictionary] = []
	for id in rear.forward_supply.delivery_stops:
		var place: Dictionary = ledger.inspect_entity(id)
		if place.get("kind","") == "PLACE": stops.append({"id":id,"label":"%s | %s" % [id,str(place.position)]})
	_sync(hull_choice,hulls)
	_sync(freight_choice,freight)
	_sync(stop_choice,stops)
	var limit: int = _freight_limit(entities,ledger.inspect_entity(_selected(hull_choice)),_selected(freight_choice))
	amount.max_value = maxi(1,limit)
	amount.tooltip_text = "%d whole units currently fit the available portions and this hull's payload; preview revalidates the actual load." % limit
	var loaders: Array[Dictionary] = []
	for id in rear.dispatch.free_hq_handlers(4):
		loaders.append({"id":id,"label":id})
	_sync(loader_choice,loaders)
	var unloaders: Array[Dictionary] = soldiers
	if automatic != null:
		unloaders = []
		var element: Dictionary = rear.military.squads.get(automatic.engineer_squad,{})
		for person in soldiers:
			if person.id in element.get("roster",[]): unloaders.append(person)
	loader_choice.disabled = automatic != null
	unloader_choice.disabled = automatic != null
	loader_choice.tooltip_text = "HQ assigns its actual available logistics staff." if automatic != null else ""
	unloader_choice.tooltip_text = "The army assigns a real member of the forward Engineer element." if automatic != null else ""
	_sync(unloader_choice,unloaders)
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
	if automatic != null:
		var local: Dictionary = automatic.snapshot()
		army_issue_status.text = "LOCAL ARMY ISSUE\nE02 available at the stop: %d\nPending member requests: %d\n%s" % [local.available_E02,local.requests.size(),local.status]
		for request in local.requests:
			army_issue_status.text += "\n%s needs %d · committed to couriers: %d" % [_member_label(request.person),request.needed,request.committed]
		army_issue_status.text += "\n\nAPC RACK ISSUE\nAutocannon rounds (E26) available at the stop: %d\n%s" % [int(local.get("available_E26",0)),str(local.get("rack_status","Waiting for actual local ammunition need."))]
		for entity in entities:
			if entity.kind == "CARRIER" and entity.owner == rear.PLAYER and entity.design_type == "T04" and rear.military.vehicles.has(entity.id):
				army_issue_status.text += "\nAPC %s aboard: %d / 180 initial target · 240 maximum (includes loaded)" % [entity.id,int(entity.ammunition.get("E26",0))]
		for request in local.get("rack_requests",[]):
			army_issue_status.text += "\nAPC %s initial allocation still needs %d · committed: %d" % [request.hull,request.needed,request.committed]
		for job in rear.forward_supply.rack_issue.jobs.values():
			army_issue_status.text += "\nAPC %s rack: %d/%d actually deposited · %s · %s" % [job.hull,job.issued,job.quantity,job.state,job.blocker]
		for job in rear.forward_supply.jobs.values():
			if job.state != "Complete": army_issue_status.text += "\nCourier %s: %s · %d %s · %s" % [_member_label(job.handler),job.state,job.quantity,job.type,job.blocker]
	else: army_issue_status.text = "Automatic local army issue is available in the Farmland and Towns playtest. Manual individual issue is under Diagnostics."
	if stops.is_empty(): route_status.text = "No forward stop has been declared in this session."

func _automatic_issue() -> RefCounted:
	if simulation == null or simulation.rear.battlefield_operations == null: return null
	var policy: RefCounted = simulation.rear.battlefield_operations.policy
	return policy.get("resupply") if policy != null and policy.get("resupply") is RefCounted else null

func _member_label(id: String) -> String:
	if not id.begins_with("start-blue-squad-"): return id
	var number := int(id.get_slice("-",3))
	var role: String = "Rifle %d" % (number+1) if number < 3 else ("Engineer" if number == 3 else "Medical")
	return role+" · "+str(int(id.get_slice("-",5))+1)


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
	var preview: Dictionary = rear.forward_supply.preview_delivery_type(_selected(hull_choice),_selected(freight_choice),int(amount.value),_selected(stop_choice),route.out,route.home,_selected(loader_choice),_selected(unloader_choice))
	if preview.ok:
		route_status.text = "%s: %.0f m round trip, about %.0f s travel plus handling. Fuel %.2f needed with reserve / %.2f in tank. Loaded mass about %.0f kg." % [route.name,preview.distance,preview.seconds,preview.required_fuel,preview.tank_fuel,preview.gross_kg]
	else:
		route_status.text = "%s refused: %s" % [route.name,preview.message]
	preview["inspection_only"] = true
	_emit(preview)


func _start_delivery() -> void:
	var route: Dictionary = _routes(_selected(hull_choice),_selected(stop_choice))
	_emit(simulation.rear.forward_supply.request_delivery_type(_selected(hull_choice),_selected(freight_choice),int(amount.value),_selected(stop_choice),route.out,route.home,_selected(loader_choice),_selected(unloader_choice)))


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
	message += "\n%s | %d requested across %d source portions" % [_freight_label(row.type),row.quantity,row.get("sources",[]).size()]
	if row.state in ["Outbound","Returning"]: message += " | route %.0f/%.0f m" % [row.route_distance,row.route_plan.distance]
	if issue_diagnostics.button_pressed:
		for source in row.get("sources",[]):
			message += "\n%s · origin %s · loaded %d/%d" % [source.stock,source.origin_id,source.loaded,source.quantity]
	if not str(row.blocker).is_empty(): message += "\n" + str(row.blocker)
	return message


func _freight_label(type: String) -> String:
	return "Autocannon rounds (E26)" if type == "E26" else type


func _freight_limit(entities: Array, hull: Dictionary, type: String) -> int:
	if hull.is_empty(): return 0
	var capacity: float = float(hull.get("vehicle_spec",{}).get("payload",0.0))
	var mass := 0.0
	var total := 0
	for stock in entities:
		if stock.kind != "STOCK" or stock.holder_id != "hq-stock" or stock.owner != simulation.rear.PLAYER or stock.design_type != type or stock.available <= 0: continue
		var count: int = mini(int(stock.available),maxi(0,int(floorf((capacity+0.000001-mass)/float(stock.unit_mass_kg)))))
		total += count
		mass += count*float(stock.unit_mass_kg)
		if count < int(stock.available): break
	return total


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
