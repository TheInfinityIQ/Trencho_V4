extends RefCounted
## Finite warehouse fixtures and space promises. IdentityLedger owns all quantities.
signal changed(module_id: String)
signal space_changed
const Packages = preload("res://game/warehousing/material_packages.gd")
const Collision = preload("res://game/warehousing/warehouse_collision.gd")
const MODULE_SIZE := Vector2(12,16)
const WALL := 0.2
const STRUCTURAL_KG := 10000
const PREPARE_SECONDS := 1.5
const STORE := "receiving"
const TIMBER_SUPPORT_Y := [0.60, 1.75]
const TIMBER_BASE_REGISTRATION_Y := -0.004 # Actual wood underside relative to retained strap-origin export.
var modules: Dictionary = {}
var bays: Dictionary = {}
var reservations: Dictionary = {}
var revision := 0
var topology_revision := 0
var _rear_ref: WeakRef
var _stock_cells: Dictionary = {}
var _work_points: Dictionary = {}
var _slot_bodies: Dictionary = {}
var _module_bodies: Dictionary = {}
var _blocked_bays: Dictionary = {}
var _topology: Dictionary = {}
var _retiring_people: Dictionary = {}
var _summaries: Dictionary = {}
var _obstacles: Array[Rect2] = []
var _obstacles_dirty := true
var _clearance_pending: Dictionary = {}
var _access_departures: Dictionary = {}
var _access_blockers: Dictionary = {}
var _sequence := 0
var recovery: RefCounted

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	rear.ledger.stock_changed.connect(_stock_changed)
	rear.ledger.entity_moved.connect(_entity_moved)
	rear.construction.site_changed.connect(_site_changed)
	recovery = preload("res://game/warehousing/warehouse_recovery.gd").new(self,rear)

func initialize_opening() -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var row := {"id":"initial-depot","kind":"depot","center":Vector2(120,169),
		"size":MODULE_SIZE,"door":Vector2(120,178),"quarter_turn":false,"state":"Complete",
		"protected_starter":true,"m11":100,"work":160.0,"progress":160.0,
		"site_store":"","warehouse_store":STORE,"blocker":"","builders":{},"haul_job":""}
	rear.construction.instances[row.id] = row
	register_module(row)
	# Exactly the existing opening500M11, represented once by20full crates+20kg.
	var parts: Array[Dictionary] = Packages.split("M11",500)
	for index in parts.size():
		var bay: Dictionary = bays["initial-depot/bay-%02d" % (0 if index < 16 else 4)]
		if bay.state != "Ready":
			bay.family = "crates"
			bay.state = "Ready"
			bay.cells = _make_cells("crates")
		var cell_index: int = index if index < 16 else index-16
		var id := "start-warehouse-M11-%02d" % index
		var result: Dictionary = rear.ledger.add_stock(id,"M11",int(parts[index].quantity),1.0,STORE,rear.PLAYER)
		assert(result.ok,str(result))
		_attach_stock(bay,cell_index,id,"M11")
	_touch("")

func register_module(row: Dictionary) -> void:
	if modules.has(row.id) or row.state != "Complete": return
	modules[row.id] = {"id":row.id,"center":row.center,"size":row.size,"door":row.door,"quarter_turn":bool(row.quarter_turn),"retiring":false}
	for bank in 2:
		for line in 4:
			var index: int = bank*4+line
			var id := "%s/bay-%02d" % [row.id,index]
			var local := Vector2(-3.0 if bank == 0 else 3.0,-4.5+float(line)*3.0)
			# Long axis follows module localX. A quarter-turn rotates the whole layout.
			var turn: float = PI/2.0 if bool(row.quarter_turn) else PI
			var at: Vector2 = row.center+local.rotated(turn)
			bays[id] = {"id":id,"module":row.id,"center":at,"rotation":turn,
				"state":"Empty","family":"","cells":[],"preparer":"","blocked":false}
	var rear: RefCounted = _rear_ref.get_ref()
	rear.stores[STORE].capacity = float(structural_capacity())
	rear.stores[STORE].accessible = true
	rear.stores[STORE].filter = Packages.TYPES.keys()
	topology_revision += 1
	_obstacles_dirty = true
	_touch(str(row.id))

