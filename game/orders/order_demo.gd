extends Control
## Controlled G17 review using real G15 formations, G08 sight and G01 holdings.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
var simulation: RefCounted
var fixing := ""
var flanking := ""
var platoon := ""
var status: Label
var details: Label

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",8)
	add_child(root)
	var title := Label.new()
	title.text = "G17 Orders and information | actual squads, sight and message time"
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	for item in ["Observe", "Advance 2 s", "Plan flank", "Spend fixing ammo", "Advance 12 s", "Block sight", "Reset"]:
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

func _make_squad(prefix: String) -> String:
	var rear: RefCounted = simulation.rear
	var people: Array[String] = []
	for i in 4:
		var id := "%s-person-%d" % [prefix,i]
		rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None")
		rear.dispatch.military_people[id] = prefix
		rear.dispatch.hq_reserve[id] = "Occupied"
		rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30)
		rear.ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER)
		rear.ledger.load_rounds(id+"-rifle",id+"-ammo",1)
		people.append(id)
	return str(rear.military.form_squad("Rifle",people).id)

func _reset() -> void:
	simulation = Base.new(true)
	var rear: RefCounted = simulation.rear
	fixing = _make_squad("fix")
	flanking = _make_squad("flank")
	rear.advance_time(8)
	platoon = rear.military.squads[fixing].platoon
	rear.ledger.add_place("flank-place","Physical flank",Vector2(1700,141))
	for id in rear.military.squads[flanking].roster: rear.ledger.move_entity(id,"flank-place",Vector2(1700,141))
	rear.ledger.add_place("enemy-place","Observed hostile position",Vector2(1700,91))
	rear.ledger.add_person("enemy","enemy-place","army-red",Records.Assignment.AVAILABLE,true,"None","None")
	status.text = "Two real squads have reported. Observe to begin one-second G08 sight samples."
	_refresh()

func _action(item: String) -> void:
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {}
	match item:
		"Observe":
			result = rear.orders.watch(fixing)
			rear.orders.watch(flanking)
		"Advance 2 s": result = rear.advance_time(2)
		"Plan flank": result = rear.orders.plan_supported_flank(platoon,fixing,flanking,"enemy","Withdraw to covered rally")
		"Spend fixing ammo":
			for id in rear.military.squads[fixing].roster:
				rear.ledger.fire_loaded_round(id+"-rifle")
				rear.ledger.record_loss(id+"-ammo",29,"G17 controlled physical expenditure")
			result = {"message":"All four fixing rifles and carried E02 are physically empty."}
		"Advance 12 s": result = rear.advance_time(12)
		"Block sight":
			rear.combat.world.obstacle("sight-wall",Rect2(Vector2(1680,90),Vector2(2,60)),0,5)
			result = {"message":"Opaque physical obstacle placed between squads and target."}
		"Reset":
			_reset()
			return
	status.text = str(result.get("message",rear.orders.status))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var lines: Array[String] = ["Time %.1f s | one-second local samples, 0.5 s squad sharing, 1 s per command link" % rear.time]
	for id in [fixing,platoon,rear.military.platoons[platoon].company,"army"]:
		var known: Dictionary = rear.orders.contact(id,"enemy")
		if known.is_empty(): lines.append("%s: no delivered enemy report" % id)
		else: lines.append("%s: enemy seen %.1f s ago | confidence %.2f | uncertainty %.1f m | current %s" % [id,known.age,known.confidence,known.uncertainty_m,str(known.current)])
	var plan: Dictionary = rear.orders.responsibilities.get(platoon,{})
	if not plan.is_empty(): lines.append("Fix %s | flank %s | %.1f degrees | %s | %s" % [plan.fixing,plan.flanking,plan.angle_degrees,plan.state,plan.blocker])
	for id in [fixing,flanking]:
		var intent: Dictionary = rear.orders.intents.get(id,{})
		if not intent.is_empty(): lines.append("%s: %s | %s | fallback: %s" % [id,intent.action,intent.state,intent.fallback])
		for person_id in rear.military.squads[id].roster:
			var person: Dictionary = rear.ledger.inspect_entity(person_id)
			var weapon: Dictionary = rear.ledger.inspect_entity(person_id+"-rifle")
			var ammo: Dictionary = rear.ledger.inspect_entity(person_id+"-ammo")
			lines.append("%s | %s | at %s | rifle %d loaded | E02 %d total / %d available / %d reserved" % [person_id,person.assignment,str(person.position),weapon.loaded_rounds,ammo.quantity,ammo.available,ammo.reserved])
	for entry in rear.orders.pending: lines.append("Pending %s due %.1f s" % [entry.kind,entry.due])
	for row in rear.orders.reports: lines.append("%.1f s %s from %s via %s: %s" % [row.observed_at,row.kind,row.source,str(row.path),row.detail])
	lines.append("Physical audit: %s" % ("reconciled" if simulation.audit().is_empty() else str(simulation.audit())))
	details.text = "\n".join(lines)
