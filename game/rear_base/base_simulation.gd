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
const VehicleCombat = preload("res://game/vehicle_combat/vehicle_combat_service.gd")
const Recovery = preload("res://game/vehicle_recovery/recovery_service.gd")
const Orders = preload("res://game/orders/order_service.gd")
const Objectives = preload("res://game/objectives/objective_service.gd")
const ForwardSupply = preload("res://game/forward_supply/forward_supply.gd")
const Field = preload("res://game/field_structures/field_service.gd")
const Bridges = preload("res://game/bridges/bridge_service.gd")
const Mines = preload("res://game/mines/mine_service.gd")
const Demolition = preload("res://game/bridges/demolition_service.gd")
const Layout = preload("res://game/staffing/rear_layout.gd")
const RearStart = preload("res://game/scenario/rear_start.gd")
var rear: RefCounted
var receiving: RefCounted
var speed: int = 0
var expanded_catalogue: bool = false
var connected_world: bool = false
var owed_simulation_seconds := 0.0
var planning_view_revision := 0
var _live_planning := false
var _live_wall_clock := true
var _live_wall_usec := -1
var _transport_view_revision := -1
var _supply_view_revision := -1
var _planning_turn := 0
var _resource_view_revision := -1
const LIVE_QUANTUM := 0.1

func _init(expanded: bool = false, world_session: bool = false, initial_rear: bool = false, hq_at: Vector2 = Vector2(1640,91), declare_scaffold_markers: bool = true, declared_access: Dictionary = {}) -> void:
	rear = Rear.new("Empty",not initial_rear)
	expanded_catalogue = expanded
	connected_world = world_session
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
	rear.dispatch = Dispatch.new(rear,hq_at)
	rear.hq = Hq.new(rear)
	rear.construction = Construction.new(rear)
	rear.military = Military.new(rear)
	rear.combat = Combat.new(rear)
	if connected_world:
		rear.combat.world.bounds = Rect2i(0, 0, 4000, 6000)
	rear.vehicle_combat = VehicleCombat.new(rear)
	rear.orders = Orders.new(rear)
	rear.objectives = Objectives.new(rear)
	rear.forward_supply = ForwardSupply.new(rear)
	if connected_world and declare_scaffold_markers:
		rear.ledger.add_place("resource-central", "Central resource objective", Vector2(2000, 3000))
		rear.objectives.register("resource-central", "Resource")
		rear.ledger.add_place("enemy-hq", "Opposing HQ", Vector2(2000, 5700))
		rear.orders.register_enemy_hq("enemy-hq")
	rear.field_structures = Field.new(rear)
	rear.bridges = Bridges.new(rear)
	rear.recovery = Recovery.new(rear)
	rear.demolition = Demolition.new(rear)
	rear.mines = Mines.new(rear)
	var dispatch_rear_ref: WeakRef = weakref(rear)
	receiving.external_rear_reservations = func() -> int:
		var owner: RefCounted = dispatch_rear_ref.get_ref()
		return owner.dispatch.return_places.size() if owner != null else 0
	if not initial_rear:
		for i in range(12): rear.add_person("base-person-%02d" % (i + 1))
	var workshop_access: Array[String] = []
	var munitions_access: Array[String] = []
	var support_access: Array[String] = []
	workshop_access.assign(declared_access.get("workshop",[]))
	munitions_access.assign(declared_access.get("munitions",[]))
	support_access.assign(declared_access.get("support",[]))
	if expanded:
		workshop_access.assign(R01.CHOICES)
		munitions_access.assign(R02.CHOICES)
		support_access.assign(Support.CHOICES)
	rear.production = R01.new(rear, workshop_access)
	rear.munitions_production = R02.new(rear, munitions_access)
	rear.support_production = Support.new(rear, support_access)
	var heavy_access: Array[String] = []
	heavy_access.assign(declared_access.get("heavy",[]))
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
	if initial_rear: RearStart.apply(self)
	rear.advance_time(0)

