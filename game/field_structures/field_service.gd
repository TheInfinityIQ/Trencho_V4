extends RefCounted
## G19 field sites use the accepted G01 ledger, G08 world and rear event clock.
const Catalog = preload("res://game/field_structures/field_catalogue.gd")
const Terrain = preload("res://game/terrain/terrain_catalog.gd")
const Routes = preload("res://game/routes/route_planner.gd")
const EPS := 0.000001
var _rear_ref: WeakRef
var projects: Dictionary = {}
var workers: Dictionary = {} # person -> one field project
var service_staff: Dictionary = {} # person -> one completed service site
var repairs: Dictionary = {} # target -> committed local repair work
var clearances: Dictionary = {} # completed wire/obstacle -> actual P02 work
var crush_contacts: Dictionary = {} # segment -> actual T05 and elapsed contact
var events: Array[Dictionary] = []
var _sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func order(code: String, center: Vector2, owner: String = "army-blue", company_id: String = "", facing: float = 0.0) -> Dictionary:
	if not Catalog.SPECS.has(code) or not center.is_finite() or not is_finite(facing) or owner not in ["army-blue","army-red"]:
		return _fail("Choose one S01–S12 blueprint, finite position and actual army owner.")
	if not company_id.is_empty() and not _rear().military.companies.has(company_id): return _fail("A named company must be an actual G15 company.")
	var spec: Dictionary = Catalog.SPECS[code]
	var area := Rect2(center-Vector2(spec.size)*0.5,Vector2(spec.size))
	var cells := Rect2i(Vector2i(floor(area.position.x),floor(area.position.y)),Vector2i(ceil(area.size.x),ceil(area.size.y)))
	if not _rear().combat.world.bounds.encloses(cells): return _fail("Field footprint must remain inside the declared world.")
	for row in projects.values():
		if row.state != "Cancelled" and row.state != "Destroyed" and area.intersects(row.area): return _fail("Field footprint overlaps an active actual site.")
	var same_kind := 0
	var segments := 0
	for row in projects.values():
		if row.state in ["Cancelled","Destroyed"] or row.owner != owner: continue
		if row.code == code and (row.company == company_id or code == "S10"): same_kind += 1
		if row.code in ["S01","S02","S04","S05"]: segments += 1
	if code in ["S07","S08","S09"] and same_kind >= 1 or code == "S06" and same_kind >= 2 or code == "S10" and same_kind >= 4 or code in ["S01","S02","S04","S05"] and segments >= 100:
		return _fail("Visible army/company field-structure cap reached.")
	var checked: Dictionary = _surface_legal(code,cells)
	if not checked.ok: return checked
	_sequence += 1
	var id := "field-%04d" % _sequence
	var added: Dictionary = _rear().ledger.add_place(id,"%s physical field site" % code,center)
	if not added.ok: return added
	var entrances: Array[Vector2] = [center]
	if code == "S01": entrances = [center+Vector2(-10,0),center,center+Vector2(10,0)]
	projects[id] = {"id":id,"code":code,"name":spec.name,"company":company_id,"owner":owner,"center":center,"area":area,"cells":cells,"facing":facing,"entrances":entrances,"state":"Awaiting material and engineers","progress":0.0,"work_required":float(spec.work),"m11_required":int(spec.m11),"m11_consumed":0,"health":maxi(1,int(spec.health/4)) if code != "S11" else 0,"max_health":int(spec.health),"load_kg":float(spec.get("load_kg",0.0)),"upgrade_from_basic":false,"assigned":[],"staff":[],"occupants":[],"patients":[],"berths":[],"last_entry":-INF,"last_damage":-INF,"blocked_reason":"Stage all M11 at this physical site, then bring local P02 engineers with E08.","created_at":_rear().time,"completed_at":-1.0,"material_receipt":[]}
	events.append({"at":_rear().time,"id":id,"kind":"Ordered","detail":code})
	return {"ok":true,"id":id,"message":"Actual field site placed; work and capability await local people, tools and full delivered M11."}

