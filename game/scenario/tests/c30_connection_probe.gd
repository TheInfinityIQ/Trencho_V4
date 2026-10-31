extends SceneTree
## Remote-only observation: ordinary owners and authored inventory; no test grants.
const Session = preload("res://game/scenario/farmland_session.gd")
const Main = preload("res://game/main/main.tscn")
var base: RefCounted
var rear: RefCounted
var hull := ""
var ammo_manifest := ""
var hull_manifest := ""
var forward_jobs: Array[String] = []
var origins: Dictionary = {}
var journal: Array[Dictionary] = []
var failures: Array[String] = []
var blockers: Dictionary = {}
var started := 0
var event_cursor := 0
var fired := false
var first_deposit := false
var stage := "Starting authored C30 session"
const REPORT := "res://.artifacts/c30/connection.json"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	started = Time.get_ticks_msec()
	base = Session.create()
	rear = base.rear
	_mark("Ordinary paused C30 opening; no T04 or E26 granted")
	if rear.ledger.total_stock("E26",rear.PLAYER) != 0:
		failures.append("Authored opening unexpectedly contains E26")
	# These are the same production/staffing/haul/vehicle/dispatch commands the
	# ordinary panels issue. Prioritize the chosen card using the finite stock.
	_command(rear.production.set_stock_target(0),"Stop new rifle batches")
	_command(rear.materials_production.set_stock_target(0),"Stop new material batches")
	_command(rear.munitions_production.request_recipe("R33"),"Select R33")
	_command(rear.munitions_production.set_stock_target(200),"Manufacture two real E26 batches")
	_command(rear.heavy_production.request_recipe("R30"),"Select R30")
	_command(rear.heavy_production.set_mode("Continuous"),"Request one APC")
	_command(rear.heavy_production.accept_order(),"Accept actual F10 order")
	_command(rear.request_haul("munitions_output","dispatch","E26",200),"Haul E26 to dispatch")
	if not await _until(func() -> bool: return not rear.heavy_production.bay_occupant.is_empty(),"Manufacturing empty T04",1700):
		await _finish(); return
	hull = rear.heavy_production.bay_occupant
	var made: Dictionary = rear.ledger.inspect_entity(hull,{},false)
	if made.design_type != "T04" or made.fuel != 0 or not made.crew.is_empty() or int(made.ammunition.get("E26",0)) != 0:
		failures.append("Manufactured hull was not the actual empty T04")
	_mark("R30 completed: same empty hull "+hull)
	for index in 3:
		_command(rear.vehicles.assign_station(hull,"start-p08-%02d" % (index+3),["Driver","Gunner","Commander"][index]),"Report existing P08 to distinct APC station")
	if not await _until(func() -> bool: return rear.ledger.inspect_entity(hull,{},false).crew.size() == 3,"Waiting for three existing crew",300):
		await _finish(); return
	while float(rear.ledger.inspect_entity(hull,{},false).fuel) < 80 and failures.is_empty():
		var worker := ""
		for id in rear.actors:
			var person: Dictionary = rear.ledger.inspect_person_status(id)
			if person.health > 0 and person.pending_assignment == "None" and person.crew_station.is_empty() and person.carrying_stock_id.is_empty() and person.carrying_weapon_id.is_empty(): worker = id; break
		if worker.is_empty(): failures.append("No real free rear fuel carrier"); break
		var units: int = mini(25,int(80-float(rear.ledger.inspect_entity(hull,{},false).fuel)))
		_command(rear.vehicles.request_refuel(hull,worker,units),"Carry real M08 into APC")
		if not await _until(func() -> bool: return not rear.vehicles.fuel_jobs.has(worker),"Physical fuel carry",240): break
	_command(rear.vehicles.start_drive(hull),"Drive same APC to F11")
	if not await _until(func() -> bool: return rear.vehicles.vehicles[hull].state == "Parked","Actual APC parking",180):
		await _finish(); return
	var transferred: Dictionary = rear.dispatch.accept(hull,"Fleet Transfer",[],{})
	_command(transferred,"Fleet Transfer actual empty APC")
	hull_manifest = str(transferred.get("id",""))
	if not await _until(func() -> bool: return rear.dispatch.manifests.get(hull_manifest,{}).get("state","") == "Loaded Waiting Dispatch","Staging APC manifest",300):
		await _finish(); return
	_command(rear.dispatch.depart(hull_manifest),"Depart actual APC manifest")
	var shipment: Dictionary = rear.dispatch.accept("start-vehicle-00","Strategic Delivery",[],{"E26":200})
	_command(shipment,"Separate manufactured E26 shipment")
	ammo_manifest = str(shipment.get("id",""))
	if not await _until(func() -> bool: return rear.dispatch.manifests.get(ammo_manifest,{}).get("state","") == "Loaded Waiting Dispatch","Loading real E26 freight",400):
		await _finish(); return
	_command(rear.dispatch.depart(ammo_manifest),"Depart separate E26 shipment")
	_mark("Separate hull and ammunition manifests departed")
	if not await _until(func() -> bool: return rear.dispatch.manifests.get(hull_manifest,{}).get("state","") == "Complete","Actual same-hull HQ receipt",700):
		await _finish(); return
	_mark("Actual Fleet Transfer complete; military deployment remains distinct from issue")
	# R33 batches stay separate physical origins. Each real forward trip carries
	# one actual HQ stack; two trips still serve one initial rack allocation.
	for trip in 2:
		var delivery := {"ok":false}
		var attempt_delivery := func() -> bool:
			if delivery.ok: return true
			var loaders: Array = rear.dispatch.free_hq_handlers(4)
			if loaders.is_empty(): return false
			for stock in rear.ledger.entities_at("hq-stock",["STOCK"],false):
				if stock.owner != rear.PLAYER or stock.design_type != "E26" or stock.available < 100: continue
				var route: Dictionary = rear.forward_supply.delivery_stops["blue-delivery"]
				var result: Dictionary = rear.forward_supply.request_delivery("start-blue-vehicle-02",stock.id,100,"blue-delivery",route.outbound_points,route.return_points,loaders[0],"start-blue-squad-03-person-00")
				if result.ok: delivery.merge(result,true); return true
				blockers["forward_delivery"] = result.duplicate(true)
			return false
		if not await _until(attempt_delivery,"Waiting for actual HQ E26 and available military truck",1000):
			await _finish(); return
		forward_jobs.append(str(delivery.id))
		_mark("Actual forward E26 trip admitted: "+str(delivery.id))
		if not await _until(func() -> bool: return rear.forward_supply.transport.jobs[delivery.id].state == "Complete","Forward travel, unloading and return",1300):
			await _finish(); return
		_mark("Actual forward E26 trip completed: "+str(delivery.id))
	if not await _until(func() -> bool: return fired,"Waiting for automatic issue, military support deployment and a legal delivered contact",1200):
		await _finish(); return
	_mark("First autonomous cannon release consumed separately manufactured R33 lineage")
	await _finish()

