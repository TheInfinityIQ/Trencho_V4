extends SceneTree

const Base = preload("res://game/rear_base/base_simulation.gd")
const DeliveryPanel = preload("res://game/forward_supply/forward_delivery_panel.gd")
const RearDemo = preload("res://game/rear_base/base_demo.tscn")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const HQ := Vector2(1640,91)
const STOP := Vector2(1640,300)
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_player_controls.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _test_player_controls() -> void:
	var base: RefCounted = Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	for id in ["ui-soldier-a","ui-soldier-b","ui-soldier-c","ui-soldier-d"]:
		_check(ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok,"actual squad member " + id)
		rear.dispatch.military_people[id] = "ui-receipt"
		rear.dispatch.hq_reserve[id] = "Occupied"
		_check(ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"issued rifle")
		_check(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"issued matching rounds")
	_check(ledger.add_person("ui-driver","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"actual qualified driver")
	rear.dispatch.military_people["ui-driver"] = "ui-receipt"
	rear.dispatch.hq_reserve["ui-driver"] = "Occupied"
	rear.advance_time(8)
	_check(rear.military.squads.size() == 1,"actual squad forms")
	if rear.military.squads.is_empty(): quit(1); return
	var squad: Dictionary = rear.military.squads.values()[0]
	_check(ledger.reserve_rear_hull("ui-admission",rear.PLAYER,"ui-fixture").ok,"T01 admission")
	_check(ledger.create_heavy_output("ui-admission","ui-fixture","ui-t01","T01","hq-berth",rear.PLAYER,Specs.TYPES.T01).ok,"actual T01 hull")
	_check(ledger.complete_hq_hull_receipt("ui-t01").ok,"military receipt")
	rear.dispatch.military_hulls["ui-t01"] = "ui-fixture"
	_check(rear.military.assign_crew("ui-driver","ui-t01","Driver").ok,"actual driver report")
	rear.advance_time(8)
	if not rear.military.vehicles.has("ui-t01"): _check(rear.military.attach_vehicle("ui-t01",squad.platoon).ok,"military attachment")
	_check(ledger.add_stock("ui-fuel","M08",20,1.0,"hq-berth",rear.PLAYER).ok,"HQ fuel")
	_check(ledger.begin_carry("initial-hq-01","ui-fuel",20).ok,"HQ worker carries fuel")
	_check(ledger.load_vehicle_fuel("initial-hq-01","ui-t01").ok,"actual tank refuel")
	_check(ledger.add_place("ui-forward-stop","Declared forward stop",STOP).ok,"actual stop")
	_check(rear.forward_supply.register_delivery_stop("ui-forward-stop").ok,"stop registered for player selection")
	_check(ledger.move_entity("ui-soldier-a","ui-forward-stop",STOP+Vector2(1,0)).ok,"recipient reaches destination")
	_check(ledger.move_entity("ui-soldier-b","ui-forward-stop",STOP-Vector2(1,0)).ok,"handler reaches destination")
	_check(ledger.add_stock("ui-hq-freight","E02",50,0.02,"hq-stock",rear.PLAYER).ok,"available physical HQ freight")
	var panel: VBoxContainer = DeliveryPanel.new(base)
	root.add_child(panel)
	await process_frame
	_check(panel.hull_choice.item_count == 1 and panel.stop_choice.item_count == 1 and panel.freight_choice.item_count == 1,"player sees only real eligible hull, freight and declared stop")
	panel.amount.value = 10
	_press(panel,"Preview route, load and fuel")
	_check(panel.route_status.text.contains("Direct candidate") and panel.route_status.text.contains("Fuel"),"player sees measured candidate and fuel before commitment")
	_press(panel,"Start physical delivery")
	_check(rear.forward_supply.transport.jobs.size() == 1,"button commits actual delivery job")
	rear.advance_time(3)
	panel.refresh()
	_check(panel.delivery_status.text.contains("loaded") and panel.delivery_status.text.contains("fuel"),"panel shows live loading and fuel state")
	rear.advance_time(95)
	panel.refresh()
	var delivery: Dictionary = rear.forward_supply.transport.jobs.values()[0]
	_check(delivery.state == "Complete" and delivery.unloaded == 10,"player command completes physical unload and return")
	_check(panel.local_stock_choice.item_count > 0,"arrived stock becomes a selectable local source")
	_check(panel.recipient_choice.item_count >= 2 and panel.handler_choice.item_count >= 2,"two nearby actual soldiers are selectable")
	panel.recipient_choice.select(0)
	panel.handler_choice.select(1)
	panel.local_amount.value = 5
	_press(panel,"Issue at forward stop")
	_check(rear.forward_supply.jobs.size() == 1,"player button requests a local physical issue")
	rear.advance_time(20)
	var issue: Dictionary = rear.forward_supply.jobs.values()[0]
	_check(issue.state == "Complete" and ledger.inspect_entity(issue.issued_stock).holder_id == "ui-soldier-a","actual issued stock reaches selected soldier")
	_check(rear.forward_supply.register_delivery_stop("ui-forward-stop",[HQ,STOP],[STOP,HQ]).ok,"scenario can supply declared physical waypoints")
	panel.refresh()
	_press(panel,"Preview route, load and fuel")
	_check(panel.route_status.text.contains("Scenario route"),"player preview identifies authored route candidate")
	_check(base.audit().is_empty(),"player supply flow preserves common physical invariants")
	panel.queue_free()
	var demo: Control = RearDemo.instantiate()
	root.add_child(demo)
	await process_frame
	var live_panel: VBoxContainer = demo.get("forward_delivery_panel")
	_check(live_panel != null and live_panel.simulation == demo.get("simulation"),"ordinary rear screen includes Supply tab bound to live session")
	demo.call("_start_session")
	_check(live_panel.simulation == demo.get("simulation"),"new player session rebinds same Supply tab")
	demo.queue_free()
	print("Forward delivery UI regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)


func _press(panel: VBoxContainer, title: String) -> void:
	for button in panel.find_children("*","Button",true,false):
		if button.text == title:
			button.pressed.emit()
			return
	_check(false,"button exists: " + title)
