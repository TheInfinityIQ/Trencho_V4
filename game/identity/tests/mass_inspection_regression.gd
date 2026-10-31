extends SceneTree
const Fixture = preload("res://game/identity/identity_fixture.gd")
const Records = preload("res://game/identity/identity_records.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	var fixture := Fixture.new()
	fixture.reset()
	var ledger: RefCounted = fixture.ledger
	check(ledger.entity_kind("missing") == "","Unknown kind query remains empty")
	check(ledger.inspect_person_status("missing").is_empty() and ledger.inspect_person_status("supplier-truck").is_empty(),"Person status refuses missing and nonperson identities")
	check(not ledger.person_has_duty("missing","") and not ledger.person_has_duty("supplier-truck",""),"Duty equality refuses unknown and nonperson identities even for an empty duty")
	check(ledger.add_stock("retained-rounds","E02",50,0.02,"worker-01","army-blue").ok,"Real retained ammunition")
	check(ledger.add_weapon("retained-rifle","E01",4,"worker-01","army-blue","E02",30).ok,"Actual retained rifle")
	check(ledger.load_rounds("retained-rifle","retained-rounds",10).ok,"Actual nested loaded rounds")
	check(ledger.add_stock("exact-cargo","M11",20,1,"rear-store","army-blue").ok,"Actual twenty-kilogram cargo")
	check(ledger.add_stock("over-cargo","M11",20,1.00000001,"rear-store","army-blue").ok,"Actual slightly heavier cargo")
	compare(ledger)
	check(ledger.inspect_entity("worker-01").contents_mass_kg == 5.0,"Retained weapon, loaded rounds and loose rounds weigh exactly five kilograms")
	check(not ledger.begin_carry("worker-01","over-cargo",20).ok,"Just over twenty-five kilograms remains refused")
	check(ledger.begin_carry("worker-01","exact-cargo",20).ok,"Exactly twenty-five kilograms remains admitted")
	check(ledger.inspect_entity("worker-01").contents_mass_kg == 25.0,"Actual carried contents reach exact capacity")
	compare(ledger)
	check(ledger.finish_carry("worker-01","rear-store").ok,"Physical carry safely deposits")
	check(ledger.transfer_weapon("retained-rifle","person-03").ok,"Loaded weapon changes physical holder")
	compare(ledger)
	check(ledger.add_weapon("query-foreign","E05",4,"person-03","army-red","E02",30).ok,"Foreign held weapon remains a physical identity")
	check(ledger.add_stock("query-foreign-rounds","E02",20,0.02,"person-03","army-red").ok,"Foreign loose rounds remain physical")
	check(ledger.load_rounds("query-foreign","query-foreign-rounds",7).ok,"Foreign matching rounds use the actual load operation")
	check(ledger.request_stock("query-reserved","query-foreign-rounds",5,"query-fixture","Retained physical count","army-red").ok,"Actual reservation does not remove physical rounds")
	check(ledger.add_weapon("query-other","E07",4,"person-03","army-blue","E26",3).ok,"Other weapon type is held alongside infantry weapons")
	check(ledger.add_stock("query-other-rounds","E26",3,0.02,"person-03","army-blue").ok and ledger.load_rounds("query-other","query-other-rounds",2).ok,"Other ammunition is actually loaded")
	# The old count includes broken weapons; eligibility belongs to its caller.
	ledger._entities["query-foreign"].health = 0
	compare(ledger)
	var held_batch: Array[Dictionary] = ledger.entities_at_any(["person-03"],["WEAPON","STOCK"],false)
	var held_copy: Array[Dictionary] = held_batch.duplicate(true)
	check(ledger.unload_rounds("query-other").ok,"Real unload changes nested quantities")
	check(held_batch == held_copy,"Earlier batch results stay detached after physical unloading")
	var fresh_batch: Array[Dictionary] = ledger.entities_at_any(["person-03"],["WEAPON","STOCK"],false)
	check(fresh_batch != held_batch,"New batch inspection observes the real unload rather than stale loaded facts")
	for row in fresh_batch:
		row.quantity = -1
		if row.kind == "WEAPON": row.loaded_rounds = -1
		if row.kind == "STOCK": row.blocked_reason = "Mutated detached result"
	check(ledger.entities_at_any(["person-03"],["WEAPON","STOCK"],false) == ledger.snapshot(false).entities.filter(func(row: Dictionary) -> bool: return row.holder_id == "person-03" and row.kind in ["WEAPON","STOCK"]),"Mutating returned stock and weapon facts cannot change later ledger inspections")
	check(ledger.transfer_weapon("query-foreign","worker-01").ok,"Foreign loaded weapon physically changes holder")
	compare(ledger)
	check(ledger.request_assignment("worker-01",Records.Assignment.REAR_LABOUR,"query-next-duty").ok,"Actual assignment changes current duty without a cache")
	check(ledger.person_has_duty("worker-01","query-next-duty") and not ledger.person_has_duty("worker-01","haul-fixture"),"Duty query immediately observes the physical assignment transition")
	check(ledger.add_stock("summary-zero","Summary",1,0.5,"receiving","army-blue").ok,"Create first summary row for real depletion")
	check(ledger.add_stock("summary-foreign","Summary",2,3.0,"receiving","army-red").ok,"Foreign stock contributes capacity before owned rows")
	check(ledger.add_stock("summary-light","Summary",3,0.1,"receiving","army-blue").ok and ledger.add_stock("summary-heavy","Summary",4,1.1,"receiving","army-blue").ok,"Same type retains heterogeneous unit masses")
	# Distinct authored offsets prove relocation keeps the first eligible position.
	ledger._entities["summary-light"].position = Vector2(2,3)
	ledger._entities["summary-heavy"].position = Vector2(4,5)
	check(ledger.request_stock("summary-reserved","summary-heavy",2,"query-fixture","Reserved stock remains physical","army-blue").ok,"Reserve physical summary stock")
	var held_summary: Dictionary = ledger.loose_stock_summary("receiving","army-blue")
	var summary_copy: Dictionary = held_summary.duplicate(true)
	check(ledger.record_consumption("summary-zero",1,"Summary depletion regression").ok,"Real consumption leaves first row depleted")
	check(held_summary == summary_copy and ledger.loose_stock_summary("receiving","army-blue") != held_summary,"Summary stays detached and new call observes depletion and new first positive row")
	compare(ledger)
	var held_ids: Array[String] = ledger.available_person_ids("army-blue")
	var ids_copy: Array[String] = held_ids.duplicate()
	check(ledger.request_assignment("worker-01",Records.Assignment.AVAILABLE,"").ok,"Actual duty release makes the worker discoverable")
	check(held_ids == ids_copy and ledger.available_person_ids("army-blue").has("worker-01"),"ID lists stay detached and fresh calls observe release")
	check(ledger.add_person("query-arrival","receiving","supplier",Records.Assignment.PASSENGER).ok,"Real incoming passenger begins unavailable")
	compare_available_people(ledger,ledger.snapshot())
	check(ledger.move_entity("query-arrival","rear-store",Vector2.ZERO).ok and ledger.complete_person_arrival("query-arrival","rear-store","army-red").ok,"Physical receiving boundary changes owner and availability")
	compare_available_people(ledger,ledger.snapshot())
	check(ledger.request_assignment("query-arrival",Records.Assignment.TRAINING,"query-course").ok,"Real training assignment withdraws an available ID")
	compare_available_people(ledger,ledger.snapshot())
	check(ledger.audit().is_empty(),"Mass inspections preserve all ledger invariants")
	print("Mass inspection regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func compare(ledger: RefCounted) -> void:
	var complete: Dictionary = ledger.snapshot()
	compare_available_people(ledger,complete)
	var metadata: Dictionary = ledger.snapshot(false)
	for index in complete.entities.size():
		var expected: Dictionary = complete.entities[index].duplicate(true)
		expected.erase("contents_mass_kg")
		check(metadata.entities[index] == expected,"Mixed metadata projection preserves every non-mass fact, including weapons, claims, holders and quantities")
	var expected_summary: Dictionary = complete.duplicate(true)
	expected_summary.entities = metadata.entities
	check(metadata == expected_summary,"Metadata projection changes no account, claim or event summary")
	for holder in ["worker-01","rear-store","receiving","person-03","retained-rifle","missing",""]:
		for owner in ["army-blue","army-red","missing",""]:
			var mass: float = 0.0
			var contents := {}
			for row in complete.entities:
				if row.kind != "STOCK" or row.holder_id != holder: continue
				mass += row.quantity * row.unit_mass_kg
				if row.owner != owner or row.quantity <= 0: continue
				if not contents.has(row.design_type): contents[row.design_type] = {"quantity":0,"mass":row.unit_mass_kg,"position":row.position}
				contents[row.design_type].quantity += row.quantity
			var expected := {"mass":mass,"contents":contents}
			var summary: Dictionary = ledger.loose_stock_summary(holder,owner)
			check(var_to_bytes(summary) == var_to_bytes(expected),"Loose-stock summary exactly matches independent full inspection order, mass and owned positive contents")
			for type in summary.contents:
				summary.contents[type].quantity = -1
				summary.contents[type].position = Vector2.INF
			check(var_to_bytes(ledger.loose_stock_summary(holder,owner)) == var_to_bytes(expected),"Returned summary contents are detached from later physical reads")
	for holder in ["worker-01","rear-store","receiving","person-03","retained-rifle","missing",""]:
		for kinds in [[],["missing"],["PERSON"],["STOCK"],["WEAPON"],["STOCK","STOCK"],["PERSON","STOCK","WEAPON"],Records.Kind.keys()]:
			var full_rows: Array = complete.entities.filter(func(row: Dictionary) -> bool: return row.holder_id == holder and row.kind in kinds)
			var metadata_rows: Array = metadata.entities.filter(func(row: Dictionary) -> bool: return row.holder_id == holder and row.kind in kinds)
			check(ledger.entities_at(holder,kinds) == full_rows,"Single holder keeps independent full snapshot-filter results and default physical mass")
			check(ledger.entities_at(holder,kinds) == legacy_entities_at(ledger,holder,kinds),"Single holder full query equals retained per-row inspection without shared carry or loaded facts")
			var queried: Array[Dictionary] = ledger.entities_at(holder,kinds,false)
			check(queried == metadata_rows,"Single holder metadata preserves canonical order, loaded rounds, carries and reservation facts")
			check(queried == legacy_entities_at(ledger,holder,kinds,false),"Single holder metadata equals original independent per-row carry and loaded inspection")
			for row in queried:
				row.quantity = -1
				if row.kind == "WEAPON": row.loaded_rounds = -1
				if row.kind == "STOCK": row.blocked_reason = "Mutated query result"
			check(ledger.entities_at(holder,kinds,false) == metadata_rows,"Single holder returns detached facts and recomputes after caller mutation")
	for holders in [[],["missing"],["worker-01","rear-store"],["rear-store","worker-01","rear-store","missing"],["retained-rifle","person-03","retained-rifle"],[""]]:
		for kinds in [[],["missing"],["PERSON"],["STOCK","WEAPON"],["STOCK","STOCK"],Records.Kind.keys()]:
			var full_union: Array = complete.entities.filter(func(row: Dictionary) -> bool: return row.holder_id in holders and row.kind in kinds)
			var metadata_union: Array = metadata.entities.filter(func(row: Dictionary) -> bool: return row.holder_id in holders and row.kind in kinds)
			check(ledger.entities_at_any(holders,kinds) == full_union,"Batch holders preserve full snapshot-filter union, canonical order and exact quantities")
			check(ledger.entities_at_any(holders,kinds,false) == metadata_union,"Batch holders preserve metadata union across empty, repeated, missing and moved holders/kinds")
	for type in ["E01","E02","missing"]:
		compare_rows(ledger.entities_of_type(type,["STOCK","WEAPON"]),ledger.entities_of_type(type,["STOCK","WEAPON"],false))
	for kind in Records.Kind.values():
		var label: String = Records.Kind.keys()[kind]
		check(ledger.entities_of_kind(kind) == complete.entities.filter(func(row: Dictionary) -> bool: return row.kind == label),"Kind query preserves full membership, facts and insertion order for "+label)
		check(ledger.entities_of_kind(kind,false) == metadata.entities.filter(func(row: Dictionary) -> bool: return row.kind == label),"Kind metadata query preserves non-mass facts and order for "+label)
	for holder in ["worker-01","rear-store","retained-rifle","missing"]:
		for type in ["E01","E02","M11","missing"]:
			var quantity := 0
			for row in complete.entities:
				if row.holder_id == holder and row.design_type == type and row.kind in ["WEAPON","STOCK","HEAVY_OBJECT"]: quantity += int(row.quantity)
			check(ledger.physical_quantity_at(holder,type,["WEAPON","STOCK","HEAVY_OBJECT"]) == quantity,"Physical quantity equals full inspection after real carry and weapon moves")
			check(ledger.physical_quantity_at(holder,type,[]) == 0,"An empty kind filter admits no physical quantities")
	for holder in ["worker-01","person-02","person-03","retained-rifle","rear-store","missing",""]:
		for loose_type in ["E02","E02 Round","E26","missing"]:
			for weapon_types in [[],["E01"],["E01","E05","E19"],["E01","E01","E07"],["E01 Rifle"],["missing"]]:
				var expected := 0
				for row in complete.entities:
					if row.holder_id != holder: continue
					if row.design_type == loose_type and row.kind in ["WEAPON","STOCK","HEAVY_OBJECT"]: expected += int(row.quantity)
					if row.kind == "WEAPON" and row.design_type in weapon_types: expected += int(row.loaded_rounds)
				check(ledger.ammunition_quantity_at(holder,loose_type,weapon_types) == expected,"Ammunition count equals independent full inspection across held, loaded, reserved, broken, foreign and moved goods")
	for row in complete.entities:
		check(row == ledger.inspect_entity(row.id),"Batched inspection equals independent raw facts for loaded rounds, carries and exact mass")
		check(ledger.entity_kind(row.id) == row.kind,"Kind-only query equals the authoritative inspection kind")
		if row.kind == "PERSON":
			for duty in ["",row.duty_id,"haul-fixture","query-next-duty","missing"]:
				check(ledger.person_has_duty(row.id,duty) == (row.duty_id == duty),"Scalar duty equality matches current authoritative person facts")
			var full: Dictionary = ledger.inspect_entity(row.id)
			full.erase("contents_mass_kg")
			var status: Dictionary = ledger.inspect_person_status(row.id)
			check(status == full and not status.has("contents_mass_kg"),"Status preserves exact person facts without inventing a load mass")
			status.health = -1
			check(ledger.inspect_person_status(row.id).health == full.health,"Person status remains a detached read")
		var expected: float = legacy(ledger,row.id)
		check(float(row.contents_mass_kg) == expected,"Snapshot keeps legacy exact subtree arithmetic for "+row.id)
		check(float(ledger.inspect_entity(row.id).contents_mass_kg) == expected,"Raw inspection keeps legacy exact subtree arithmetic for "+row.id)
func legacy_entities_at(ledger: RefCounted, holder: String, kinds: Array, include_mass: bool = true) -> Array[Dictionary]:
	# Retained single-holder algorithm, without batch-query facts or delegation.
	var result: Array[Dictionary] = []
	for entity in ledger._entities.values():
		if entity.holder_id == holder and Records.Kind.keys()[entity.kind] in kinds: result.append(ledger.inspect_entity(entity.id,{},include_mass))
	return result

func compare_available_people(ledger: RefCounted, complete: Dictionary) -> void:
	for row in complete.entities:
		if row.kind == "PERSON": check(ledger._entities[row.id] is Records.Person,"Canonical PERSON kind retains its typed assignment record")
	for owner in ["army-blue","army-red","supplier","missing",""]:
		var expected: Array[String] = []
		for row in complete.entities:
			if row.kind == "PERSON" and row.owner == owner and row.assignment == "Available": expected.append(row.id)
		var ids: Array[String] = ledger.available_person_ids(owner)
		check(ids == expected,"Available IDs equal independent full snapshot selection in canonical order")
		ids.clear()
		check(ledger.available_person_ids(owner) == expected,"Mutating returned ID arrays cannot change fresh available-person discovery")

func compare_rows(full: Array, projected: Array) -> void:
	check(full.size() == projected.size(),"Filtered metadata query retains exact membership")
	for index in full.size():
		var expected: Dictionary = full[index].duplicate(true)
		expected.erase("contents_mass_kg")
		check(projected[index] == expected,"Filtered metadata query preserves exact non-mass facts and ordering")
func legacy(ledger: RefCounted, holder: String) -> float:
	var total := 0.0
	for entity in ledger._entities.values():
		if entity.holder_id == holder: total += entity.unit_mass_kg*entity.quantity+legacy(ledger,entity.id)
	return total
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
