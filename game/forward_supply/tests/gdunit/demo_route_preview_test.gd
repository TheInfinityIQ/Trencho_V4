extends GdUnitTestSuite
## Ordinary authored session and production UI/service; no replacement world or stock.
const Diagnostics = preload("res://game/forward_supply/tests/gdunit/happy_path_diagnostics.gd")


func test_ordinary_supply_preview_and_successful_delivery(_timeout := 320000) -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(2)
	var supply := _button(main,"Supply")
	assert_object(supply).is_not_null()
	if supply == null: return
	supply.pressed.emit()
	await runner.simulate_frames(1)
	var base: Control = main.get("_base")
	var session: RefCounted = base.get("simulation")
	var panel: VBoxContainer = base.get("forward_delivery_panel")
	assert_bool(panel.is_visible_in_tree()).is_true()
	assert_int(session.speed).is_zero()
	var freight: OptionButton = panel.get("freight_choice")
	var found_ammunition := false
	for index in freight.item_count:
		if str(freight.get_item_metadata(index)) == "E02":
			freight.select(index)
			freight.item_selected.emit(index)
			found_ammunition = true
			break
	assert_bool(found_ammunition).is_true()
	if not found_ammunition: return
	var preview := _button(panel,"Preview route, load and fuel")
	assert_object(preview).is_not_null()
	if preview == null: return
	var before: Dictionary = session.rear.ledger.snapshot()
	var jobs: Dictionary = session.rear.forward_supply.transport.jobs.duplicate(true)
	var results: Array[Dictionary] = []
	panel.result_reported.connect(func(result: Dictionary) -> void: results.append(result))
	preview.pressed.emit()
	assert_int(results.size()).is_equal(1)
	if results.is_empty(): return
	var result: Dictionary = results.back()
	print("ORDINARY_SUPPLY_PREVIEW ",JSON.stringify(result))
	assert_bool(bool(result.get("ok",false))).is_true()
	assert_bool(bool(result.get("inspection_only",false))).is_true()
	assert_float(float(result.get("distance",0))).is_greater(0.0)
	assert_float(float(result.get("seconds",0))).is_greater(0.0)
	assert_float(float(result.get("required_fuel",0))).is_greater(0.0)
	assert_float(float(result.get("tank_fuel",0))).is_greater_equal(float(result.get("required_fuel",INF)))
	assert_float(float(result.get("gross_kg",0))).is_greater(0.0)
	assert_str((panel.get("route_status") as Label).text).contains("Fuel")
	assert_bool(bool(result.get("dispatch_ready",true))).is_false()
	assert_str(str(result.get("dispatch_blocker",""))).is_not_empty()
	var hull_choice: OptionButton = panel.get("hull_choice")
	var hull_id := str(hull_choice.get_item_metadata(hull_choice.selected))
	var hull: Dictionary = session.rear.ledger.inspect_entity(hull_id)
	assert_vector(result.get("hull_position",Vector2.INF)).is_equal(hull.position)
	assert_vector(result.get("route_origin",Vector2.INF)).is_equal(session.rear.ledger.inspect_entity("hq-berth").position)
	assert_bool(bool(result.get("reposition_required",false))).is_true()
	assert_dict(session.rear.ledger.snapshot()).is_equal(before)
	assert_dict(session.rear.forward_supply.transport.jobs).is_equal(jobs)
	# An estimate must never bypass the actual loading-location/crew/handler guards.
	var start := _button(panel,"Start physical delivery")
	assert_object(start).is_not_null()
	if start == null: return
	start.pressed.emit()
	assert_int(results.size()).is_equal(2)
	assert_bool(bool(results.back().get("ok",true))).is_false()
	assert_dict(session.rear.ledger.snapshot()).is_equal(before)
	assert_dict(session.rear.forward_supply.transport.jobs).is_equal(jobs)
	assert_float(session.rear.time).is_equal(0.0)
	assert_int(session.speed).is_zero()
	await _successful_delivery(main,base,session,panel,results)