func _until(predicate: Callable, label: String, maximum_sim: float) -> bool:
	stage = label
	var deadline: float = rear.time+maximum_sim
	while failures.is_empty() and rear.time < deadline and Time.get_ticks_msec()-started < 1150000:
		_observe()
		if predicate.call(): _save(); return true
		rear.advance_time(5)
		if int(rear.time)%60 == 0: _save()
		await process_frame
	failures.append("Unpassed: "+label+" at simulation "+str(rear.time))
	_save()
	return false

func _observe() -> void:
	for batch in rear.munitions_production.history:
		if batch.recipe == "R33" and batch.state == "Completed": origins[batch.output_id] = batch.receipt
	var events: Array = rear.ledger.get("_events")
	while event_cursor < events.size():
		var event: Dictionary = events[event_cursor]
		event_cursor += 1
		if not hull.is_empty() and str(event.description) == "Consumption: Mounted Autocannon fired from "+hull:
			var origin: String = str(rear.ledger.inspect_entity(event.entity_id,{},false).get("origin_id",""))
			if origins.has(origin): fired = true
			else: failures.append("Cannon consumed an unmanufactured E26 origin: "+origin)
	if not hull.is_empty() and not first_deposit and int(rear.ledger.inspect_entity(hull,{},false).get("ammunition",{}).get("E26",0)) > 0:
		first_deposit = true
		_mark("First actual E26 rack deposit; independent from hull arrival and cannon release")

func _command(result: Dictionary, label: String) -> void:
	journal.append({"time":rear.time,"action":label,"result":result.duplicate(true)})
	if not result.get("ok",false) or result.get("confirmation_required",false): failures.append(label+": "+str(result))

func _mark(label: String) -> void:
	journal.append({"time":rear.time,"event":label})
	print("C30_EVENT ",rear.time," ",label)
	_save()

func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://.artifacts/c30")
	var report := {"revision":OS.get_environment("GITHUB_SHA"),"stage":stage,"simulation_seconds":rear.time,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"hull":hull,"hull_manifest":hull_manifest,"ammo_manifest":ammo_manifest,"forward_jobs":forward_jobs,"manufactured_origins":origins,"first_rack_deposit":first_deposit,"first_manufactured_round_release":fired,"second_demand_passed":false,"journal":journal,"failures":failures,"blockers":blockers,"opening":rear.battlefield_operations.policy.snapshot(),"heavy":rear.heavy_production.snapshot(),"munitions":rear.munitions_production.snapshot(),"dispatch":rear.dispatch.snapshot()}
	if not hull.is_empty(): report["actual_hull"] = rear.ledger.inspect_entity(hull,{},false)
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))

func _finish() -> void:
	failures.append_array(base.audit())
	_save()
	# Render the actual final session in the ordinary inspector, retaining a
	# partial state when the physical chain or natural combat does not complete.
	if DisplayServer.get_name() != "headless":
		var main: Control = Main.instantiate()
		root.add_child(main)
		var demo: Control = main.get("_base")
		demo.set_process(false)
		demo.simulation = base
		demo.base_map.simulation = base
		demo.forward_delivery_panel.bind(base)
		main._on_session_changed(base)
		main._show_battlefield()
		var field: Control = main.get("_battlefield")
		field.set_process(false)
		if not hull.is_empty(): field.selected_id = hull; field._refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.artifacts/c30/connection.png")
	print("C30_RESULT ",JSON.stringify({"stage":stage,"fired":fired,"first_deposit":first_deposit,"failures":failures}))
	quit(0 if failures.is_empty() and fired else 1)
