extends Control
## Controlled G16 review: real ledger people and goods on the shared base clock.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
var simulation: RefCounted
var status: Label
var details: Label

func _ready() -> void:
	_build()
	_reset()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",8)
	add_child(root)
	var title := Label.new()
	title.text = "G16 Combat, wounds and morale | controlled field review"
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	for item in ["Fire", "Reload", "Incapacitate", "Start care", "Interrupt care", "Resume care", "Advance 5 s", "Reset"]:
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

func _reset() -> void:
	simulation = Base.new(true)
	var rear: RefCounted = simulation.rear
	var ledger: RefCounted = rear.ledger
	ledger.add_person("g16-shooter","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None")
	ledger.add_place("g16-hostile-place","Observed hostile position",Vector2(1715,91))
	ledger.add_person("g16-hostile","g16-hostile-place","army-red",Records.Assignment.AVAILABLE,true,"None","None")
	ledger.add_person("g16-patient","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None")
	ledger.add_person("g16-medic","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P03","None")
	ledger.add_weapon("g16-rifle","E01",4.0,"g16-shooter",rear.PLAYER,"E02",10)
	ledger.add_stock("g16-rounds","E02",4,0.02,"g16-shooter",rear.PLAYER)
	ledger.load_rounds("g16-rifle","g16-rounds",1)
	ledger.add_stock("g16-remote-rounds","E02",20,0.02,"hq-stock",rear.PLAYER)
	ledger.add_stock("g16-kit","E11",1,4.0,"g16-medic",rear.PLAYER)
	ledger.add_stock("g16-pack","E12",1,1.0,"g16-medic",rear.PLAYER)
	status.text = "One loaded round, three loose rounds on the shooter, twenty at HQ stock. The medic has a kit and one pack."
	_refresh()

func _action(item: String) -> void:
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {}
	match item:
		"Fire": result = rear.combat.fire("g16-shooter","g16-hostile","g16-rifle")
		"Reload": result = rear.combat.request_reload("g16-shooter","g16-rifle","g16-rounds",1)
		"Incapacitate": result = rear.combat.injure("g16-patient",100)
		"Start care": result = rear.combat.start_care("g16-medic","g16-patient","g16-pack")
		"Interrupt care": result = rear.combat.interrupt_care("g16-patient")
		"Resume care": result = rear.combat.start_care("g16-medic","g16-patient")
		"Advance 5 s": result = rear.advance_time(5)
		"Reset":
			_reset()
			return
	status.text = str(result.get("message","Shot released: hit %s; injury %s; rounds %s" % [str(result.get("hit",false)),str(result.get("injury",0)),str(result.get("remaining",0))]))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var ledger: RefCounted = rear.ledger
	var combat: Dictionary = rear.combat.snapshot()
	var lines: Array[String] = ["Time %.1f s | actual holdings and positions" % rear.time]
	for item in ledger.snapshot().entities:
		if not str(item.id).begins_with("g16-") and not str(item.id).begins_with("casualty-drop:g16-"): continue
		if item.kind == "PERSON":
			lines.append("%s | %s | health %d | morale %d | suppression %d | bleed %.1f s | at %s | holder %s" % [item.id,item.assignment,item.health,item.morale,item.suppression,item.bleed_remaining,str(item.position),item.holder_id])
		elif item.kind == "STOCK":
			lines.append("%s %s | %d total, %d available, %d reserved | holder %s | at %s" % [item.id,item.design_type,item.quantity,item.available,item.reserved,item.holder_id,str(item.position)])
		elif item.kind == "WEAPON":
			lines.append("%s %s | intact %s | %d loaded | holder %s | at %s" % [item.id,item.design_type,str(item.functional),item.loaded_rounds,item.holder_id,str(item.position)])
		elif item.kind == "PLACE": lines.append("%s | recoverable place at %s" % [item.id,str(item.position)])
	for id in combat.demands: lines.append("Demand %s: %s" % [id,combat.demands[id].blocked_reason])
	for id in rear.combat.care: lines.append("Care %s: %.1f/10 s | active %s | pack committed %s" % [id,rear.combat.care[id].progress,str(rear.combat.care[id].active),rear.combat.care[id].pack])
	for event in combat.events: lines.append("%.1f s: %s" % [event.at,event.message])
	var errors: Array[String] = simulation.audit()
	lines.append("Audit: %s" % ("All physical counts and assignments reconcile" if errors.is_empty() else str(errors)))
	details.text = "\n".join(lines)
