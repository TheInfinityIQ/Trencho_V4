extends SceneTree
## Normal-scene command path with explicit component time; no grants, hull fixtures or FPS claim.
const GameScene = preload("res://game/main/main.tscn")
var _game: Control
var _base: Control
var _model: RefCounted
var _sites := {}

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		_diagnose(message)
		quit(1)
	return condition

func _diagnose(message: String) -> void:
	if _model == null: return
	var sites := []
	for row in _model.rear.construction.instances.values():
		sites.append({"id":row.id,"kind":row.kind,"state":row.state,"progress":row.progress,"blocker":row.blocker,"materials":_model.rear.ledger.available_stock_at(row.id,"M11")})
	print("TRUCK_FAILURE " + JSON.stringify({"message":message,"time":_model.rear.time,"money":_model.receiving.requisition_balance(),"sites":sites,"hauls":_model.rear.jobs,"courses":_model.rear.training.rows,"vehicles":_model.rear.vehicles.vehicles,"requests":_game._session.automatic_logistics.requests}))
	print("TRUCK_STAFFING " + JSON.stringify(_model.rear.requests))
	for id in _model.rear.actors:
		var person: Dictionary = _model.rear.ledger.inspect_person_status(id)
		if person.basic_training: print("TRUCK_QUALIFIED " + JSON.stringify(person))

func _frames(count: int = 2) -> void:
	for _frame in count: await process_frame

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found := _button(child,caption)
		if found != null: return found
	return null

func _press(caption: String) -> bool:
	var button := _button(_base,caption)
	if not _require(button != null and not button.disabled,"A usable visible button is required: " + caption): return false
	button.pressed.emit()
	await _frames()
	return true

func _select_metadata(option: OptionButton, id: String) -> bool:
	for index in option.item_count:
		if str(option.get_item_metadata(index)) == id and not option.is_item_disabled(index):
			option.select(index)
			option.item_selected.emit(index)
			return true
	return _require(false,"A current selectable choice is required: " + id)

func _advance(until: Callable, ceiling: int, stage: String) -> bool:
	print("TRUCK_STAGE " + stage + " at " + str(_model.rear.time))
	for elapsed in range(0,ceiling,5):
		if until.call(): return true
		# The owner still settles every physical boundary inside this interval.
		# This component check samples UI between finite chunks, not at native1x.
		_model.rear.advance_time(mini(5,ceiling-elapsed))
		await process_frame
		if elapsed % 300 == 0: print("TRUCK_PROGRESS " + stage + " at " + str(_model.rear.time))
	return _require(bool(until.call()),"Physical progression did not complete: " + stage)

func _place(kind: String, point: Vector2) -> bool:
	_base.show_panel("Build")
	_base.select_build_kind(kind)
	var count: int = _model.rear.construction.instances.size()
	_base.confirm_build_at(point)
	await _frames()
	if not _require(_model.rear.construction.instances.size() == count+1,"Normal placement must admit " + kind): return false
	var id: String = _model.rear.construction.instances.keys()[-1]
	_sites[kind] = id
	_base.base_map.selected.emit("site",id)
	await _frames()
	_base.construction_builders.value = 4
	return await _press("Set builders")

func _staff(kind: String, count: int) -> bool:
	_base.base_map.selected.emit("site",str(_sites[kind]))
	await _frames()
	_base.context_staff.value = count
	await _frames()
	return _require(int(_model.rear.requests[_sites[kind]].target) == count,"Actual facility staffing must follow its control: " + kind)

func _production(kind: String, count: int) -> bool:
	_base.base_map.selected.emit("site",str(_sites[kind]))
	await _frames()
	_base.stock_target.value = count
	_base.mode.select(0)
	return await _press("Apply production order")

