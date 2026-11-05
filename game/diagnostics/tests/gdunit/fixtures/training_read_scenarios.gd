extends RefCounted
## Legal prepared states and query-independent state capture for the Train migration.
const Base = preload("res://game/rear_base/base_simulation.gd")

static func labels() -> Array[String]:
	return ["empty", "queued", "reporting", "active", "access_paused", "instructor_paused", "withdrawn", "completed", "multiple_sites"]

static func fixture(label: String = "active") -> RefCounted:
	if label == "empty": return Base.new(false, false, false, Vector2(1640, 91), true, {}, true)
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for index in 2: _require(rear.add_person("read-instructor-%02d" % index, true, "None", "duty-training"))
	_require(rear.set_target("training", 1))
	if label == "idle": return base
	if label == "multiple_sites": _second_site(base)
	_require(rear.training.request_course("P08" if label == "queued" else "P01", 24 if label == "multiple_sites" else 12))
	if label in ["queued", "reporting"]: return base
	rear.advance_time(30)
	match label:
		"access_paused": _require(rear.training.set_access(false))
		"instructor_paused": _require(rear.set_target("training", 0))
		"withdrawn": _require(rear.training.withdraw(rear.training.rows[0].id))
		"completed":
			_require(rear.set_target("training", 2))
			rear.advance_time(150)
	return base

static func _second_site(base: RefCounted) -> void:
	var rear: RefCounted = base.rear
	_require(rear.ledger.add_stock("read-build-materials", "M11", 500, 1.0, "depot", rear.PLAYER))
	_require(rear.set_target("hauling", 2))
	_require(rear.set_target("construction", 2))
	for step in 120:
		if rear._present("construction") >= 2: break
		rear.advance_time(5)
	var point := Vector2(INF, INF)
	for y in range(15, 166, 10):
		for x in range(15, 226, 10):
			if rear.construction.preview("training", Vector2(x, y)).ok:
				point = Vector2(x, y)
				break
		if is_finite(point.x): break
	assert(is_finite(point.x), "The prepared second F06 needs a legal footprint.")
	var placed: Dictionary = rear.construction.place("training", point)
	_require(placed)
	_require(rear.construction.order_materials(placed.id, "depot"))
	_require(rear.construction.set_builders(placed.id, 2))
	for step in 240:
		if rear.construction.instances[placed.id].state == "Complete": break
		rear.advance_time(5)
	assert(rear.construction.instances[placed.id].state == "Complete", "Second F06 must be physically completed, not injected.")
	_require(rear.set_target("hauling", 0))
	_require(rear.set_target("construction", 0))
	for index in 2: _require(rear.add_person("read-second-instructor-%02d" % index, true, "None", "duty-training"))
	for index in 12: _require(rear.add_person("read-extra-student-%02d" % index))
	_require(rear.set_target(placed.id, 1))

static func read_view(base: RefCounted, selected: String = "") -> Dictionary:
	# The same harness captures the pre-change broad path, then compares the new
	# path against it. Tests explicitly require the new API after implementation.
	if base.has_method("training_view"): return base.training_view(selected)
	var view: Dictionary = base.snapshot(false, false)
	view.rear_population = base.receiving.rear_population()
	view.training_selected_person = selected_person(base, selected)
	return view

static func selected_person(base: RefCounted, selected: String) -> Dictionary:
	for row in base.rear.training.rows:
		if row.id == selected and not row.person_id.is_empty(): return base.rear.ledger.inspect_person_status(row.person_id)
	return {}

static func display_values(view: Dictionary) -> Dictionary:
	var stores: Array = []
	for storage in view.rear.stores:
		var stocks: Array = []
		for stock in storage.stocks:
			stocks.append({"id":stock.id, "owner":stock.owner, "type":stock.design_type, "quantity":stock.quantity, "reserved":stock.reserved})
		stores.append({"id":storage.id, "stocks":stocks})
	var person: Dictionary = view.training_selected_person
	var detail := {}
	if not person.is_empty():
		for field in ["id", "basic_training", "qualification", "position", "duty_id", "assignment"]: detail[field] = person[field]
	return {"training":view.training, "selected_person":detail, "stores":stores,
		"money":view.receiving.money, "orders":view.receiving.orders, "recovery_offer":view.receiving.recovery_offer,
		"rear_population":view.rear_population}

static func frozen_baseline_projection(raw: Dictionary) -> Dictionary:
	# Reviewed against the original 2026-11-03 source and all nine full states.
	# Preserve the original frozen hashes, checking the seven additive idle
	# scheduler fields explicitly. Unknown additions still fail the old hash.
	var state: Dictionary = raw.duplicate(true)
	var base_fields: Dictionary = state.fields
	var base_defaults := {"_advance_due":false,"_foot_view_revision":-1,"_forward_view_revision":-1}
	for field in base_defaults:
		assert(base_fields.has(field) and base_fields[field] == base_defaults[field],"Changed scheduler state in frozen training fixture: "+field)
		base_fields.erase(field)
	var transport: Dictionary = base_fields.rear.fields.forward_supply.fields.transport.fields
	var transport_defaults := {"_plan_queue":[],"_plans":{},"_route_sequence":0,"planning_revision":0}
	for field in transport_defaults:
		assert(transport.has(field) and transport[field] == transport_defaults[field],"Changed forward-planning state in frozen training fixture: "+field)
		transport.erase(field)
	return state

static func raw_state(base: RefCounted) -> Dictionary:
	# Inspect stored script fields rather than calling a service snapshot/audit.
	# RefCounted aliases use stable property paths; instance IDs never enter hashes.
	return _raw_value(base, {}, "base")

static func _raw_value(value: Variant, seen: Dictionary, path: String) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys: result[str(key)] = _raw_value(value[key], seen, path + "/" + str(key))
		return result
	if value is Array:
		var result: Array = []
		for index in value.size(): result.append(_raw_value(value[index], seen, path + "/" + str(index)))
		return result
	if value is Object:
		if value == null or value is WeakRef: return null
		if value.get_script() == null: return {"native_class":value.get_class()}
		var identity: int = value.get_instance_id()
		if seen.has(identity): return {"reference":seen[identity]}
		seen[identity] = path
		var fields := {}
		for property in value.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
			fields[property.name] = _raw_value(value.get(property.name), seen, path + "/" + str(property.name))
		return {"script":value.get_script().resource_path, "fields":fields}
	if typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL]: return "<callback>"
	return value

static func fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func _require(result: Dictionary) -> void:
	assert(result.ok, str(result))
