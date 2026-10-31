extends RefCounted
## One explicit authored opening, with physical starting supply and no runtime grants.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Map = preload("res://game/battlefield/farmland_scenario.gd")
const Start = preload("res://game/scenario/battlefield_start.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
const Opening = preload("res://game/battlefield/opening_policy.gd")

static func create() -> RefCounted:
	var base := Base.new(false,true,true,Vector2(2000,450),false,{"heavy":["R30"],"munitions":["R33"]})
	var rear: RefCounted = base.rear
	Map.apply(rear.combat.world)
	for objective in Map.OBJECTIVES:
		_must(rear.ledger.add_place(objective.id,objective.kind,objective.position))
		_must(rear.objectives.register(objective.id,objective.kind))
	_must(rear.ledger.add_place("enemy-hq","Opposing headquarters",Map.RED_HQ))
	_must(rear.orders.register_enemy_hq("enemy-hq"))
	_must(Map.initialize_defences(rear))
	var armies: Dictionary = Start.apply(base)
	for army in armies.values():
		for hull in army.hulls: _must(rear.military.attach_initial_vehicle(hull.id,hull.parent))
	for squad in rear.military.squads: _must(rear.orders.watch(squad))
	var points: Dictionary = Map.waypoints()
	_must(rear.ledger.add_place("blue-delivery","Forward supply stop",points["blue-delivery"]))
	_must(rear.forward_supply.register_delivery_stop("blue-delivery",points["blue-delivery-route"],points["blue-delivery-return"]))
	rear.battlefield_operations = Execution.new(rear)
	rear.battlefield_operations.policy = Opening.new(rear,armies,points)
	rear.advance_time(0)
	return base

static func _must(result: Dictionary) -> void:
	assert(result.ok,str(result))
