extends SceneTree
## Brief checks of the new supply read/actions. No forced shortage or full delivery claim.
const Farmland = preload("res://game/scenario/farmland_session.gd")
const Session = preload("res://game/main/game_session.gd")
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const VIEW_COUNTER := "logistics/army_supply_view.gd::view"

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _frames(count: int = 3) -> void:
	for _frame in count: await process_frame

func _run() -> void:
	if not _require(ResourceLoader.exists("res://game/logistics/army_supply_view.gd"),"Army supply reader is not implemented."): return
	if not _require(ResourceLoader.exists("res://game/logistics/army_supply_panel.gd"),"Army supply panel is not implemented."): return
	var Reader = load("res://game/logistics/army_supply_view.gd")
	var Panel = load("res://game/logistics/army_supply_panel.gd")
	var session := Session.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.replace_simulation(Farmland.create_empty_field(true))
	var rear: RefCounted = session.simulation.rear
	var logistics: Node = session.automatic_logistics
	logistics.set_process(false)
	var before: Dictionary = rear.ledger.snapshot(false)
	var opening: Dictionary = Reader.view(session)
	if not _require(opening.stock.hq == 6000 and opening.stock.rear == 0,"Show the approved real6000-round HQ opening separately from empty rear stock."): return
	if not _require(opening.recipients.is_empty() and not opening.held,"Do not invent a frontline shortage or cancellation hold at the opening."): return
	if not _require(rear.ledger.snapshot(false) == before,"Supply presentation must not change physical state."): return
	var request: Dictionary = logistics.request_delivery("E02",100)
	if not _require(request.ok and logistics.cancel_request(request.id).ok,"Existing explicit request/cancellation commands must work."): return
	var held: Dictionary = Reader.view(session)
	if not _require(held.held and held.requests.size() == 1 and held.requests[0].cancelled,"Show the actual cancelled request and hold."): return
	var intent: Dictionary = logistics.supply_intent("E02")
	intent.held = false
	if not _require(logistics.supply_intent("E02").held,"Intent reads must be detached from authoritative dictionaries."): return
	if not _require(logistics.resume_automatic_supply("E02").ok and logistics.resume_automatic_supply("E02").ok,"Explicit resume must be idempotent."): return
	if not _require(not logistics.supply_intent("E02").held and logistics.requests.size() == 1 and logistics.requests[request.id].cancelled,"Resume must not revive cancelled work or create a manual shipment."): return
	if not _require(rear.ledger.snapshot(false) == before and session.simulation.speed == 0,"Reading/cancelling/resuming while paused must preserve goods and time intent."): return
	CallLog.enabled = true
	CallLog.capture_stacks = false
	var panel: VBoxContainer = Panel.new()
	root.add_child(panel)
	panel.bind(session,Reader.view)
	await _frames()
	var calls: int = CallLog.totals().get(VIEW_COUNTER,0)
	await _frames(6)
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls,"The Army needs panel must not poll idle frames."): return
	session.notify_command()
	session.notify_command()
	logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls+1,"A committed-event burst must produce one visible read."): return
	panel.hide()
	await _frames()
	calls = CallLog.totals().get(VIEW_COUNTER,0)
	session.notify_command()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls,"Hidden Army needs must not read the model."): return
	panel.show()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls+1,"Showing Army needs must read current facts."): return
	var replacement := Session.new()
	root.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.replace_simulation(Farmland.create_empty_field(true))
	replacement.automatic_logistics.set_process(false)
	panel.bind(replacement,Reader.view)
	await _frames()
	calls = CallLog.totals().get(VIEW_COUNTER,0)
	session.notify_command()
	logistics.changed.emit()
	await _frames()
	if not _require(panel.view.requests.is_empty() and int(CallLog.totals().get(VIEW_COUNTER,0)) == calls,"Rebinding must clear old rows and disconnect old events."): return
	panel.queue_free()
	session.queue_free()
	replacement.queue_free()
	await _frames()
	var game: Control = load("res://game/main/main.tscn").instantiate()
	root.add_child(game)
	game._session.set_physics_process(false)
	if not _require(game._base.show_panel("ArmyNeeds"),"Ordinary rear navigation must expose Army needs."): return
	await _frames()
	if not _require(game._base.army_supply_panel.is_visible_in_tree() and game._base.army_supply_panel.view.stock.hq == 6000,"The ordinary view must use the real current session."): return
	game._base._army_supply_action({"id":"rear_requests","panel":"Supplies"})
	if not _require(game._base._supply_views.get_tab_title(game._base._supply_views.current_tab) == "Army requests","Request navigation must open the existing request subtab."): return
	var member: String = game._base.simulation.rear.military.squads[game._base.simulation.rear.battlefield_operations.policy.resupply.rifle_squads[0]].roster[0]
	game._observe_recipient(member)
	if not _require(game._battlefield.is_visible_in_tree() and game._battlefield.selected_id == member,"Observation must select the actual friendly recipient without creating orders."): return
	if not _require(not game._battlefield.focus_entity("missing-entity"),"Observation must reject missing identities."): return
	if not _require(game._base.simulation.audit().is_empty(),"New navigation and supply intent must preserve ledger invariants."): return
	game.queue_free()
	await _frames()
	print(JSON.stringify({"result":"PASS","scope":"Army needs read purity, actual opening quantities, explicit cancellation/resume, event/visibility/rebind lifecycle, ordinary navigation and friendly observation. No full supply cycle, native input or FPS certification."}))
	quit(0)
