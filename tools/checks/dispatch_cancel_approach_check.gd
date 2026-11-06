extends SceneTree
## Explicit disconnected physical fixture; not ordinary production or a genuine Army need.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _manufacture(rear: RefCounted, recipe: String) -> String:
	var heavy: RefCounted = rear.heavy_production
	if not _require(heavy.request_recipe(recipe).ok,"Select the existing component recipe."): return ""
	heavy.set_mode("Continuous")
	if not _require(heavy.accept_order().ok,"Admit the real heavy-output bay claim."): return ""
	for type in Fixed.RECIPES[recipe].inputs:
		if not _require(rear.ledger.add_stock("cancel-input-"+recipe+"-"+str(type),type,Fixed.RECIPES[recipe].inputs[type],1.0,"vehicle_input",rear.PLAYER).ok,"Explicitly supply this disconnected component recipe fixture."): return ""
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var output: String = heavy.bay_occupant
	if not _require(not output.is_empty(),"Actual timed manufacture must occupy the real output bay."): return ""
	return output

func _parked(rear: RefCounted, hull: String, row: Dictionary) -> bool:
	var physical: Dictionary = rear.ledger.inspect_entity(hull,{},false)
	return row.state == "Cancelled" and rear.vehicles.vehicles[hull].state == "Parked" and physical.position == rear.yard.PARKING_POSITIONS[row.home_slot] and rear.yard.occupied[row.home_slot] == hull and rear.yard.reserved[row.home_slot].is_empty() and row.task.is_empty() and rear.dispatch._active_manifest(hull).is_empty()

