extends GdUnitTestSuite
## Current automatic-logistics changes; component evidence is explicitly separate from ordinary play.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Session = preload("res://game/main/game_session.gd")
const Opening = preload("res://game/scenario/farmland_session.gd")
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
var _watchdog: Node

func before_test() -> void:
	_watchdog = Probe.new()
	add_child(_watchdog)
	_watchdog.action = {"label":"Rear logistics component: explicit stepping is not FPS evidence"}

func after_test() -> void:
	_watchdog.queue_free()
	await get_tree().process_frame

func _session(model: RefCounted) -> Node:
	var session: Node = auto_free(Session.new())
	add_child(session)
	session.set_physics_process(false)
	session.replace_simulation(model)
	return session

func _advance(model: RefCounted, seconds: int) -> void:
	# Explicit synthetic component stepping, not a native FPS observation.
	for _step in seconds:
		model.rear.advance_time(1.0)
		await get_tree().process_frame

func test_empty_field_workers_and_purchased_inputs_reach_a_real_completed_batch() -> void:
	var model := Base.new(false,false,false,Vector2(1640,91),false,{},true)
	var session := _session(model)
	var rear: RefCounted = model.rear
	assert_bool(model.receiving.buy_people().ok).is_true()
	assert_bool(model.receiving.buy_resources({"M01":6,"M02":3}).ok).is_true()
	assert_bool(rear.set_target("receiving",2,2).ok).is_true()
	assert_bool(rear.set_target("hauling",3,2).ok).is_true()
	var site: Dictionary = rear.construction.place("workshop",Vector2(65,55))
	assert_bool(site.ok).is_true()
	assert_bool(rear.construction.set_builders(site.id,2).ok).is_true()
	model.set_speed(1)
	session.notify_command()
	for _step in 600:
		await _advance(model,1)
		if rear.construction.instances[site.id].state == "Complete": break
	assert_str(rear.construction.instances[site.id].state).is_equal("Complete")
	assert_int(rear.actors.size()).is_equal(8)
	if not rear.construction.activities.has(site.id): return
	var activity: RefCounted = rear.construction.activities[site.id]
	assert_bool(activity.set_stock_target(1).ok).is_true()
	assert_bool(rear.set_target(site.id,2).ok).is_true()
	session.notify_command()
	for _step in 300:
		await _advance(model,1)
		if not activity.history.is_empty(): break
	_watchdog._save("workshop-result.json",{"time":rear.time,"facility":activity.snapshot(),"workforce":rear.workforce_snapshot(),"jobs":rear.jobs,"ledger":rear.ledger.snapshot(false)})
	assert_int(activity.history.size()).is_equal(1)
	assert_int(rear.ledger.physical_quantity_at(activity._spec.output_store,"E01",["WEAPON"])).is_equal(1)
	var rifle: Dictionary = rear.ledger.entities_at(activity._spec.output_store,["WEAPON"],false)[0]
	assert_str(rifle.owner).is_equal(rear.PLAYER)
	assert_str(rifle.ammo_type).is_equal("E02")
	assert_int(rifle.loaded_capacity).is_equal(30)
	assert_int(rifle.loaded_rounds).is_zero()
	assert_int(activity.snapshot().physical_output).is_equal(1)
	assert_float(rear.ledger.loose_stock_mass_at(activity._spec.output_store)).is_equal(4.0)
	assert_float(rear.ledger.loose_stock_summaries([activity._spec.output_store],rear.PLAYER)[activity._spec.output_store].mass).is_equal(4.0)
	var input_jobs := {}
	for job in rear.jobs:
		if job.destination == activity._spec.input_store:
			input_jobs[job.type] = int(input_jobs.get(job.type,0))+int(job.requested)
	assert_dict(input_jobs).is_equal({"M01":2,"M02":1})
	assert_int(rear.ledger.available_stock_at("receiving","M01")).is_equal(4)
	assert_int(rear.ledger.available_stock_at("receiving","M02")).is_equal(2)
	assert_array(rear.audit()).is_empty()