func reserve(person: String, code: String, quantity: int, allow_prepare: bool = true, queue_access: bool = false) -> Dictionary:
	if quantity <= 0 or quantity > Packages.capacity(code): return _reject("INVALID_PACKAGE","Invalid material package.")
	if free_net_kg() < quantity: return _reject("WAREHOUSE_FULL","Warehouse full — free storage or expand it.")
	var family := Packages.fixture_family(code)
	var candidates: Array = _candidate_bays(family)
	var rear: RefCounted = _rear_ref.get_ref()
	var origin: Vector2 = rear.ledger.inspect_entity(person,{},false).position
	var has_position := false
	var ready_position_blocked := false
	var pending_room := false
	for pending: Dictionary in bays.values():
		if pending.get("staging",false) or pending.get("clearing",false): continue
		if modules[pending.module].retiring or pending.state in ["Empty","Ready"] or pending.family != family: continue
		if not _free_cells(pending.id,pending.cells,code,quantity).is_empty(): pending_room = true
	for bay: Dictionary in candidates:
		if modules[bay.module].retiring: continue
		var compatible: bool = bay.state == "Ready" and bay.family == family
		var replacing: bool = bay.state == "Ready" and bay.family != family and _can_reconfigure(bay)
		var preparing: bool = bay.state == "Empty" or replacing
		if not compatible and not (allow_prepare and preparing): continue
		if preparing:
			if ready_position_blocked: return _reject("ROUTE_BLOCKED","Route blocked — clear warehouse handling access.")
			if pending_room: return _reject("STORAGE_PREPARING","Preparing storage — waiting for the reserved shelf to become ready.")
		var cells: Array = bay.cells if compatible else _make_cells(family)
		var cell_index := -1
		var at := Vector2.INF
		var queued := false
		for candidate: int in _free_cells(bay.id,cells,code,quantity):
			has_position = true
			at = _choose_point(bay,person,origin,cells[candidate])
			if not at.is_finite() and queue_access and compatible:
				var waiting: Vector2 = _cell_service_point(bay,cells[candidate])
				if not rear.walk_path(origin,waiting).is_empty():
					at = waiting
					queued = true
			if at.is_finite():
				cell_index = candidate
				break
		if not at.is_finite():
			if compatible and not _free_cells(bay.id,cells,code,quantity).is_empty(): ready_position_blocked = true
			continue
		_sequence += 1
		var token := "warehouse-space-%06d" % _sequence
		if preparing:
			if replacing: bay.previous_family = str(bay.family)
			bay.family = family
			bay.cells = cells
			bay.state = "Reserved"
			bay.preparer = person
			_obstacles_dirty = true
		reservations[token] = {"id":token,"person":person,"bay":bay.id,"cell":cell_index,
			"code":code,"quantity":quantity,"point":at,"queued":queued}
		if not queued:
			_work_points[person] = {"holder":STORE,"point":at,"bay":str(bay.id)}
			rear.ledger.register_handling_point(STORE,person,at)
		_touch(bay.module)
		return {"ok":true,"id":token,"point":at,"prepare":bay.state != "Ready"}
	if has_position: return _reject("ROUTE_BLOCKED","Route blocked — clear warehouse handling access.")
	if pending_room: return _reject("STORAGE_PREPARING","Preparing storage — waiting for the reserved shelf to become ready.")
	return _reject("WAREHOUSE_FULL","Warehouse full — free compatible storage or expand it.")

func probe(person: String, code: String, quantity: int, allow_prepare: bool = true, fallback_origin: Vector2 = Vector2.INF) -> Vector2:
	if quantity <= 0 or quantity > Packages.capacity(code) or free_net_kg() < quantity: return Vector2.INF
	var rear: RefCounted = _rear_ref.get_ref()
	var origin: Vector2 = rear.ledger.inspect_entity(person,{},false).get("position",fallback_origin)
	if not origin.is_finite(): return Vector2.INF
	var family := Packages.fixture_family(code)
	for bay: Dictionary in _candidate_bays(family):
		if modules[bay.module].retiring: continue
		var compatible: bool = bay.state == "Ready" and bay.family == family
		var preparing: bool = bay.state == "Empty" or (bay.state == "Ready" and bay.family != family and _can_reconfigure(bay))
		if not compatible and not (allow_prepare and preparing): continue
		var cells: Array = bay.cells if compatible else _make_cells(family)
		for index: int in _free_cells(bay.id,cells,code,quantity):
			var at := _choose_point(bay,person,origin,cells[index])
			if at.is_finite(): return at
	return Vector2.INF

