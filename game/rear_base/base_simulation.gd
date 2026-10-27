extends RefCounted
## Scene-owned connected integration scenario; no replacement inventory or clock.
const Rear = preload("res://game/staffing/rear_simulation.gd")
const Receiving = preload("res://game/procurement/receiving_simulation.gd")
const R01 = preload("res://game/production/r01_production.gd")
const R02 = preload("res://game/production/r02_production.gd")
const R26 = preload("res://game/production/r26_production.gd")
const Support = preload("res://game/production/support_production.gd")
const Layout = preload("res://game/staffing/rear_layout.gd")
var rear := Rear.new("Empty")
var receiving: RefCounted
var speed: int = 0
var expanded_catalogue: bool = false

func _init(expanded: bool = false) -> void:
	expanded_catalogue = expanded
	# G02 deposits at the same accepted G03 store/entrance.
	rear.ledger.add_place("personnel", "F08 shared arrival entrance", Layout.door("personnel"))
	receiving = Receiving.new(rear.ledger)
	receiving.route = Layout.path
	var rear_ref: WeakRef = weakref(rear)
	receiving.receiving_room = func() -> float:
		var owner: RefCounted = rear_ref.get_ref()
		var store: Dictionary = owner.stores.receiving
		if not store.accessible or not store.filter.is_empty(): return 0.0
		# Exclude receiving's own reservations here; G02 subtracts them exactly once.
		return maxf(0, store.capacity - owner.ledger.loose_stock_mass_at("receiving") - owner._reserved_space("receiving") + owner.receiving.reserved_storage_kg())
	rear.receiving = receiving
	for i in range(12): rear.add_person("base-person-%02d" % (i + 1))
	var workshop_access: Array[String] = []
	var munitions_access: Array[String] = []
	var support_access: Array[String] = []
	if expanded:
		workshop_access.assign(R01.CHOICES)
		munitions_access.assign(R02.CHOICES)
		support_access.assign(Support.CHOICES)
	rear.production = R01.new(rear, workshop_access)
	rear.munitions_production = R02.new(rear, munitions_access)
	rear.support_production = Support.new(rear, support_access)
	rear.materials_production = R26.new(rear)
	# Begin idle; the player sets staff, material orders and production targets.
	for activity in rear._production_activities(): activity.set_mode("Stock target")
	rear.advance_time(0)

func tick(real_seconds: float) -> void:
	if speed > 0: rear.advance_time(real_seconds * speed)

func set_speed(value: int) -> Dictionary:
	if value not in [0, 1, 2]: return {"ok": false, "message": "Choose Pause, 1x or 2x."}
	speed = value
	return {"ok": true, "message": "Paused" if speed == 0 else "%dx simulation speed" % speed}

func snapshot() -> Dictionary:
	return {"rear": rear.snapshot(), "receiving": receiving.snapshot(), "speed": speed,
		"production": rear.production.snapshot(), "munitions": rear.munitions_production.snapshot(),
		"materials": rear.materials_production.snapshot(), "support": rear.support_production.snapshot(),
		"expanded_catalogue": expanded_catalogue}

func audit() -> Array[String]:
	var failures: Array[String] = rear.audit()
	failures.append_array(receiving.audit())
	if not is_equal_approx(rear.time, receiving._time) or not is_equal_approx(rear.time, rear.ledger.snapshot().time):
		failures.append("Shared event clocks disagree")
	for id in receiving._workers:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.duty_id != "receiving" or rear.actors[id].phase != "Unloading": failures.append("Receiving duty is not exclusive")
	return failures
