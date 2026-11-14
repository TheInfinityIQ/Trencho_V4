extends RefCounted
## One finite staging batch; ordinary Rear hauling owns workers and elapsed work.
const STORE := "warehouse-staging"
const CENTER := Vector2(106,186)
const SIZE := Vector2(6,4)
var _warehouse: WeakRef
var _rear: WeakRef
var batch: Dictionary = {}
var _sequence := 0
var _staged: Dictionary = {}

func _init(warehouse: RefCounted, rear: RefCounted) -> void:
	_warehouse = weakref(warehouse)
	_rear = weakref(rear)
	assert(rear.ledger.add_place(STORE,"Finite warehouse bay recovery staging",CENTER).ok)
	rear.stores[STORE] = {"id":STORE,"capacity":400.0,"accessible":true,"filter":[],"pile":false,"source_only":true}
	warehouse.bays[STORE] = {"id":STORE,"module":STORE,"store":STORE,"staging":true,"center":CENTER,"rotation":0.0,"state":"Empty","family":"","cells":[],"preparer":"","blocked":false}
	rear.ledger.stock_changed.connect(_stock_changed)

func status() -> Dictionary:
	var kg := 0
	for count: int in _staged.values(): kg += count
	var active := not batch.is_empty() and bool(batch.get("active",false))
	return {"active":active,"occupied":not _staged.is_empty(),"kg":kg,"packages":_staged.size(),"message":"Finishing carried packages" if active and batch.get("stopping",false) else "Clearing selected bay" if active else "Occupied — collect staged goods before clearing another bay" if kg > 0 else "Empty — one bay batch fits in the6×4m staging area"}

func quote(bay_id: String) -> Dictionary:
	var warehouse: RefCounted = _warehouse.get_ref()
	var rear: RefCounted = _rear.get_ref()
	var bay: Dictionary = warehouse.bays.get(bay_id,{})
	var reason := ""
	if bay.is_empty() or bay.get("staging",false): reason = "Select an actual warehouse bay."
	elif bay.state != "Ready" or warehouse.modules[bay.module].retiring: reason = "Finish shelf preparation or warehouse clearing first."
	elif bool(status().active): reason = "Another bay batch is still moving."
	elif not _staged.is_empty(): reason = "Staging is occupied. Collect its goods before another batch."
	for point: Dictionary in warehouse._work_points.values():
		if point.get("bay","") in [bay_id,STORE]: reason = "A worker is using this bay or staging access."
	for promise: Dictionary in warehouse.reservations.values():
		if promise.bay in [bay_id,STORE]: reason = "Incoming storage is already promised here. Let that handling finish."
	var rows: Array[Dictionary] = []
	var contents := {}
	var pieces: Array[String] = [bay_id]
	if not bay.is_empty():
		for index in bay.cells.size():
			var cell: Dictionary = bay.cells[index]
			if cell.stocks.size() > 1: reason = "This cell needs separate package handling before clearance."
			for id: String in cell.stocks:
				var stock: Dictionary = rear.ledger.inspect_entity(id,{},false)
				var count := int(stock.get("quantity",0))
				if count <= 0: continue
				if stock.get("design_type","") == "M04": reason = "Timber needs two-worker handling, which is not connected yet."
				elif not warehouse.Packages.TYPES.has(stock.design_type) or count > warehouse.Packages.capacity(str(stock.design_type)) or count*float(stock.unit_mass_kg) > 25.0: reason = "A package exceeds the supported single-worker staging layout."
				if stock.get("owner","") != rear.PLAYER or stock.get("holder_id","") != warehouse.STORE or rear.ledger.available(id) != count: reason = "Some goods are already reserved or no longer here. Nothing will move."
				rows.append({"id":id,"cell":index,"code":str(stock.design_type),"quantity":count})
				contents[stock.design_type] = int(contents.get(stock.design_type,0))+count
				pieces.append("%s:%d:%s" % [id,count,str(stock.design_type)])
	if rows.is_empty() and reason.is_empty(): reason = "This bay is already empty."
	return {"eligible":reason.is_empty(),"message":reason,"fingerprint":"|".join(pieces),"rows":rows,"contents":contents,"packages":rows.size(),"staging":status()}