func _candidate_bays(family: String) -> Array:
	var result: Array = bays.values().filter(func(bay: Dictionary) -> bool: return not bay.get("staging",false) and not bay.get("clearing",false))
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var first := 0 if a.state == "Ready" and a.family == family else 1 if a.state == "Empty" else 2
		var second := 0 if b.state == "Ready" and b.family == family else 1 if b.state == "Empty" else 2
		return str(a.id)<str(b.id) if first == second else first<second)
	return result

func _can_reconfigure(bay: Dictionary) -> bool:
	if bay.get("staging",false) or bay.get("clearing",false): return false
	if bay.state != "Ready" or modules[bay.module].retiring: return false
	for cell: Dictionary in bay.cells:
		if not cell.stocks.is_empty(): return false
	for promise: Dictionary in reservations.values():
		if promise.bay == bay.id: return false
	for point: Dictionary in _work_points.values():
		if point.get("bay","") == bay.id: return false
	return true

func begin_preparation(token: String) -> Dictionary:
	if not reservations.has(token): return _reject("NO_SPACE_PROMISE","Storage reservation no longer exists.")
	var promise: Dictionary = reservations[token]
	var bay: Dictionary = bays[promise.bay]
	if bay.state == "Ready": return {"ok":true,"ready":true}
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.ledger.inspect_entity(promise.person,{},false).position.distance_to(promise.point) > 0.05:
		return _reject("NOT_AT_SHELF","Worker must reach the shelf service point first.")
	if not _clear_for_appearance(bay):
		bay.blocked = true
		_blocked_bays[bay.id] = true
		return _reject("SHELF_OCCUPIED","Shelf site occupied — waiting for clearance.")
	bay.state = "Preparing"
	bay.started_at = rear.time
	bay.blocked = false
	_blocked_bays.erase(bay.id)
	_touch(bay.module)
	return {"ok":true,"ready":false}

func finish_preparation(token: String) -> bool:
	if not reservations.has(token): return false
	var bay: Dictionary = bays[reservations[token].bay]
	if not _clear_for_appearance(bay):
		bay.blocked = true
		_blocked_bays[bay.id] = true
		return false
	bay.state = "Ready"
	bay.erase("previous_family")
	bay.preparer = ""
	bay.blocked = false
	_blocked_bays.erase(bay.id)
	_touch(bay.module)
	return true

func reveal_preparation(token: String) -> bool:
	if not reservations.has(token): return false
	var bay: Dictionary = bays[reservations[token].bay]
	if not _clear_for_appearance(bay):
		bay.blocked = true
		_blocked_bays[bay.id] = true
		return false
	bay.state = "Revealed"
	bay.blocked = false
	_blocked_bays.erase(bay.id)
	_touch(bay.module)
	return true

func ready(token: String) -> bool:
	return reservations.has(token) and bays[reservations[token].bay].state == "Ready"

func destination_point(token: String) -> Vector2:
	return reservations[token].point if reservations.has(token) else Vector2.INF

func acquire_access(token: String) -> bool:
	if not ready(token): return false
	var promise: Dictionary = reservations[token]
	var rear: RefCounted = _rear_ref.get_ref()
	var bay: Dictionary = bays[promise.bay]
	var origin: Vector2 = rear.ledger.inspect_entity(promise.person,{},false).position
	var at := _choose_point(bay,str(promise.person),origin,bay.cells[int(promise.cell)])
	if not at.is_finite(): return false
	promise.point = at
	promise.queued = false
	var holder := str(bay.get("store",STORE))
	_work_points[promise.person] = {"holder":holder,"point":at,"bay":str(bay.id)}
	rear.ledger.register_handling_point(holder,str(promise.person),at)
	return true

