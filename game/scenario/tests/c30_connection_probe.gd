extends SceneTree
## Remote-only observation: ordinary owners and authored inventory; no test grants.
const Session = preload("res://game/scenario/farmland_session.gd")
const Main = preload("res://game/main/main.tscn")
const Fixed = preload("res://game/production/fixed_production.gd")
var base: RefCounted
var rear: RefCounted
var hull := ""
var ammo_manifest := ""
var hull_manifest := ""
var forward_jobs: Array[String] = []
var shipped_units := 0
var origins: Dictionary = {}
var local_issue_origins: Dictionary = {}
var journal: Array[Dictionary] = []
var failures: Array[String] = []
var blockers: Dictionary = {}
var started := 0
var event_cursor := 0
var fired := false
var first_deposit := false
var empty_field_arrival := false
var stage := "Starting authored C30 session"
var last_input_report := -INF
var contact_evidence: Array[Dictionary] = []
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
	_command(rear.munitions_production.set_mode("Stock target"),"Set actual R33 stock-target mode")
	_command(rear.munitions_production.set_stock_target(200),"Manufacture two real E26 batches")
	_command(rear.heavy_production.request_recipe("R30"),"Select R30")
	_command(rear.heavy_production.set_mode("Continuous"),"Request one APC")
	_command(rear.heavy_production.accept_order(),"Accept actual F10 order")
	_command(rear.heavy_production.set_parking_destination(4),"Choose existing west F11 place 5 before manufacture")
	for type in Fixed.RECIPES.R30.inputs:
		_command(rear.request_haul("depot","vehicle_input",type,int(Fixed.RECIPES.R30.inputs[type])),"Haul actual R30 ingredient %d %s" % [int(Fixed.RECIPES.R30.inputs[type]),type])
	for type in Fixed.RECIPES.R33.inputs:
		_command(rear.request_haul("depot","munitions_input",type,2*int(Fixed.RECIPES.R33.inputs[type])),"Haul actual two-batch R33 ingredient %d %s" % [2*int(Fixed.RECIPES.R33.inputs[type]),type])
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
	# One ordinary carry fuels the rear/transfer leg; normal HQ handling may
	# supply the later mission. Full eighty-unit rear filling is not a rule.
	while float(rear.ledger.inspect_entity(hull,{},false).fuel) < 25 and failures.is_empty():
		var worker := ""
		for id in rear.actors:
			var person: Dictionary = rear.ledger.inspect_person_status(id)
			if person.health > 0 and person.pending_assignment == "None" and person.crew_station.is_empty() and person.carrying_stock_id.is_empty() and person.carrying_weapon_id.is_empty(): worker = id; break
		if worker.is_empty(): failures.append("No real free rear fuel carrier"); break
		var units: int = mini(25,int(25-float(rear.ledger.inspect_entity(hull,{},false).fuel)))
		_command(rear.vehicles.request_refuel(hull,worker,units),"Carry real M08 into APC")
		if not await _until(func() -> bool: return not rear.vehicles.fuel_jobs.has(worker),"Physical fuel carry",240): break
	if not failures.is_empty():
		await _finish(); return
	_command(rear.vehicles.start_drive(hull),"Drive same APC to F11")
	if not await _until(func() -> bool: return rear.vehicles.vehicles[hull].state == "Parked","Actual APC parking",180):
		await _finish(); return
	var transferred: Dictionary = rear.dispatch.accept(hull,"Fleet Transfer",[],{})
	_command(transferred,"Fleet Transfer actual empty APC")
	hull_manifest = str(transferred.get("id",""))
	if not await _until(func() -> bool: return rear.dispatch.manifests.get(hull_manifest,{}).get("state","") == "Loaded Waiting Dispatch","Staging APC manifest",300):
		await _finish(); return
	var route_preview: Dictionary = rear.dispatch.route_preview(hull_manifest)
	journal.append({"time":rear.time,"action":"Actual Fleet Transfer fuel and reserve preview","ok":route_preview.get("ok",false),"distance":route_preview.get("distance",0),"required_fuel":route_preview.get("required_fuel",0),"tank_fuel":route_preview.get("tank_fuel",0)})
	if not route_preview.get("ok",false) or not route_preview.get("fuel_ok",false):
		failures.append("Actual Fleet Transfer route and 25 percent fuel reserve are not covered: "+str(route_preview.get("message","")))
		await _finish(); return
	_command(rear.dispatch.depart(hull_manifest),"Depart actual APC manifest")
	var shipment: Dictionary = rear.dispatch.accept("start-vehicle-00","Strategic Delivery",[],{"E26":200})
	_command(shipment,"Separate manufactured E26 shipment")
	ammo_manifest = str(shipment.get("id",""))
	if not await _until(func() -> bool: return rear.dispatch.manifests.get(ammo_manifest,{}).get("state","") == "Loaded Waiting Dispatch","Loading real E26 freight",400):
		await _finish(); return
	_mark("Ammunition is physically loaded and withheld in the rear while the empty APC deploys")
	if not await _until(func() -> bool: return rear.dispatch.manifests.get(hull_manifest,{}).get("state","") == "Complete","Actual same-hull HQ receipt",700):
		await _finish(); return
	_mark("Actual Fleet Transfer complete; military deployment remains distinct from issue")
	var at_supply := func() -> bool:
		var actual: Dictionary = rear.ledger.inspect_entity(hull,{},false)
		return actual.holder_id == "blue-delivery" and actual.position == rear.ledger.inspect_entity("blue-delivery",{},false).position
	if not await _until(at_supply,"Empty APC physical arrival at the forward stop",1000):
		await _finish(); return
	empty_field_arrival = int(rear.ledger.inspect_entity(hull,{},false).ammunition.get("E26",0)) == 0
	if not empty_field_arrival: failures.append("APC did not reach the forward stop with an actually empty rack")
	_mark("Same APC physically arrived at forward stop with empty rack; ammunition still withheld in rear")
	_command(rear.dispatch.depart(ammo_manifest),"Release separately manufactured E26 after empty APC field arrival")
	# One type/quantity load retains the real carry-sized portions and origins.
	# Two R33 batches still serve ONE initial rack allocation, not repeated need.
	var delivery := {"ok":false}
	var attempt_delivery := func() -> bool:
		if delivery.ok: return true
		var loaders: Array = rear.dispatch.free_hq_handlers(4)
		if loaders.is_empty(): return false
		var route: Dictionary = rear.forward_supply.delivery_stops["blue-delivery"]
		var result: Dictionary = rear.forward_supply.request_delivery_type("start-blue-vehicle-02","E26",200,"blue-delivery",route.outbound_points,route.return_points,loaders[0],"start-blue-squad-03-person-00")
		if result.ok: delivery.merge(result,true); return true
		blockers["forward_delivery"] = result.duplicate(true)
		return false
	if not await _until(attempt_delivery,"Waiting for 200 actual HQ E26 and an available military truck",1000):
		await _finish(); return
	forward_jobs.append(str(delivery.id))
	_mark("One actual 200-round multi-portion E26 load admitted: "+str(delivery.id))
	if not await _until(func() -> bool: return rear.forward_supply.transport.jobs[delivery.id].state == "Complete","Forward travel, physical unloading and return",1300):
		await _finish(); return
	shipped_units = 200
	_mark("One actual multi-portion E26 load completed unloading and return")
	if not await _until(func() -> bool: return fired,"Waiting for automatic issue, military support deployment and a legal delivered contact",1200):
		await _finish(); return
	_mark("First autonomous cannon release consumed separately manufactured R33 lineage")
	await _finish()

