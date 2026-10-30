extends RefCounted
## G20 bridge projects and timed traffic on the shared ledger and world.
const Catalog = preload("res://game/bridges/bridge_catalogue.gd")
const Terrain = preload("res://game/terrain/terrain_catalog.gd")
const Routes = preload("res://game/routes/route_planner.gd")
const EPS := 0.000001
var _rear_ref: WeakRef
var projects: Dictionary = {}
var workers: Dictionary = {}
var repairs: Dictionary = {}
var traffic: Dictionary = {} # bridge -> active traversal
var queues: Dictionary = {} # bridge -> ordered waiting traversals
var events: Array[Dictionary] = []
var _sequence := 0
var _salvage_sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func order(code: String, bank_a: Vector2, bank_b: Vector2, owner: String = "army-blue") -> Dictionary:
	if not Catalog.SPECS.has(code) or owner not in ["army-blue","army-red"] or not bank_a.is_finite() or not bank_b.is_finite(): return _fail("Choose a bridge blueprint, two finite banks and an army owner.")
	var world: RefCounted = _rear().combat.world
	var direction := (bank_b-bank_a).normalized()
	var distance := bank_a.distance_to(bank_b)
	if distance < 2.0 or distance > float(Catalog.SPECS[code].span)+2.0: return _fail("Bank separation exceeds this bridge's possible clear-water span.")
	for bank in [bank_a,bank_b]:
		var at := Vector2i(floori(bank.x),floori(bank.y))
		if not world.bounds.has_point(at) or world.cell(at).terrain in ["TR09","TR10","TR11","TR12"] or not world.support(at,0).ok: return _fail("Both bridge endpoints require stable, infantry-accessible land support.")
	var near_access: Dictionary = _holding_approach(bank_a,bank_b,0)
	var far_access: Dictionary = _holding_approach(bank_a,bank_b,1)
	if not near_access.ok and not far_access.ok: return _fail("At least one twenty-metre holding approach needs continuous physical infantry access; near: %s; far: %s" % [near_access.reason,far_access.reason])
	var work_bank := 0 if near_access.ok else 1
	var samples := maxi(2,ceili(distance*4.0))
	var first_water := INF
	var last_water := -INF
	var dry_after_water := false
	for index in range(1,samples):
		var travelled := distance*float(index)/float(samples)
		var point := bank_a+direction*travelled
		var at := Vector2i(floori(point.x),floori(point.y))
		if not world.bounds.has_point(at): return _fail("Bridge span exceeds declared terrain.")
		if world.cell(at).terrain == "TR11":
			if dry_after_water: return _fail("One bridge cannot skip an unsupported dry island.")
			first_water = minf(first_water,travelled)
			last_water = travelled
		elif first_water != INF: dry_after_water = true
	if first_water == INF or last_water < first_water: return _fail("A bridge needs a real contiguous deep-water gap.")
	var span := ceili(last_water-first_water+distance/float(samples))
	if span > int(Catalog.SPECS[code].span): return _fail("Clear water exceeds %s maximum span." % code)
	var width: float = Catalog.SPECS[code].width
	var deck: Array[Vector2i] = []
	var approaches: Array[Vector2i] = []
	var reach := distance+40.0
	var minimum := bank_a.min(bank_b)-Vector2(reach,reach)
	var maximum := bank_a.max(bank_b)+Vector2(reach,reach)
	for y in range(maxi(world.bounds.position.y,floori(minimum.y)),mini(world.bounds.end.y,ceili(maximum.y))):
		for x in range(maxi(world.bounds.position.x,floori(minimum.x)),mini(world.bounds.end.x,ceili(maximum.x))):
			var at := Vector2i(x,y)
			var offset := Vector2(at)+Vector2(0.5,0.5)-bank_a
			var along := offset.dot(direction)
			var across := absf(offset.cross(direction))
			if across > width*0.5+EPS: continue
			if along > first_water-EPS and along < last_water+distance/float(samples)+EPS and world.cell(at).terrain == "TR11": deck.append(at)
			elif (along >= -20.0 and along <= 0.0 or along >= distance and along <= distance+20.0) and world.cell(at).terrain != "TR11": approaches.append(at)
	if deck.is_empty(): return _fail("Measured bridge footprint misses the water gap.")
	for at in deck:
		if not world.cell(at).get("overlay",{}).is_empty(): return _fail("Bridge deck cannot overwrite an existing authored crossing or completed surface.")
	for other in projects.values():
		if other.state in ["Cancelled","Destroyed"]: continue
		for at in deck:
			if at in other.deck: return _fail("Another actual bridge project owns this water footprint.")
	var active := 0
	for other in projects.values():
		if other.state not in ["Cancelled","Destroyed"]: active += 1
	if active >= 6: return _fail("Six newly built bridge crossings are already active.")
	_sequence += 1
	var id := "bridge-%04d" % _sequence
	var a_id := id+"-a"
	var b_id := id+"-b"
	var a_place: Dictionary = _rear().ledger.add_place(a_id,code+" near-bank supply and repair",bank_a)
	if not a_place.ok: return a_place
	var b_place: Dictionary = _rear().ledger.add_place(b_id,code+" far-bank supply and repair",bank_b)
	if not b_place.ok: return b_place
	var spec: Dictionary = Catalog.SPECS[code]
	var max_health := int(spec.base_health)+int(spec.health_per_m)*span
	projects[id] = {"id":id,"code":code,"owner":owner,"banks":[bank_a,bank_b],"places":[a_id,b_id],"work_bank":work_bank,"direction":direction,"span":span,"deck":deck,"approaches":approaches,"width":width,"state":"Awaiting material and engineers","health":maxi(1,int(max_health/4)),"max_health":max_health,"m11_required":int(spec.m11)*span,"m11_consumed":0,"work_required":float(spec.work)*span,"progress":0.0,"assigned":[],"last_damage":-INF,"blocked_reason":"Stage full M11 at one bank; two local P02/E08 engineers must start safely.","upgrade_from":"","upgrade_old_deck":[],"upgrade_old_approaches":[],"completed_at":-1.0,"material_receipt":[]}
	queues[id] = []
	events.append({"at":_rear().time,"id":id,"kind":"Ordered","detail":code})
	return {"ok":true,"id":id,"span":span,"m11":int(spec.m11)*span,"work":int(spec.work)*span,"max_health":max_health,"message":"Real water span and both supported bank endpoints recorded; full local delivery and engineers remain required."}

