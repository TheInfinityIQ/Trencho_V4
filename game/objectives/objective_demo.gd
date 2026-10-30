extends Control
## G18 controlled physical objective review; T02 occupancy is the staged A30 fixture.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var simulation: RefCounted
var squad := ""
var status: Label
var details: Label

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",8)
	add_child(root)
	var title := Label.new()
	title.text = "G18 Objectives and income | real passenger occupancy and control"
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	for item in ["Advance 15 s", "Dismount", "Contest", "Retreat", "Reset"]:
		var button := Button.new()
		button.name = item.replace(" ", "")
		button.text = item
		button.pressed.connect(_action.bind(item))
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
	simulation = Base.new(true)
	var rear: RefCounted = simulation.rear
	var people: Array[String] = []
	for i in 4:
		var id := "g18-person-%d" % i
		rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None")
		rear.dispatch.military_people[id] = "g18-fixture"
		rear.dispatch.hq_reserve[id] = "Occupied"
		rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30)
		rear.ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER)
		rear.ledger.load_rounds(id+"-rifle",id+"-ammo",1)
		people.append(id)
	squad = str(rear.military.form_squad("Rifle",people).id)
	rear.advance_time(8)
	rear.ledger.reserve_rear_hull("g18-admission",rear.PLAYER,"g18-fixture")
	rear.ledger.create_heavy_output("g18-admission","g18-fixture","g18-transport","T02","hq-berth",rear.PLAYER,Specs.TYPES.T02)
	rear.ledger.complete_hq_hull_receipt("g18-transport")
	rear.dispatch.military_hulls["g18-transport"] = "g18-fixture"
	rear.ledger.add_person("g18-driver","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None")
	rear.dispatch.military_people["g18-driver"] = "g18-fixture"
	rear.dispatch.hq_reserve["g18-driver"] = "Occupied"
	rear.military.assign_crew("g18-driver","g18-transport","Driver")
	rear.advance_time(8)
	rear.military.board_squad(squad,"g18-transport")
	var position: Vector2 = rear.ledger.inspect_entity("g18-transport").position
	rear.ledger.add_place("g18-resource","Physical resource objective",position)
	rear.objectives.register("g18-resource","Resource")
	rear.ledger.add_place("g18-retreat","Physical safe retreat",position+Vector2(100,0))
	rear.advance_time(0)
	status.text = "Four people are physically aboard the parked transport. Advance time to confirm zero capture."
	_refresh()

func _action(item: String) -> void:
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {}
	match item:
		"Advance 15 s": result = rear.advance_time(15)
		"Dismount": result = rear.military.exit_squad(squad)
		"Contest":
			if rear.ledger.inspect_entity("g18-red").is_empty():
				rear.ledger.add_person("g18-red","g18-resource","army-red",Records.Assignment.AVAILABLE,true,"None","None")
				rear.ledger.add_weapon("g18-red-rifle","E01",4.0,"g18-red","army-red","E02",10)
				rear.ledger.add_stock("g18-red-ammo","E02",1,0.02,"g18-red","army-red")
			result = {"message":"Actual armed enemy entered the 25 m radius."}
		"Retreat":
			for id in rear.military.squads[squad].roster: rear.ledger.move_entity(id,"g18-retreat",rear.ledger.inspect_entity("g18-retreat").position)
			result = {"message":"Same four members physically moved outside the capture radius."}
		"Reset":
			_reset()
			return
	rear.advance_time(0)
	var obj: Dictionary = rear.objectives.inspect("g18-resource")
	status.text = "%s | control %.1f | %s" % [item,obj.control,("Contested" if obj.state == "Contested" else ("Owned by "+str(obj.owner) if not str(obj.owner).is_empty() else "Unowned"))]
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var obj: Dictionary = rear.objectives.inspect("g18-resource")
	var balance: Dictionary = rear.receiving.snapshot()
	var lines: Array[String] = ["Time %.1f s | resource at %s | radius 25 m" % [rear.time,str(obj.position)],"Control %.1f / -60..+60 | owner %s | %s | capture %.1f/s" % [obj.control,obj.owner if not obj.owner.is_empty() else "None",obj.state,obj.capture_rate],"Requisition %.2f | total income %.2f | this objective %.2f | rate %.1f/s" % [balance.money,balance.income,obj.income,obj.income_rate],"Eligible blue %s | red %s" % [str(obj.blue),str(obj.red)]]
	if not obj.blocked_reason.is_empty(): lines.append("Blocked: "+obj.blocked_reason)
	var hull: Dictionary = rear.ledger.inspect_entity("g18-transport")
	lines.append("Transport %s | at %s | passengers %s | crew %s" % [hull.id,str(hull.position),str(hull.passengers),str(hull.crew_by_station)])
	for id in rear.military.squads[squad].roster:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		var weapon: Dictionary = rear.ledger.inspect_entity(id+"-rifle")
		var ammo: Dictionary = rear.ledger.inspect_entity(id+"-ammo")
		lines.append("%s | %s | at %s | holder %s | rifle %d loaded | E02 %d total / %d available / %d reserved" % [id,person.assignment,str(person.position),person.holder_id,weapon.loaded_rounds,ammo.quantity,ammo.available,ammo.reserved])
	for blocked in obj.blockers: lines.append("%s at %s: %s" % [blocked.person,str(blocked.position),blocked.reason])
	for event in rear.objectives.events: lines.append("%.1f s %s owner %s -> %s" % [event.at,event.id,event.from,event.to])
	lines.append("Physical audit: %s" % ("reconciled" if simulation.audit().is_empty() else str(simulation.audit())))
	details.text = "\n".join(lines)