func _until(predicate: Callable, label: String, maximum_sim: float) -> bool:
	stage = label
	var deadline: float = rear.time+maximum_sim
	while failures.is_empty() and rear.time < deadline and Time.get_ticks_msec()-started < 1150000:
		_observe()
		if not failures.is_empty(): break
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
	for job in rear.forward_supply.rack_issue.jobs.values():
		if job.hull != hull or job.stop != "blue-delivery" or job.source_holder != "blue-delivery" or int(job.issued) <= 0: continue
		var origin: String = str(rear.ledger.inspect_entity(job.stock,{},false).get("origin_id",""))
		if not origins.has(origin): continue
		local_issue_origins[origin] = {"job":job.id,"handler":job.handler,"actually_issued":job.issued,"source":job.stock}
		if not first_deposit:
			first_deposit = true
			_mark("First actual Engineer E26 rack deposit at blue-delivery from manufactured R33 origin")
	var events: Array = rear.ledger.get("_events")
	while event_cursor < events.size():
		var event: Dictionary = events[event_cursor]
		event_cursor += 1
		if not hull.is_empty() and str(event.description) == "Consumption: Mounted Autocannon fired from "+hull:
			var origin: String = str(rear.ledger.inspect_entity(event.entity_id,{},false).get("origin_id",""))
			if empty_field_arrival and local_issue_origins.has(origin): fired = true
			else: failures.append("Cannon release did not follow evidenced empty field arrival and local R33 rack issue: "+origin)
	if not hull.is_empty() and not first_deposit and int(rear.ledger.inspect_entity(hull,{},false).get("ammunition",{}).get("E26",0)) > 0:
		failures.append("APC rack filled before an evidenced physical forward Engineer deposit")

