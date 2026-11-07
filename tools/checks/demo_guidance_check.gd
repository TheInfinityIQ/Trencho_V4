extends SceneTree
## Direct component checks. No grants, fabricated need or native-input/FPS claim.
const Session = preload("res://game/main/game_session.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")
const Farmland = preload("res://game/scenario/farmland_session.gd")
const Guidance = preload("res://game/ui/demo_guidance.gd")
const GuidancePanel = preload("res://game/ui/demo_guidance_panel.gd")
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const COUNTER := "ui/demo_guidance.gd::view"
var _checks := 0
var _destinations: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _frames(count: int = 3) -> void:
	for _frame in count: await process_frame

func _run() -> void:
	CallLog.enabled = true
	CallLog.capture_stacks = false
	var session := Session.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.replace_simulation(Farmland.create_empty_field(true))
	session.automatic_logistics.set_process(false)
	var rear: RefCounted = session.simulation.rear
	var before: Dictionary = rear.ledger.snapshot(false)
	var opening := Guidance.view(session)
	if not _require(not opening.factory.complete and opening.next_action.panel == "Workers/Jobs","Opening must use real worker navigation, not claim manufactured progress."): return
	if not _require(opening.school.crew == 0 and opening.transport.trucks == 0 and opening.army_status.contains("No current rear ammunition shortfall"),"Opening has no rear crew/truck and must preserve existing military coverage."): return
	if not _require(rear.ledger.snapshot(false) == before and rear.training.rows.is_empty() and session.automatic_logistics.requests.is_empty(),"Guidance must preserve real goods, courses and actual demand."): return
	var panel := GuidancePanel.new()
	root.add_child(panel)
	panel.bind(session)
	panel.action_requested.connect(_capture_destination)
	await _frames()
	if not _require(not panel._summary.visible and not panel._primary.disabled,"Current action is available while the wider sequence starts collapsed."): return
	panel._primary.pressed.emit()
	if not _require(_destinations == ["Workers/Jobs"],"Primary action must emit existing navigation only."): return
	var calls: int = CallLog.totals().get(COUNTER,0)
	await _frames(8)
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Quiet guidance must not poll idle frames."): return
	session.notify_command()
	session.notify_command()
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls+1,"Committed-event burst must coalesce into one visible query."): return
	calls += 1
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls+1,"Logistics-only changes must invalidate guidance."): return
	panel.hide()
	await _frames()
	calls = CallLog.totals().get(COUNTER,0)
	session.notify_command()
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Hidden guidance must defer all reads."): return
	var request: Dictionary = session.automatic_logistics.request_delivery("E02",100)
	if not _require(request.ok and session.automatic_logistics.cancel_request(request.id).ok,"Exercise actual explicit request cancellation without fabricating demand."): return
	panel.show()
	await _frames()
	if not _require(panel.view.next_action.panel == "ArmyNeeds" and panel.view.next_action.reason.contains("held"),"Showing guidance must read and preserve actual held intent."): return
	if not _require(session.automatic_logistics.supply_intent("E02").held and rear.ledger.snapshot(false) == before,"Showing/clicking guidance cannot resume supply or alter stock."): return
	# Actual ordinary purchases and physical factory work; no fabricated output.
	var model := Base.new(false,false,false,Vector2(1640,91),false,{},true)
	session.replace_simulation(model)
	session.automatic_logistics.set_process(false)
	rear = model.rear
	await _frames()
	if not _require(panel.view.next_action.panel == "Workers/Jobs" and not panel.view.factory.complete,"Replacement must clear held intent and old progress."): return
	if not _require(model.receiving.buy_people().ok and model.receiving.buy_resources({"M01":31,"M04":70,"M03":1}).ok,"Approved opening must admit ordinary workers and ingredients."): return
	rear.set_target("receiving",2,2)
	rear.set_target("hauling",2,2)
	var materials: Dictionary = rear.construction.place("materials",Vector2(65,55))
	var ammunition: Dictionary = rear.construction.place("munitions",Vector2(120,100))
	if not _require(materials.ok and ammunition.ok,"Actual Materials/Munitions sites must place."): return
	rear.construction.set_builders(materials.id,2)
	rear.construction.set_builders(ammunition.id,2)
	model.set_speed(1)
	for _second in 1800:
		rear.advance_time(1.0)
		await process_frame
		if rear.construction.instances[materials.id].state == "Complete" and rear.construction.instances[ammunition.id].state == "Complete": break
	if not _require(rear.construction.activities.has(materials.id) and rear.construction.activities.has(ammunition.id),"Physical builders/materials must produce both facilities."): return
	var material: RefCounted = rear.construction.activities[materials.id]
	var ammo: RefCounted = rear.construction.activities[ammunition.id]
	material.set_stock_target(100)
	ammo.set_stock_target(100)
	rear.set_target(materials.id,2)
	rear.set_target(ammunition.id,2)
	var covered := Guidance.view(session)
	if not _require(not covered.factory.complete and covered.factory.facilities.materials.target_covered and covered.next_action.label == "Raise production target","Existing stock coverage must not count as new manufacture."): return
	material.set_stock_target(int(material.stock_coverage(false).projected)+100)
	for _second in 1800:
		rear.advance_time(1.0)
		await process_frame
		if not material.history.is_empty() and not ammo.history.is_empty(): break
	var manufactured := Guidance.view(session)
	if not _require(manufactured.factory.complete and manufactured.next_action.panel == "Build" and manufactured.next_action.label == "Build a School","Only physical completed batches may move the companion to school/transport preparation."): return
	if not _require(rear.ledger.available_stock_at(material._spec.output_store,"M11") == 100 and rear.ledger.available_stock_at(ammo._spec.output_store,"E02") == 100,"Manufacturing milestone must have real physical outputs."): return
	var school: Dictionary = rear.construction.place("training",Vector2(180,130))
	if not _require(school.ok,"Real School site should be admitted using existing stock."): return
	var building := Guidance.view(session)
	if not _require(building.next_action.label == "Inspect School construction","Actual unfinished School must be inspectable."): return
	if not _require(rear.construction.cancel(school.id).ok,"Actual unstarted School cancellation should remain valid."): return
	if not _require(Guidance.view(session).next_action.label == "Build a School","Cancelled School cannot retain preparation readiness."): return
	if not _require(model.audit().is_empty(),"Focused physical factory/cancellation demonstration must preserve invariants."): return
	# Detached selector edge cases do not assert a physical truck/course was created.
	var edge_factory := {"complete":true}
	var edge_sites := {"training":{"state":"Complete"},"vehicle_works":{},"park":{},"dispatch":{}}
	var edge_school := {"crew":0,"basic":0,"instructors":0,"courses":0,"crew_access":true}
	var edge_transport := {"trucks":0,"driven":0,"fueled":0,"trips":0}
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,{}).panel == "Supplies","No qualified first teacher must route to actual recovery purchase controls."): return
	edge_school.basic = 1
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,{}).panel == "Train","A real basic-trained teacher requires instructor assignment/reporting."): return
	edge_transport.trips = 1
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,{}).panel == "ArmyNeeds","Active trip must be followed instead of demanding a replacement truck."): return
	edge_transport.trips = 0
	edge_transport.trucks = 1
	edge_school.crew = 1
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,{}).panel == "Vehicles","Existing truck without seated Driver must route to Vehicles."): return
	edge_transport.driven = 1
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,{}).label == "Review transport fuel","A Driver alone cannot establish fueled transport."): return
	edge_transport.fueled = 1
	edge_sites.dispatch = {"state":"Complete","requested":0,"present":0}
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,{}).panel == "Workers/Jobs","Unstaffed Logistics Centre must route to workforce controls."): return
	edge_sites.dispatch.requested = 1
	edge_sites.dispatch.present = 1
	var covered_army := {"rear_shortage":0}
	if not _require(Guidance._next(edge_factory,edge_sites,edge_school,edge_transport,covered_army).reason.contains("covered by existing"),"Existing military coverage cannot be sold as required new manufacture."): return
	var replacement := Session.new()
	root.add_child(replacement)
	replacement.set_physics_process(false)
	panel.bind(replacement)
	await _frames()
	calls = CallLog.totals().get(COUNTER,0)
	session.notify_command()
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Rebinding must disconnect both prior owners."): return
	panel.queue_free()
	await _frames()
	replacement.notify_command()
	replacement.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Exit must remove subscriptions and stale deferred reads."): return
	session.queue_free()
	replacement.queue_free()
	await _frames()
	print(JSON.stringify({"result":"PASS","checks":_checks,"scope":"Guidance component: pure approved opening/stock coverage, navigation, lifecycle, real factory manufacture and School cancellation; selector edges are detached inputs. Shell mount remains lead integration; no physical truck/course, native-input, whole-demo or FPS acceptance."}))
	quit(0)

func _capture_destination(action: String) -> void:
	_destinations.append(action)
