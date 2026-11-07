extends SceneTree
## Explicit arranged named target and existing-stock issue; projection cases are not ordinary demand or full transport evidence.
const Farmland = preload("res://game/scenario/farmland_session.gd")
const Session = preload("res://game/main/game_session.gd")
const Reader = preload("res://game/logistics/army_supply_view.gd")

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _run() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.replace_simulation(Farmland.create_empty_field())
	session.automatic_logistics.set_process(false)
	var rear: RefCounted = session.simulation.rear
	var supply: RefCounted = rear.battlefield_operations.policy.resupply
	var before: Dictionary = rear.ledger.snapshot(false)
	var opening: Dictionary = Reader.view(session)
	if not _require(opening.stock.hq == 6000 and opening.recipients.is_empty() and opening.supply_state == "No reported need","Approved opening must retain6000 HQ rounds without inventing a shortage."): return
	if not _require(rear.ledger.snapshot(false) == before,"Opening feedback must not mutate physical stock."): return
	var squad_id: String = supply.rifle_squads[0]
	if not _require(supply.request_squad_replenishment(squad_id,"feedback-arranged-1",80).ok,"Explicitly arrange the existing named refill target; this is not natural consumption."): return
	var requested: Dictionary = supply.requests.duplicate(true)
	var covered: Dictionary = Reader.view(session)
	if not _require(covered.supply_state == "HQ stock covers need" and covered.rear_shortage == 0 and "does not require extra manufacture" in covered.supply_feedback,"Missing local rounds must be explained as covered by existing HQ stock."): return
	for row in covered.recipients:
		if not _require(row.needed == 20 and row.target == 80 and row.destination == supply.stop_id and row.squad == squad_id and "actual recipient receipt" in row.detail,"Explain real recipient target, destination and physical collection handoff."): return
	covered.recipients[0].target = 999
	if not _require(supply.requests == requested and rear.ledger.snapshot(false) == before,"Feedback and detached-row mutation must preserve source requests and physical state."): return
	# Pure supplied-fact projection branches; no fabricated freight is entered in a physical owner.
	for case in [
		{"need":20,"remaining":0,"forward":0,"hq":0,"rear":0,"incoming":0,"state":"Courier issue"},
		{"need":20,"remaining":20,"forward":20,"hq":0,"rear":0,"incoming":0,"state":"Local issue"},
		{"need":20,"remaining":20,"forward":0,"hq":0,"rear":0,"incoming":20,"state":"Forward freight"},
		{"need":20,"remaining":20,"forward":0,"hq":0,"rear":20,"incoming":0,"state":"Rear stock covers gap"},
		{"need":20,"remaining":20,"forward":0,"hq":0,"rear":5,"incoming":0,"state":"Review rear deliveries"}
	]:
		var facts := {"forward":case.forward,"hq":case.hq,"rear":case.rear}
		var feedback: Dictionary = Reader._supply_feedback(case.need,case.remaining,facts,case.incoming,false,true)
		if not _require(feedback.state == case.state,"Separate existing supply stages in pure projection: "+str(case.state)): return
		if case.state == "Review rear deliveries" and not _require("15 rounds are not covered" in feedback.detail and "rear-to-HQ cargo is not counted" in feedback.detail,"Incomplete available-stock coverage must direct the player to actual rear cargo before extra production."): return
	var queued: Dictionary = session.automatic_logistics.request_delivery("E02",1)
	if not _require(queued.ok and session.automatic_logistics.cancel_request(queued.id).ok,"Use actual rear request/cancellation commands for the hold."): return
	session.automatic_logistics.set_process(false)
	var held: Dictionary = Reader.view(session)
	if not _require(held.held and held.supply_state == "HQ stock covers need" and "does not recall existing forward freight" in held.supply_feedback,"Rear cancellation must not falsely cancel HQ coverage or forward freight."): return
	# Explicit endpoint arrangement, preserving existing people and existing HQ stock through co-located custody transfers.
	var members: Array = rear.military.squads[squad_id].roster
	var engineers: Array = rear.military.squads[supply.engineer_squad].roster
	var at: Vector2 = rear.ledger.inspect_entity(supply.stop_id,{},false).position
	for ids in [members,engineers]:
		for index in ids.size():
			if not _require(rear.ledger.move_entity(str(ids[index]),supply.stop_id,at+Vector2(index,0)).ok,"Arrange existing dismounted people at their real supply stop."): return
	supply.tick()
	if not _require("check existing HQ coverage" in supply.status and "manufacture and physically deliver" not in supply.status,"Missing local stock must direct to current coverage rather than assert manufacture."): return
	var stock := ""
	for item in rear.ledger.entities_at("hq-stock",["STOCK"],false):
		if item.design_type == "E02" and item.owner == rear.PLAYER: stock = item.id; break
	if not _require(not stock.is_empty(),"Existing authored HQ ammunition is required."): return
	var carrier := str(engineers[0])
	if not _require(rear.ledger.move_entity(carrier,"hq-stock",rear.ledger.inspect_entity(stock,{},false).position).ok,"Arrange existing carrier beside actual HQ stock."): return
	var portion: Dictionary = rear.ledger.transfer_stock(stock,160,carrier)
	if not _require(portion.ok,"Pick up160 existing rounds without granting new stock."): return
	if not _require(rear.ledger.move_entity(carrier,supply.stop_id,at).ok and rear.ledger.transfer_stock(str(portion.entity_id),160,supply.stop_id).ok,"Arrange carrier endpoint and deposit the same co-located physical portion."): return
	var local: Dictionary = Reader.view(session)
	if not _require(local.supply_state == "Local issue" and local.stock.hq == 5840 and local.stock.forward == 160,"Existing HQ relocation must remain distinct from manufacture and recipient receipt."): return
	supply.tick()
	var courier: Dictionary = Reader.view(session)
	if not _require(courier.supply_state == "Courier issue" and courier.recipients[0].carried == 60 and courier.recipients[0].committed == 20,"Courier commitment must not be presented as carried rounds."): return
	for _second in 30:
		supply.tick()
		rear.advance_time(1.0)
		if supply.squad_replenishment_status(squad_id).get("state","") == "Complete": break
	if not _require(supply.release_squad_replenishment(squad_id,"feedback-arranged-1").ok,"Actual physical issue and clear handling are required before named handoff."): return
	var received: Dictionary = Reader.view(session)
	if not _require(received.supply_state == "No reported need" and received.recipients.size() == 8,"Fulfilled requests remain followable without becoming a new shortage."): return
	for row in received.recipients:
		if not _require(row.carried == 80 and row.issued == 20 and "current orders and surviving capability" in row.detail,"Actual recipient receipt must not be promoted into operational success."): return
	if not _require(supply.request_squad_replenishment(squad_id,"feedback-arranged-2",100).ok,"A later explicit named cycle is separate."): return
	for row in Reader.view(session).recipients:
		if not _require(row.issued == 0 and row.needed == 20 and row.target == 100,"Later named target must not inherit old issue credit."): return
	if not _require(session.simulation.audit().is_empty(),"Feedback and existing-stock courier issue must preserve physical invariants."): return
	session.queue_free()
	for _frame in 3: await process_frame
	print(JSON.stringify({"result":"PASS","scope":"Read-only no-need/HQ/cancellation feedback; supplied-fact branch checks; explicitly arranged existing-stock physical courier receipt and named handoff. No natural need, ordinary HQ-forward transport, operational success or FPS claim."}))
	quit(0)