func _run() -> void:
	_game = GameScene.instantiate()
	root.add_child(_game)
	_game._session.set_physics_process(false)
	_base = _game._base
	_model = _base.simulation
	# Isolate the factory/logistics command chain from wall-clock waiting. These
	# are real purchases and physical owners; no battlefield journey is certified.
	_model.cancel_live_planning()
	if not _require(_base.get("training_site") is OptionButton and _base.get("instructor_hire_button") is Button and _base.get("vehicle_fuel_person") is OptionButton,"Training needs actual school/instructor controls, and trucks need a separate fuel-worker choice."): return
	if not _require(_game._shell._navigation_buttons.has("Train") and _game._shell._navigation_buttons.has("Vehicles"),"Training and Vehicles must be directly reachable from normal navigation."): return
	if not _require(_model.empty_field_opening and _model.receiving.rear_population() == 0 and _model.receiving.requisition_balance() == 2500,"Keep the approved empty-field opening."): return
	_base.show_panel("Supplies")
	await _frames()
	if not await _press("Hire 8 workers · 140 requisition · 90 s travel"): return
	for type in {"M01":392,"M02":80,"M03":2,"M04":560,"M08":25}:
		_base.cart[type].value = {"M01":392,"M02":80,"M03":2,"M04":560,"M08":25}[type]
	if not await _press("Buy resources"): return
	_game._shell._navigation_buttons.Train.pressed.emit()
	await _frames()
	if not _require(_base.instructor_hire_button.is_visible_in_tree() and not _base.instructor_hire_button.disabled,"The first instructor must be hireable through ordinary Training."): return
	_base.instructor_hire_button.pressed.emit()
	_game._session.set_speed(1)
	if not _require(_model.rear.set_target("receiving",2,2).ok and _model.rear.set_target("hauling",4,2).ok,"Request actual receiving and hauling workers."): return
	if not await _advance(func() -> bool: return _model.receiving.rear_population() >= 9,600,"first workers and instructor arrival"): return
	_base.show_panel("Supplies")
	_base._supply_views.current_tab = 0
	await _frames()
	if not await _press("Hire 8 workers · 140 requisition · 90 s travel"): return
	if not await _advance(func() -> bool: return _model.receiving.rear_population() == 17,600,"second worker arrival"): return
	if not await _press("Hire 8 workers · 140 requisition · 90 s travel"): return
	if not await _advance(func() -> bool: return _model.receiving.rear_population() == 25,600,"third purchased worker cohort"): return
	if not _require(_model.rear.set_target("hauling",8,2).ok,"Use the purchased shared workforce for expansion hauling."): return
	# Vehicle Works intentionally occupies an old template Workshop location.
	# The empty-field game must use only actual player-created geometry.
	for entry in [["materials",Vector2(50,35)],["munitions",Vector2(85,35)],["training",Vector2(55,120)],["vehicle_works",Vector2(125,25)],["park",Vector2(170,145)],["dispatch",Vector2(215,120)]]:
		if not await _place(str(entry[0]),entry[1]): return
	if not await _advance(func() -> bool: return _model.rear.construction.instances[_sites.materials].state == "Complete",2400,"Materials Plant construction"): return
	if not await _staff("materials",2) or not await _production("materials",1200): return
	if not await _advance(func() -> bool:
		for id in _sites.values():
			if _model.rear.construction.instances[id].state != "Complete": return false
		return true,7200,"expansion supplied by newly manufactured Building Materials"): return
	if not _require(not _model.rear.construction.activities[_sites.materials].history.is_empty(),"Expansion must actually manufacture new Building Materials."): return
	if not await _staff("munitions",1) or not await _production("munitions",200): return
	if not await _staff("vehicle_works",2) or not await _production("vehicle_works",1): return
	if not await _press("Accept heavy order"): return
	_game._shell._navigation_buttons.Train.pressed.emit()
	await _frames()
	if not _select_metadata(_base.training_site,str(_sites.training)): return
	_base.instructor_count.value = 1
	await _frames()
	if not _require(_model.rear.requests[_sites.training].target == 1,"Instructor target must address the built school's actual duty."): return
	# Make the requested specialist duty outrank our earlier high-priority
	# generic hauling, using the same normal Jobs control available to players.
	_base.show_panel("Workers/Jobs")
	await _frames(60)
	if not _require(_base.workforce_panel.controls.has(_sites.training),"The built school must have a normal staffing-priority control."): return
	var priority: OptionButton = _base.workforce_panel.controls[_sites.training].priority
	priority.select(3)
	priority.item_selected.emit(3)
	if not await _advance(func() -> bool: return _model.rear.training.instructors().size() == 1,1200,"actual instructor reporting"): return
	var instructor: String = _model.rear.training.instructors()[0]
	_game._shell._navigation_buttons.Train.pressed.emit()
	await _frames()
	if not _select_metadata(_base.training_course,"P08"): return
	_base.training_count.value = 1
	if not await _press("Request course"): return
	if not _require(_model.rear.training.instructors().has(instructor) and _model.rear.training.rows[-1].person_id != instructor,"A queued specialist course must not take the school's only instructor."): return
	if not _select_metadata(_base.training_course,"P01"): return
	_base.training_count.value = 1
	if not await _press("Request course"): return
	if not await _advance(func() -> bool:
		for course in _model.rear.training.rows:
			if course.course == "P01" and course.state == "Completed": return true
		return false,1800,"actual basic training"): return
	if not await _advance(func() -> bool:
		for course in _model.rear.training.rows:
			if course.course == "P08" and course.state == "Completed": return true
		return false,1800,"actual Driver training"): return
	var driver := ""
	for course in _model.rear.training.rows:
		if course.course == "P08" and course.state == "Completed": driver = course.person_id
	if not await _advance(func() -> bool: return _model.rear.vehicles.vehicles.size() == 1,2400,"transport truck manufacture"): return
	var hull: String = _model.rear.vehicles.vehicles.keys()[0]
	_game._shell._navigation_buttons.Vehicles.pressed.emit()
	await _frames()
	_base.vehicle_rows.select(_base.vehicle_ids.find(hull))
	_base.vehicle_rows.item_selected.emit(_base.vehicle_ids.find(hull))
	if not _select_metadata(_base.vehicle_person,driver): return
	if not await _press("Report and board selected station"): return
	if not await _advance(func() -> bool: return _model.rear.ledger.inspect_entity(hull,{},false).crew_by_station.get("Driver","") == driver,1200,"Driver reporting and boarding"): return
	var fuel_worker := ""
	for id in _model.rear.actors:
		var person: Dictionary = _model.rear.ledger.inspect_person_status(id)
		if person.assignment == "Available" and person.pending_assignment == "None" and person.crew_station.is_empty(): fuel_worker = id; break
	if not _require(not fuel_worker.is_empty(),"Use an actual available worker for fuel handling."): return
	if not _select_metadata(_base.vehicle_fuel_person,fuel_worker): return
	_base.vehicle_fuel_units.value = 25
	if not await _press("Carry purchased fuel into this tank"): return
	if not await _advance(func() -> bool: return _model.rear.ledger.inspect_entity(hull,{},false).fuel >= 25.0,1200,"actual purchased fuel carry"): return
	if not await _press("Drive SAME F10 hull to promised F11 place"): return
	if not await _advance(func() -> bool: return _model.rear.vehicles.vehicles[hull].state == "Parked",1200,"same manufactured hull reaches parking"): return
	if not _require(_model.rear.set_target(str(_sites.dispatch),2,2).ok,"Staff the actual Logistics Centre."): return
	if not await _advance(func() -> bool: return _model.rear.ledger.available_stock_at(_model.rear.construction.instances[_sites.munitions].output_store,"E02") >= 200,1200,"new ammunition manufacture"): return
	for cycle in 2:
		_base.show_panel("Supplies")
		_base._supply_views.current_tab = 2
		await _frames()
		_base.army_request_count.value = 100
		if not await _press("Request delivery to HQ"): return
		var request: String = _game._session.automatic_logistics.requests.keys()[-1]
		if not await _advance(func() -> bool: return _game._session.automatic_logistics.requests[request].state == "Complete" and _model.rear.vehicles.vehicles[hull].state == "Parked",3600,"new ammunition delivery and same-hull return " + str(cycle+1)): return
		if not _require(_game._session.automatic_logistics.requests[request].delivered == 100,"Each request must credit only its actual HQ receipt."): return
	if not _require(_model.rear.ledger.available_stock_counts(["hq-stock"],"E02",_model.rear.PLAYER)["hq-stock"] == 6200,"Both loads of newly manufactured ammunition must reach HQ."): return
	if not _require(_model.receiving.requisition_balance() >= 0 and _model.audit().is_empty(),"The complete purchased/manufactured chain must preserve budget and physical invariants."): return
	print(JSON.stringify({"result":"PASS","scope":"Ordinary main-scene controls/commands with explicit component time: actual worker/instructor/resource purchases, six constructed facilities using manufactured M11, basic/Driver training, newly manufactured fueled truck, two actual newly manufactured ammunition loads and same-hull HQ returns. No grants, diagnostic hull/site setup, natural army shortage, native-input or FPS certification.","simulation_seconds":_model.rear.time,"requisition_left":_model.receiving.requisition_balance(),"hull":hull}))
	_game.queue_free()
	await _frames()
	quit(0)