func assign_engineer(site_id: String, person_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state in ["Complete","Cancelled","Destroyed"] or engineer_committed(person_id) or (_rear().bridges != null and _rear().bridges.engineer_committed(person_id)) or (_rear().demolition != null and _rear().demolition.engineer_committed(person_id)) or (_rear().mines != null and _rear().mines.engineer_committed(person_id)): return _fail("Choose an unfinished site and an engineer not already committed elsewhere.")
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	if person.get("kind","") != "PERSON" or person.owner != row.owner or person.qualification != "P02": return _fail("A real friendly P02 engineer is required.")
	if row.assigned.size() >= 4: return _fail("At most four engineers may share one ordinary field project.")
	row.assigned.append(person_id)
	workers[person_id] = site_id
	_refresh_site(row)
	return {"ok":true,"message":"Engineer committed to this site; work still requires physical reach, E08, safety and full M11."}

func release_engineer(person_id: String) -> Dictionary:
	if not workers.has(person_id): return _fail("This person has no field-project commitment.")
	var site_id: String = workers[person_id]
	workers.erase(person_id)
	projects[site_id].assigned.erase(person_id)
	_refresh_site(projects[site_id])
	return {"ok":true,"message":"Engineer released; earned work and consumed goods remain."}

func engineer_committed(person_id: String) -> bool:
	if workers.has(person_id) or service_staff.has(person_id): return true
	for job in repairs.values():
		if person_id in job.engineers: return true
	for job in clearances.values():
		if job.engineer == person_id: return true
	return false

func _repair_busy(person_id: String) -> bool:
	for job in repairs.values():
		if person_id in job.engineers: return true
	return false

func stage_request(site_id: String, source_id: String, priority: int = 1) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state in ["Complete","Cancelled","Destroyed"]: return _fail("Only an unfinished actual site can request materials.")
	var missing: int = maxi(0,int(row.m11_required)-_rear().ledger.available_stock_at(site_id,"M11"))
	if missing == 0: return {"ok":true,"message":"Full M11 already staged at the site."}
	if _rear().ledger.inspect_entity(source_id).get("kind","") != "PLACE": return _fail("Source must be an actual physical stock place.")
	var available: int = _rear().ledger.available_stock_at(source_id,"M11")
	if available < missing: return _fail("Source has %d available M11; %d are missing at the site. This planning check does not move or reserve goods." % [available,missing])
	# A field destination is outside the rear-only G03 store path. Report the
	# actual requirement; delivery is confirmed only by the endpoint transfer.
	return {"ok":true,"source":source_id,"destination":site_id,"type":"M11","quantity":missing,"priority":priority,"message":"Move actual M11 to the site by a field transport activity; no material is reserved or delivered by this request."}

func deliver_material(site_id: String, stock_id: String, count: int) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	var stock: Dictionary = _rear().ledger.inspect_entity(stock_id)
	if row.is_empty() or row.state in ["Cancelled","Destroyed"] or stock.get("kind","") != "STOCK" or stock.owner != row.owner or count <= 0: return _fail("Actual owned stock and an active destination required.")
	if stock.holder_id == site_id: return {"ok":true,"message":"Stock is already physically staged at the site."}
	var holder: Dictionary = _rear().ledger.inspect_entity(stock.holder_id)
	if holder.get("kind","") not in ["PERSON","CARRIER"] or holder.position.distance_to(row.center) > 2.0+EPS: return _fail("A real person or carrier must finish its movement to within two metres of the field site with this stock.")
	if row.state != "Complete" and (stock.design_type != "M11" or _rear().ledger.available_stock_at(site_id,"M11")+count > row.m11_required): return _fail("Temporary construction supply area holds exactly this blueprint's remaining M11, with no other free storage.")
	if row.state == "Complete":
		match row.code:
			"S06","S07":
				var current_mass := 0.0
				for item in _rear().ledger.entities_at(site_id,["STOCK"]): current_mass += float(item.quantity)*float(item.unit_mass_kg)
				if current_mass+float(stock.unit_mass_kg)*count > float(Catalog.SPECS[row.code].storage_kg)+EPS: return _fail("Actual cache or depot mass capacity would be exceeded.")
			"S08":
				if stock.design_type != "E12": return _fail("A completed aid post accepts only actual E12 medicine through this service handoff.")
			"S09":
				if stock.design_type != "M11": return _fail("A completed repair point accepts only actual M11 repair material through this service handoff.")
			_:
				return _fail("This completed structure has no permanent stock service; its construction supply area has closed.")
	var moved: Dictionary
	if holder.kind == "PERSON" and holder.carrying_stock_id == stock_id:
		if count != stock.quantity: return _fail("An active person carry must deposit its whole physical load at this site.")
		moved = _rear().ledger.finish_carry(holder.id,site_id)
	else: moved = _rear().ledger.transfer_stock(stock_id,count,site_id)
	if moved.ok and row.state != "Complete": _refresh_site(row)
	return moved

func assign_staff(site_id: String, person_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state != "Complete" or row.code not in ["S06","S07","S08","S09","S10"] or engineer_committed(person_id) or (_rear().bridges != null and _rear().bridges.engineer_committed(person_id)) or (_rear().mines != null and _rear().mines.engineer_committed(person_id)): return _fail("Choose a completed field service and an uncommitted actual person.")
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	if person.get("kind","") != "PERSON" or person.owner != row.owner or person.health <= 0 or person.assignment in ["Wounded","Recovery","Dead"]: return _fail("Active friendly person required.")
	if row.code in ["S07","S09"] and row.staff.size() >= 2 or row.code in ["S08","S10"] and row.staff.size() >= 1: return _fail("Service staffing positions are full.")
	row.staff.append(person_id)
	service_staff[person_id] = site_id
	return {"ok":true,"message":"Person assigned; readiness still follows actual local qualification, tools and stock."}

func release_staff(person_id: String) -> Dictionary:
	if not service_staff.has(person_id): return _fail("No field service assignment exists.")
	var id: String = service_staff[person_id]
	service_staff.erase(person_id)
	projects[id].staff.erase(person_id)
	return {"ok":true,"message":"Actual person released; service readiness recalculated."}

func service_status(site_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty(): return _fail("Unknown actual field site.")
	if row.state != "Complete": return {"ok":false,"reason":"Structure incomplete, damaged beyond operation or destroyed.","staff":[],"local_stock":{}}
	var local: Array[String] = []
	for id in row.staff:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if person.get("kind","") == "PERSON" and person.owner == row.owner and person.health > 0 and person.assignment not in ["Wounded","Recovery","Dead"] and person.position.distance_to(row.center) <= 2.0 and person.crew_station.is_empty(): local.append(id)
	var reason := ""
	var stock := {}
	var bay_target := ""
	match row.code:
		"S06":
			var mass := 0.0
			for item in _rear().ledger.entities_at(site_id,["STOCK"]): mass += float(item.quantity)*float(item.unit_mass_kg)
			stock = {"mass_kg":mass,"capacity_kg":2000.0}
			if mass <= EPS: reason = "Cache is empty; it creates no supplies."
			elif mass > 2000.0+EPS: reason = "Cache exceeds physical capacity."
		"S07":
			if local.size() < 2: reason = "Two actual local logistics staff required."
			var depot_mass := 0.0
			for item in _rear().ledger.entities_at(site_id,["STOCK"]): depot_mass += float(item.quantity)*float(item.unit_mass_kg)
			stock = {"mass_kg":depot_mass,"capacity_kg":10000.0,"berths":2}
			if reason.is_empty() and depot_mass <= EPS: reason = "Depot has no physically delivered goods to dispatch."
			if reason.is_empty() and depot_mass > 10000.0+EPS: reason = "Depot exceeds physical capacity."
		"S08":
			if local.is_empty() or _rear().ledger.inspect_entity(local[0]).qualification != "P03" or _rear().military._held(local[0],"E11") < 1: reason = "Local P03 medic with E11 required."
			elif _rear().ledger.available_stock_at(site_id,"E12") + _rear().military._held(local[0],"E12") < 1: reason = "Physical E12 at aid post or carried by its medic required; empty post gives no treatment."
		"S09":
			for target_id in repairs:
				if repairs[target_id].point == site_id: bay_target = target_id
			var ready_engineer := false
			for id in local:
				if _rear().ledger.inspect_entity(id).qualification == "P02" and _rear().military._held(id,"E08") > 0: ready_engineer = true
			if not bay_target.is_empty(): reason = "The one repair bay is occupied by "+bay_target+"."
			elif not ready_engineer: reason = "Local P02 engineer with E08 required."
			elif _rear().ledger.available_stock_at(site_id,"M11") < 10: reason = "Ten local M11 required per repair; empty point repairs nothing."
		"S10":
			if local.is_empty() or not _rear().ledger.inspect_entity(local[0]).basic_training or _rear().military._held(local[0],"E20") < 1: reason = "Trained local observer with actual E20 required."
		_: pass
	return {"ok":reason.is_empty(),"reason":reason,"staff":local,"local_stock":stock,"bay_target":bay_target,"capacity":Catalog.SPECS[row.code]}

func lookout_observe(site_id: String, target: Vector2) -> Dictionary:
	var status: Dictionary = service_status(site_id)
	if not status.ok or projects[site_id].code != "S10": return _fail("Lookout needs an operational S10 and real local observer/E20.")
	return _rear().combat.world.observe(projects[site_id].center,target,"lookout_staffed")

func start_aid_care(site_id: String, patient_id: String, pack_id: String) -> Dictionary:
	var status: Dictionary = service_status(site_id)
	if not status.ok or projects[site_id].code != "S08": return _fail("Aid post lacks its actual medic, tools or supplies.")
	if not projects[site_id].patients.has(patient_id): return _fail("Actual patient must first occupy one of the aid post's eight patient places.")
	var patient: Dictionary = _rear().ledger.inspect_entity(patient_id)
	if patient.get("kind","") != "PERSON" or patient.position.distance_to(projects[site_id].center) > 2.0+EPS: return _fail("Actual patient must be at the aid post.")
	var medic_id: String = status.staff[0]
	var pack: Dictionary = _rear().ledger.inspect_entity(pack_id)
	if pack.get("kind","") != "STOCK" or pack.design_type != "E12" or pack.holder_id != medic_id: return _fail("One actual E12 pack must first be carried by this medic.")
	return _rear().combat.start_care(medic_id,patient_id,pack_id)

func admit_patient(site_id: String, patient_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	var patient: Dictionary = _rear().ledger.inspect_entity(patient_id)
	if row.is_empty() or row.code != "S08" or row.state != "Complete" or patient.get("kind","") != "PERSON" or patient.owner != row.owner or patient.assignment != "Wounded" or patient.position.distance_to(row.center) > 2.0+EPS: return _fail("An actual friendly wounded person must reach a completed aid post.")
	if row.patients.has(patient_id): return {"ok":true,"message":"Patient already occupies one place."}
	if row.patients.size() >= 8: return _fail("All eight actual aid-post patient places are occupied.")
	row.patients.append(patient_id)
	return {"ok":true,"message":"One real patient admitted; qualified local care and a carried E12 pack remain necessary."}

func discharge_patient(site_id: String, patient_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or not row.patients.has(patient_id): return _fail("No such admitted patient.")
	row.patients.erase(patient_id)
	return {"ok":true,"message":"Actual patient place released; the person's health and location are unchanged."}

func dock_vehicle(site_id: String, hull_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
	if row.is_empty() or row.code != "S07" or row.state != "Complete" or hull.get("kind","") != "CARRIER" or hull.owner != row.owner or hull.position.distance_to(row.center) > 2.0+EPS: return _fail("An actual friendly stopped carrier must reach the completed depot.")
	if row.berths.has(hull_id): return {"ok":true,"message":"Carrier already occupies this berth."}
	if row.berths.size() >= 2: return _fail("Both actual depot truck berths are occupied.")
	row.berths.append(hull_id)
	return {"ok":true,"message":"Carrier occupies one of two real depot berths; staff and stock still gate service."}

func undock_vehicle(site_id: String, hull_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or not row.berths.has(hull_id): return _fail("Carrier does not occupy this depot.")
	row.berths.erase(hull_id)
	return {"ok":true,"message":"Actual depot berth released."}

func withdraw_stock(site_id: String, stock_id: String, count: int, carrier_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	var stock: Dictionary = _rear().ledger.inspect_entity(stock_id)
	var carrier: Dictionary = _rear().ledger.inspect_entity(carrier_id)
	if row.is_empty() or row.code not in ["S06","S07"] or not service_status(site_id).ok or stock.get("kind","") != "STOCK" or stock.holder_id != site_id or count <= 0 or carrier.get("kind","") != "CARRIER" or carrier.owner != row.owner or carrier.position.distance_to(row.center) > 2.0+EPS: return _fail("Actual stocked service, owned local goods and a stopped friendly carrier are required.")
	if row.code == "S07" and not row.berths.has(carrier_id): return _fail("Depot loading requires this actual vehicle in one of its two berths.")
	return _rear().ledger.transfer_stock(stock_id,count,carrier_id)

func request_repair(target_id: String, engineers: Array, repair_point_id: String = "") -> Dictionary:
	if repairs.has(target_id) or engineers.is_empty() or engineers.size() > 2: return _fail("One unfinished repair per actual target, with one or two P02 engineers.")
	var target: Dictionary = projects.get(target_id,{}) if repair_point_id.is_empty() else _rear().ledger.inspect_entity(target_id)
	var site: Dictionary = projects.get(target_id,{}) if repair_point_id.is_empty() else projects.get(repair_point_id,{})
	if site.is_empty() or site.state != "Complete": return _fail("Repair needs an operational actual field site.")
	if not _site_safe(site): return _fail("Repair waits until no visible hostile is within 150 m and ten seconds have passed since site damage.")
	if repair_point_id.is_empty():
		if target.health <= 0 or target.health >= target.max_health or target.code == "S11": return _fail("Only a damaged, surviving ordinary structure can be repaired.")
	else:
		if site.code != "S09" or target.get("kind","") not in ["CARRIER","HEAVY_OBJECT"] or target.get("health",0) <= 0 or target.get("health",0) >= target.get("max_health",0) or target.position.distance_to(site.center) > 2.0+EPS: return _fail("A damaged, stationary actual vehicle or gun must be at the S09 bay.")
		for other_id in repairs:
			if repairs[other_id].point == repair_point_id: return _fail("The one S09 repair bay is occupied by "+other_id+"; this target waits.")
		if not service_status(repair_point_id).ok: return _fail("Repair point lacks actual P02, E08 or ten local M11.")
	for id in engineers:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if engineers.count(id) > 1 or person.get("kind","") != "PERSON" or person.owner != site.owner or person.qualification != "P02" or person.health <= 0 or person.position.distance_to(site.center) > 2.0+EPS or _rear().military._held(id,"E08") < 1 or workers.has(id) or _repair_busy(id) or (_rear().bridges != null and _rear().bridges.engineer_committed(id)) or (_rear().demolition != null and _rear().demolition.engineer_committed(id)) or (_rear().mines != null and _rear().mines.engineer_committed(id)) or (not repair_point_id.is_empty() and not site.staff.has(id)): return _fail("Each distinct assigned P02 needs actual local E08 and safe physical access.")
	var consumed: Dictionary = _rear().ledger.consume_local_batch(site.id,site.owner,{"M11":10},"G19 repair of "+target_id)
	if not consumed.ok: return consumed
	repairs[target_id] = {"target":target_id,"site":site.id,"point":repair_point_id,"engineers":engineers.duplicate(),"progress":0.0,"receipt":consumed.receipt,"at":_rear().time}
	return {"ok":true,"message":"Ten local M11 committed once; 40 actual engineer-work seconds remain."}

func cancel_repair(target_id: String) -> Dictionary:
	if not repairs.has(target_id): return _fail("No actual repair job exists.")
	repairs.erase(target_id)
	return {"ok":true,"message":"Repair cancelled; consumed M11 is lost and no health is granted."}

func clear_segment(site_id: String, engineer_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state != "Complete" or row.code not in ["S04","S05"] or clearances.has(site_id): return _fail("A completed wire or vehicle obstacle needs one clearance job.")
	var person: Dictionary = _rear().ledger.inspect_entity(engineer_id)
	if person.get("kind","") != "PERSON" or person.owner != row.owner or person.qualification != "P02" or person.health <= 0 or person.position.distance_to(row.center) > 2.0+EPS or _rear().military._held(engineer_id,"E08") < 1 or engineer_committed(engineer_id) or (_rear().bridges != null and _rear().bridges.engineer_committed(engineer_id)) or (_rear().demolition != null and _rear().demolition.engineer_committed(engineer_id)) or (_rear().mines != null and _rear().mines.engineer_committed(engineer_id)) or not _site_safe(row): return _fail("One uncommitted safe local P02 with E08 is required.")
	clearances[site_id] = {"engineer":engineer_id,"progress":0.0,"required":20.0 if row.code == "S04" else 120.0}
	return {"ok":true,"message":"Clearance started with no material yield; work pauses if engineer leaves."}

func crush_segment(site_id: String, hull_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
	if row.is_empty() or row.state != "Complete" or row.code not in ["S02","S04"] or hull.get("kind","") != "CARRIER" or hull.design_type != "T05" or not row.area.grow(4.0).has_point(hull.position): return _fail("Actual T05 contact with sound sandbags or wire is required.")
	if crush_contacts.has(site_id): return _fail("This segment already has a committed T05 contact.")
	crush_contacts[site_id] = {"hull":hull_id,"progress":0.0}
	return {"ok":true,"message":"Actual T05 contact started; the shared clock must earn three seconds before this segment clears."}

func _crush_ready(site_id: String, job: Dictionary) -> bool:
	var row: Dictionary = projects.get(site_id,{})
	var hull: Dictionary = _rear().ledger.inspect_entity(job.hull)
	return not row.is_empty() and row.state == "Complete" and hull.get("kind","") == "CARRIER" and hull.design_type == "T05" and row.area.grow(4.0).has_point(hull.position)

func _repair_rate(job: Dictionary) -> float:
	var site: Dictionary = projects.get(job.site,{})
	if site.is_empty() or site.state != "Complete" or not _site_safe(site): return 0.0
	if not job.point.is_empty():
		var target: Dictionary = _rear().ledger.inspect_entity(job.target)
		if target.is_empty() or target.position.distance_to(site.center) > 2.0+EPS: return 0.0
	var rate := 0.0
	for id in job.engineers:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if person.get("kind","") == "PERSON" and person.owner == site.owner and person.qualification == "P02" and person.health > 0 and person.position.distance_to(site.center) <= 2.0+EPS and _rear().military._held(id,"E08") > 0 and (job.point.is_empty() or site.staff.has(id)): rate += 1.0
	return rate

func _clearance_rate(site_id: String, job: Dictionary) -> float:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state != "Complete" or not _site_safe(row): return 0.0
	var person: Dictionary = _rear().ledger.inspect_entity(job.engineer)
	return 1.0 if person.get("kind","") == "PERSON" and person.owner == row.owner and person.qualification == "P02" and person.health > 0 and person.position.distance_to(row.center) <= 2.0+EPS and _rear().military._held(job.engineer,"E08") > 0 else 0.0

func working(person_id: String) -> bool:
	if not workers.has(person_id): return false
	var row: Dictionary = projects[workers[person_id]]
	return row.state == "Building" and person_id in _eligible_engineers(row)

func assess_vehicle(hull_id: String, facing: float = 0.0) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
	if hull.get("kind","") != "CARRIER" or not hull.has("vehicle_spec") or not Terrain.VEHICLES.has(hull.design_type): return _fail("An actual catalogued vehicle hull is required.")
	var direction := Vector2.from_angle(facing)
	var probe: Dictionary = _rear().combat.world.route({"position":hull.position,"facing":facing,"size":hull.vehicle_spec.footprint,"movement_class":Terrain.VEHICLES[hull.design_type].class,"base":Terrain.VEHICLES[hull.design_type].base,"rate":Terrain.VEHICLES[hull.design_type].rate,"gross_mass_kg":Routes.gross_kg(_rear().ledger,hull_id)},hull.position+direction*0.1)
	return {"ok":probe.ok,"status":"Mobile terrain support" if probe.ok else "Terrain Stranded","reason":"" if probe.ok else probe.reason,"position":hull.position,"health":hull.health,"hull":hull_id}

func route_vehicle(hull_id: String, destination: Vector2, facing: float = 0.0) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
	if hull.get("kind","") != "CARRIER": return _fail("An actual vehicle hull is required.")
	return Routes.plan(_rear().ledger,hull_id,[hull.position,destination],{"world":_rear().combat.world,"strict_turns":true})

func next_boundary() -> float:
	var next := INF
	for row in projects.values():
		if row.state in ["Complete","Cancelled","Destroyed"]: continue
		if row.last_damage + 10.0 > _rear().time + EPS: next = minf(next,float(row.last_damage)+10.0)
		var rate: float = float(_eligible_engineers(row).size())
		if rate > 0.0 and row.m11_consumed > 0:
			next = minf(next,_rear().time+(float(row.work_required)-float(row.progress))/rate)
	for job in repairs.values():
		var site: Dictionary = projects.get(job.site,{})
		if not site.is_empty() and site.last_damage + 10.0 > _rear().time + EPS: next = minf(next,float(site.last_damage)+10.0)
		var rate: float = _repair_rate(job)
		if rate > 0: next = minf(next,_rear().time+(40.0-float(job.progress))/rate)
	for id in clearances:
		var job: Dictionary = clearances[id]
		var site: Dictionary = projects.get(id,{})
		if not site.is_empty() and site.last_damage + 10.0 > _rear().time + EPS: next = minf(next,float(site.last_damage)+10.0)
		if _clearance_rate(id,job) > 0: next = minf(next,_rear().time+float(job.required)-float(job.progress))
	for id in crush_contacts:
		var job: Dictionary = crush_contacts[id]
		if _crush_ready(id,job): next = minf(next,_rear().time+3.0-float(job.progress))
	return next

func advance_to(at: float) -> void:
	var delta: float = at-_rear().time
	if delta <= EPS: return
	for row in projects.values():
		if row.m11_consumed <= 0 or row.state in ["Complete","Cancelled","Destroyed"]: continue
		var rate: float = float(_eligible_engineers(row).size())
		if rate <= 0.0: continue
		row.progress = minf(float(row.work_required),float(row.progress)+rate*delta)
	for job in repairs.values(): job.progress = minf(40.0,float(job.progress)+_repair_rate(job)*delta)
	for id in clearances:
		var job: Dictionary = clearances[id]
		job.progress = minf(float(job.required),float(job.progress)+_clearance_rate(id,job)*delta)
	for id in crush_contacts:
		var job: Dictionary = crush_contacts[id]
		if _crush_ready(id,job): job.progress = minf(3.0,float(job.progress)+delta)

func settle() -> bool:
	var changed := false
	for target_id in repairs.keys():
		var job: Dictionary = repairs[target_id]
		if job.progress < 40.0-EPS: continue
		if job.point.is_empty():
			var structure: Dictionary = projects[target_id]
			structure.health = mini(int(structure.max_health),int(structure.health)+100)
		else:
			var restored: Dictionary = _rear().ledger.apply_heavy_repair(target_id,100)
			if not restored.ok: continue
		repairs.erase(target_id)
		events.append({"at":_rear().time,"id":target_id,"kind":"Repaired","detail":"100 capped health from 10 M11 and 40 work"})
		changed = true
	for id in clearances.keys():
		var job: Dictionary = clearances[id]
		if job.progress < job.required-EPS: continue
		var site: Dictionary = projects[id]
		site.state = "Destroyed"
		site.health = 0
		site.blocked_reason = "Cleared by actual engineer work; no M11 or timber created."
		_rear().combat.world.set_project_structure(id,site.code,site.area,false)
		clearances.erase(id)
		events.append({"at":_rear().time,"id":id,"kind":"Cleared","detail":site.code})
		changed = true
	for id in crush_contacts.keys():
		var job: Dictionary = crush_contacts[id]
		if job.progress < 3.0-EPS or not _crush_ready(id,job): continue
		var site: Dictionary = projects[id]
		site.state = "Destroyed"
		site.health = 0
		site.blocked_reason = "Crushed by the actual T05 after three contact seconds; no free hull injury or material recovery."
		_rear().combat.world.set_project_structure(site.id,site.code,site.area,false)
		crush_contacts.erase(id)
		events.append({"at":_rear().time,"id":id,"kind":"Crushed","detail":job.hull})
		changed = true
	for row in projects.values():
		if row.state in ["Complete","Cancelled","Destroyed"]: continue
		changed = _refresh_site(row) or changed
		if row.m11_consumed > 0 and row.progress >= row.work_required-EPS:
			if row.code in ["S11","S12"]:
				var applied: Dictionary = _rear().combat.world.set_project_overlay(row.id,row.cells,"road" if row.code == "S11" else "causeway",true,float(row.load_kg))
				if not applied.ok:
					row.blocked_reason = applied.reason
					continue
			row.state = "Complete"
			row.health = row.max_health
			if row.code in ["S01","S02","S03","S04","S05"]: _rear().combat.world.set_project_structure(row.id,row.code,row.area,true,row.facing)
			row.completed_at = _rear().time
			row.blocked_reason = ""
			for id in row.assigned: workers.erase(id)
			row.assigned.clear()
			events.append({"at":_rear().time,"id":row.id,"kind":"Complete","detail":row.code})
			changed = true
	return changed

func cancel(site_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state in ["Complete","Cancelled","Destroyed"]: return _fail("Only unfinished field work can be cancelled.")
	var recovered := 0
	if row.m11_consumed > 0:
		recovered = int(row.m11_consumed/2)
		if recovered > 0:
			var pile_id := "field-salvage-%s" % site_id
			var placed: Dictionary = _rear().ledger.add_place(pile_id,"Recoverable cancelled field material",row.center)
			if not placed.ok: return placed
			var returned: Dictionary = _rear().ledger.recover_consumed_material(pile_id+"-m11","M11",recovered,1.0,pile_id,row.owner)
			if not returned.ok: return returned
	for id in row.assigned: workers.erase(id)
	row.assigned.clear()
	if row.upgrade_from_basic:
		row.upgrade_from_basic = false
		row.state = "Complete"
		row.progress = float(Catalog.SPECS.S12.work)
		row.work_required = float(Catalog.SPECS.S12.work)
		row.m11_required = int(Catalog.SPECS.S12.m11)
		row.m11_consumed = int(Catalog.SPECS.S12.m11)
		row.load_kg = 8000.0
		_rear().combat.world.set_project_overlay(row.id,row.cells,"causeway",true,row.load_kg)
		row.blocked_reason = "Heavy upgrade cancelled; basic completed causeway reopened with its prior 8t limit."
		return {"ok":true,"recovered":recovered,"message":row.blocked_reason}
	row.state = "Cancelled"
	row.blocked_reason = "Cancelled; staged unconsumed M11 stays at site, and %d consumed M11 returned as a recoverable pile." % recovered
	events.append({"at":_rear().time,"id":site_id,"kind":"Cancelled","detail":row.blocked_reason})
	return {"ok":true,"recovered":recovered,"message":row.blocked_reason}

func damage(site_id: String, amount: int) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state in ["Cancelled","Destroyed"] or row.code == "S11" or amount <= 0: return _fail("Only an actual damageable field structure can take positive damage.")
	var completed: bool = row.state == "Complete"
	row.health = maxi(0,int(row.health)-amount)
	row.last_damage = _rear().time
	if row.health == 0:
		row.state = "Destroyed"
		row.blocked_reason = "Destroyed; full rebuild and new physical M11 required."
		if completed and row.code == "S12": _rear().combat.world.set_project_overlay(row.id,row.cells,"causeway",false)
		if completed and row.code in ["S01","S02","S03","S04","S05"]: _rear().combat.world.set_project_structure(row.id,row.code,row.area,false)
		for id in row.assigned: workers.erase(id)
		row.assigned.clear()
		for id in row.staff: service_staff.erase(id)
		row.staff.clear()
		row.occupants.clear()
		row.patients.clear()
		row.berths.clear()
		events.append({"at":_rear().time,"id":site_id,"kind":"Destroyed","detail":row.code})
	return {"ok":true,"message":row.blocked_reason if row.health == 0 else "Actual structure health reduced without changing its material history."}

func rebuild(site_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state != "Destroyed": return _fail("Only a destroyed actual structure can be rebuilt.")
	row.state = "Awaiting material and engineers"
	row.progress = 0.0
	row.m11_consumed = 0
	row.material_receipt = []
	row.health = maxi(1,int(row.max_health/4))
	row.blocked_reason = "Rebuild needs a fresh full local M11 batch and actual engineers; broken support stays absent."
	events.append({"at":_rear().time,"id":site_id,"kind":"Rebuild ordered","detail":row.code})
	return {"ok":true,"message":row.blocked_reason}

func upgrade_causeway(site_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.code != "S12" or row.state != "Complete" or row.load_kg >= 80000.0: return _fail("Only a completed basic causeway has a heavy upgrade.")
	for item in _rear().ledger.snapshot().entities:
		if item.kind == "CARRIER" and row.area.has_point(item.position): return _fail("Causeway must be empty of actual vehicles before heavy upgrade.")
	row.upgrade_from_basic = true
	row.progress = 0.0
	row.work_required = float(Catalog.SPECS.S12.work)
	row.m11_required = int(Catalog.SPECS.S12.m11)
	row.m11_consumed = 0
	row.material_receipt = []
	row.state = "Awaiting material and engineers"
	row.load_kg = 80000.0
	_rear().combat.world.set_project_overlay(row.id,row.cells,"causeway",false,0.0,true)
	row.blocked_reason = "Heavy upgrade closed to traffic; another 100 M11 and 160 engineer-work are required."
	return {"ok":true,"message":row.blocked_reason}

func enter(site_id: String, person_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.state != "Complete" or row.code not in ["S01","S03","S06"]: return _fail("A finished personnel shelter is required.")
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	if person.get("kind","") != "PERSON" or person.owner not in ["army-blue","army-red"] or person.health <= 0 or not _at_entrance(row,person.position): return _fail("An actual living person must be at one of this structure's physical entrances.")
	if row.code == "S06" and person.owner != row.owner: return _fail("Enemy caches and their goods cannot be looted by entry.")
	for current_id in row.occupants:
		if _rear().ledger.inspect_entity(current_id).owner != person.owner: return _fail("Enemy occupants prevent entry until the shelter is cleared.")
	if row.occupants.has(person_id): return {"ok":true,"message":"Person already inside."}
	var used := 0
	for current_id in row.occupants:
		var current: Dictionary = _rear().ledger.inspect_entity(current_id)
		used += 2 if row.code == "S03" and current.qualification == "P04" and _rear().military._held(current_id,"E05") > 0 else 1
	var portable_mg: bool = row.code == "S03" and person.qualification == "P04" and _rear().military._held(person_id,"E05") > 0
	if portable_mg:
		for current_id in row.occupants:
			if _rear().military._held(current_id,"E05") > 0: return _fail("Only one actual portable machine gun may occupy a bunker.")
	if used+(2 if portable_mg else 1) > int(Catalog.SPECS[row.code].occupants): return _fail("Shelter occupancy is full.")
	if _rear().time-float(row.last_entry) < 1.0-EPS: return _fail("Entry supports one person per second.")
	row.occupants.append(person_id)
	row.last_entry = _rear().time
	return {"ok":true,"message":"One actual person entered, with no equipment or gun granted."}

func exit(site_id: String, person_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or not row.occupants.has(person_id): return _fail("Person is not in this actual structure.")
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	if person.get("kind","") != "PERSON" or not _at_entrance(row,person.position): return _fail("The actual occupant must reach a physical entrance to exit.")
	if _rear().time-float(row.last_entry) < 1.0-EPS: return _fail("Exit supports one person per second.")
	row.occupants.erase(person_id)
	row.last_entry = _rear().time
	return {"ok":true,"message":"Actual occupant left the structure."}

func _at_entrance(row: Dictionary, position: Vector2) -> bool:
	for entrance in row.entrances:
		if position.distance_to(entrance) <= 2.0+EPS: return true
	return false

func bunker_port_allows(site_id: String, person_id: String, target: Vector2) -> bool:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty() or row.code != "S03" or row.state != "Complete" or not row.occupants.has(person_id): return false
	var delta: Vector2 = target-row.center
	return delta.length() > EPS and absf(wrapf(delta.angle()-float(row.facing),-PI,PI)) <= PI/3.0+EPS

func occupant_fire_allowed(person_id: String, target: Vector2) -> bool:
	for row in projects.values():
		if row.code == "S03" and row.state == "Complete" and row.occupants.has(person_id): return bunker_port_allows(row.id,person_id,target)
	return true

func inspect(site_id: String) -> Dictionary:
	var row: Dictionary = projects.get(site_id,{})
	if row.is_empty(): return {}
	var result: Dictionary = row.duplicate(true)
	result["m11_local_available"] = _rear().ledger.available_stock_at(site_id,"M11")
	result["m11_missing"] = maxi(0,int(row.m11_required)-int(result.m11_local_available)) if row.m11_consumed == 0 else 0
	result["eligible_engineers"] = _eligible_engineers(row)
	result["service"] = service_status(site_id)
	return result

func snapshot() -> Dictionary:
	var rows := {}
	for id in projects: rows[id] = inspect(id)
	return {"projects":rows,"workers":workers.duplicate(true),"service_staff":service_staff.duplicate(true),"repairs":repairs.duplicate(true),"clearances":clearances.duplicate(true),"crush_contacts":crush_contacts.duplicate(true),"events":events.duplicate(true)}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for id in projects:
		var row: Dictionary = projects[id]
		if _rear().ledger.inspect_entity(id).get("kind","") != "PLACE" or not Catalog.SPECS.has(row.code) or row.progress < -EPS or row.progress > row.work_required+EPS: errors.append("G19 invalid physical site/progress: "+id)
		if row.code != "S11" and (row.health < 0 or row.health > row.max_health): errors.append("G19 invalid structure health: "+id)
		if row.m11_consumed not in [0,row.m11_required]: errors.append("G19 partial material consumption: "+id)
		for person_id in row.assigned:
			if workers.get(person_id,"") != id: errors.append("G19 engineer commitment mismatch: "+person_id)
		for person_id in row.staff:
			if service_staff.get(person_id,"") != id: errors.append("G19 service staff commitment mismatch: "+person_id)
		if row.patients.size() > 8 or row.berths.size() > 2: errors.append("G19 service capacity exceeded: "+id)
		if row.state == "Complete" and row.code in ["S11","S12"]:
			var tile: Dictionary = _rear().combat.world.cell(row.cells.get_center())
			if tile.get("overlay",{}).get("id","") != id: errors.append("G19 completed surface absent from terrain: "+id)
		if row.state == "Destroyed" and row.code == "S12" and _rear().combat.world.cell(row.cells.get_center()).get("overlay",{}).get("id","") == id: errors.append("G19 destroyed causeway still grants support: "+id)
	for person_id in workers:
		if not projects.has(workers[person_id]) or not projects[workers[person_id]].assigned.has(person_id): errors.append("G19 orphan engineer commitment: "+person_id)
	for person_id in service_staff:
		if not projects.has(service_staff[person_id]) or not projects[service_staff[person_id]].staff.has(person_id): errors.append("G19 orphan service staff commitment: "+person_id)
	for target_id in repairs:
		var job: Dictionary = repairs[target_id]
		if not projects.has(job.site) or job.progress < -EPS or job.progress > 40.0+EPS: errors.append("G19 invalid repair job: "+target_id)
	for id in clearances:
		if not projects.has(id) or clearances[id].progress < -EPS or clearances[id].progress > clearances[id].required+EPS: errors.append("G19 invalid clearance job: "+id)
	return errors

func _refresh_site(row: Dictionary) -> bool:
	var old_state: String = row.state
	var old_blocker: String = row.blocked_reason
	if row.m11_consumed <= 0:
		var local: int = _rear().ledger.available_stock_at(row.id,"M11")
		if local < row.m11_required:
			row.state = "Awaiting material and engineers"
			row.blocked_reason = "%d M11 missing at site; HQ or in-transit stock is not staged." % (int(row.m11_required)-local)
		else:
			var engineers: Array[String] = _eligible_engineers(row)
			if engineers.is_empty():
				row.state = "Awaiting engineers"
				row.blocked_reason = "Full M11 staged; local P02 with E08 and safe access required."
			else:
				var spent: Dictionary = _rear().ledger.consume_local_batch(row.id,row.owner,{"M11":int(row.m11_required)},"G19 field project "+row.id)
				if spent.ok:
					row.m11_consumed = row.m11_required
					row.material_receipt = spent.receipt
					row.state = "Building"
					row.blocked_reason = ""
					events.append({"at":_rear().time,"id":row.id,"kind":"Started","detail":"Actual staged M11 consumed once."})
				else: row.blocked_reason = spent.message
	else:
		if _eligible_engineers(row).is_empty():
			row.state = "Paused"
			row.blocked_reason = "Work paused; progress and consumed M11 retained until safe local P02/E08 return."
		else:
			row.state = "Building"
			row.blocked_reason = ""
	return old_state != row.state or old_blocker != row.blocked_reason

func _eligible_engineers(row: Dictionary) -> Array[String]:
	var eligible: Array[String] = []
	if not _site_safe(row): return eligible
	for id in row.assigned:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if person.is_empty() or person.owner != row.owner or person.qualification != "P02" or person.health <= 0 or person.assignment in ["Wounded","Recovery","Dead","Training","Rear Labour"] or not person.crew_station.is_empty() or _rear().combat.broken.has(id): continue
		if person.position.distance_to(row.center) > 2.0+EPS or _rear().military._held(id,"E08") <= 0: continue
		eligible.append(id)
	return eligible

func _site_safe(row: Dictionary) -> bool:
	if _rear().time-float(row.last_damage) < 10.0-EPS: return false
	for other in _rear().ledger.snapshot().entities:
		if other.kind != "PERSON" or other.owner == row.owner or other.owner not in ["army-blue","army-red"] or other.health <= 0 or other.position.distance_to(row.center) > 150.0: continue
		if _rear().combat.world.observe(row.center,other.position).visible: return false
	return true

func _surface_legal(code: String, area: Rect2i) -> Dictionary:
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var tile: Dictionary = _rear().combat.world.cell(Vector2i(x,y))
			var slope: float = rad_to_deg(atan(Vector2(tile.get("gradient",Vector2.ZERO)).length()))
			if code not in ["S11","S12"] and not _rear().combat.world.support(Vector2i(x,y),0).ok: return _fail("This field site lacks actual infantry ground support.")
			if code == "S11" and (tile.terrain in ["TR09","TR10","TR11","TR12"] or slope > 10.0+EPS): return _fail("S11 needs dry passable ground with slope at most ten degrees.")
			if code == "S12" and not ((tile.terrain == "TR09" and not tile.get("deep_bog",false)) or (tile.terrain == "TR12" and tile.get("landform","") == "bog_edge")): return _fail("S12 needs shallow swamp or bog edge, not deep water or cliff.")
	return {"ok":true}

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