func tick(real_seconds: float) -> void:
	if _live_planning:
		if _live_wall_clock:
			push_error("A live wall-clock session uses tick_live, not explicitly supplied elapsed time.")
			return
		if not is_finite(real_seconds) or real_seconds < 0.0: return
		owed_simulation_seconds += real_seconds*speed
		_pump_live()
		return
	if speed > 0: rear.advance_time(real_seconds * speed)

func enable_live_planning(use_wall_clock: bool = true) -> void:
	if _live_planning or rear.battlefield_operations == null: return
	_live_planning = true
	_live_wall_clock = use_wall_clock
	_live_wall_usec = Time.get_ticks_usec() if _live_wall_clock else -1
	rear.military.troop_transport.incremental_planning = true
	rear.vehicle_departures_allowed = speed > 0

func cancel_live_planning() -> void:
	if not _live_planning: return
	var supply := _supply_travel_owner()
	if supply != null: supply.cancel_planning()
	var resource := _resource_planning_owner()
	if resource != null: resource.cancel_planning()
	rear.military.troop_transport.cancel_planning()
	rear.military.troop_transport.incremental_planning = false
	rear.vehicle_departures_allowed = false
	owed_simulation_seconds = 0.0
	_live_planning = false
	_live_wall_usec = -1

func tick_live(real_seconds: float) -> void:
	if not _live_planning:
		tick(real_seconds)
		return
	if not _live_wall_clock:
		push_error("An explicit elapsed-time session uses tick, not the live wall clock.")
		return
	_accrue_live_wall_time()
	_pump_live()

func _accrue_live_wall_time() -> void:
	if not _live_wall_clock: return
	var now: int = Time.get_ticks_usec()
	if _live_wall_usec >= 0:
		owed_simulation_seconds += float(now-_live_wall_usec)/1000000.0*speed
	_live_wall_usec = now

func _pump_live() -> void:
	var transport: RefCounted = rear.military.troop_transport
	var supply := _supply_travel_owner()
	var resource := _resource_planning_owner()
	var owners: Array[RefCounted] = [transport]
	if supply != null: owners.append(supply)
	if resource != null: owners.append(resource)
	for offset in owners.size():
		var index: int = (_planning_turn+offset)%owners.size()
		var owner: RefCounted = owners[index]
		if not owner.has_planning_work(): continue
		# Pure work can reach Ready while paused. Only the running clock admits
		# real work. No authoritative advance/settle/commit yields; pure route
		# work emits no session mutations, so callbacks receive settled state.
		# These three owners share one allowance per returned frame. Resource
		# estimates cannot consume logical mission seconds or starve departures.
		_planning_turn = (index+1)%owners.size()
		var changed: bool = owner.pump_planning(speed > 0,128,4000)
		if changed: rear.advance_time(0.0,true)
		_refresh_trip_admissions()
		return
	if speed == 0 or owed_simulation_seconds <= 0.0: return
	var before: float = rear.time
	rear.advance_time(minf(owed_simulation_seconds,LIVE_QUANTUM),true)
	owed_simulation_seconds = maxf(0.0,owed_simulation_seconds-(rear.time-before))
	_refresh_trip_admissions()

func after_command() -> void:
	if not _live_planning: return
	# Management callbacks receive the same settled t. Apply their immediate
	# effects in receipt order before recapturing private planning inputs.
	_accrue_live_wall_time()
	rear.military.troop_transport.invalidate_planning()
	var supply := _supply_travel_owner()
	if supply != null: supply.invalidate_planning()
	var resource := _resource_planning_owner()
	if resource != null: resource.invalidate_planning()
	rear.advance_time(0.0,true)
	_refresh_trip_admissions()
	planning_view_revision += 1