func test_intact_rifles_and_loaded_ammo_use_storage_capacity_without_becoming_loose_haul_stock() -> void:
	# Explicit isolated storage fixture, not a grant in ordinary acceptance.
	var model := Base.new(false,false,false)
	var rear: RefCounted = model.rear
	assert_bool(rear.ledger.add_weapon("stored-rifle","E01",4.0,"receiving",rear.PLAYER,"E02",30).ok).is_true()
	assert_bool(rear.ledger.add_stock("loaded-rounds","E02",10,0.02,"receiving",rear.PLAYER).ok).is_true()
	assert_bool(rear.ledger.load_rounds("stored-rifle","loaded-rounds",10).ok).is_true()
	var facts: Dictionary = rear.ledger.loose_stock_summaries(["receiving","stored-rifle"],rear.PLAYER)
	assert_float(facts.receiving.mass).is_equal_approx(4.2,0.000001)
	assert_float(facts["stored-rifle"].mass).is_equal_approx(0.2,0.000001)
	assert_float(rear.ledger.loose_stock_mass_at("receiving")).is_equal_approx(facts.receiving.mass,0.000001)
	assert_dict(facts.receiving.contents).is_empty()
	var before: Dictionary = rear.stores.duplicate(true)
	assert_bool(rear.set_store("receiving",true,4.0).ok).is_false()
	assert_dict(rear.stores).is_equal(before)
	assert_int(rear.ledger.physical_quantity_at("receiving","E01",["WEAPON"])).is_equal(1)
	assert_int(rear.ledger.loaded_rounds("stored-rifle")).is_equal(10)
	assert_array(rear.audit()).is_empty()

func test_two_requests_use_real_returning_transport_and_credit_unloading_once() -> void:
	# Declared prebuilt component, not the ordinary empty-field opening. Its
	# constructor supplies the GDD people/vehicles/stocks before observation.
	var model := Base.new(false,false,true)
	model.empty_field_opening = true
	var session := _session(model)
	var rear: RefCounted = model.rear
	assert_bool(rear.set_target("dispatch",2).ok).is_true()
	model.set_speed(1)
	var initial_hq: int = rear.ledger.available_stock_at("hq-stock","M08")
	var initial_rear: int = rear.ledger.available_stock_at("depot","M08")
	var used_hull := ""
	var initial_fuel := -1.0
	for cycle in 2:
		var request: Dictionary = session.automatic_logistics.request_delivery("M08",20)
		assert_bool(request.ok).is_true()
		for _step in 1400:
			await _advance(model,1)
			var row: Dictionary = session.automatic_logistics.requests[request.id]
			if not str(row.manifest).is_empty() and used_hull.is_empty():
				used_hull = rear.dispatch.manifests[row.manifest].hull
				initial_fuel = rear.ledger.inspect_entity(used_hull,{},false).fuel
			if row.state == "Complete": break
		var row: Dictionary = session.automatic_logistics.requests[request.id]
		assert_str(row.state).override_failure_message(str(row)).is_equal("Complete")
		assert_int(row.delivered).is_equal(20)
		assert_int(row.credited.size()).is_equal(1)
		assert_int(rear.dispatch.manifests.size()).is_equal(cycle+1)
	assert_int(rear.ledger.available_stock_at("hq-stock","M08")).is_equal(initial_hq+40)
	assert_int(rear.ledger.available_stock_at("depot","M08")).is_equal(initial_rear-40)
	if not used_hull.is_empty():
		assert_str(rear.vehicles.vehicles[used_hull].state).is_equal("Parked")
		assert_float(rear.ledger.inspect_entity(used_hull,{},false).fuel).is_less(initial_fuel)
	for manifest in rear.dispatch.manifests.values():
		assert_str(manifest.hull).is_equal(used_hull)
		assert_str(manifest.state).is_equal("Complete")
	assert_array(rear.audit()).is_empty()
	# A third actual trip checks cancellation after departure. Its loaded cargo
	# still arrives physically and must count when the player reopens demand.
	var sent: Dictionary = session.automatic_logistics.request_delivery("M08",20)
	var departed := false
	for _step in 600:
		await _advance(model,1)
		var row: Dictionary = session.automatic_logistics.requests[sent.id]
		if not row.manifest.is_empty() and rear.dispatch.manifests[row.manifest].departed:
			departed = true
			break
	assert_bool(departed).is_true()
	if not departed: return
	assert_bool(session.automatic_logistics.cancel_request(sent.id).ok).is_true()
	var reopened: Dictionary = session.automatic_logistics.request_delivery("M08",5)
	var in_transit: Dictionary = rear.ledger.snapshot()
	session.automatic_logistics.ensure_army_supply("M08",25)
	assert_int(session.automatic_logistics.requests.size()).is_equal(4)
	assert_int(session.automatic_logistics.requests[reopened.id].requested).is_equal(5)
	assert_dict(rear.ledger.snapshot()).is_equal(in_transit)
	assert_array(rear.audit()).is_empty()

