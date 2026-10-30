extends RefCounted
## GDD20.2 declared initial supply, not a runtime transfer or replenishment.
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const HQ_STOCK := {"E02":6000,"E08":2,"E11":2,"E21":2,"E12":40,"M11":600,"M06":40,"M08":300}
const MASS := {"E02":0.02,"E08":6.0,"E11":4.0,"E21":4.0,"E12":1.0,"M11":1.0,"M06":1.0,"M08":1.0}

static func apply(base: RefCounted) -> Dictionary:
	var rear: RefCounted = base.rear
	assert(rear.time == 0.0 and base.speed == 0 and rear.military.squads.is_empty())
	assert(rear.dispatch.hq_position == Vector2(2000,450),"Scenario HQ berth must be outside the declared blue HQ footprint")
	var armies := {}
	for side in ["blue","red"]:
		var owner: String = "army-"+side
		var prefix: String = "start-"+side
		var centre := Vector2(2000,400 if side == "blue" else 5600)
		var stage := centre+Vector2(0,250 if side == "blue" else -250)
		var stage_id: String = prefix+"-stage"
		_must(rear.ledger.add_place(stage_id,"Initial troop staging",stage))
		var hq_stock: String = "hq-stock" if side == "blue" else prefix+"-hq-stock"
		var hq_reserve: String = "hq-reserve" if side == "blue" else prefix+"-hq-reserve"
		if side == "red":
			_must(rear.ledger.add_place(hq_stock,"Opposing HQ local stock and service staging",centre+Vector2(0,50)))
			_must(rear.ledger.add_place(hq_reserve,"Opposing HQ reserve staging",centre+Vector2(15,50)))
			for index in 5: _must(rear.ledger.add_initial_hq_person(prefix+"-hq-%02d" % index,hq_stock,owner,Records.Assignment.HQ_DUTY))
		for type in HQ_STOCK: _must(rear.ledger.add_stock(prefix+"-hq-"+type,type,HQ_STOCK[type],MASS[type],hq_stock,owner))
		for index in 16: _must(rear.ledger.add_weapon(prefix+"-hq-rifle-%02d" % index,"E01",4,hq_stock,owner,"E02",30))
		for index in 2:
			var id: String = prefix+"-recovery-%02d" % index
			_must(rear.ledger.add_initial_hq_person(id,hq_reserve,owner,Records.Assignment.HQ_RESERVE,"P03"))
			_stock(rear,id,"E11",1,owner)
			_stock(rear,id,"E12",5,owner)
			if side == "blue":
				rear.dispatch.military_people[id] = "Initial recovery team"
				rear.dispatch.hq_reserve[id] = "Occupied"
		var company: String = prefix+"-company"
		var rifles: Array[String] = []
		var squad_ids: Array[String] = []
		for squad_index in 5:
			var kind := "Rifle" if squad_index < 3 else ("Engineer" if squad_index == 3 else "Medical")
			var squad_id: String = prefix+"-squad-%02d" % squad_index
			var roster: Array[String] = []
			for person_index in 8:
				var person_id: String = squad_id+"-person-%02d" % person_index
				var qualification := "P02" if squad_index == 3 and person_index < 2 else ("P03" if squad_index == 4 and person_index < 2 else "None")
				_must(rear.ledger.add_person(person_id,stage_id,owner,Records.Assignment.AVAILABLE,true,qualification,"None"))
				var at: Vector2 = stage+Vector2((-30 if squad_index < 2 else 30)+(person_index-3.5)*2.0,-18 if squad_index in [0,3] else 0)
				if squad_index == 2: at = centre+Vector2((person_index-3.5)*2,60 if side == "blue" else -60)
				_must(rear.ledger.move_entity(person_id,stage_id,at))
				_must(rear.ledger.add_weapon(person_id+"-rifle","E01",4,person_id,owner,"E02",30))
				_stock(rear,person_id,"E02",60 if kind == "Rifle" else 30,owner)
				_must(rear.ledger.load_rounds(person_id+"-rifle",person_id+"-E02",10))
				if qualification == "P02": _stock(rear,person_id,"E08",1,owner)
				if qualification == "P03":
					_stock(rear,person_id,"E11",1,owner)
					_stock(rear,person_id,"E12",6,owner)
					_stock(rear,person_id,"E21",1,owner)
				roster.append(person_id)
			var platoon: String = prefix+("-platoon-rifle" if squad_index < 3 else "-platoon-support")
			_must(rear.military.add_initial_squad(squad_id,kind,roster,company,platoon,owner))
			squad_ids.append(squad_id)
			if kind == "Rifle": rifles.append(squad_id)
		var hulls: Array[Dictionary] = []
		for hull_index in 4:
			var type := "T02" if hull_index < 2 else ("T01" if hull_index == 2 else "T03")
			var hull_id: String = prefix+"-vehicle-%02d" % hull_index
			var pad_id: String = hull_id+"-pad"
			var at: Vector2 = stage+Vector2(-30 if hull_index%2 == 0 else 30,-12 if hull_index < 2 else 20)
			_must(rear.ledger.add_place(pad_id,"Initial vehicle staging pad",at))
			_must(rear.ledger.add_initial_vehicle(hull_id,type,pad_id,owner,Specs.TYPES[type],float(Specs.TYPES[type].tank_capacity),"Military"))
			for station in Specs.TYPES[type].stations:
				var crew_id: String = hull_id+"-"+str(station).to_lower()
				_must(rear.ledger.add_person(crew_id,pad_id,owner,Records.Assignment.AVAILABLE,true,"P04" if station == "Gunner" else "P08","None"))
				_must(rear.ledger.assign_initial_vehicle_crew(crew_id,hull_id,station))
				if side == "blue": rear.dispatch.military_people[crew_id] = "Initial vehicle crew"
			if side == "blue": rear.dispatch.military_hulls[hull_id] = "Initial field fleet"
			if type == "T03":
				_stock(rear,hull_id,"E02",900,owner)
				rear.vehicle_combat._mount(hull_id).loaded.MG = 60
			var parent: String = company if type == "T02" else prefix+("-platoon-support" if type == "T01" else "-platoon-rifle")
			hulls.append({"id":hull_id,"parent":parent})
		armies[owner] = {"root":"army" if side == "blue" else "army-red","company":company,"hq":centre,"staging":stage_id,"stock":hq_stock,"commander":"initial-hq-05" if side == "blue" else prefix+"-hq-04","rifles":rifles,"engineer":squad_ids[3],"medical":squad_ids[4],"hulls":hulls}
	return armies

static func _stock(rear: RefCounted, holder: String, type: String, quantity: int, owner: String) -> void:
	_must(rear.ledger.add_stock(holder+"-"+type,type,quantity,MASS[type],holder,owner))

static func _must(result: Dictionary) -> void:
	if not result.ok: push_error(str(result))
	assert(result.ok,"Invalid starting battlefield state")
