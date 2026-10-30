extends Control
## Interactive A36 review through the same bridge, military, ledger and demolition services.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Canvas = preload("res://game/bridges/bridge_canvas.gd")
var simulation: RefCounted
var bridge_id := ""
var squad_id := ""
var demolition_id := ""
var headline: Label
var details: Label
var map: Control

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",6)
	add_child(layout)
	var title := Label.new()
	title.text = "Bridge denial | A36 attached demolition"
	layout.add_child(title)
	var actions := HFlowContainer.new()
	layout.add_child(actions)
	for label in ["Order D04","Stage 14 M06","Place 19 s","Withdraw","Arm 10 s","Authorize","Choose fuse","Friendly enters","Start fuse","Friendly clears","Start fuse again","Advance 5 s","Reset"]:
		var button := Button.new()
		button.name = label.replace(" ","")
		button.text = label
		button.pressed.connect(_action.bind(label))
		actions.add_child(button)
	headline = Label.new()
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(headline)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(details)
	map = Canvas.new()
	map.custom_minimum_size = Vector2(300,170)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(map)
	_reset()

func _reserve(rear: RefCounted, id: String, engineer: bool) -> void:
	rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P02" if engineer else "None","None")
	rear.dispatch.military_people[id] = "review-receipt"
	rear.dispatch.hq_reserve[id] = "Occupied"
	rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30)
	rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER)
	if engineer: rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER)

func _reset() -> void:
	simulation = Base.new(true)
	var rear: RefCounted = simulation.rear
	rear.combat.world.paint(Rect2i(101,10,30,20),"TR11")
	var ordered: Dictionary = rear.bridges.order("B03",Vector2(100.5,20.5),Vector2(131.5,20.5))
	bridge_id = ordered.id
	for i in 4:
		var id := "review-builder-%d" % i
		rear.ledger.add_person(id,bridge_id+"-a",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02")
		rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER)
		rear.bridges.assign_engineer(bridge_id,id)
	rear.ledger.add_carrier("review-build-carrier","hq-stock",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("review-build-m11","M11",2400,1.0,"review-build-carrier",rear.PLAYER)
	rear.ledger.move_entity("review-build-carrier","hq-stock",Vector2(100.5,20.5))
	rear.bridges.deliver_material(bridge_id,"review-build-m11",2400)
	rear.advance_time(300)
	for i in 4: _reserve(rear,"review-denial-%d" % i,i < 2)
	var roster: Array[String] = ["review-denial-0","review-denial-1","review-denial-2","review-denial-3"]
	var squad: Dictionary = rear.military.form_squad("Engineer",roster)
	squad_id = squad.id
	rear.advance_time(8)
	for i in 2: rear.ledger.move_entity("review-denial-%d" % i,bridge_id+"-a",Vector2(100.5,20.5))
	rear.ledger.add_carrier("review-charge-carrier","hq-stock",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("review-charge-m06","M06",14,1.0,"review-charge-carrier",rear.PLAYER)
	rear.ledger.add_person("review-friendly",bridge_id+"-a",rear.PLAYER,Records.Assignment.AVAILABLE,true)
	rear.ledger.move_entity("review-friendly",bridge_id+"-a",Vector2(70.5,26.5))
	demolition_id = ""
	map.simulation = simulation
	map.bridge_id = bridge_id
	headline.text = "Built B03 has 7,000 health. The engineer squad waits at the endpoint; fourteen M06 are still on a remote carrier."
	_refresh()

func _action(label: String) -> void:
	if label == "Reset":
		_reset()
		return
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {"ok":false,"message":"Order D04 first."}
	var bank := Vector2(100.5,20.5)
	if label == "Order D04":
		var engineers: Array[String] = ["review-denial-0","review-denial-1"]
		result = rear.demolition.order("Bridge",bridge_id,squad_id,engineers)
		if result.ok: demolition_id = result.id
	elif not demolition_id.is_empty():
		match label:
			"Stage 14 M06":
				rear.ledger.move_entity("review-charge-carrier","hq-stock",bank+Vector2(-5,0))
				result = rear.demolition.deliver(demolition_id,"review-charge-m06",14)
			"Place 19 s": result = rear.advance_time(19)
			"Withdraw":
				for i in 2: rear.ledger.move_entity("review-denial-%d" % i,bridge_id+"-a",bank+Vector2(-30,i))
				for i in 4: rear.ledger.move_entity("review-builder-%d" % i,bridge_id+"-a",bank+Vector2(-30,4+i))
				rear.ledger.move_entity("review-build-carrier","hq-stock",bank+Vector2(-30,-4))
				rear.ledger.move_entity("review-charge-carrier","hq-stock",bank+Vector2(-30,-6))
				result = rear.advance_time(0)
			"Arm 10 s": result = rear.advance_time(10)
			"Authorize":
				result = rear.demolition.authorize(demolition_id,rear.military.commander(),{"retreat":"withdraw west","forward_supply":"hold convoy","wounded_evacuation":"clear patients","alternate_or_restore":"rebuild B03 with full M11"})
			"Choose fuse": result = rear.demolition.set_mode(demolition_id,"Fuse")
			"Friendly enters": result = rear.ledger.move_entity("review-friendly",bridge_id+"-a",Vector2(115.5,20.5))
			"Start fuse","Start fuse again": result = rear.demolition.start_fuse(demolition_id)
			"Friendly clears": result = rear.ledger.move_entity("review-friendly",bridge_id+"-a",bank+Vector2(-30,10))
			"Advance 5 s":
				result = rear.advance_time(5)
				if rear.bridges.inspect(bridge_id).state == "Destroyed": result = {"ok":true,"message":"The five-second fuse destroyed the cleared bridge span."}
	rear.advance_time(0)
	headline.text = str(result.get("message","Action completed."))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var bridge: Dictionary = rear.bridges.inspect(bridge_id)
	var project: Dictionary = rear.demolition.inspect(demolition_id) if not demolition_id.is_empty() else {}
	details.text = "Time %.1f s | B03 %d / %d health | %s\nD04: %s | %.1f / %.1f work | M06 %d staged, %d consumed | %s\n%s" % [rear.time,bridge.health,bridge.max_health,bridge.state,project.get("state","Not ordered"),float(project.get("progress",0.0)),float(project.get("work_required",0.0)),int(project.get("local_m06",0)),int(project.get("m06_consumed",0)),str(project.get("blocked_reason","")),"Accounting reconciled" if simulation.audit().is_empty() else "Audit: "+str(simulation.audit())]
	map.queue_redraw()