func confirm(bay_id: String, expected: String) -> Dictionary:
	var offer := quote(bay_id)
	if not offer.eligible or offer.fingerprint != expected: return _reject(str(offer.message) if not offer.eligible else "The bay contents changed; review the new batch before confirming.")
	var warehouse: RefCounted = _warehouse.get_ref()
	var rear: RefCounted = _rear.get_ref()
	_sequence += 1
	var id := "warehouse-clear-%04d" % _sequence
	var ids: Array = offer.rows.map(func(row: Dictionary) -> String: return str(row.id))
	var reserved: Dictionary = rear.ledger.request_whole_package_batch(id,ids,id,"Warehouse bay clearance",warehouse.STORE,rear.PLAYER)
	if not reserved.ok: return reserved
	var rows: Array = offer.rows.duplicate(true)
	for index in rows.size():
		rows[index].claim = reserved.receipt[index].claim
		rows[index].delivered = false
	batch = {"id":id,"source":bay_id,"active":true,"stopping":false,"rows":rows,"jobs":[]}
	warehouse.bays[bay_id].clearing = true
	var by_code := {}
	for row: Dictionary in rows: by_code[row.code] = int(by_code.get(row.code,0))+int(row.quantity)
	for code: String in by_code:
		var queued: Dictionary = rear._queue_haul(warehouse.STORE,STORE,code,int(by_code[code]),1)
		var job: Dictionary = rear._job(str(queued.id))
		job.warehouse_recovery = id
		batch.jobs.append(job.id)
	warehouse._touch(str(warehouse.bays[bay_id].module))
	warehouse._touch(STORE)
	rear.state_changed.emit()
	rear._settle()
	return {"ok":true,"message":"Bay clearance queued under Other hauling. Real workers prepare staging and move its whole packages; the source bay stays closed to new deposits."}

func option(job: Dictionary, person: Dictionary) -> Dictionary:
	if batch.is_empty() or not batch.active or batch.stopping or job.get("warehouse_recovery","") != batch.id: return {}
	var warehouse: RefCounted = _warehouse.get_ref()
	var rear: RefCounted = _rear.get_ref()
	var stage: Dictionary = warehouse.bays[STORE]
	if stage.state not in ["Empty","Ready"]: return {}
	var facts: Dictionary = rear.ledger.inspect_entity(str(person.id))
	for row: Dictionary in batch.rows:
		if row.delivered or row.code != job.type: continue
		var claim: Dictionary = rear.ledger.inspect_claim(str(row.claim))
		if int(claim.get("reserved",0)) != int(row.quantity): continue
		var busy := false
		for actor: Dictionary in rear.actors.values():
			if actor.load.get("stock","") == row.id: busy = true
		if busy: continue
		var stock: Dictionary = rear.ledger.inspect_entity(str(row.id),{},false)
		if stock.get("holder_id","") != warehouse.STORE or int(stock.quantity) != int(row.quantity) or float(facts.contents_mass_kg)+float(stock.unit_mass_kg)*int(row.quantity) > 25.0: continue
		var pickup: Vector2 = warehouse.stock_point(str(row.id),str(person.id))
		var cells: Array = stage.cells if stage.state == "Ready" else warehouse._make_cells("crates")
		var drop: Vector2 = warehouse._choose_point(stage,str(person.id),Vector2(person.position),cells[int(row.cell)])
		if not pickup.is_finite() or not drop.is_finite(): continue
		var approach: Array = rear.walk_path(person.position,pickup)
		var path: Array = rear.walk_path(pickup,drop)
		if approach.is_empty() or path.is_empty(): continue
		return {"job":job,"stock":stock,"count":int(row.quantity),"claim":str(row.claim),"cell":int(row.cell),"point":drop,"approach":approach,"distance":rear.Layout.length(approach)+rear.Layout.length(path)}
	job.blocker = "Waiting for actual package access, staging preparation or a clear route"
	return {}