func _command(result: Dictionary, label: String) -> void:
	journal.append({"time":rear.time,"action":label,"result":result.duplicate(true)})
	if not result.get("ok",false) or result.get("confirmation_required",false): failures.append(label+": "+str(result))

func _mark(label: String) -> void:
	journal.append({"time":rear.time,"event":label})
	print("C30_EVENT ",rear.time," ",label)
	_save()

func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://.artifacts/c30")
	var heavy: Dictionary = rear.heavy_production.snapshot()
	var munitions: Dictionary = rear.munitions_production.snapshot()
	if rear.time >= last_input_report+60:
		last_input_report = rear.time
		journal.append({"time":rear.time,"event":"Physical factory inputs","heavy_recipe":heavy.recipe,"heavy_local":heavy.local_inputs,"heavy_missing":heavy.missing_local,"munitions_recipe":munitions.recipe,"munitions_local":munitions.local_inputs,"munitions_missing":munitions.missing_local})
	var report := {"revision":OS.get_environment("GITHUB_SHA"),"stage":stage,"simulation_seconds":rear.time,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"hull":hull,"hull_manifest":hull_manifest,"ammo_manifest":ammo_manifest,"forward_jobs":forward_jobs,"manufactured_origins":origins,"first_rack_deposit":first_deposit,"first_manufactured_round_release":fired,"second_demand_passed":false,"journal":journal,"failures":failures,"blockers":blockers,"opening":rear.battlefield_operations.policy.snapshot(),"heavy":heavy,"munitions":munitions,"dispatch":rear.dispatch.snapshot()}
	report["empty_field_arrival"] = empty_field_arrival
	report["local_issue_origins"] = local_issue_origins
	report["forward_units_completed"] = shipped_units
	var deliveries: Array[Dictionary] = []
	for id in forward_jobs:
		var job: Dictionary = rear.forward_supply.transport.jobs.get(id,{})
		if job.is_empty(): continue
		deliveries.append({"id":id,"state":job.state,"type":job.type,"quantity":job.quantity,"loaded":job.loaded,"unloaded":job.unloaded,"sources":job.sources.duplicate(true),"loaded_items":job.loaded_items.duplicate(),"delivered_items":job.delivered_items.duplicate(),"return_completed":job.return_completed,"blocker":job.blocker})
	report["forward_deliveries"] = deliveries
	var hq_handling: Array[Dictionary] = []
	for job in rear.hq.jobs.values():
		if not hull.is_empty() and job.target == hull: hq_handling.append(job.duplicate(true))
	report["actual_hq_vehicle_handling"] = hq_handling
	if not hull.is_empty(): report["actual_hull"] = rear.ledger.inspect_entity(hull,{},false)
	if not hull.is_empty():
		var support_complete := false
		for deployment in report.opening.deployments:
			if deployment.hull == hull and deployment.state == "Support position reached": support_complete = true
		if contact_evidence.is_empty() and support_complete and int(report.actual_hull.ammunition.get("E26",0)) > 0:
			contact_evidence.append(_contact_evidence("Supplied support position reached"))
		if not failures.is_empty() and (contact_evidence.is_empty() or contact_evidence[-1].get("label","") != "Failure"):
			contact_evidence.append(_contact_evidence("Failure"))
	report["contact_evidence"] = contact_evidence
	var output := FileAccess.open(REPORT,FileAccess.WRITE)
	if output == null:
		if not failures.has("Could not write the C30 evidence report"): failures.append("Could not write the C30 evidence report")
		push_error("Could not write the C30 evidence report")
		return
	output.store_string(JSON.stringify(report,"\t"))

