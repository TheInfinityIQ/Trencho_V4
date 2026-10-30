extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	var generic := Base.new()
	expect(generic.rear.actors.size() == 12 and generic.rear.yard.occupied[0] == "yard-t01","Generic fixture retains its twelve people and yard hull")
	var base := Base.new(false,false,true)
	var rear: RefCounted = base.rear
	expect(base.speed == 0 and rear.time == 0 and base.receiving.snapshot().money == 2500,"Opening is paused at time zero with2500 requisition")
	expect(rear.actors.size() == 60 and rear.receiving.rear_population() == 60,"Exactly sixty actual rear people")
	var types := {"P00":0,"P01":0,"P08":0}
	var available := 0
	for id in rear.actors:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		types[p.design_type] += 1
		expect(p.health == 100 and (p.qualification != "P08" or p.basic_training),"Healthy actual person with prerequisite: "+id)
		if p.assignment == "Available": available += 1
	expect(types == {"P00":42,"P01":12,"P08":6} and available == 11,"Exact qualification mix and eleven available")
	var stock := {"M01":600,"M02":300,"M03":200,"M04":600,"M05":100,"M06":40,"M07":40,"M08":200,"M09":40,"M10":20,"M11":500}
	for type in stock: expect(rear.ledger.available_stock_at("depot",type) == stock[type],"Exact depot "+type)
	expect(rear.ledger.total_stock("E01") == 0 and rear.ledger.entities_at("workshop_output",["WEAPON"]).is_empty(),"No starting manufactured weapons")
	expect(rear.ledger.inspect_entity("yard-t01").is_empty() and rear.ledger.rear_fleet_status(rear.PLAYER).live == 3,"No extra fixture hull")
	expect(rear.yard.PARKING_POSITIONS.size() == 8 and rear.construction.instances["initial-park-west"].center == Vector2(80,145),"Two physical F11 parks supply eight slots")
	for slot in rear.yard.PARKING_POSITIONS.size(): expect(rear.heavy_production._slot_legal(slot,"T01"),"Legal starting parking footprint: %d" % slot)
	for i in 3:
		var id := "start-vehicle-%02d" % i
		var hull: Dictionary = rear.ledger.inspect_entity(id)
		expect(hull.design_type == ("T02" if i == 2 else "T01") and hull.fuel == 40 and hull.crew.size() == 1 and hull.passengers.is_empty(),"Exact initial hull fuel and distinct driver: "+id)
		expect(rear.vehicles.readiness(id).transfer_crew_eligible and rear.yard.occupied[i] == id,"Same initial hull is dispatchable and parked: "+id)
	var staff := {"receiving":4,"workshop":4,"munitions":4,"support":0,"materials":6,"vehicle_works":4,"training":2,"dispatch":4,"hauling":16,"construction":2}
	for duty in staff: expect(rear.requests[duty].target == staff[duty] and rear._assigned(duty) == staff[duty],"Opening target and actual staffing: "+duty)
	expect(rear.production.stock_target == 32 and rear.munitions_production.stock_target == 6000 and rear.materials_production.stock_target == 1000,"GDD production targets")
	expect(rear.heavy_production.snapshot().selected_recipe.is_empty() and rear.training.rows.is_empty(),"No heavy selection or enrolled students")
	expect(not rear.heavy_production.resume().ok and not rear.heavy_production.accept_order().ok,"Enabling or ordering cannot invent an unselected heavy recipe")
	expect(base.audit().is_empty(),"Opening shared audit: "+str(base.audit()))
	var accepted: Dictionary = rear.dispatch.accept("start-vehicle-02","Strategic Delivery",[],{"M11":100})
	expect(accepted.ok,"Initialized strategic hull accepts a real supply manifest")
	rear.advance_time(1)
	expect(base.audit().is_empty(),"Initialized services advance consistently: "+str(base.audit()))
	expect(rear.heavy_production.request_recipe("R25").ok and rear.heavy_production.enabled,"Player can select the first vehicle recipe")
	print("Rear start regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