func _successful_delivery(main: Control, base: Control, session: RefCounted, panel: VBoxContainer, results: Array[Dictionary]) -> void:
	# Supply deterministic elapsed time to the existing clock adapter. Keep the
	# ordinary world, initial orders, pending planners and physical custody intact.
	# Cancelling/recreating live planning here would invalidate the real opening.
	base.set_process(false)
	var before_clock: Dictionary = session.rear.ledger.snapshot()
	var transport: RefCounted = session.rear.military.troop_transport
	var before_jobs: Dictionary = transport.jobs.duplicate(true)
	var pending_keys: Array = transport.get("_planning_requests").keys().duplicate()
	var generation: int = transport.get("_planning_generation")
	var owed: float = session.owed_simulation_seconds
	session.set("_live_wall_clock",false)
	session.set("_live_wall_usec",-1)
	assert_dict(session.rear.ledger.snapshot()).is_equal(before_clock)
	assert_dict(transport.jobs).is_equal(before_jobs)
	assert_array(transport.get("_planning_requests").keys()).is_equal(pending_keys)
	assert_int(int(transport.get("_planning_generation"))).is_equal(generation)
	assert_float(session.owed_simulation_seconds).is_equal(owed)
	assert_float(session.rear.time).is_equal(0.0)
	assert_int(session.speed).is_zero()
	var run := _button(main.get("_field_clock"),"1x")
	assert_object(run).is_not_null()
	if run == null: return
	run.pressed.emit()
	var driver_started: int = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec()+300000
	var clock_ticks := 0
	var tick_usec := 0
	var last_inspection := -INF
	var last_log: int = Time.get_ticks_msec()
	var admitted := false
	var job_id := ""
	var expected_sources: Array = []
	var hq_before := 0
	var start_time := -1.0
	var starting_fuel := 0.0
	var saw_outbound := false
	var saw_forward_hull := false
	var deposits := {}
	var state := "Awaiting actual truck and handlers"
	while Time.get_ticks_msec() < deadline and session.rear.time < 2600.0:
		# One ordinary owner tick per returned frame; never drain planners or
		# bypass event boundaries. Measure driver cost instead of assuming it.
		var tick_started: int = Time.get_ticks_usec()
		session.tick(0.1)
		tick_usec += Time.get_ticks_usec()-tick_started
		clock_ticks += 1
		if admitted:
			var row: Dictionary = session.rear.forward_supply.transport.jobs[job_id]
			state = str(row.state)+" · "+str(row.blocker)
			saw_outbound = saw_outbound or row.state == "Outbound"
			var actual: Dictionary = session.rear.ledger.inspect_entity(row.hull,{},false)
			saw_forward_hull = saw_forward_hull or actual.holder_id == row.stop
			for id in row.delivered_items:
				if deposits.has(id): continue
				var stock: Dictionary = session.rear.ledger.inspect_entity(id,{},false)
				assert_str(str(stock.get("holder_id",""))).is_equal(str(row.stop))
				assert_str(str(stock.get("owner",""))).is_equal(str(session.rear.PLAYER))
				deposits[id] = {"quantity":int(stock.get("quantity",0)),"holder":stock.get("holder_id",""),"origin":stock.get("origin_id",""),"time":session.rear.time}
		if not admitted and session.rear.time-last_inspection >= 5.0:
			last_inspection = session.rear.time
			panel.refresh()
			var hulls: OptionButton = panel.get("hull_choice")
			var unloaders: OptionButton = panel.get("unloader_choice")
			var loaders: OptionButton = panel.get("loader_choice")
			var hull_id := str(hulls.get_item_metadata(hulls.selected)) if hulls.selected >= 0 else ""
			var hull: Dictionary = session.rear.ledger.inspect_entity(hull_id,{},false)
			state = "Waiting at "+str(hull.get("holder_id","no truck"))+" · handlers "+str(loaders.item_count)+"/"+str(unloaders.item_count)
			if hull.get("holder_id","") == "hq-berth" and unloaders.selected >= 0 and loaders.selected >= 0:
				(panel.get("amount") as SpinBox).value = 60
				_button(panel,"Preview route, load and fuel").pressed.emit()
				var estimate: Dictionary = results.back()
				state = str(estimate.get("message","No estimate"))
				if estimate.get("ok",false) and estimate.get("dispatch_ready",false):
					hq_before = _stock_at(session,"hq-stock","E02")
					_button(panel,"Start physical delivery").pressed.emit()
					var request: Dictionary = results.back()
					assert_bool(bool(request.get("ok",false))).is_true()
					if not request.get("ok",false): return
					job_id = str(request.id)
					var row: Dictionary = session.rear.forward_supply.transport.jobs[job_id]
					expected_sources = row.sources.duplicate(true)
					start_time = session.rear.time
					starting_fuel = float(hull.fuel)
					admitted = true
					print("HAPPY_DELIVERY_ADMITTED ",JSON.stringify({"time":start_time,"job":job_id,"quantity":row.quantity,"sources":expected_sources}))
					print("HAPPY_HANDOFF_ADMISSION ",JSON.stringify(Diagnostics.capture(session,job_id)))
		if admitted and session.rear.forward_supply.transport.jobs[job_id].unloaded == 60: break
		if admitted and session.rear.forward_supply.transport.jobs[job_id].state in ["Blocked Route","Stranded","Fuel Empty","Paused"]: break
		if not admitted and session.rear.time >= 1800.0: break
		if Time.get_ticks_msec()-last_log >= 10000:
			last_log = Time.get_ticks_msec()
			print("HAPPY_DELIVERY_PROGRESS ",JSON.stringify({"time":session.rear.time,"admitted":admitted,"state":state}))
		await get_tree().process_frame
	assert_bool(admitted).override_failure_message("No successful ordinary Supply admission: "+state+" at "+str(session.rear.time)).is_true()
	if not admitted: return
	var completed: Dictionary = session.rear.forward_supply.transport.jobs[job_id]
	var handoff: Dictionary = Diagnostics.capture(session,job_id)
	print("HAPPY_HANDOFF_TERMINAL ",JSON.stringify(handoff))
	var evidence := FileAccess.open("res://.artifacts/gdunit4/demo/handoff_diagnostics.json",FileAccess.WRITE)
	if evidence != null: evidence.store_string(JSON.stringify(handoff,"\t")); evidence.close()
	print("HAPPY_DELIVERY_RESULT ",JSON.stringify({"start":start_time,"time":session.rear.time,"loaded":completed.loaded,"unloaded":completed.unloaded,"state":completed.state,"blocker":completed.blocker,"delivered_items":completed.delivered_items,"deposits":deposits,"saw_outbound":saw_outbound,"saw_forward_hull":saw_forward_hull,"clock_ticks":clock_ticks,"tick_wall_seconds":tick_usec/1000000.0,"driver_wall_seconds":(Time.get_ticks_usec()-driver_started)/1000000.0}))
	assert_int(completed.loaded).is_equal(60)
	assert_int(completed.unloaded).is_equal(60)
	assert_bool(saw_outbound).is_true()
	assert_bool(saw_forward_hull).is_true()
	assert_float(float(session.rear.ledger.inspect_entity(completed.hull,{},false).fuel)).is_less(starting_fuel)
	assert_array(completed.delivered_items).is_not_empty()
	var deposited := 0
	for deposit in deposits.values(): deposited += int(deposit.quantity)
	assert_int(deposited).is_equal(60)
	assert_int(_stock_at(session,"hq-stock","E02")).is_equal(hq_before-60)
	for id in completed.delivered_items:
		var delivered: Dictionary = session.rear.ledger.inspect_entity(id,{},false)
		assert_str(str(delivered.get("design_type",""))).is_equal("E02")
		var traced := false
		for source in expected_sources:
			if delivered.get("origin_id","") == source.origin_id: traced = true
		assert_bool(traced).is_true()
	_button(main.get("_field_clock"),"Pause").pressed.emit()
	assert_int(session.speed).is_zero()
	var trace := {"revision":OS.get_environment("GITHUB_SHA"),"quantity":60,"accepted_at":start_time,"unloaded_at":session.rear.time,"job":job_id,"stop":completed.stop,"hq_debit":hq_before-_stock_at(session,"hq-stock","E02"),"deposits":deposits,"fuel_before":starting_fuel,"fuel_after":session.rear.ledger.inspect_entity(completed.hull,{},false).fuel,"paused":session.speed == 0}
	var output := FileAccess.open("res://.artifacts/gdunit4/demo/happy_path.json",FileAccess.WRITE)
	assert_object(output).is_not_null()
	if output != null: output.store_string(JSON.stringify(trace,"\t"))


func _stock_at(session: RefCounted, place: String, type: String) -> int:
	var quantity := 0
	for stock in session.rear.ledger.entities_at(place,["STOCK"],false):
		if stock.owner == session.rear.PLAYER and stock.design_type == type: quantity += int(stock.quantity)
	return quantity


func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := _button(child,title)
		if found != null: return found
	return null