func commit(token: String, stock_id: String) -> Dictionary:
	if not ready(token): return _reject("STORAGE_NOT_READY","Actual reserved shelf is not ready.")
	var promise: Dictionary = reservations[token]
	var rear: RefCounted = _rear_ref.get_ref()
	var stock: Dictionary = rear.ledger.inspect_entity(stock_id,{},false)
	var bay: Dictionary = bays[promise.bay]
	if stock.get("holder_id","") != str(bay.get("store",STORE)) or stock.get("design_type","") != promise.code or int(stock.get("quantity",0)) != int(promise.quantity):
		return _reject("DEPOSIT_MISMATCH","Only the exact actual deposited stock consumes this storage promise.")
	if not bay.cells[int(promise.cell)].stocks.is_empty(): return _reject("POSITION_OCCUPIED","A physical crate already occupies this shelf position.")
	_attach_stock(bay,int(promise.cell),stock_id,str(promise.code))
	_clearance_pending[promise.person] = promise.point
	reservations.erase(token)
	_work_points.erase(promise.person)
	_touch(bay.module)
	return {"ok":true}

func release(token: String) -> void:
	if not reservations.has(token): return
	var promise: Dictionary = reservations[token]
	var bay: Dictionary = bays[promise.bay]
	reservations.erase(token)
	_work_points.erase(promise.person)
	if bay.state != "Ready" and bay.preparer == promise.person:
		var previous: String = str(bay.get("previous_family",""))
		bay.state = "Ready" if not previous.is_empty() else "Empty"
		bay.family = previous
		bay.preparer = ""
		bay.cells = _make_cells(previous) if not previous.is_empty() else []
		bay.erase("previous_family")
		bay.blocked = false
		_blocked_bays.erase(bay.id)
		_obstacles_dirty = true
	_touch(bay.module)

func free_net_kg() -> int:
	var rear: RefCounted = _rear_ref.get_ref()
	var reserved := 0
	for promise: Dictionary in reservations.values(): reserved += int(promise.quantity)
	return maxi(0,structural_capacity()-int(rear.ledger.loose_stock_mass_at(STORE))-reserved)

func structural_capacity() -> int:
	var count := 0
	for module: Dictionary in modules.values():
		if not module.retiring: count += 1
	return count*STRUCTURAL_KG

func physical_space_status(code: String, quantity: int) -> String:
	if quantity <= 0 or quantity > Packages.capacity(code) or free_net_kg() < quantity: return "Full"
	var family := Packages.fixture_family(code)
	var preparing := false
	var empty_site := false
	for bay: Dictionary in bays.values():
		if bay.get("staging",false) or bay.get("clearing",false): continue
		if modules[bay.module].retiring: continue
		if bay.state == "Empty":
			empty_site = true
			continue
		if bay.state == "Ready" and bay.family != family and _can_reconfigure(bay):
			empty_site = true
			continue
		if bay.family != family or _free_cells(bay.id,bay.cells,code,quantity).is_empty(): continue
		if bay.state == "Ready": return "Ready"
		preparing = true
	return "Preparing" if preparing else "Unprepared" if empty_site else "Full"

func connected_modules(module_id: String) -> Dictionary:
	if not modules.has(module_id): return {}
	var connected := {module_id:true}
	var queue: Array[String] = [module_id]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for other: String in modules:
			if not connected.has(other) and joined(modules[id],modules[other]):
				connected[other] = true
				queue.append(other)
	return connected

func stock_module(stock_id: String) -> String:
	var address: Dictionary = _stock_cells.get(stock_id,{})
	return str(bays[address.bay].module) if not address.is_empty() else ""