func _contact_evidence(label: String) -> Dictionary:
	# Diagnostic-only ground truth, never fed into command knowledge or target selection.
	var actual: Dictionary = rear.ledger.inspect_entity(hull,{},false)
	var parent: String = str(rear.military.vehicles.get(hull,{}).get("parent",""))
	var observer: Dictionary = rear.orders._apc_observer(hull)
	var candidates: Array[Dictionary] = []
	var world: RefCounted = rear.combat.world
	for target in rear.ledger.snapshot(false).entities:
		var affiliation: String = str(target.controller).trim_suffix("-hq") if target.kind == "CARRIER" else str(target.owner)
		if affiliation != "army-red" or target.kind not in ["PERSON","CARRIER"] or target.get("health",0) <= 0 or target.get("assignment","") in ["Wounded","Recovery","Dead"]: continue
		var distance: float = actual.position.distance_to(target.position)
		var known: Dictionary = rear.orders.contact(parent,target.id)
		var protected_person: bool = target.kind == "PERSON" and rear.ledger.entity_kind(target.holder_id) == "CARRIER" and not rear.vehicle_combat._exposed_gunner(target)
		var row := {"id":target.id,"class":target.design_type,"position":target.position,"health":target.health,"holder":target.holder_id,"distance_m":distance,"protected_person":protected_person,"parent_contact":known,"visible_sources":[],"refusals":[]}
		if distance > 450.0+world.EPS: row.refusals.append("Outside450m weapon range")
		if protected_person: row.refusals.append("Protected occupant")
		if target.design_type == "T05": row.refusals.append("Autonomous Autocannon excludes reportedT05")
		if not known.get("current",false): row.refusals.append("No current contact delivered to actual parent")
		for element in rear.orders.visible:
			var seen: Dictionary = rear.orders.visible[element].get(target.id,{})
			if not seen.is_empty(): row.visible_sources.append({"element":element,"parent":rear.orders._parent(element),"source":seen.source,"observed_at":seen.observed_at})
		if distance <= 450.0+world.EPS:
			var sight: Dictionary = world.observe(actual.position,target.position,str(observer.get("role","ordinary")),3.0,450)
			row["sight"] = {"role":sight.role,"visible":sight.visible,"firing_line_clear":sight.firing_line_clear,"eye":{},"muzzle":{}}
			for ray in ["eye","muzzle"]:
				for field in ["reason","blocker","distance","range","from","to","budget"]: row.sight[ray][field] = sight[ray].get(field)
			if not row.sight.visible: row.refusals.append("Actual mounted eye blocked or outside available observation range")
			if not row.sight.firing_line_clear: row.refusals.append("Actual3m muzzle blocked")
			if rear.vehicle_combat.mounts.has(hull): row["mounted_fire_gate"] = rear.vehicle_combat.inspect_fire(hull,target.id,"Autocannon")
			else: row["mounted_fire_gate"] = {"ok":false,"blocked_reason":"No mount acquired/aimed yet"}
		candidates.append(row)
	var squad_observers: Array[Dictionary] = []
	for squad_id in rear.orders.watch_squads:
		var squad: Dictionary = rear.military.squads.get(squad_id,{})
		if squad.get("owner","") != rear.PLAYER: continue
		for person_id in rear.military._active_roster_members(squad):
			var person: Dictionary = rear.ledger.inspect_entity(person_id,{},false)
			squad_observers.append({"squad":squad_id,"parent":squad.platoon,"person":person_id,"position":person.position,"health":person.health})
	var parent_contacts := {}
	for target_id in rear.orders.contacts.get(parent,{}): parent_contacts[target_id] = rear.orders.contact(parent,target_id)
	return {"label":label,"simulation_seconds":rear.time,"hull":hull,"position":actual.position,"actual_parent":parent,"observer":observer,"capability":rear.military.vehicle_capability(hull,"Fire"),"readiness":rear.military.vehicle_readiness(hull),"military_committed":rear.military.hull_committed(hull),"supply_committed":rear.forward_supply.hull_committed(hull),"mounted_action":rear.battlefield_operations.vehicle_execution.status.get(hull,""),"parent_contacts":parent_contacts,"living_red_candidates":candidates,"actual_blue_squad_observers":squad_observers}

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
		if root.get_texture().get_image().save_png("res://.artifacts/c30/connection.png") != OK: failures.append("Could not save the ordinary C30 inspector image")
	_save()
	print("C30_RESULT ",JSON.stringify({"stage":stage,"fired":fired,"first_deposit":first_deposit,"failures":failures}))
	quit(0 if failures.is_empty() and fired else 1)