func _refresh_trip_admissions() -> void:
	var resource := _resource_planning_owner()
	if resource != null and int(resource.planning_revision) != _resource_view_revision:
		_resource_view_revision = int(resource.planning_revision)
		planning_view_revision += 1
	var supply := _supply_travel_owner()
	if supply != null and int(supply.planning_revision) != _supply_view_revision:
		_supply_view_revision = int(supply.planning_revision)
		planning_view_revision += 1
	var revision: int = rear.military.troop_transport.planning_revision
	if revision == _transport_view_revision: return
	_transport_view_revision = revision
	planning_view_revision += 1
	if rear.battlefield_operations == null: return
	var policy: RefCounted = rear.battlefield_operations.policy
	if policy != null and policy.has_method("refresh_trip_admissions"): policy.refresh_trip_admissions()

func _supply_travel_owner() -> RefCounted:
	return rear.battlefield_operations.supply_travel if rear.battlefield_operations != null else null

func _resource_planning_owner() -> RefCounted:
	if rear.battlefield_operations == null: return null
	var policy: RefCounted = rear.battlefield_operations.policy
	return policy.resource_planning_owner() if policy != null and policy.has_method("resource_planning_owner") else null

func set_speed(value: int) -> Dictionary:
	if value not in [0, 1, 2]: return {"ok": false, "message": "Choose Pause, 1x or 2x."}
	if _live_planning: _accrue_live_wall_time()
	speed = value
	if _live_planning: rear.vehicle_departures_allowed = speed > 0
	return {"ok": true, "message": "Paused" if speed == 0 else "%dx simulation speed" % speed,"speed_change":true}

func snapshot() -> Dictionary:
	var view := {"rear": rear.snapshot(), "receiving": receiving.snapshot(), "speed": speed,
		"production": rear.production.snapshot(), "munitions": rear.munitions_production.snapshot(),
		"materials": rear.materials_production.snapshot(), "support": rear.support_production.snapshot(),
		"training":rear.training.snapshot(), "heavy":rear.heavy_production.snapshot(),
		"vehicles":rear.vehicles.snapshot(), "dispatch":rear.dispatch.snapshot(),
		"hq":rear.hq.snapshot(), "construction":rear.construction.snapshot(),
		"military":rear.military.snapshot(rear.PLAYER), "combat":rear.combat.snapshot(rear.PLAYER), "orders":rear.orders.snapshot(), "objectives":rear.objectives.snapshot(), "forward_supply":rear.forward_supply.snapshot(), "field_structures":rear.field_structures.snapshot(), "bridges":rear.bridges.snapshot(), "demolition":rear.demolition.snapshot(), "mines":rear.mines.snapshot(), "expanded_catalogue": expanded_catalogue}
	view.rear.people = view.rear.people.filter(func(person: Dictionary) -> bool: return person.owner == rear.PLAYER)
	view.rear.ledger.entities = view.rear.ledger.entities.filter(func(entity: Dictionary) -> bool: return entity.owner != "army-red")
	return view

func audit() -> Array[String]:
	var failures: Array[String] = rear.audit()
	failures.append_array(receiving.audit())
	failures.append_array(rear.dispatch.audit())
	failures.append_array(rear.hq.audit())
	failures.append_array(rear.construction.audit())
	failures.append_array(rear.military.audit())
	failures.append_array(rear.combat.audit())
	failures.append_array(rear.recovery.audit())
	failures.append_array(rear.orders.audit())
	failures.append_array(rear.objectives.audit())
	failures.append_array(rear.forward_supply.audit())
	if rear.battlefield_operations != null: failures.append_array(rear.battlefield_operations.audit())
	failures.append_array(rear.field_structures.audit())
	failures.append_array(rear.bridges.audit())
	failures.append_array(rear.demolition.audit())
	failures.append_array(rear.mines.audit())
	if not is_equal_approx(rear.time, receiving._time) or not is_equal_approx(rear.time, rear.ledger.snapshot().time):
		failures.append("Shared event clocks disagree")
	for id in receiving._workers:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.duty_id not in receiving.freight_berths.map(func(row: Dictionary) -> String: return row.duty) or rear.actors[id].phase != "Unloading": failures.append("Receiving duty is not exclusive")
	return failures