func exterior_doors(module_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for id: String in connected_modules(module_id):
		var module: Dictionary = modules[id]
		if module.retiring or hidden_boundaries(id).has("Boundary_Front"): continue
		var turn: float = PI/2.0 if bool(module.quarter_turn) else PI
		result.append(module.center+Vector2(0,-9).rotated(turn))
	return result

func summary(module_id: String) -> Dictionary:
	if _summaries.has(module_id): return _summaries[module_id]
	if not modules.has(module_id): return {}
	var connected := connected_modules(module_id)
	var result := {"modules":connected.size(),"ready":0,"preparing":0,"scheduled":0,"empty":0,
		"kg":0,"module_kg":0,"reserved":0,"packages":0,"contents":{},"module_contents":{},
		"empty_crate_positions":0,"empty_timber_positions":0}
	for bay: Dictionary in bays.values():
		if not connected.has(bay.module): continue
		if bay.state == "Ready": result.ready += 1
		elif bay.state == "Empty": result.empty += 1
		elif bay.state == "Reserved": result.scheduled += 1
		else: result.preparing += 1
		for index in bay.cells.size():
			var cell: Dictionary = bay.cells[index]
			var quantity := _cell_quantity(cell)
			if quantity <= 0:
				if bay.state == "Ready":
					var promised := false
					for promise: Dictionary in reservations.values():
						if promise.bay == bay.id and int(promise.cell) == index: promised = true
					if not promised:
						if bay.family == "timber": result.empty_timber_positions += 1
						else: result.empty_crate_positions += 1
				continue
			result.kg += quantity
			result.packages += 1
			result.contents[cell.code] = int(result.contents.get(cell.code,0))+quantity
			if bay.module == module_id:
				result.module_kg += quantity
				result.module_contents[cell.code] = int(result.module_contents.get(cell.code,0))+quantity
	for promise: Dictionary in reservations.values():
		if connected.has(bays[promise.bay].module): result.reserved += int(promise.quantity)
	_summaries[module_id] = result
	return result

func work_point(person: String) -> Vector2:
	return _work_points.get(person,{}).get("point",Vector2.INF)

func stock_service_point(stock_id: String) -> Vector2:
	if not _stock_cells.has(stock_id): return Vector2.INF
	var address: Dictionary = _stock_cells[stock_id]
	var bay: Dictionary = bays[address.bay]
	return _cell_service_point(bay,bay.cells[int(address.cell)])

func stock_point(stock_id: String, person: String, keep: bool = false) -> Vector2:
	if not _stock_cells.has(stock_id): return Vector2.INF
	var rear: RefCounted = _rear_ref.get_ref()
	var bay: Dictionary = bays[_stock_cells[stock_id].bay]
	var origin: Vector2 = rear.ledger.inspect_entity(person,{},false).position
	var point := _choose_point(bay,person,origin,bay.cells[int(_stock_cells[stock_id].cell)])
	if point.is_finite() and keep:
		var holder := str(bay.get("store",STORE))
		_work_points[person] = {"holder":holder,"point":point,"bay":str(bay.id)}
		rear.ledger.register_handling_point(holder,person,point)
	return point

func release_point(person: String) -> void:
	if _work_points.erase(person): _touch("")

func take_clearance(person: String) -> Vector2:
	var point: Vector2 = _clearance_pending.get(person,Vector2.INF)
	_clearance_pending.erase(person)
	return point

func watch_clearance(person: String, point: Vector2) -> void:
	_access_departures[person] = point

func clearance_path(person: String, origin: Vector2) -> Array:
	# Only a finished deposit requests this short walk. Reserve against actual
	# people and their committed endpoints; no idle scan or Table round trip.
	var rear: RefCounted = _rear_ref.get_ref()
	var occupied: Array[Vector2] = []
	for row: Dictionary in rear.ledger.rear_worker_views(rear.actors.keys(),rear.PLAYER):
		if row.id != person: occupied.append(row.position)
	for actor: Dictionary in rear.actors.values():
		if actor.id == person or actor.motion.is_empty(): continue
		var route: Array = actor.motion.get("path",[])
		if not route.is_empty(): occupied.append(route.back())
	var candidates: Array[Vector2] = []
	for module: Dictionary in modules.values():
		var turn: float = PI/2.0 if module.quarter_turn else PI
		# End aprons stay1.3m beyond the nearest shelf service face. Side
		# aisles are passage, not idle parking: resting there can obstruct a
		# different package position even after clearing the previous one.
		for x: float in [-3.0,3.0]:
			for z: float in [-6.9,6.9]:
				var at: Vector2 = module.center+Vector2(x,z).rotated(turn)
				if at.distance_squared_to(origin) < 1.5*1.5: continue
				var clear := true
				for other: Vector2 in occupied:
					if other.distance_squared_to(at) < 1.2*1.2: clear = false
				if clear: candidates.append(at)
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return origin.distance_squared_to(a)<origin.distance_squared_to(b))
	for at: Vector2 in candidates:
		var path: Array = rear.walk_path(origin,at)
		if not path.is_empty(): return path
	var outside: Vector2 = rear.work_point(person,"duty-depot")
	return rear.walk_path(origin,outside) if outside.is_finite() else []

