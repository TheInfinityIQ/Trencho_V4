extends Control
const Fixture = preload("res://game/vehicle_recovery/recovery_fixture.gd")
var fixture: RefCounted
var status: Label
var details: Label

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",8)
	add_child(root)
	var title := Label.new()
	title.text = "G24 Vehicle recovery | physical occupants, salvage, repair and towing"
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	for label in ["Destroy carrier","Repair scenario","Health repair","Mobility repair","Couple","Try B02","Cross B03","Detach","Advance 10 s","Advance 20 s","Advance 60 s","Reset"]:
		var button := Button.new()
		button.name = label.replace(" ","")
		button.text = label
		button.pressed.connect(_action.bind(label))
		actions.add_child(button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	_reset()

func _reset() -> void:
	fixture = Fixture.new()
	status.text = "Explicit review scenario: loaded tanks at a completed B03; actual P02/E08 nearby. Carrier holds healthy, injured and incapacitated people."
	_refresh()

func _action(label: String) -> void:
	var rear: RefCounted = fixture.base.rear
	var result: Dictionary = {"ok":true,"message":"Shared clock advanced."}
	match label:
		"Reset":
			_reset()
			return
		"Destroy carrier": result = rear.ledger.apply_vehicle_surface_damage("carrier",1000,999,"Side","Review destroying hit")
		"Repair scenario":
			_reset()
			rear = fixture.base.rear
			rear.ledger.move_entity("repairer","repairer-ground",Vector2(68.5,23.5))
			rear.ledger.add_place("repair-staging","Review staged repair M11",Vector2(68.5,23.5))
			rear.ledger.add_stock("repair-material","M11",60,1.0,"repair-staging",rear.PLAYER)
			rear.advance_time(10)
			result.message = "Fresh repair scenario: actual P02, kit and staged M11 beside disabled tank; damage cooldown elapsed."
		"Health repair": result = rear.recovery.start_repair("tow",["repairer"])
		"Mobility repair": result = rear.recovery.start_repair("tow",["repairer"],"Mobility")
		"Couple": result = rear.recovery.start_coupling("tractor","tow","repairer")
		"Try B02": result = rear.bridges.request_crossing(fixture.b02,"tractor",0)
		"Cross B03": result = rear.bridges.request_crossing(fixture.b03,"tractor",0)
		"Detach": result = rear.recovery.start_coupling("tractor","tow","repairer",false)
		"Advance 10 s": rear.advance_time(10)
		"Advance 20 s": rear.advance_time(20)
		"Advance 60 s": rear.advance_time(60)
	status.text = ("Accepted: " if result.ok else "Blocked: ")+str(result.get("message",result.get("reason",result.get("blocked_reason",""))))
	rear.advance_time(0)
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = fixture.base.rear
	var lines: Array[String] = ["Simulation time %.2f s | B02 limit 10,000 kg | B03 limit 80,000 kg" % rear.time]
	for id in ["tractor","tow","carrier"]:
		var view: Dictionary = rear.recovery.inspect(id)
		var hull: Dictionary = view.hull
		lines.append("%s | health %d/%d | fuel %.3f | position %s | gross %.1f kg | tow %s / tractor %s" % [id,hull.health,hull.max_health,hull.fuel,str(hull.position),view.gross_kg,hull.towing,hull.towed_by])
		lines.append("Conditions: "+("Mobile" if view.conditions.is_empty() else view.blocked_reason))
		if not view.job.is_empty(): lines.append("%s work %.2f/%.0f | committed M11 %d | %s" % [view.job.mode,view.job.progress,view.job.work,view.job.cost,view.job.blocked_reason])
		if not view.coupling.is_empty(): lines.append("Coupling work %.2f/20 active seconds" % view.coupling.progress)
		lines.append("Nearby unreserved ground M11: %d" % view.available_m11)
	for id in ["healthy","injured","incapacitated"]:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		lines.append("%s | health %d | %s | suppression %d | holder %s | %s" % [id,p.health,p.assignment,p.suppression,p.holder_id,str(p.position)])
	for id in ["freight-a","freight-b","odd-rounds","incapacitated-rounds"]:
		var item: Dictionary = rear.ledger.inspect_entity(id)
		lines.append("%s: actual %d / reserved %d / available %d | %s" % [id,item.quantity,item.reserved,item.available,item.holder_id])
	lines.append("Ledger audit: "+str(fixture.base.audit()))
	details.text = "\n".join(lines)
