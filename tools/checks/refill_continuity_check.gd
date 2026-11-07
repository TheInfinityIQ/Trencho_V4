extends SceneTree
## Arranged physical courier component; no ordinary shortage or full supply-cycle claim.
const Farmland = preload("res://game/scenario/farmland_session.gd")
const Session = preload("res://game/main/game_session.gd")
const Reader = preload("res://game/logistics/army_supply_view.gd")
const ArmyPanel = preload("res://game/logistics/army_supply_panel.gd")

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
	var squad_id: String = supply.rifle_squads[0]
	var members: Array = rear.military.squads[squad_id].roster
	var engineers: Array = rear.military.squads[supply.engineer_squad].roster
	var at: Vector2 = rear.ledger.inspect_entity(supply.stop_id,{},false).position
	# Explicit fixture positioning and relocation of existing HQ ammunition.
	# No new stock is created; this is not the ordinary transport path.
	for ids in [members,engineers]:
		for index in ids.size():
			if not _require(rear.ledger.move_entity(str(ids[index]),supply.stop_id,at+Vector2(index,0)).ok,"Arrange real dismounted people at the actual supply stop."): return
	var stock := ""
	for item in rear.ledger.entities_at("hq-stock",["STOCK"],false):
		if item.design_type == "E02" and item.owner == rear.PLAYER: stock = item.id; break
	if not _require(not stock.is_empty(),"Use existing authored HQ ammunition."): return
	# Local transfers require exact co-location. Arrange one existing carrier's
	# movement endpoints, preserving custody through pickup and local deposit.
	var carrier := str(engineers[0])
	var source_at: Vector2 = rear.ledger.inspect_entity(stock,{},false).position
	if not _require(rear.ledger.move_entity(carrier,"hq-stock",source_at).ok,"Arrange the existing carrier beside HQ stock."): return
	var portion: Dictionary = rear.ledger.transfer_stock(stock,160,carrier)
	if not _require(portion.ok,"Pick up only existing co-located ammunition for the component."): return
	if not _require(rear.ledger.move_entity(carrier,supply.stop_id,at).ok,"Arrange the loaded carrier's endpoint at the supply stop."): return
	if not _require(rear.ledger.transfer_stock(str(portion.entity_id),160,supply.stop_id).ok,"Deposit the same co-located carried portion at the stop."): return
	if not _require(supply.request_squad_replenishment(squad_id,"continuity-component-1",80).ok,"The real named refill owner must admit the arranged cycle."): return
	var opening: Dictionary = Reader.view(session)
	if not _require(opening.has("rear_shortage") and opening.rear_shortage == 0,"Explain actual HQ/local coverage separately from personal need."): return
	var panel: VBoxContainer = ArmyPanel.new()
	root.add_child(panel)
	panel.bind(session,Reader.view)
	for _frame in 3: await process_frame
	var selected: String = panel._selected_recipient
	if not _require(not selected.is_empty(),"Select the real active recipient before issue completes."): return
	for _second in 30:
		supply.tick()
		rear.advance_time(1.0)
		if supply.squad_replenishment_status(squad_id).get("state","") == "Complete": break
	if not _require(supply.release_squad_replenishment(squad_id,"continuity-component-1").ok,"Every real named recipient must receive its rounds and clear handling before release."): return
	if not _require(supply.requests.is_empty(),"The source owner must clear fulfilled requests."): return
	var before: Dictionary = rear.ledger.snapshot(false)
	var completed: Dictionary = Reader.view(session)
	if not _require(completed.recipients.size() == 8,"Keep the latest named refill's actual recipients followable after request removal."): return
	for row in completed.recipients:
		if not _require(not row.reported and row.needed == 0 and row.carried == 80 and row.issued == 20 and not str(row.detail).is_empty(),"Separate actual20-round receipt, present80 rounds and zero reported need."): return
	if not _require(rear.ledger.snapshot(false) == before,"Continuity projection must stay physically read-only."): return
	session.notify_command()
	for _frame in 3: await process_frame
	if not _require(panel._selected_recipient == selected and not panel._action_buttons.observe.disabled,"Keep the selected real recipient and Observe available after refill."): return
	if not _require(supply.request_squad_replenishment(squad_id,"continuity-component-2",100).ok,"A later explicit named cycle must replace the old cycle."): return
	var next: Dictionary = Reader.view(session)
	for row in next.recipients:
		if not _require(row.reported and row.issued == 0 and row.needed == 20,"The new cycle must not inherit previous issue receipts as fresh delivery."): return
	if not _require(session.simulation.audit().is_empty(),"Actual courier issue and presentation must preserve physical invariants."): return
	panel.queue_free()
	session.queue_free()
	for _frame in 3: await process_frame
	print(JSON.stringify({"result":"PASS","scope":"Arranged existing-stock/people named courier refill: real physical issue, active-request removal, stable recipient/Observe continuity, pure read, truthful HQ coverage and cycle replacement. No ordinary shortage, full transport/return-to-duty or FPS certification."}))
	quit(0)