func set_slot_body(bay_id: String, body_id: int, inside: bool) -> void:
	# Area3D enter/exit owns player/vehicle occupation; no overlap query per frame.
	if not bays.has(bay_id): return
	if not _slot_bodies.has(bay_id): _slot_bodies[bay_id] = {}
	if inside: _slot_bodies[bay_id][body_id] = true
	else: _slot_bodies[bay_id].erase(body_id)
	_touch(bays[bay_id].module)

func fixture_bounds(bay: Dictionary) -> Rect2:
	var size := Vector2(2.6,1.0).rotated(float(bay.rotation)).abs()
	return Rect2(bay.center-size/2.0,size)

func set_module_body(module_id: String, body_id: int, inside: bool) -> void:
	if not modules.has(module_id): return
	if not _module_bodies.has(module_id): _module_bodies[module_id] = {}
	if inside: _module_bodies[module_id][body_id] = true
	else: _module_bodies[module_id].erase(body_id)

func obstacles() -> Array[Rect2]:
	if not _obstacles_dirty: return _obstacles
	var result: Array[Rect2] = []
	for module: Dictionary in modules.values(): result.append_array(_walls(module))
	for bay: Dictionary in bays.values():
		if bay.state != "Empty": result.append(fixture_bounds(bay))
	_obstacles = result
	_obstacles_dirty = false
	return _obstacles

func can_remove(module_id: String) -> bool:
	if not modules.has(module_id) or not _module_bodies.get(module_id,{}).is_empty(): return false
	var rear: RefCounted = _rear_ref.get_ref()
	var module: Dictionary = modules[module_id]
	var bounds := Rect2(module.center-module.size/2.0,module.size)
	if module.retiring:
		if not _retiring_people.get(module_id,{}).is_empty(): return false
	else:
		for person: Dictionary in rear.ledger.rear_worker_views(rear.actors.keys(),rear.PLAYER):
			if bounds.has_point(person.position): return false
	var neighbors := 0
	for other: Dictionary in modules.values():
		if other.id != module_id and joined(module,other): neighbors += 1
	if neighbors > 1: return false
	for promise: Dictionary in reservations.values():
		if bays[promise.bay].module == module_id: return false
	for bay: Dictionary in bays.values():
		if bay.module != module_id: continue
		for cell: Dictionary in bay.cells:
			if not cell.stocks.is_empty(): return false
	return true

func retire(module_id: String) -> void:
	if not modules.has(module_id): return
	modules[module_id].retiring = true
	_retiring_people[module_id] = {}
	var rear: RefCounted = _rear_ref.get_ref()
	rear.stores[STORE].capacity = float(structural_capacity())
	_touch(module_id)

func joined(first: Dictionary, second: Dictionary) -> bool:
	var delta: Vector2 = (first.center-second.center).abs()
	return (is_equal_approx(delta.x,(float(first.size.x)+float(second.size.x))/2.0) and is_zero_approx(delta.y) and is_equal_approx(first.size.y,second.size.y)) or (is_equal_approx(delta.y,(float(first.size.y)+float(second.size.y))/2.0) and is_zero_approx(delta.x) and is_equal_approx(first.size.x,second.size.x))

