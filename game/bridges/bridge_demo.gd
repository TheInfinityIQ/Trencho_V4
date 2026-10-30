extends Control
## Interactive G20 review of one actual 30 m B03 project and live terrain support.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Canvas = preload("res://game/bridges/bridge_canvas.gd")
var simulation: RefCounted
var bridge_id := ""
var headline: Label
var details: Label
var map: Control

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",7)
	add_child(layout)
	var title := Label.new()
	title.text = "Bridges | Live B03 water crossing"
	layout.add_child(title)
	var actions := HFlowContainer.new()
	layout.add_child(actions)
	for label in ["Advance 100 s","Stage arrived M11","Advance 300 s","Queue equipped person","Advance crossing","Damage to half","Repair 100","Reset"]:
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
	map.custom_minimum_size = Vector2(300,190)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(map)
	_reset()

func _reset() -> void:
	simulation = Base.new(true)
	var rear: RefCounted = simulation.rear
	rear.combat.world.paint(Rect2i(101,10,30,20),"TR11")
	var ordered: Dictionary = rear.bridges.order("B03",Vector2(100.5,20.5),Vector2(131.5,20.5))
	bridge_id = ordered.id
	for n in range(4):
		var id := "review-engineer-"+str(n)
		rear.ledger.add_person(id,bridge_id+"-a",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02")
		rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER)
		rear.bridges.assign_engineer(bridge_id,id)
	rear.ledger.add_carrier("review-m11-carrier","hq-stock",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("review-m11","M11",2400,1.0,"review-m11-carrier",rear.PLAYER)
	rear.ledger.add_person("review-walker","hq-stock",rear.PLAYER,Records.Assignment.AVAILABLE,true)
	rear.ledger.move_entity("review-walker","hq-stock",Vector2(80.5,20.5))
	rear.ledger.add_stock("review-walker-kit","E08",1,5.0,"review-walker",rear.PLAYER)
	headline.text = "Four equipped engineers wait at one bank. All 2,400 M11 are still on the remote carrier."
	map.simulation = simulation
	map.bridge_id = bridge_id
	_refresh()

func _action(label: String) -> void:
	if label == "Reset":
		_reset()
		return
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {}
	match label:
		"Advance 100 s": result = rear.advance_time(100)
		"Advance 300 s": result = rear.advance_time(300)
		"Stage arrived M11":
			var stock: Dictionary = rear.ledger.inspect_entity("review-m11")
			if stock.available > 0 and stock.holder_id == "review-m11-carrier":
				rear.ledger.move_entity("review-m11-carrier","hq-stock",Vector2(100.5,20.5))
				result = rear.bridges.deliver_material(bridge_id,"review-m11",2400)
			else: result = {"message":"Construction M11 has already been staged or consumed."}
		"Queue equipped person": result = rear.bridges.request_crossing(bridge_id,"review-walker",0)
		"Advance crossing": result = rear.advance_time(50)
		"Damage to half":
			var bridge: Dictionary = rear.bridges.inspect(bridge_id)
			result = rear.bridges.damage(bridge_id,maxi(1,bridge.health-int(bridge.max_health/2)))
		"Repair 100":
			if rear.bridges.inspect(bridge_id).state == "Complete":
				rear.advance_time(10)
				rear.ledger.add_stock("review-repair-m11","M11",10,1.0,"review-m11-carrier",rear.PLAYER)
				result = rear.bridges.deliver_material(bridge_id,"review-repair-m11",10)
				if result.ok: result = rear.bridges.request_repair(bridge_id,["review-engineer-0"])
				if result.ok: rear.advance_time(40)
			else: result = {"message":"Finish the bridge before repair."}
	rear.advance_time(0)
	headline.text = str(result.get("message","Action completed."))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var bridge: Dictionary = rear.bridges.inspect(bridge_id)
	var person: Dictionary = rear.ledger.inspect_entity("review-walker")
	details.text = "Time %.1f s | %s | %.1f / %.1f engineer work | %d / %d health\nM11: %d at chosen bank, %d consumed | live load %.0f kg | crossing cap %.0f m/s\nEquipped person at %.1f m | crossing %d | queue %d | %s" % [rear.time,bridge.state,bridge.progress,bridge.work_required,bridge.health,bridge.max_health,bridge.local_m11,bridge.m11_consumed,bridge.effective_load_kg,bridge.speed_cap_mps,person.position.x,bridge.traffic.size(),bridge.queued.size(),"accounting reconciled" if simulation.audit().is_empty() else "audit: "+str(simulation.audit())]
	map.queue_redraw()