func _run() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var hull := _manufacture(rear,"R28")
	if hull.is_empty(): return
	rear.add_person("cancel-driver",true,"P08")
	if not _require(rear.vehicles.assign_station(hull,"cancel-driver","Driver").ok,"Seat the same actual qualified Driver."): return
	rear.advance_time(160)
	if not _require(rear.ledger.add_stock("cancel-fuel","M08",12,1.0,"depot",rear.PLAYER).ok,"Explicitly supply disconnected fixture fuel."): return
	if not _require(rear.vehicles.request_refuel(hull,"base-person-11",12).ok,"Use real local pickup/carry/tank handling."): return
	rear.advance_time(200)
	if not _require(rear.vehicles.start_drive(hull).ok,"Drive the same manufactured hull out of F10."): return
	rear.advance_time(100)
	if not _require(rear.vehicles.vehicles[hull].state == "Parked","Actual parking must complete before dispatch admission."): return
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	var service: RefCounted = rear.dispatch
	var first: Dictionary = service.accept(hull,"Strategic Delivery",[],{"E02":20})
	if not _require(first.ok,"The exact reproduced empty-stock request must be admitted."): return
	var row: Dictionary = service.manifests[first.id]
	if not _require(row.state == "Approaching Dispatch" and row.stock_items.is_empty(),"Reproduce the initial real approach with no physical ammunition."): return
	var crew: Dictionary = rear.ledger.inspect_entity(hull,{},false).crew_by_station.duplicate()
	var fuel_before: float = rear.ledger.inspect_entity(hull,{},false).fuel
	if not _require(service.cancel(first.id).ok,"Cancel during the initial actual approach."): return
	if not _require(not service.cancel(first.id).ok,"A repeated cancellation cannot withdraw commitments twice."): return
	rear.advance_time(200)
	print(JSON.stringify({"initial_cancel":{"state":row.state,"vehicle":rear.vehicles.vehicles[hull].state,"holder":rear.ledger.inspect_entity(hull,{},false).holder_id,"task":row.task,"blocker":row.blocker}}))
	if not _require(_parked(rear,hull,row),"Initial approach cancellation must finish the same hull's physical safe parking and release its lane/manifest commitment."): return
	if not _require(rear.ledger.inspect_entity(hull,{},false).crew_by_station == crew and rear.ledger.inspect_entity(hull,{},false).fuel < fuel_before and rear.ledger.available_stock_at("hq-stock","E02") == 0,"Real cancellation preserves crew, burns actual travel fuel and fabricates no HQ cargo."): return
	if not _require(not service.cancel(first.id).ok and base.audit().is_empty(),"Late cancellation remains inert after legal parking and clean audit."): return
	# Real reserved cargo, a real passenger and a real uncommitted field gun
	# exercise pending-withdrawal edits without inventing a successful load.
	var gun := _manufacture(rear,"R13")
	if gun.is_empty(): return
	rear.add_person("cancel-passenger")
	if not _require(rear.ledger.add_stock("cancel-rounds","E02",20,0.02,"dispatch",rear.PLAYER).ok,"Explicitly supply just20 actual fixture rounds for the next manifest."): return
	var second: Dictionary = service.accept(hull,"Fleet Transfer",["cancel-passenger"],{"E02":20})
	if not _require(second.ok,"Reuse the same physically parked hull with actual cargo/passenger admissions."): return
	var pending: Dictionary = service.manifests[second.id]
	if not _require(pending.state == "Approaching Dispatch" and pending.stock_items.size() == 1 and service.incoming_hulls.has(hull) and service.incoming_people.size() == 2,"Actual approach owns the reserved cargo and fleet/passenger admissions."): return
	var claim: String = pending.stock_items[0].claim
	if not _require(rear.ledger.inspect_claim(claim).reserved == 20,"Only20 actual rounds are reserved."): return
	rear.advance_time((float(pending.route_deadline)-rear.time)/2.0)
	if not _require(pending.state == "Approaching Dispatch" and pending.distance > 0 and pending.distance < pending.route_length,"The second cancellation occurs midway through real physical approach."): return
	var route: Array = pending.route.duplicate(true)
	var deadline: float = pending.route_deadline
	if not _require(service.cancel(second.id).ok,"Withdraw the same in-flight approach's own commitments once."): return
	if not _require(pending.route == route and pending.route_deadline == deadline and rear.ledger.inspect_entity(hull,{},false).crew_by_station == crew,"Cancellation retains the captured route/deadline and real seated crew."): return
	if not _require(service.incoming_hulls.is_empty() and service.incoming_people.is_empty() and service.passenger_promises.is_empty() and rear.ledger.inspect_claim(claim).reserved == 0 and rear.ledger.available_stock_at("dispatch","E02") == 20,"Cancellation releases only actual predeparture admissions and source claims, preserving all goods."): return
	var before: Dictionary = pending.duplicate(true)
	if not _require(not service.cancel(second.id).ok and not service.cancel(first.id).ok and not service.change_mode(second.id,"Strategic Delivery").ok and not service.set_route_profile(second.id,{}).ok and not service.add_field_gun(second.id,gun).ok,"Repeated/late cancellation and manifest edits cannot reopen pending withdrawal."): return
	if not _require(pending == before and service.weapon_promises.is_empty() and rear.heavy_production.bay_occupant == gun,"Rejected edits leave the pending physical route and uncommitted field gun intact."): return
	rear.advance_time(200)
	if not _require(_parked(rear,hull,pending) and rear.ledger.inspect_person_status("cancel-passenger").assignment == "Available" and rear.ledger.available_stock_at("dispatch","E02") == 20 and base.audit().is_empty(),"Reserved-cargo/passenger cancellation safely returns the same hull without losing goods or stranding people."): return
	var third: Dictionary = service.accept(hull,"Strategic Delivery",[],{"E02":20})
	if not _require(third.ok,"The same returned hull is available for a later useful shipment."): return
	var shipping: Dictionary = service.manifests[third.id]
	if not _require(not service.cancel(second.id).ok and shipping.state == "Approaching Dispatch","A late old-manifest cancel cannot affect the new trip."): return
	rear.advance_time(600)
	if not _require(shipping.state == "Loaded Waiting Dispatch" and rear.ledger.available_stock_at(hull,"E02") == 20 and rear.ledger.available_stock_at("hq-stock","E02") == 0,"Existing physical loading still places exactly20 rounds aboard before HQ credit."): return
	if not _require(service.depart(third.id).ok,"The reused actual hull can depart after physical loading."): return
	rear.advance_time(1)
	if not _require(not service.cancel(third.id).ok and shipping.departed and rear.ledger.available_stock_at(hull,"E02") == 20,"Existing departed-cancel rejection preserves actual cargo."): return
	rear.advance_time(800)
	if not _require(shipping.state == "Complete" and rear.vehicles.vehicles[hull].state == "Parked" and rear.ledger.available_stock_at("hq-stock","E02") == 20 and rear.ledger.inspect_entity(hull,{},false).crew_by_station == crew and base.audit().is_empty(),"Later real unloading/HQ credit and same-hull return still finish cleanly."): return
	print(JSON.stringify({"result":"PASS","checks":checks,"scope":"Explicit disconnected fixture: real manufacture/crew/refuel/parking, immediate and mid-approach cancel, source/admission release, repeated/late-command rejection, physical same-hull return/reuse, actual20-round loading/HQ receipt and departed-cancel rejection. No ordinary empty-field, genuine Army need, native input, visible rendering or FPS certification."}))
	quit(0)
