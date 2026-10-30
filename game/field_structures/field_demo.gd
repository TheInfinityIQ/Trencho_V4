extends Control
## G19 physical construction review: one bunker, one engineer, one remote M11 carrier.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
var simulation: RefCounted
var site_id := ""
var headline: Label
var details: Label

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",8)
	add_child(root)
	var title := Label.new()
	title.text = "Field works | Bunker construction"
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	for label in ["Advance 100 s","Stage arrived M11","Enter bunker","Reset"]:
		var button := Button.new()
		button.name = label.replace(" ","")
		button.text = label
		button.pressed.connect(_action.bind(label))
		actions.add_child(button)
	headline = Label.new()
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(headline)
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
	var ordered: Dictionary = rear.field_structures.order("S03",Vector2(80,20))
	site_id = ordered.id
	rear.ledger.add_person("review-engineer",site_id,rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02")
	rear.ledger.add_stock("review-e08","E08",1,5.0,"review-engineer",rear.PLAYER)
	rear.field_structures.assign_engineer(site_id,"review-engineer")
	rear.ledger.add_carrier("review-carrier","hq-stock",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("review-m11","M11",300,1.0,"review-carrier",rear.PLAYER)
	headline.text = "Bunker ordered. Engineer on site; 300 M11 remain at HQ. Staging uses a controlled arrival fixture; live forward travel belongs to G26a."
	_refresh()

func _action(label: String) -> void:
	if label == "Reset":
		_reset()
		return
	var rear: RefCounted = simulation.rear
	var result: Dictionary = {}
	match label:
		"Advance 100 s": result = rear.advance_time(100)
		"Stage arrived M11":
			var stock: Dictionary = rear.ledger.inspect_entity("review-m11")
			if stock.available > 0 and stock.holder_id == "review-carrier":
				rear.ledger.move_entity("review-carrier",site_id,Vector2(80,20))
				result = rear.field_structures.deliver_material(site_id,"review-m11",stock.available)
				if result.ok: result.message = "Controlled arrival placed the same carrier on site; its actual M11 was handed off separately from construction work."
			else: result = {"message":"The materials have already been delivered or consumed."}
		"Enter bunker": result = rear.field_structures.enter(site_id,"review-engineer")
	rear.advance_time(0)
	headline.text = str(result.get("message","Action completed."))
	_refresh()

func _refresh() -> void:
	var rear: RefCounted = simulation.rear
	var site: Dictionary = rear.field_structures.inspect(site_id)
	var material: Dictionary = rear.ledger.inspect_entity("review-m11")
	var engineer: Dictionary = rear.ledger.inspect_entity("review-engineer")
	var lines: Array[String] = [
		"Time: %.1f s | %s" % [rear.time,site.name],
		"State: %s | %.1f / %.1f engineer work | health %d / %d" % [site.state,site.progress,site.work_required,site.health,site.max_health],
		"Engineer: %s at %s | P02 | actual E08 held: %d" % [engineer.id,str(engineer.position),rear.military._held(engineer.id,"E08")],
		"M11 at site: %d available | %d missing | %d consumed" % [site.m11_local_available,site.m11_missing,site.m11_consumed],
		"Original M11 stock: %d units held by %s at %s" % [material.quantity,material.holder_id,str(material.position)],
		"Actual occupants: %s | bunker firing equipment supplied: none" % str(site.occupants),
	]
	if not site.blocked_reason.is_empty(): lines.append("Blocked: "+site.blocked_reason)
	lines.append("Accounting: "+("reconciled" if simulation.audit().is_empty() else str(simulation.audit())))
	details.text = "\n\n".join(lines)
