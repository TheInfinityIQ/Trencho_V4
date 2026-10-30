extends RefCounted
## Explicit scenario initial conditions; actions use the shared live services.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Records = preload("res://game/identity/identity_records.gd")
var base := Base.new(true)
var b02: String
var b03: String

func _init() -> void:
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	b03 = _bridge("B03",101)
	b02 = _bridge("B02",301)
	hull("tractor","T05",Vector2(80.5,20.5),true)
	hull("tow","T05",Vector2(68.5,20.5),true)
	for id in ["tractor","tow"]:
		ledger.add_stock(id+"-shells","E25",40,12.0,id,rear.PLAYER)
		ledger.add_stock(id+"-coax","E02",1200,0.02,id,rear.PLAYER)
		ledger.add_stock(id+"-freight","M11",200,1.0,id,rear.PLAYER)
	ledger.apply_device_damage("tow",100,200,"Scenario initial surviving bottom hit")
	engineer("repairer",Vector2(80.5,23.5))
	ledger.add_stock("local-m11","M11",100,1.0,"repairer-ground",rear.PLAYER)
	hull("carrier","T02",Vector2(500,50),false)
	for id in ["healthy","injured","incapacitated"]:
		ledger.add_person(id,"carrier",rear.PLAYER,Records.Assignment.PASSENGER,true)
		ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",5)
		ledger.add_stock(id+"-rounds","E02",5,0.02,id,rear.PLAYER)
	rear.combat.injure("injured",50)
	rear.combat.injure("incapacitated",100)
	ledger.add_stock("freight-a","M11",3,1.0,"carrier",rear.PLAYER)
	ledger.add_stock("freight-b","M11",4,1.0,"carrier",rear.PLAYER)
	ledger.add_stock("odd-rounds","E02",7,0.02,"carrier",rear.PLAYER)

func hull(id: String, type: String, position: Vector2, crew: bool) -> void:
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	ledger.reserve_rear_hull(id+"-admit",rear.PLAYER,id)
	ledger.create_heavy_output(id+"-admit",id,id,type,"hq-berth",rear.PLAYER,Specs.TYPES[type])
	ledger.complete_hq_hull_receipt(id)
	rear.dispatch.military_hulls[id] = id
	if crew:
		for station in Specs.TYPES[type].stations:
			var person: String = id+"-"+str(station)
			ledger.add_person(person,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08")
			rear.dispatch.military_people[person] = id
			ledger.request_military_crew_report(person,id,station)
			ledger.move_entity(person,"hq-berth",ledger.inspect_entity("hq-berth").position)
			ledger.complete_military_crew_report(person,id,station)
	ledger.add_place(id+"-fuel-place","Initial local fuel",ledger.inspect_entity("hq-berth").position)
	ledger.add_stock(id+"-fuel","M08",int(Specs.TYPES[type].tank_capacity),1.0,id+"-fuel-place",rear.PLAYER)
	ledger.add_person(id+"-fueler","hq-berth",rear.PLAYER,Records.Assignment.HQ_DUTY,true)
	var remaining: int = int(Specs.TYPES[type].tank_capacity)
	while remaining > 0:
		var count := mini(20,remaining)
		assert(ledger.begin_carry(id+"-fueler",id+"-fuel",count).ok)
		assert(ledger.load_vehicle_fuel(id+"-fueler",id).ok)
		remaining -= count
	ledger.add_place(id+"-ground","Scenario physical ground",position)
	ledger.move_entity(id,id+"-ground",position)

func engineer(id: String, position: Vector2) -> void:
	var ledger: RefCounted = base.rear.ledger
	ledger.add_place(id+"-ground","Engineer physical ground",position)
	ledger.add_person(id,id+"-ground",base.rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02")
	ledger.add_stock(id+"-kit","E08",1,5.0,id,base.rear.PLAYER)

func _bridge(code: String, x: int) -> String:
	var rear: RefCounted = base.rear
	rear.combat.world.paint(Rect2i(x,10,20,20),"TR11")
	var result: Dictionary = rear.bridges.order(code,Vector2(x-0.5,20.5),Vector2(x+20.5,20.5))
	assert(result.ok,"Bridge order failed")
	var id: String = result.id
	for n in range(2):
		var person := id+"-builder-"+str(n)
		engineer(person,rear.bridges.projects[id].banks[0])
		rear.bridges.assign_engineer(id,person)
	rear.ledger.add_stock(id+"-material","M11",result.m11,1.0,rear.bridges.projects[id].places[0],rear.PLAYER)
	rear.advance_time(float(result.work)/2.0)
	assert(rear.bridges.inspect(id).state == "Complete")
	return id