func choose_work_bank(id: String, bank_index: int) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state in ["Complete","Cancelled","Destroyed"] or row.m11_consumed > 0 or bank_index not in [0,1]: return _fail("Choose either accessible bank before this work consumes M11.")
	var access: Dictionary = _holding_approach(row.banks[0],row.banks[1],bank_index)
	if not access.ok: return _fail("Chosen work bank lacks a continuous physical holding approach: "+access.reason)
	row.work_bank = bank_index
	_refresh(row)
	return {"ok":true,"message":"Construction or rebuilding will use the chosen physical bank supply area."}

func _holding_approach(bank_a: Vector2, bank_b: Vector2, side: int) -> Dictionary:
	var direction: Vector2 = (bank_b-bank_a).normalized()
	var bank: Vector2 = bank_a if side == 0 else bank_b
	var outward: Vector2 = -direction if side == 0 else direction
	var holding: Vector2 = bank+outward*20.0
	return _rear().combat.world.route({"position":holding,"facing":(-outward).angle(),"size":Vector2(0.6,0.6),"movement_class":0,"base":1.5,"rate":0.0,"gross_mass_kg":80.0},bank)

func deliver_material(id: String, stock_id: String, count: int, bank_index: int = -1) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	var stock: Dictionary = _rear().ledger.inspect_entity(stock_id)
	if row.is_empty() or row.state in ["Cancelled","Destroyed"] or stock.get("kind","") != "STOCK" or stock.design_type != "M11" or stock.owner != row.owner or count <= 0: return _fail("Only actual owned M11 can reach an active bridge bank.")
	var chosen: int = row.work_bank if bank_index == -1 else bank_index
	if chosen not in [0,1] or row.state != "Complete" and chosen != row.work_bank: return _fail("Stage construction M11 at the chosen active bank; repair M11 may reach either bank.")
	var place: String = row.places[chosen]
	if stock.holder_id == place: return {"ok":true,"message":"This M11 is already staged at the chosen bank."}
	var holder: Dictionary = _rear().ledger.inspect_entity(stock.holder_id)
	if holder.get("kind","") not in ["PERSON","CARRIER"] or holder.position.distance_to(row.banks[chosen]) > 2.0+EPS: return _fail("A real carrier or person must bring M11 within two metres of the chosen bank.")
	var capacity := 10 if row.state == "Complete" else int(row.m11_required)
	if _rear().ledger.available_stock_at(place,"M11")+count > capacity: return _fail("Bank supply area holds only this project's remaining M11 or ten repair M11.")
	var moved: Dictionary
	if holder.kind == "PERSON" and holder.carrying_stock_id == stock_id:
		if count != stock.quantity: return _fail("An active person carry deposits its full physical load.")
		moved = _rear().ledger.finish_carry(holder.id,place)
	else: moved = _rear().ledger.transfer_stock(stock_id,count,place)
	if moved.ok and row.state != "Complete": _refresh(row)
	return moved