func test_manual_promises_and_cancellation_hold_preserve_explicit_request_quantities() -> void:
	var model: RefCounted = Opening.create_empty_field(true)
	var session := _session(model)
	var logistics: Node = session.automatic_logistics
	var supply: RefCounted = model.rear.battlefield_operations.policy.resupply
	var before: Dictionary = model.rear.ledger.snapshot()
	var manual: Dictionary = logistics.request_delivery("E02",100)
	logistics.ensure_army_supply("E02",80)
	assert_int(logistics.requests.size()).is_equal(1)
	logistics.ensure_army_supply("E02",140)
	var automatic: String = logistics._army_requests.E02
	assert_int(logistics.requests[automatic].requested).is_equal(40)
	logistics.ensure_army_supply("E02",140)
	assert_int(logistics.requests.size()).is_equal(2)
	var extra: Dictionary = logistics.request_delivery("E02",20)
	logistics.ensure_army_supply("E02",200)
	assert_int(logistics.requests[automatic].requested).is_equal(80)
	assert_int(logistics.requests[manual.id].requested).is_equal(100)
	assert_int(logistics.requests[extra.id].requested).is_equal(20)
	assert_bool(logistics.cancel_request(automatic).ok).is_true()
	logistics.ensure_army_supply("E02",1000)
	assert_int(logistics.requests.size()).is_equal(3)
	# Explicitly reopening demand releases the hold and invalidates the source
	# owner's last notification; this marker is diagnostic notification state.
	supply._rear_shortages.E02 = 200
	var reopened: Dictionary = logistics.request_delivery("E02",25)
	assert_bool(supply._rear_shortages.has("E02")).is_false()
	logistics.ensure_army_supply("E02",200)
	var replacement: String = logistics._army_requests.E02
	assert_str(replacement).is_not_equal(automatic)
	assert_int(logistics.requests[replacement].requested).is_equal(55)
	assert_bool(logistics.requests[replacement].automatic).is_true()
	assert_int(logistics.requests[reopened.id].requested).is_equal(25)
	# Cancelling a manual promise must also prevent a renamed automatic copy.
	assert_bool(logistics.cancel_request(reopened.id).ok).is_true()
	logistics.ensure_army_supply("E02",300)
	assert_int(logistics.requests.size()).is_equal(5)
	assert_int(logistics.requests[replacement].requested).is_equal(55)
	assert_dict(model.rear.ledger.snapshot()).is_equal(before)
	assert_array(model.rear.audit()).is_empty()
	var next_model: RefCounted = Opening.create_empty_field(true)
	session.replace_simulation(next_model)
	var next_before: Dictionary = next_model.rear.ledger.snapshot()
	logistics.ensure_army_supply("E02",10)
	assert_int(logistics.requests.size()).is_equal(1)
	assert_int(logistics.requests.values()[0].requested).is_equal(10)
	assert_dict(next_model.rear.ledger.snapshot()).is_equal(next_before)
	assert_dict(model.rear.ledger.snapshot()).is_equal(before)

func test_ordinary_request_and_cancel_buttons_do_not_create_goods_or_vehicles() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	await runner.simulate_frames(3)
	var base: Control = game._base
	# Navigate using real controls, including the new embedded tab header.
	var supplies: Button
	for button in game._shell.find_children("*","Button",true,false):
		if button.text == "Supplies": supplies = button; break
	assert_object(supplies).is_not_null()
	if supplies == null: return
	await _press(runner,supplies)
	var tabs: TabContainer
	# Resolve the tab owner from the actual child, independent of card wrappers.
	var owner: Node = base.army_request_rows
	while owner != null and not owner is TabContainer: owner = owner.get_parent()
	if owner is TabContainer: tabs = owner
	assert_object(tabs).is_not_null()
	if tabs == null: return
	var bar := tabs.get_tab_bar()
	_click_at(bar.get_viewport(),bar.global_position+bar.get_tab_rect(2).get_center())
	await runner.simulate_frames(2)
	var ledger: RefCounted = base.simulation.rear.ledger
	var before: Dictionary = ledger.snapshot()
	await _press(runner,base.army_request_button)
	assert_int(game._session.automatic_logistics.requests.size()).is_equal(1)
	assert_dict(ledger.snapshot()).is_equal(before)
	await _press(runner,base.army_request_cancel)
	var row: Dictionary = game._session.automatic_logistics.requests.values()[0]
	assert_bool(row.cancelled).is_true()
	assert_str(row.state).is_equal("Cancelled")
	assert_dict(ledger.snapshot()).is_equal(before)

func _press(runner: GdUnitSceneRunner, button: Control) -> void:
	assert_bool(button.is_visible_in_tree()).is_true()
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await runner.simulate_frames(2)
	_click_at(button.get_viewport(),button.get_global_rect().get_center())
	await runner.simulate_frames(2)

func _click_at(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		viewport.push_input(event,true)
