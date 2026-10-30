extends Control
## Small controlled review of actual G23 hulls, crew, rack stock, aim and surfaces.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Records = preload("res://game/identity/identity_records.gd")
var simulation: RefCounted
var status: Label
var details: Label

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",10)
	add_child(root)
	var title := Label.new()
	title.text = "G23 Vehicle armour and weapons | actual crew, rack and struck surface"
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	for name in ["Fire", "Advance 2 s", "Flank and aim", "Advance 3 s", "Reset"]:
		var button := Button.new()
		button.name = name.replace(" ","")
		button.text = name
		button.pressed.connect(_action.bind(name))
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
	var ledger: RefCounted = rear.ledger
	ledger.reserve_rear_hull("review-apc-admission",rear.PLAYER,"review")
	ledger.create_heavy_output("review-apc-admission","review","review-apc","T04","hq-berth",rear.PLAYER,Specs.TYPES.T04)
	ledger.complete_hq_hull_receipt("review-apc")
	rear.dispatch.military_hulls["review-apc"] = "review"
	ledger.reserve_rear_hull("review-tank-admission","army-red","review")
	ledger.create_heavy_output("review-tank-admission","review","review-tank","T05","hq-berth","army-red",Specs.TYPES.T05)
	ledger.add_place("review-target-place","Tank front",Vector2(1740,91))
	ledger.move_entity("review-tank","review-target-place",Vector2(1740,91))
	ledger.add_place("review-flank-place","Tank rear approach",Vector2(1840,91))
	rear.vehicle_combat.set_facing("review-tank",180.0)
	for station in ["Driver","Gunner","Commander"]:
		var id: String = "review-"+str(station).to_lower()
		ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None")
		rear.dispatch.military_people[id] = "review"
		rear.dispatch.hq_reserve[id] = "Occupied"
		rear.military.assign_crew(id,"review-apc",station)
		rear.advance_time(8)
	ledger.add_stock("review-e26","E26",20,0.5,"review-apc",rear.PLAYER)
	rear.vehicle_combat.aim("review-apc","review-tank")
	status.text = "Front target ready. Fire, advance for impact, then move to its rear and aim."
	_refresh()

func _action(name: String) -> void:
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {}
	match name:
		"Fire": result = rear.vehicle_combat.fire("review-apc","review-tank","Autocannon")
		"Advance 2 s": result = rear.advance_time(2)
		"Flank and aim":
			result = rear.ledger.move_entity("review-apc","review-flank-place",Vector2(1840,91))
			if result.ok: result = rear.vehicle_combat.aim("review-apc","review-tank")
		"Advance 3 s": result = rear.advance_time(3)
		"Reset":
			_reset()
			return
	status.text = str(result.get("blocked_reason",result.get("message","Shot released; actual round spent and impact scheduled.")))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var apc: Dictionary = rear.vehicle_combat.inspect("review-apc")
	var tank: Dictionary = rear.ledger.inspect_entity("review-tank")
	var surface: String = rear.vehicle_combat._surface(tank,apc.position)
	var lines: Array[String] = [
		"Clock %.2f s | struck tank surface: %s | front armour 100, rear armour 40 | W06 penetration 45" % [rear.time,surface],
		"T04 APC %s | health %d/%d | actual crew %s" % [str(apc.position),apc.health,Specs.TYPES.T04.health,str(apc.crew)],
		"T04 rack E26: %d total, %d available, %d reserved | loaded magazine %s" % [int(apc.rack.get("E26",0)),int(apc.rack_available.get("E26",0)),int(apc.rack_reserved.get("E26",0)),str(apc.loaded)],
		"T05 tank %s | facing %.0f degrees | health %d/%d" % [str(tank.position),tank.facing_degrees,tank.health,tank.max_health],
		"Turret aim due %.2f | next fire %s | in flight %d" % [float(apc.aim_due),str(apc.next_fire),rear.vehicle_combat.projectiles.size()],
	]
	for event in rear.vehicle_combat.events.slice(maxi(0,rear.vehicle_combat.events.size()-6)):
		lines.append("%.2f | %s | %s | %s" % [float(event.time),event.weapon,str(event.get("phase","Shot")),str(event.get("affected",event.get("ammo","")))])
	details.text = "\n".join(lines)
