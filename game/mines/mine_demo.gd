extends Control
## Bounded review of actual field actions; these buttons are diagnostics, not player orders.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var simulation: RefCounted
var squad_id := ""
var device_id := ""
var headline: Label
var details: Label
var diagram: Control
const SITE := Vector2(200,100)

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var title := Label.new()
	title.text = "G22 mines and clearance | A37 / A38 | declared flat-road fixture"
	layout.add_child(title)
	var actions := HFlowContainer.new()
	actions.name = "Actions"
	layout.add_child(actions)
	for label in ["Order D02","Deliver 3 M06","Place 12 s","Arm 10 s","Drive tank","Scan 3 s","Disarm 12 s","Reset"]:
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
	diagram = Control.new()
	diagram.custom_minimum_size = Vector2(900,250)
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.draw.connect(_draw_map)
	layout.add_child(diagram)
	_reset()

func _reset() -> void:
	simulation = Base.new(true)
	var rear: RefCounted = simulation.rear
	for i in 4:
		var id := "review-miner-%d" % i
		rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P02" if i < 2 else "None","None")
		rear.dispatch.military_people[id] = "g22-review-receipt"
		rear.dispatch.hq_reserve[id] = "Occupied"
		rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30)
		rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER)
		if i < 2: rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER)
	var roster: Array[String] = ["review-miner-0","review-miner-1","review-miner-2","review-miner-3"]
	squad_id = rear.military.form_squad("Engineer",roster).id
	rear.advance_time(8)
	rear.ledger.add_place("review-mine-road","Declared flat road",Vector2.ZERO)
	for i in 4: rear.ledger.move_entity("review-miner-%d" % i,"review-mine-road",SITE+Vector2(-30,i*2))
	rear.ledger.move_entity("review-miner-0","review-mine-road",SITE)
	rear.ledger.add_carrier("review-freight","review-mine-road",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("review-m06","M06",3,1.0,"review-freight",rear.PLAYER)
	rear.ledger.reserve_rear_hull("review-admit","army-red","g22-review")
	rear.ledger.create_heavy_output("review-admit","g22-review","review-tank","T05","review-mine-road","army-red",Specs.TYPES.T05)
	rear.ledger.add_person("review-driver","review-mine-road","army-red",Records.Assignment.AVAILABLE,true,"P08","None")
	rear.ledger.request_assignment("review-driver",Records.Assignment.REAR_LABOUR,"crew:review-tank:Driver")
	rear.ledger.complete_vehicle_station_entry("review-driver","review-tank","Driver")
	rear.ledger.move_entity("review-tank","review-mine-road",SITE+Vector2(160,0))
	rear.ledger.add_person("review-sweeper","review-mine-road","army-red",Records.Assignment.AVAILABLE,true,"P02")
	rear.ledger.add_stock("review-sweep-kit","E08",1,5.0,"review-sweeper","army-red")
	rear.ledger.move_entity("review-sweeper","review-mine-road",SITE+Vector2(250,0))
	device_id = ""
	headline.text = "An actual Engineer squad, three M06 on a remote carrier, and an uninformed T05 are declared starting resources."
	_refresh()

func _action(label: String) -> void:
	if label == "Reset": _reset(); return
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {"ok":false,"message":"Order a D02 first."}
	if label == "Order D02":
		result = rear.mines.order("D02",SITE,squad_id,"review-miner-0",{"approach_vehicle":"review-tank","friendly_corridor":[SITE+Vector2(-80,60),SITE+Vector2(80,60)],"retreat_route":[SITE+Vector2(-40,0),SITE+Vector2(-80,0)]})
		if result.ok: device_id = result.id
	elif not device_id.is_empty():
		match label:
			"Deliver 3 M06":
				rear.ledger.move_entity("review-freight","review-mine-road",SITE+Vector2(0,5))
				result = rear.mines.deliver(device_id,"review-m06",3)
			"Place 12 s": result = rear.advance_time(12)
			"Arm 10 s":
				rear.ledger.move_entity("review-miner-0","review-mine-road",SITE+Vector2(-30,0))
				rear.ledger.move_entity("review-freight","review-mine-road",SITE+Vector2(-30,10))
				result = rear.advance_time(10)
			"Drive tank": result = rear.ledger.move_entity("review-tank","review-mine-road",SITE+Vector2(-20,0))
			"Scan 3 s":
				rear.ledger.move_entity("review-sweeper","review-mine-road",SITE+Vector2(10,0))
				result = rear.mines.start_scan("review-sweeper")
				if result.ok: rear.advance_time(3)
			"Disarm 12 s":
				rear.ledger.move_entity("review-sweeper","review-mine-road",SITE+Vector2(1,0))
				result = rear.mines.start_disarm(device_id,"review-sweeper")
				if result.ok: rear.advance_time(12)
	headline.text = label+": "+str(result.get("message","Completed" if result.ok else "Blocked"))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var device: Dictionary = rear.mines.inspect(device_id)
	var tank: Dictionary = rear.ledger.inspect_entity("review-tank")
	var context: Dictionary = device.get("order_context",{})
	var route: String = rear.mines.route_blocker("army-red",[SITE+Vector2(50,0),SITE-Vector2(50,0)])
	details.text = "Time %.1f s | D02 %s | work %.1f / 12 | M06 available %d, committed %d, consumed %d\nT05 health %d / 1200 | %s | physical centre (%.2f, %.2f)\nOpponent knowledge: %d markers | route: %s\n%s" % [rear.time,device.get("state","not ordered"),device.get("progress",0.0),device.get("available_m06",0),device.get("committed_m06",0),device.get("m06_consumed",0),tank.health,"Damage Immobilized" if tank.get("damage_immobilized",false) else "mobile",tank.position.x,tank.position.y,rear.mines.inspect_known("army-red").size(),"permitted by received knowledge" if route.is_empty() else route,device.get("blocked_reason","")]
	details.text += "\nApproach observation: "+str(context.get("approach",{}))+" | Marked friendly corridor at y=160; retreat west of x=160."
	diagram.queue_redraw()

func _draw_map() -> void:
	if simulation == null: return
	var rear: RefCounted = simulation.rear
	var origin := Vector2(diagram.size.x*0.5,110)
	var scale := 7.0
	diagram.draw_rect(Rect2(Vector2(0,70),Vector2(diagram.size.x,80)),Color(0.18,0.21,0.24))
	diagram.draw_line(Vector2(0,110),Vector2(diagram.size.x,110),Color(0.7,0.7,0.5),2)
	for pair in [["review-tank",Color(0.8,0.35,0.2)],["review-miner-0",Color(0.3,0.65,1.0)],["review-sweeper",Color(1.0,0.7,0.2)]]:
		var entity: Dictionary = rear.ledger.inspect_entity(pair[0])
		var position: Vector2 = origin+(entity.position-SITE)*scale
		if entity.kind == "CARRIER": diagram.draw_rect(Rect2(position-Vector2(4.25,1.75)*scale,Vector2(8.5,3.5)*scale),pair[1],false,3)
		else: diagram.draw_circle(position,5,pair[1])
	var device: Dictionary = rear.mines.inspect(device_id)
	if not device.is_empty():
		diagram.draw_circle(origin,10,Color(0.6,0.6,0.6) if device.state in ["Inert","Detonated"] else Color(1.0,0.2,0.2))
		diagram.draw_arc(origin,1.5*scale,0,TAU,32,Color(1.0,0.7,0.2),2)
	diagram.draw_string(ThemeDB.fallback_font,Vector2(14,25),"Metre diagram: blue P02, orange opposing sweeper, red T05 footprint, centre D02 / 1.5 m trigger circle",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