func _walls(module: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for box: Dictionary in module_colliders(str(module.id)):
		if float(box.position.y)+float(box.size.y)/2.0 <= 0.1 or float(box.position.y)-float(box.size.y)/2.0 >= 1.9: continue
		var size := Vector2(box.size.x,box.size.z)
		result.append(Rect2(Vector2(box.position.x,box.position.z)-size/2.0,size))
	return result

func hidden_boundaries(module_id: String) -> Dictionary:
	var hidden := {}
	var module: Dictionary = modules[module_id]
	var turn: float = PI/2.0 if bool(module.quarter_turn) else PI
	for other: Dictionary in modules.values():
		if other.id == module_id or not joined(module,other): continue
		var local: Vector2 = (other.center-module.center).rotated(-turn)
		var group: String = ("Boundary_Left" if local.x < 0.0 else "Boundary_Right") if absf(local.x) > absf(local.y) else ("Boundary_Front" if local.y < 0.0 else "Boundary_Back")
		hidden[group] = true
	return hidden

func module_colliders(module_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var module: Dictionary = modules[module_id]
	var hidden := hidden_boundaries(module_id)
	var turn: float = PI/2.0 if bool(module.quarter_turn) else PI
	for original: Dictionary in Collision.BOXES:
		if hidden.has(original.group): continue
		var local: Vector3 = original.position
		var point: Vector2 = module.center+Vector2(local.x,local.z).rotated(turn)
		var raw_size: Vector3 = original.size
		var size: Vector2 = Vector2(raw_size.x,raw_size.z).rotated(turn).abs()
		result.append({"group":original.group,"position":Vector3(point.x,local.y,point.y),"size":Vector3(size.x,raw_size.y,size.y)})
	return result

func _make_cells(family: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var columns := 1 if family == "timber" else 4
	for deck in 2:
		for row in 2:
			for column in columns:
				var height: float = float(TIMBER_SUPPORT_Y[deck])+TIMBER_BASE_REGISTRATION_Y if family == "timber" else 0.25+0.7*deck
				result.append({"code":"","stocks":[],"offset":Vector3(0.0 if columns == 1 else -0.93+0.62*column,height,-0.25+0.5*row)})
	return result

func _free_cells(bay_id: String, cells: Array, code: String, quantity: int) -> Array[int]:
	var result: Array[int] = []
	for index in cells.size():
		var cell: Dictionary = cells[index]
		# A partly filled crate still occupies its full envelope. Two separately
		# arriving packages cannot share a position by merely adding their kg.
		if not cell.stocks.is_empty(): continue
		var promised := 0
		var promise_code := ""
		for promise: Dictionary in reservations.values():
			if promise.bay == bay_id and int(promise.cell) == index:
				promised += int(promise.quantity)
				promise_code = str(promise.code)
		if not promise_code.is_empty() and promise_code != code: continue
		if promised == 0 and quantity <= Packages.capacity(code): result.append(index)
	return result

func _cell_quantity(cell: Dictionary) -> int:
	var rear: RefCounted = _rear_ref.get_ref()
	var count := 0
	for id: String in cell.stocks: count += int(rear.ledger.inspect_entity(id,{},false).get("quantity",0))
	return count

func _attach_stock(bay: Dictionary, cell_index: int, stock_id: String, code: String) -> void:
	var cell: Dictionary = bay.cells[cell_index]
	cell.code = code
	cell.stocks.append(stock_id)
	_stock_cells[stock_id] = {"bay":bay.id,"cell":cell_index}
	var local: Vector3 = cell.offset
	var at: Vector2 = bay.center+Vector2(local.x,local.z).rotated(float(bay.rotation))
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Dictionary = rear.ledger.position_stored_stock(stock_id,str(bay.get("store",STORE)),at)
	assert(result.ok,str(result))

func _cell_service_point(bay: Dictionary, cell: Dictionary) -> Vector2:
	var side := -1.0 if float(cell.offset.z) < 0.0 else 1.0
	return bay.center+Vector2(float(cell.offset.x),side*1.1).rotated(float(bay.rotation))

func _choose_point(bay: Dictionary, person: String, origin: Vector2, cell: Dictionary) -> Vector2:
	var rear: RefCounted = _rear_ref.get_ref()
	var people: Array[Dictionary] = rear.ledger.rear_worker_views(rear.actors.keys(),rear.PLAYER)
	# Each row is collected from its own accessible face. Do not reach across a
	# buried rear row or sideways across several neighbouring crate positions.
	var at: Vector2 = _cell_service_point(bay,cell)
	var clear := true
	for id: String in _work_points:
		if id != person and _work_points[id].point.distance_squared_to(at) < 1.2*1.2: clear = false
	for row: Dictionary in people:
		if row.id != person and row.position.distance_squared_to(at) < 1.2*1.2:
			clear = false
			# Watch the actual blocker; avoid path search for an occupied face.
			if not _access_blockers.has(row.id): _access_blockers[row.id] = []
			if not at in _access_blockers[row.id]: _access_blockers[row.id].append(at)
	if not clear: return Vector2.INF
	var path: Array = rear.construction.walking_path(origin,at,fixture_bounds(bay)) if bay.state == "Empty" else rear.walk_path(origin,at)
	return at if not path.is_empty() else Vector2.INF

func _clear_for_appearance(bay: Dictionary) -> bool:
	if not _slot_bodies.get(bay.id,{}).is_empty(): return false
	var rear: RefCounted = _rear_ref.get_ref()
	var bounds := fixture_bounds(bay).grow(0.45)
	for person: Dictionary in rear.ledger.rear_worker_views(rear.actors.keys(),rear.PLAYER):
		if bounds.has_point(person.position): return false
	return true

func _stock_changed(id: String) -> void:
	if not _stock_cells.has(id): return
	var rear: RefCounted = _rear_ref.get_ref()
	var stock: Dictionary = rear.ledger.inspect_entity(id,{},false)
	var address: Dictionary = _stock_cells[id]
	var bay: Dictionary = bays[address.bay]
	if int(stock.get("quantity",0)) <= 0 or stock.get("holder_id","") != str(bay.get("store",STORE)):
		bay.cells[int(address.cell)].stocks.erase(id)
		_stock_cells.erase(id)
	_touch(bay.module)

func _entity_moved(_id: String, start: Vector2, finish: Vector2) -> void:
	# Only blocked shelf appearances watch relevant movement. Normal movement does
	# not scan fixtures, stock or routes and cannot rebuild warehouse presentation.
	if _access_departures.has(_id) and finish.distance_squared_to(_access_departures[_id]) >= 1.2*1.2:
		_access_departures.erase(_id)
		_touch("")
	if _access_blockers.has(_id):
		var remaining: Array = []
		var cleared := false
		for point: Vector2 in _access_blockers[_id]:
			if finish.distance_squared_to(point) >= 1.2*1.2: cleared = true
			else: remaining.append(point)
		if remaining.is_empty(): _access_blockers.erase(_id)
		else: _access_blockers[_id] = remaining
		if cleared: _touch("")
	if not _retiring_people.is_empty():
		var rear: RefCounted = _rear_ref.get_ref()
		if rear.actors.has(_id):
			for module_id: String in _retiring_people:
				var module: Dictionary = modules[module_id]
				var bounds := Rect2(module.center-module.size/2.0,module.size)
				if bounds.has_point(finish): _retiring_people[module_id][_id] = true
				else: _retiring_people[module_id].erase(_id)
	if _blocked_bays.is_empty(): return
	for bay_id: String in _blocked_bays:
		var bounds := fixture_bounds(bays[bay_id]).grow(0.45)
		if bounds.has_point(start) and not bounds.has_point(finish):
			_touch(bays[bay_id].module)

func _site_changed(id: String) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = rear.construction.instances.get(id,{})
	if row.is_empty(): return
	var topology: Array = [row.center,row.size,row.state]
	if _topology.get(id,[]) != topology:
		_topology[id] = topology
		_touch(id)
	if row.get("kind","") != "depot": return
	if row.state == "Complete": register_module(row)
	elif row.state in ["Cancelled","Dismantled"] and modules.has(id) and can_remove(id):
		for bay_id: String in bays.keys():
			if bays[bay_id].module == id: bays.erase(bay_id)
		modules.erase(id)
		_retiring_people.erase(id)
		topology_revision += 1
		_obstacles_dirty = true
		rear.stores[STORE].capacity = float(structural_capacity())
		_touch(id)

func _touch(module_id: String) -> void:
	revision += 1
	if not module_id.is_empty():
		_summaries.clear()
		changed.emit(module_id)
	space_changed.emit()

func _reject(code: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"message":message}