func reserve_destination(person: String, selected: Dictionary) -> Dictionary:
	var warehouse: RefCounted = _warehouse.get_ref()
	var rear: RefCounted = _rear.get_ref()
	var stage: Dictionary = warehouse.bays[STORE]
	var prepare: bool = stage.state == "Empty"
	if not prepare and stage.state != "Ready": return _reject("Staging shelf preparation is already in progress.")
	for promise: Dictionary in warehouse.reservations.values():
		if promise.bay == STORE and int(promise.cell) == int(selected.cell): return _reject("This staging position is already promised.")
	if prepare:
		stage.cells = warehouse._make_cells("crates")
		stage.family = "crates"
		stage.state = "Reserved"
		stage.preparer = person
		warehouse._obstacles_dirty = true
	warehouse._sequence += 1
	var token := "warehouse-space-%06d" % int(warehouse._sequence)
	warehouse.reservations[token] = {"id":token,"person":person,"bay":STORE,"cell":int(selected.cell),"code":selected.stock.design_type,"quantity":int(selected.count),"point":selected.point,"queued":false}
	warehouse._work_points[person] = {"holder":STORE,"point":selected.point,"bay":STORE}
	rear.ledger.register_handling_point(STORE,person,selected.point)
	warehouse._touch(STORE)
	return {"ok":true,"id":token,"point":selected.point,"prepare":prepare}

func accepts(person: String, code: String, mass: float) -> bool:
	var rear: RefCounted = _rear.get_ref()
	var load: Dictionary = rear.actors.get(person,{}).get("load",{})
	return not batch.is_empty() and batch.active and load.get("warehouse_recovery","") == batch.id and load.get("destination","") == STORE and load.get("type","") == code and is_equal_approx(float(load.get("mass",0)),mass)

func deposited(id: String) -> void:
	var rear: RefCounted = _rear.get_ref()
	_staged[id] = int(rear.ledger.inspect_entity(id,{},false).quantity)
	for row: Dictionary in batch.get("rows",[]):
		if row.id == id: row.delivered = true
	_finish_if_done()

func stop() -> Dictionary:
	if batch.is_empty() or not batch.active: return _reject("No bay clearance is moving.")
	var rear: RefCounted = _rear.get_ref()
	batch.stopping = true
	for id: String in batch.jobs: rear._job(id).cancelled = true
	for actor: Dictionary in rear.actors.values():
		if actor.load.get("warehouse_recovery","") != batch.id: continue
		if actor.phase not in ["Carry","Drop"]: rear._release_load(actor)
	for row: Dictionary in batch.rows:
		var claim: Dictionary = rear.ledger.inspect_claim(str(row.claim))
		if not claim.get("cancelled",true): rear.ledger.release_claim(str(row.claim))
	_finish_if_done()
	rear._settle()
	return {"ok":true,"message":"Stopped uncollected work. Carried packages still finish safely at staging."}

func _finish_if_done() -> void:
	if batch.is_empty() or not batch.active: return
	var rear: RefCounted = _rear.get_ref()
	if not batch.stopping:
		for row: Dictionary in batch.rows:
			if not row.delivered: return
	for actor: Dictionary in rear.actors.values():
		if actor.load.get("warehouse_recovery","") == batch.id: return
	batch.active = false
	var warehouse: RefCounted = _warehouse.get_ref()
	warehouse.bays[batch.source].clearing = false
	warehouse._touch(str(warehouse.bays[batch.source].module))
	warehouse._touch(STORE)

func _stock_changed(id: String) -> void:
	if not _staged.has(id): return
	var stock: Dictionary = _rear.get_ref().ledger.inspect_entity(id,{},false)
	if stock.get("holder_id","") != STORE or int(stock.get("quantity",0)) <= 0: _staged.erase(id)
	else: _staged[id] = int(stock.quantity)
	_warehouse.get_ref()._touch(STORE)

func _reject(message: String) -> Dictionary:
	return {"ok":false,"message":message,"requires_reconciliation":false}
