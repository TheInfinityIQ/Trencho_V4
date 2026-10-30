extends RefCounted
## Scene-owned connected integration scenario; no replacement inventory or clock.
const Rear = preload("res://game/staffing/rear_simulation.gd")
const Receiving = preload("res://game/procurement/receiving_simulation.gd")
const R01 = preload("res://game/production/r01_production.gd")
const R02 = preload("res://game/production/r02_production.gd")
const R26 = preload("res://game/production/r26_production.gd")
const Support = preload("res://game/production/support_production.gd")
const Training = preload("res://game/training/training_service.gd")
const Heavy = preload("res://game/production/heavy_production.gd")
const Vehicles = preload("res://game/vehicles/vehicle_activity.gd")
const Dispatch = preload("res://game/dispatch/dispatch_service.gd")
const Hq = preload("res://game/hq/hq_logistics.gd")
const Construction = preload("res://game/construction/construction_service.gd")
const Military = preload("res://game/military/organization.gd")
const Combat = preload("res://game/combat/combat_service.gd")
const Orders = preload("res://game/orders/order_service.gd")
const Objectives = preload("res://game/objectives/objective_service.gd")
const Field = preload("res://game/field_structures/field_service.gd")
const Bridges = preload("res://game/bridges/bridge_service.gd")
const Demolition = preload("res://game/bridges/demolition_service.gd")
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
	receiving.receiving_room = func(slot: int) -> float:
		var owner: RefCounted = rear_ref.get_ref()
		var store_id: String = owner.receiving.freight_berths[slot].store
		var store: Dictionary = owner.stores[store_id]
		if not store.accessible or not store.filter.is_empty(): return 0.0
		# Exclude receiving's own reservations here; G02 subtracts them exactly once.
		return maxf(0, store.capacity - owner.ledger.loose_stock_mass_at(store_id) - owner._reserved_space(store_id) + owner.receiving.reserved_storage_kg(slot))
	rear.receiving = receiving
	rear.vehicles = Vehicles.new(rear)
	rear.dispatch = Dispatch.new(rear)
	rear.hq = Hq.new(rear)
	rear.construction = Construction.new(rear)
	rear.military = Military.new(rear)
	rear.combat = Combat.new(rear)
	rear.orders = Orders.new(rear)
	rear.objectives = Objectives.new(rear)
	rear.field_structures = Field.new(rear)
	rear.bridges = Bridges.new(rear)
	rear.demolition = Demolition.new(rear)
	var dispatch_rear_ref: WeakRef = weakref(rear)
	receiving.external_rear_reservations = func() -> int:
		var owner: RefCounted = dispatch_rear_ref.get_ref()
		return owner.dispatch.return_places.size() if owner != null else 0
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
	var heavy_access: Array[String] = []
	if expanded: heavy_access.assign(Heavy.CHOICES)
	rear.heavy_production = Heavy.new(rear,heavy_access)
	rear.materials_production = R26.new(rear)
	var owner_ref: WeakRef = weakref(rear)
	var access: Callable = func(id: String) -> bool:
		var owner: RefCounted = owner_ref.get_ref()
		for activity in [owner.production,owner.munitions_production,owner.support_production,owner.heavy_production]:
			if activity.recipe_accessible(id): return true
		return id == "R26"
	rear.training = Training.new(rear,access)
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
		"training":rear.training.snapshot(), "heavy":rear.heavy_production.snapshot(),
		"vehicles":rear.vehicles.snapshot(), "dispatch":rear.dispatch.snapshot(),
		"hq":rear.hq.snapshot(), "construction":rear.construction.snapshot(),
		"military":rear.military.snapshot(), "combat":rear.combat.snapshot(), "orders":rear.orders.snapshot(), "objectives":rear.objectives.snapshot(), "field_structures":rear.field_structures.snapshot(), "bridges":rear.bridges.snapshot(), "demolition":rear.demolition.snapshot(), "expanded_catalogue": expanded_catalogue}

func audit() -> Array[String]:
	var failures: Array[String] = rear.audit()
	failures.append_array(receiving.audit())
	failures.append_array(rear.dispatch.audit())
	failures.append_array(rear.hq.audit())
	failures.append_array(rear.construction.audit())
	failures.append_array(rear.military.audit())
	failures.append_array(rear.combat.audit())
	failures.append_array(rear.orders.audit())
	failures.append_array(rear.objectives.audit())
	failures.append_array(rear.field_structures.audit())
	failures.append_array(rear.bridges.audit())
	failures.append_array(rear.demolition.audit())
	if not is_equal_approx(rear.time, receiving._time) or not is_equal_approx(rear.time, rear.ledger.snapshot().time):
		failures.append("Shared event clocks disagree")
	for id in receiving._workers:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.duty_id not in receiving.freight_berths.map(func(row: Dictionary) -> String: return row.duty) or rear.actors[id].phase != "Unloading": failures.append("Receiving duty is not exclusive")
	return failures