func assign_engineer(id: String, person_id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	if row.is_empty() or row.state in ["Complete","Cancelled","Destroyed"] or engineer_committed(person_id) or _rear().field_structures.engineer_committed(person_id) or row.assigned.size() >= 4 or person.get("kind","") != "PERSON" or person.owner != row.owner or person.qualification != "P02": return _fail("Up to four actual uncommitted friendly P02 may join unfinished bridge work.")
	row.assigned.append(person_id)
	workers[person_id] = id
	_refresh(row)
	return {"ok":true,"message":"Engineer assigned; actual local kit, safety, full M11 and a second P02 still gate construction."}

func release_engineer(person_id: String) -> Dictionary:
	if not workers.has(person_id): return _fail("Engineer has no bridge-project commitment.")
	var id: String = workers[person_id]
	workers.erase(person_id)
	projects[id].assigned.erase(person_id)
	_refresh(projects[id])
	return {"ok":true,"message":"Engineer released; earned work remains."}

func engineer_committed(person_id: String) -> bool:
	if _rear().recovery != null and _rear().recovery.workers.has(person_id): return true
	if workers.has(person_id): return true
	for job in repairs.values():
		if person_id in job.engineers: return true
	return false

func _eligible(row: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not _safe(row) or not _holding_approach(row.banks[0],row.banks[1],row.work_bank).ok: return result
	for id in row.assigned:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if person.get("kind","") != "PERSON" or person.owner != row.owner or person.qualification != "P02" or person.health <= 0 or person.assignment in ["Wounded","Recovery","Dead","Training","Rear Labour"] or not person.crew_station.is_empty() or _rear().combat.broken.has(id): continue
		if person.position.distance_to(row.banks[row.work_bank]) > 2.0+EPS or _rear().military._held(id,"E08") < 1: continue
		result.append(id)
	return result

func _safe(row: Dictionary) -> bool:
	if _rear().time-float(row.last_damage) < 10.0-EPS: return false
	for other in _rear().ledger.snapshot().entities:
		if other.kind != "PERSON" or other.owner == row.owner or other.owner not in ["army-blue","army-red"] or other.health <= 0: continue
		for bank in row.banks:
			if other.position.distance_to(bank) <= 150.0 and _rear().combat.world.observe(bank,other.position).visible: return false
	return true

func _refresh(row: Dictionary) -> bool:
	if row.state in ["Complete","Cancelled","Destroyed"]: return false
	var old_state: String = row.state
	var old_reason: String = row.blocked_reason
	var access: Dictionary = _holding_approach(row.banks[0],row.banks[1],row.work_bank)
	var local: int = _rear().ledger.available_stock_at(row.places[row.work_bank],"M11")
	var eligible: Array[String] = _eligible(row)
	if row.m11_consumed == 0:
		if not access.ok:
			row.state = "Awaiting access"
			row.blocked_reason = "Chosen construction bank approach blocked: "+access.reason
		elif local < row.m11_required:
			row.state = "Awaiting material and engineers"
			row.blocked_reason = "%d actual M11 missing at chosen bank." % (row.m11_required-local)
		elif eligible.size() < 2:
			row.state = "Awaiting engineers"
			row.blocked_reason = "Full M11 staged; two safe local P02 with E08 required."
		else:
			var spent: Dictionary = _rear().ledger.consume_local_batch(row.places[row.work_bank],row.owner,{"M11":int(row.m11_required)},"G20 bridge project "+row.id)
			if spent.ok:
				row.m11_consumed = row.m11_required
				row.material_receipt = spent.receipt
				row.state = "Building"
				row.blocked_reason = ""
				events.append({"at":_rear().time,"id":row.id,"kind":"Started","detail":"Full local M11 consumed once"})
			else: row.blocked_reason = spent.message
	else:
		row.state = "Building" if eligible.size() >= 2 else "Paused"
		row.blocked_reason = "" if eligible.size() >= 2 else ("Work paused; chosen bank approach blocked: "+access.reason if not access.ok else "Work paused; two safe local P02/E08 required, with progress retained.")
	return row.state != old_state or row.blocked_reason != old_reason

func next_boundary() -> float:
	var next := INF
	for row in projects.values():
		if row.state in ["Complete","Cancelled","Destroyed"]: continue
		if row.last_damage+10.0 > _rear().time+EPS: next = minf(next,float(row.last_damage)+10.0)
		var eligible: Array[String] = _eligible(row)
		if row.m11_consumed > 0 and eligible.size() >= 2: next = minf(next,_rear().time+(row.work_required-row.progress)/eligible.size())
	for id in repairs:
		var job: Dictionary = repairs[id]
		var rate := _repair_rate(id)
		if rate > 0: next = minf(next,_rear().time+(40.0-job.progress)/rate)
	for id in traffic:
		var crossing: Dictionary = traffic[id]
		if crossing.get("paused",false): continue
		next = minf(next,_rear().time+crossing.seconds-crossing.progress)
	return next

func advance_to(at: float) -> void:
	var delta: float = at-_rear().time
	if delta <= EPS: return
	for row in projects.values():
		if row.state == "Building": row.progress = minf(row.work_required,row.progress+_eligible(row).size()*delta)
	for id in repairs:
		var job: Dictionary = repairs[id]
		job.progress = minf(40.0,job.progress+_repair_rate(id)*delta)
	for id in traffic:
		var crossing: Dictionary = traffic[id]
		if crossing.get("paused",false): continue
		var earned: float = minf(delta,crossing.seconds-crossing.progress)
		var lead_before: Dictionary = _rear().ledger.inspect_entity(crossing.entity)
		if lead_before.get("holder_id","") != crossing.place or lead_before.get("kind","") == "PERSON" and not lead_before.crew_station.is_empty():
			crossing.blocked_reason = "Crossing body left its independent physical place; progress held until real disembark or return."
			continue
		var tow_before: Dictionary = {}
		if not crossing.get("tow","").is_empty():
			tow_before = _rear().ledger.inspect_entity(crossing.tow)
			if tow_before.get("holder_id","") != crossing.tow_place:
				crossing.blocked_reason = "Towed vehicle left its physical place; coupled crossing progress held."
				continue
		var next_progress: float = crossing.progress+earned
		var position: Vector2 = crossing.start.lerp(crossing.finish,next_progress/crossing.seconds)
		var moved: Dictionary = _rear().ledger.move_entity(crossing.entity,crossing.place,position)
		if not moved.ok:
			crossing.blocked_reason = "Actual crossing movement failed: "+moved.message
			continue
		if not crossing.get("tow","").is_empty():
			var behind: Vector2 = -(crossing.finish-crossing.start).normalized()*12.0
			var tow_moved: Dictionary = _rear().ledger.move_entity(crossing.tow,crossing.tow_place,position+behind)
			if not tow_moved.ok:
				var restored: Dictionary = _rear().ledger.move_entity(crossing.entity,crossing.place,lead_before.position)
				crossing.blocked_reason = "Actual tow movement failed: "+tow_moved.message+("; lead rollback failed: "+restored.message if not restored.ok else "")
				continue
		if crossing.fuel > 0.0:
			var burned: Dictionary = _rear().ledger.burn_vehicle_fuel(crossing.entity,crossing.fuel*earned/crossing.seconds)
			if not burned.ok:
				var lead_restored: Dictionary = _rear().ledger.move_entity(crossing.entity,crossing.place,lead_before.position)
				var tow_restored := {"ok":true,"message":""}
				if not tow_before.is_empty(): tow_restored = _rear().ledger.move_entity(crossing.tow,crossing.tow_place,tow_before.position)
				crossing.blocked_reason = "Actual fuel unavailable; crossing movement held."+(" Rollback failed." if not lead_restored.ok or not tow_restored.ok else "")
				continue
		crossing.progress = next_progress
		crossing.blocked_reason = ""

func settle() -> bool:
	var changed := false
	for row in projects.values():
		if row.state in ["Complete","Cancelled","Destroyed"]: continue
		changed = _refresh(row) or changed
		if row.m11_consumed > 0 and row.progress >= row.work_required-EPS:
			var old_health: int = row.health
			row.health = row.max_health
			if not _set_surface(row,true).ok:
				row.health = old_health
				continue
			row.state = "Complete"
			row.completed_at = _rear().time
			row.blocked_reason = ""
			row.upgrade_from = ""
			row.upgrade_old_deck = []
			row.upgrade_old_approaches = []
			for person_id in row.assigned: workers.erase(person_id)
			row.assigned.clear()
			events.append({"at":_rear().time,"id":row.id,"kind":"Complete","detail":row.code})
			changed = true
	for id in repairs.keys():
		var job: Dictionary = repairs[id]
		if job.progress < 40.0-EPS: continue
		var row: Dictionary = projects[id]
		row.health = mini(row.max_health,row.health+100)
		repairs.erase(id)
		_set_surface(row,true)
		events.append({"at":_rear().time,"id":id,"kind":"Repaired","detail":"100 capped health"})
		changed = true
	for id in traffic.keys():
		var crossing: Dictionary = traffic[id]
		if crossing.progress < crossing.seconds-EPS: continue
		traffic.erase(id)
		events.append({"at":_rear().time,"id":id,"kind":"Crossed","detail":crossing.entity})
		changed = true
	for id in queues.keys():
		if _busy(id) or queues[id].is_empty(): continue
		var row: Dictionary = projects.get(id,{})
		if row.is_empty() or row.state != "Complete": continue
		var candidate: Dictionary = queues[id][0]
		var admitted: Dictionary = _admission(row,candidate.entity,candidate.side,candidate.get("tow",""))
		if not admitted.ok:
			candidate.blocked_reason = admitted.reason
			continue
		if row.code == "B01":
			var count := 0
			var mass := 0.0
			for queued in queues[id]:
				if queued.side != candidate.side or count >= 8: break
				var check: Dictionary = _admission(row,queued.entity,queued.side)
				if not check.ok or mass+check.gross_kg > float(Catalog.SPECS.B01.load)*(0.5 if row.health <= row.max_health/2 else 1.0)+EPS: break
				count += 1
				mass += check.gross_kg
			# A footbridge batch traverses with its actual people, bounded together.
			for index in range(count):
				var person_crossing: Dictionary = queues[id].pop_front()
				person_crossing.progress = 0.0
				person_crossing.seconds = admitted.seconds
				traffic[id+":"+person_crossing.entity] = person_crossing
			if count > 0: changed = true
		else:
			var vehicle_crossing: Dictionary = queues[id].pop_front()
			vehicle_crossing.progress = 0.0
			vehicle_crossing.seconds = admitted.seconds
			traffic[id] = vehicle_crossing
			changed = true
	return changed

func _set_surface(row: Dictionary, complete: bool) -> Dictionary:
	var spec: Dictionary = Catalog.SPECS[row.code]
	return _rear().combat.world.set_bridge_surface(row.id,row.deck,row.approaches,row.code,float(spec.load)*(0.5 if row.health <= row.max_health/2 else 1.0),2.0 if row.health <= row.max_health/2 else 4.0,float(spec.width),spec.classes,complete)

func _busy(id: String) -> bool:
	for key in traffic:
		if str(key) == id or str(key).begins_with(id+":"): return true
	return false

func damage(id: String, amount: int) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state in ["Cancelled","Destroyed"] or amount <= 0: return _fail("Only an actual surviving bridge takes positive damage.")
	row.health = maxi(0,row.health-amount)
	row.last_damage = _rear().time
	if row.health == 0:
		row.state = "Destroyed"
		row.blocked_reason = "Whole water span destroyed; full original M11 and work needed to rebuild."
		_set_surface(row,false)
		repairs.erase(id)
		queues[id].clear()
		for person_id in row.assigned: workers.erase(person_id)
		row.assigned.clear()
		for key in traffic.keys():
			var crossing: Dictionary = traffic[key]
			if str(key) != id and not str(key).begins_with(id+":"): continue
			var entity: Dictionary = _rear().ledger.inspect_entity(crossing.entity)
			if _on_water(row,entity.position):
				if entity.kind == "PERSON": _rear().ledger.kill_person(entity.id,"Bridge collapse on water span")
				elif entity.kind == "CARRIER": _rear().ledger.destroy_carrier_on_bridge(entity.id)
			if not crossing.get("tow","").is_empty():
				var tow: Dictionary = _rear().ledger.inspect_entity(crossing.tow)
				if _on_water(row,tow.position): _rear().ledger.destroy_carrier_on_bridge(crossing.tow)
			traffic.erase(key)
		events.append({"at":_rear().time,"id":id,"kind":"Destroyed","detail":"Water-span occupants lost"})
	else:
		if row.state == "Complete":
			_set_surface(row,true)
			if row.health <= row.max_health/2: _retime_traffic(row)
		row.blocked_reason = "Damaged: half load and 2 m/s crossing cap." if row.health <= row.max_health/2 else "Structure remains sound; new crossings recheck current health."
	return {"ok":true,"health":row.health,"message":row.blocked_reason}

func _retime_traffic(row: Dictionary) -> void:
	# A load admitted before damage stays aboard. Re-evaluate only the real
	# remaining lane at the new speed; do not restart distance or grant fuel.
	for key in traffic:
		if str(key) != row.id and not str(key).begins_with(row.id+":"): continue
		var crossing: Dictionary = traffic[key]
		var entity: Dictionary = _rear().ledger.inspect_entity(crossing.entity)
		var position: Vector2 = entity.position
		if position.distance_to(crossing.finish) <= EPS: continue
		var direction: Vector2 = (crossing.finish-position).normalized()
		var profile := {"position":position,"facing":direction.angle(),"gross_mass_kg":float(entity.unit_mass_kg)+float(entity.contents_mass_kg)+float(entity.get("fuel",0.0)),"bridge_existing_traffic":true}
		if entity.kind == "PERSON":
			profile["size"] = Vector2(0.6,0.6)
			profile["movement_class"] = 0
			profile["base"] = 1.5
			profile["rate"] = 0.0
		else:
			var vehicle: Dictionary = Terrain.VEHICLES.get(entity.design_type,{})
			if vehicle.is_empty():
				crossing.paused = true
				crossing.blocked_reason = "Actual vehicle type is unavailable for remaining bridge route."
				continue
			profile["size"] = entity.vehicle_spec.footprint
			profile["movement_class"] = int(vehicle.class)
			profile["base"] = float(vehicle.base)*(0.75 if entity.health <= 0.5*float(entity.max_health) else 1.0)
			profile["rate"] = float(vehicle.rate)
			if not crossing.get("tow","").is_empty():
				profile.rate *= 2.0
		var remaining: Dictionary = _rear().combat.world.route(profile,crossing.finish)
		if not remaining.ok:
			crossing.paused = true
			crossing.blocked_reason = "Remaining damaged-bridge route blocked: "+remaining.reason
			continue
		crossing.start = position
		crossing.progress = 0.0
		crossing.seconds = float(remaining.seconds)*(4.0 if not crossing.get("tow","").is_empty() else 1.0)
		crossing.fuel = float(remaining.fuel)
		crossing.paused = false
		crossing.blocked_reason = "Bridge damaged; remaining actual crossing retimed at current 2 m/s deck limit."

func _on_water(row: Dictionary, position: Vector2) -> bool:
	return Vector2i(floori(position.x),floori(position.y)) in row.deck

func rebuild(id: String, bank_index: int = 0) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state != "Destroyed" or bank_index not in [0,1]: return _fail("A destroyed bridge can rebuild from either actual bank.")
	var access: Dictionary = _holding_approach(row.banks[0],row.banks[1],bank_index)
	if not access.ok: return _fail("Rebuild bank lacks a continuous physical holding approach: "+access.reason)
	row.work_bank = bank_index
	row.state = "Awaiting material and engineers"
	row.health = maxi(1,int(row.max_health/4))
	row.progress = 0.0
	row.m11_consumed = 0
	row.material_receipt = []
	row.blocked_reason = "Full original M11 and two local P02/E08 needed; deck stays closed."
	return {"ok":true,"message":row.blocked_reason}

func upgrade(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.code != "B02" or row.state != "Complete" or row.health != row.max_health or row.span > int(Catalog.SPECS.B03.span) or _busy(id) or not queues[id].is_empty(): return _fail("Only an empty sound B02 within B03 span can close for upgrade.")
	# Widen the real water and approach footprint before admitting heavy traffic.
	var old: Dictionary = Catalog.SPECS.B02
	var heavy: Dictionary = Catalog.SPECS.B03
	var widened: Dictionary = _widened_cells(row,float(heavy.width))
	if not widened.ok: return widened
	_set_surface(row,false)
	row.upgrade_old_deck = row.deck.duplicate()
	row.upgrade_old_approaches = row.approaches.duplicate()
	row.deck = widened.deck
	row.approaches = widened.approaches
	row.upgrade_from = "B02"
	row.code = "B03"
	row.width = heavy.width
	row.max_health = int(heavy.base_health)+int(heavy.health_per_m)*row.span
	row.health = maxi(1,int(row.max_health/4))
	row.m11_required = (int(heavy.m11)-int(old.m11))*row.span
	row.work_required = float(int(heavy.work)-int(old.work))*row.span
	row.m11_consumed = 0
	row.progress = 0.0
	row.state = "Awaiting material and engineers"
	row.blocked_reason = "B02 closed until full difference M11 and work complete; no early heavy crossing."
	return {"ok":true,"m11":row.m11_required,"work":row.work_required,"message":row.blocked_reason}

func _widened_cells(row: Dictionary, width: float) -> Dictionary:
	var world: RefCounted = _rear().combat.world
	var a: Vector2 = row.banks[0]
	var distance: float = row.banks[0].distance_to(row.banks[1])
	var deck: Array[Vector2i] = []
	var approaches: Array[Vector2i] = []
	var minimum := a.min(row.banks[1])-Vector2(24.0,24.0)
	var maximum := a.max(row.banks[1])+Vector2(24.0,24.0)
	for y in range(maxi(world.bounds.position.y,floori(minimum.y)),mini(world.bounds.end.y,ceili(maximum.y))):
		for x in range(maxi(world.bounds.position.x,floori(minimum.x)),mini(world.bounds.end.x,ceili(maximum.x))):
			var at := Vector2i(x,y)
			var offset := Vector2(at)+Vector2(0.5,0.5)-a
			var along := offset.dot(row.direction)
			if absf(offset.cross(row.direction)) > width*0.5+EPS: continue
			if along > 0.0 and along < distance and world.cell(at).terrain == "TR11":
				var existing: Dictionary = world.cell(at).get("overlay",{})
				if not existing.is_empty() and existing.get("id","") != row.id: return _fail("B03 widening conflicts with another actual crossing.")
				deck.append(at)
			elif (along >= -20.0 and along <= 0.0 or along >= distance and along <= distance+20.0) and world.cell(at).terrain != "TR11": approaches.append(at)
	return {"ok":true,"deck":deck,"approaches":approaches}

func cancel(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state in ["Complete","Cancelled","Destroyed"]: return _fail("Only unfinished bridge work can be cancelled.")
	var recovered := int(row.m11_consumed/2)
	if recovered > 0:
		_salvage_sequence += 1
		var pile_id := "%s-salvage-%04d" % [id,_salvage_sequence]
		var placed: Dictionary = _rear().ledger.add_place(pile_id,"Recovered bridge material",row.banks[row.work_bank])
		if not placed.ok: return placed
		var restored: Dictionary = _rear().ledger.recover_consumed_material(pile_id+"-m11","M11",recovered,1.0,pile_id,row.owner)
		if not restored.ok: return restored
	for person_id in row.assigned: workers.erase(person_id)
	row.assigned.clear()
	if row.upgrade_from == "B02":
		row.deck = row.upgrade_old_deck
		row.approaches = row.upgrade_old_approaches
		row.upgrade_old_deck = []
		row.upgrade_old_approaches = []
		row.code = "B02"
		row.width = Catalog.SPECS.B02.width
		row.max_health = int(Catalog.SPECS.B02.base_health)+int(Catalog.SPECS.B02.health_per_m)*row.span
		row.health = row.max_health
		row.m11_required = int(Catalog.SPECS.B02.m11)*row.span
		row.m11_consumed = row.m11_required
		row.work_required = float(Catalog.SPECS.B02.work)*row.span
		row.progress = row.work_required
		row.state = "Complete"
		row.upgrade_from = ""
		_set_surface(row,true)
	else: row.state = "Cancelled"
	row.blocked_reason = "Cancelled; staged stock remains, half consumed M11 recovered as a real pile."
	return {"ok":true,"recovered":recovered,"message":row.blocked_reason}

func request_repair(id: String, engineers: Array, bank_index: int = 0) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state != "Complete" or row.health <= 0 or row.health >= row.max_health or repairs.has(id) or engineers.is_empty() or engineers.size() > 4 or bank_index not in [0,1] or not _safe(row): return _fail("Damaged surviving bridge, safe bank and one to four actual engineers required.")
	var unique: Dictionary = {}
	for person_id in engineers:
		var person: Dictionary = _rear().ledger.inspect_entity(person_id)
		if unique.has(person_id) or person.get("kind","") != "PERSON" or person.owner != row.owner or person.qualification != "P02" or person.health <= 0 or person.position.distance_to(row.banks[bank_index]) > 2.0+EPS or _rear().military._held(person_id,"E08") < 1 or engineer_committed(person_id) or _rear().field_structures.engineer_committed(person_id): return _fail("Each distinct repair engineer needs free time, physical bank access and actual E08.")
		unique[person_id] = true
	var spent: Dictionary = _rear().ledger.consume_local_batch(row.places[bank_index],row.owner,{"M11":10},"G20 bridge repair "+id)
	if not spent.ok: return spent
	repairs[id] = {"engineers":engineers.duplicate(),"bank":bank_index,"progress":0.0,"receipt":spent.receipt}
	return {"ok":true,"message":"Ten real local M11 consumed; 40 engineer-work seconds restore at most 100 health."}

func cancel_repair(id: String) -> Dictionary:
	if not repairs.has(id): return _fail("No actual bridge repair job exists.")
	repairs.erase(id)
	return {"ok":true,"message":"Repair cancelled; consumed M11 is lost and no health is granted."}

func _repair_rate(id: String) -> float:
	var row: Dictionary = projects[id]
	var job: Dictionary = repairs[id]
	if row.state != "Complete" or not _safe(row): return 0.0
	var rate := 0.0
	for person_id in job.engineers:
		var person: Dictionary = _rear().ledger.inspect_entity(person_id)
		if person.get("kind","") == "PERSON" and person.owner == row.owner and person.qualification == "P02" and person.health > 0 and person.position.distance_to(row.banks[job.bank]) <= 2.0+EPS and _rear().military._held(person_id,"E08") > 0: rate += 1.0
	return rate

func request_crossing(id: String, entity_id: String, side: int, known_mine: bool = false, tow_id: String = "") -> Dictionary:
	var actual: Dictionary = _rear().ledger.inspect_entity(entity_id)
	if actual.get("kind","") == "CARRIER":
		if not actual.get("towed_by","").is_empty(): return _fail("Tow object must cross with its actual tractor.")
		if tow_id.is_empty(): tow_id = actual.get("towing","")
		if not tow_id.is_empty() and actual.get("towing","") != tow_id: return _fail("Twenty-second physical tow coupling required before crossing.")
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state != "Complete" or side not in [0,1] or known_mine: return _fail("Completed bridge, chosen bank and mine-free known approach required.")
	for key in traffic:
		if traffic[key].entity == entity_id: return _fail("This actual entity already occupies a crossing.")
	for queued in queues[id]:
		if queued.entity == entity_id: return _fail("This entity is already waiting at the bridge.")
	var admitted: Dictionary = _admission(row,entity_id,side,tow_id)
	if not admitted.ok: return admitted
	queues[id].append({"entity":entity_id,"tow":tow_id,"side":side,"start":admitted.start,"finish":admitted.finish,"place":admitted.place,"tow_place":admitted.get("tow_place",""),"seconds":admitted.seconds,"fuel":admitted.fuel,"progress":0.0})
	return {"ok":true,"queue_position":queues[id].size()+int(_busy(id)),"message":"Actual entity waits at the twenty-metre holding point; one vehicle or bounded foot party crosses at a time."}

func cancel_crossing(id: String, entity_id: String) -> Dictionary:
	if not queues.has(id): return _fail("Unknown actual bridge queue.")
	for index in range(queues[id].size()):
		if queues[id][index].entity == entity_id:
			queues[id].remove_at(index)
			return {"ok":true,"message":"Waiting crossing removed; physical entity remains at its current holding point."}
	return _fail("Only a waiting crossing can be cancelled; active traffic must clear or be destroyed.")

func _admission(row: Dictionary, entity_id: String, side: int, tow_id: String = "") -> Dictionary:
	var entity: Dictionary = _rear().ledger.inspect_entity(entity_id)
	if entity.get("kind","") not in ["PERSON","CARRIER"] or entity.health <= 0: return _fail("Actual living person or serviceable vehicle required.")
	var holder: Dictionary = _rear().ledger.inspect_entity(entity.holder_id)
	if holder.get("kind","") != "PLACE" or entity.kind == "PERSON" and not entity.crew_station.is_empty(): return _fail("Bridge entry needs an independently dismounted person or vehicle at a physical place; seated passengers and crew must exit first.")
	var outward: Vector2 = -row.direction if side == 0 else row.direction
	var start: Vector2 = row.banks[side]+outward*20.0
	var finish: Vector2 = row.banks[1-side]-outward*20.0
	if entity.position.distance_to(start) > 2.0+EPS: return _fail("Crossing starts only at the real twenty-metre holding point.")
	for other in _rear().ledger.snapshot().entities:
		if other.kind == "PERSON" and other.owner != entity.owner and other.owner in ["army-blue","army-red"] and other.health > 0 and other.position.distance_to(row.banks[1-side]) < 20.0 and _rear().combat.world.observe(row.banks[1-side],other.position).visible: return _fail("Observed hostile at far approach blocks ordinary crossing.")
	var gross := 0.0
	var seconds := 0.0
	var fuel := 0.0
	if entity.kind == "PERSON":
		if not tow_id.is_empty(): return _fail("Only a B03 vehicle can tow one actual vehicle over a bridge.")
		gross = float(entity.unit_mass_kg)+float(entity.contents_mass_kg)
		if gross > float(Catalog.SPECS[row.code].load)*(0.5 if row.health <= row.max_health/2 else 1.0)+EPS: return _fail("Person and carried gear exceed live bridge load.")
		var travel: Dictionary = _rear().combat.world.route({"position":start,"facing":(finish-start).angle(),"size":Vector2(0.6,0.6),"movement_class":0,"base":1.5,"rate":0.0,"gross_mass_kg":gross},finish)
		if not travel.ok: return _fail(travel.reason)
		seconds = travel.seconds
	else:
		if row.code == "B01" or row.code == "B02" and entity.design_type in ["T04","T05"]: return _fail("Bridge class bars this actual vehicle type.")
		gross = Routes.gross_kg(_rear().ledger,entity_id)
		if not tow_id.is_empty():
			var tow: Dictionary = _rear().ledger.inspect_entity(tow_id)
			if tow.get("towed_by","") != entity_id or tow.get("health",0) <= 0 or tow.position.distance_to(start-(finish-start).normalized()*12.0) > 2.0+EPS: return _fail("Actual coupled tow object must be twelve metres behind at holding.")
			gross += Routes.gross_kg(_rear().ledger,tow_id) if tow.kind == "CARRIER" else float(tow.unit_mass_kg)+float(tow.contents_mass_kg)
			if gross > float(Catalog.SPECS[row.code].load)*(0.5 if row.health <= row.max_health/2 else 1.0)+EPS: return _fail("Coupled actual gross exceeds live bridge load.")
		var route: Dictionary = Routes.plan(_rear().ledger,entity_id,[start,finish],{"world":_rear().combat.world,"strict_turns":true})
		if not route.ok: return _fail(route.reason)
		seconds = route.seconds
		fuel = route.fuel
		if entity.fuel+EPS < fuel: return _fail("Actual vehicle tank lacks crossing fuel; no free travel is granted.")
	return {"ok":true,"start":start,"finish":finish,"place":entity.holder_id,"tow_place":_rear().ledger.inspect_entity(tow_id).get("holder_id","") if not tow_id.is_empty() else "","seconds":seconds,"fuel":fuel,"gross_kg":gross}

func inspect(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty(): return _fail("Unknown bridge identity.")
	var view: Dictionary = row.duplicate(true)
	view["effective_load_kg"] = float(Catalog.SPECS[row.code].load)*(0.5 if row.health <= row.max_health/2 else 1.0) if row.state == "Complete" else 0.0
	view["speed_cap_mps"] = (2.0 if row.health <= row.max_health/2 else 4.0) if row.state == "Complete" else 0.0
	view["queued"] = queues[id].duplicate(true)
	view["traffic"] = []
	for key in traffic:
		if str(key) == id or str(key).begins_with(id+":"): view.traffic.append(traffic[key].duplicate(true))
	view["local_m11"] = _rear().ledger.available_stock_at(row.places[row.work_bank],"M11")
	return view

func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for id in projects: rows.append(inspect(id))
	return {"projects":rows,"workers":workers.duplicate(true),"repairs":repairs.duplicate(true),"traffic":traffic.duplicate(true),"queues":queues.duplicate(true),"events":events.duplicate(true)}

func audit() -> Array[String]:
	var failures: Array[String] = []
	for row in projects.values():
		if row.health < 0 or row.health > row.max_health or row.progress < 0 or row.progress > row.work_required+EPS: failures.append("Bridge state bounds: "+row.id)
		for person_id in row.assigned:
			if workers.get(person_id,"") != row.id: failures.append("Bridge engineer ownership: "+person_id)
		if row.state == "Complete" and row.m11_consumed <= 0: failures.append("Bridge completion without consumed material: "+row.id)
	return failures

func _fail(message: String) -> Dictionary:
	return {"ok":false,"reason":message,"message":message}
