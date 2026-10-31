extends GdUnitTestSuite
## Small component fixture; this does not exercise the ordinary authored opening.

const Base = preload("res://game/rear_base/base_simulation.gd")
const DeliveryPanel = preload("res://game/forward_supply/forward_delivery_panel.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Diagnostics = preload("res://game/forward_supply/tests/gdunit/happy_path_diagnostics.gd")
const HQ := Vector2(1640,91)
const STOP := Vector2(1640,121)


func test_ready_supply_preview_and_panel_delivery(_timeout := 15000) -> void:
	var session: RefCounted = Base.new(false,true,false,HQ,false)
	var rear: RefCounted = session.rear
	var ledger: RefCounted = rear.ledger
	assert_bool(ledger.add_place("component-stop","Component delivery destination",STOP).ok).is_true()
	var roster: Array[String] = []
	for index in 4:
		var id := "component-member-%d" % index
		assert_bool(ledger.add_person(id,"component-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok).is_true()
		assert_bool(ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok).is_true()
		assert_bool(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok).is_true()
		roster.append(id)
	assert_bool(rear.military.add_initial_squad("component-squad","Rifle",roster,"component-company","component-platoon",rear.PLAYER).ok).is_true()
	assert_bool(ledger.add_initial_vehicle("component-t01","T01","hq-berth",rear.PLAYER,Specs.TYPES.T01,20.0,"Military").ok).is_true()
	assert_bool(ledger.add_person("component-driver","hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok).is_true()
	assert_bool(ledger.assign_initial_vehicle_crew("component-driver","component-t01","Driver").ok).is_true()
	assert_bool(rear.military.attach_initial_vehicle("component-t01","component-platoon").ok).is_true()
	# The initial scenario registers admitted military hulls with this same owner.
	rear.dispatch.military_hulls["component-t01"] = "Component initial receipt"
	assert_bool(ledger.add_stock("component-hq-rounds","E02",60,0.02,"hq-stock",rear.PLAYER).ok).is_true()
	assert_bool(rear.forward_supply.register_delivery_stop("component-stop",[HQ,STOP],[STOP,HQ]).ok).is_true()
	var panel: VBoxContainer = auto_free(DeliveryPanel.new(session))
	add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	assert_int(panel.hull_choice.item_count).is_equal(1)
	assert_int(panel.freight_choice.item_count).is_equal(1)
	assert_int(panel.stop_choice.item_count).is_equal(1)
	assert_int(panel.loader_choice.item_count).is_greater(0)
	assert_int(panel.unloader_choice.item_count).is_equal(4)
	panel.amount.value = 60
	var results: Array[Dictionary] = []
	panel.result_reported.connect(func(result: Dictionary) -> void: results.append(result))
	var before: Dictionary = ledger.snapshot()
	var jobs_before: Dictionary = rear.forward_supply.transport.jobs.duplicate(true)
	var preview := _button(panel,"Preview route, load and fuel")
	assert_object(preview).is_not_null()
	if preview == null: return
	preview.pressed.emit()
	assert_int(results.size()).is_equal(1)
	if results.is_empty(): return
	var estimate: Dictionary = results.back()
	assert_bool(bool(estimate.get("ok",false))).is_true()
	assert_bool(bool(estimate.get("dispatch_ready",false))).is_true()
	assert_bool(bool(estimate.get("inspection_only",false))).is_true()
	assert_float(float(estimate.get("required_fuel",0.0))).is_greater(0.0)
	assert_dict(ledger.snapshot()).is_equal(before)
	assert_dict(rear.forward_supply.transport.jobs).is_equal(jobs_before)
	var start := _button(panel,"Start physical delivery")
	assert_object(start).is_not_null()
	if start == null: return
	start.pressed.emit()
	assert_int(results.size()).is_equal(2)
	var request: Dictionary = results.back()
	assert_bool(bool(request.get("ok",false))).is_true()
	if not request.get("ok",false): return
	var job: Dictionary = rear.forward_supply.transport.jobs[str(request.id)]
	var before_inspection: Dictionary = ledger.snapshot()
	var diagnostic: Dictionary = Diagnostics.capture(session,str(request.id))
	assert_bool(bool(diagnostic.delivery_missing)).is_false()
	assert_str(str(diagnostic.delivery.id)).is_equal(str(request.id))
	assert_dict(ledger.snapshot()).is_equal(before_inspection)
	assert_str(str(job.hull)).is_equal("component-t01")
	assert_int(job.loaded).is_zero()
	assert_int(job.unloaded).is_zero()
	assert_bool(session.set_speed(1).ok).is_true()
	var saw_outbound := false
	var saw_forward_hull := false
	for step in 300:
		session.tick(0.5)
		saw_outbound = saw_outbound or job.state == "Outbound"
		saw_forward_hull = saw_forward_hull or ledger.inspect_entity(job.hull,{},false).get("holder_id","") == "component-stop"
		if job.unloaded == 60: break
		if job.state in ["Paused","Blocked Route","Stranded","Fuel Empty"]: break
		if step % 10 == 0: await get_tree().process_frame
	print("SUPPLY_COMPONENT_RESULT ",JSON.stringify({"time":rear.time,"state":job.state,"blocker":job.blocker,"loaded":job.loaded,"unloaded":job.unloaded}))
	assert_bool(saw_outbound).is_true()
	assert_bool(saw_forward_hull).is_true()
	assert_int(job.loaded).is_equal(60)
	assert_int(job.unloaded).is_equal(60)
	assert_float(float(ledger.inspect_entity(job.hull,{},false).fuel)).is_less(20.0)
	var hq_quantity := 0
	for stock in ledger.entities_at("hq-stock",["STOCK"],false):
		if stock.owner == rear.PLAYER and stock.design_type == "E02": hq_quantity += int(stock.quantity)
	assert_int(hq_quantity).is_zero()
	assert_array(job.delivered_items).is_not_empty()
	var delivered_quantity := 0
	for id in job.delivered_items:
		var stock: Dictionary = ledger.inspect_entity(id,{},false)
		assert_str(str(stock.holder_id)).is_equal("component-stop")
		assert_str(str(stock.owner)).is_equal(str(rear.PLAYER))
		assert_str(str(stock.design_type)).is_equal("E02")
		assert_str(str(stock.origin_id)).is_equal("component-hq-rounds")
		delivered_quantity += int(stock.quantity)
	assert_int(delivered_quantity).is_equal(60)


func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := _button(child,title)
		if found != null: return found
	return null
