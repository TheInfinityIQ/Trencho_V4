extends GdUnitTestSuite
## Independent legacy read oracle, scalar-query cost and immediate domain-transition guards.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")

func test_00_cohesion_matches_legacy_eligibility_boarding_and_geometry() -> void:
	var base := _fixture()
	var rear: RefCounted = base.rear
	var row: Dictionary = rear.military.squads["cohesion-squad"]
	var person: RefCounted = rear.ledger._entities[row.roster[1]]
	var saved := {"health":person.health,"assignment":person.assignment,"duty_id":person.duty_id,"crew_station":person.crew_station,"holder_id":person.holder_id,"position":person.position}
	var cases := [{}, {"health":0}, {"assignment":Records.Assignment.WOUNDED}, {"assignment":Records.Assignment.RECOVERY},
		{"assignment":Records.Assignment.DEAD}, {"assignment":Records.Assignment.AVAILABLE}, {"duty_id":"different-squad"},
		{"crew_station":"Driver"}, {"holder_id":"cohesion-carrier"}, {"position":Vector2(30,0)}, {"position":Vector2(30.0001,0)},
		{"position":Vector2(0,30)}, {"position":Vector2(0,30.0001)}]
	for boarded in [false,true]:
		row.vehicle = "cohesion-carrier" if boarded else ""
		for variant in cases:
			for key in saved: person.set(key,saved[key])
			for key in variant: person.set(key,variant[key])
			assert_that(rear.combat.squad_cohesion(row.id)).override_failure_message("Legacy parity: " + str(variant) + " boarded=" + str(boarded)).is_equal(_legacy(rear,row.id))
			for include_boarded in [false,true]:
				assert_that(rear.military._active_roster_members(row,include_boarded)).is_equal(_legacy_members(rear,row,include_boarded))
	for key in saved: person.set(key,saved[key])
	for id in row.roster:
		rear.ledger._entities[id].holder_id = "cohesion-carrier"
		rear.ledger._entities[id].position = Vector2.ZERO
	assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	assert_str(rear.combat.squad_cohesion(row.id).state).is_equal("Boarded")
	row.vehicle = "other-carrier"
	assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	for id in row.roster: rear.ledger._entities[id].holder_id = "cohesion-place"
	for missing in ["", "missing-person", "cohesion-place"]:
		row.leader = missing
		assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	row.leader = row.roster[0]
	for assignment in [Records.Assignment.FORMATION_DUTY, Records.Assignment.WOUNDED, Records.Assignment.RECOVERY, Records.Assignment.DEAD]:
		rear.ledger._entities[row.leader].assignment = assignment
		assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	row.state = "Reporting"
	assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	assert_that(rear.combat.squad_cohesion("missing-squad")).is_equal(_legacy(rear,"missing-squad"))

func test_01_movement_and_injury_keep_immediate_dispersion_timestamps() -> void:
	var base := _fixture()
	var rear: RefCounted = base.rear
	var row: Dictionary = rear.military.squads["cohesion-squad"]
	assert_str(rear.combat.squad_cohesion(row.id).state).is_equal("Coherent")
	for id in row.roster:
		if id != row.leader: assert_bool(rear.ledger.move_entity(id,"cohesion-place",Vector2(1600,91)).ok).is_true()
	assert_bool(rear.combat.dispersed_since.has(row.id)).is_true()
	var started: float = rear.combat.dispersed_since[row.id]
	assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	rear.advance_time(10)
	assert_str(rear.combat.squad_cohesion(row.id).state).is_equal("Dispersed")
	assert_float(rear.combat.dispersed_since[row.id]).is_equal(started)
	for id in row.roster: assert_bool(rear.ledger.move_entity(id,"cohesion-place",Vector2(1500,91)).ok).is_true()
	assert_bool(rear.combat.dispersed_since.has(row.id)).is_false()
	assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	assert_bool(rear.combat.injure(row.leader,500).ok).is_true()
	assert_that(rear.combat.squad_cohesion(row.id)).is_equal(_legacy(rear,row.id))
	assert_array(base.audit()).is_empty()

func test_02_repeated_cohesion_reads_export_no_detailed_entities() -> void:
	var base := _fixture()
	var combat: RefCounted = base.rear.combat
	var expected := _legacy(base.rear,"cohesion-squad")
	var before := Counter.totals()
	for repeat in 100: assert_that(combat.squad_cohesion("cohesion-squad")).is_equal(expected)
	var after := Counter.totals()
	assert_int(int(after.get("identity/identity_ledger.gd::inspect_entity",0))-int(before.get("identity/identity_ledger.gd::inspect_entity",0))).is_equal(0)
	assert_int(int(after.get("identity/identity_ledger.gd::formation_cohesion_counts",0))-int(before.get("identity/identity_ledger.gd::formation_cohesion_counts",0))).is_equal(100)
	assert_bool(combat.dispersed_since.is_empty()).is_true()

func test_03_batch_ammunition_matches_fresh_scalar_counts() -> void:
	var base := _fixture()
	var rear: RefCounted = base.rear
	var ids: Array[String] = rear.military.squads["cohesion-squad"].roster.duplicate()
	ids.append("missing-person")
	for id in rear.military.squads["cohesion-squad"].roster:
		assert_bool(rear.ledger.load_rounds(id+"-rifle",id+"-rounds",10).ok).is_true()
	var counts: Dictionary = rear.military.personal_round_counts(ids)
	for id in ids: assert_int(counts[id]).is_equal(rear.military._rounds(id))
	counts[ids[0]] = -100
	assert_int(rear.military.personal_round_counts(ids)[ids[0]]).is_equal(60)
	for shot in 7: assert_bool(rear.ledger.fire_loaded_round(ids[0]+"-rifle").ok).is_true()
	counts = rear.military.personal_round_counts(ids)
	for id in ids: assert_int(counts[id]).is_equal(rear.military._rounds(id))
	assert_int(counts[ids[0]]).is_equal(53)
	var empty: Array[String] = []
	assert_that(rear.military.personal_round_counts(empty)).is_equal({})
	assert_array(base.audit()).is_empty()

func test_04_mounted_rack_and_idle_reload_reads_stay_local() -> void:
	var base := _fixture()
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var combat: RefCounted = rear.vehicle_combat
	assert_bool(ledger.add_stock("rack-a","E02",12,0.02,"cohesion-carrier",rear.PLAYER).ok).is_true()
	assert_bool(ledger.add_stock("rack-b","E02",7,0.02,"cohesion-carrier",rear.PLAYER).ok).is_true()
	assert_bool(ledger.request_stock("rack-claim","rack-a",12,"cohesion-carrier","Actual reserved rounds",rear.PLAYER).ok).is_true()
	var expected := 0
	var source := ""
	for item in ledger.snapshot().entities:
		if item.kind == "STOCK" and item.holder_id == "cohesion-carrier" and item.design_type == "E02":
			expected += int(item.available)
			if source.is_empty() and item.available > 0: source = item.id
	var before := Counter.totals()
	assert_int(combat._available_rack("cohesion-carrier","E02")).is_equal(expected)
	assert_str(combat._rack_source("cohesion-carrier","E02")).is_equal(source)
	assert_int(int(Counter.totals().get("identity/identity_ledger.gd::snapshot",0))-int(before.get("identity/identity_ledger.gd::snapshot",0))).is_equal(0)
	assert_bool(ledger.release_claim("rack-claim").ok).is_true()
	assert_int(combat._available_rack("cohesion-carrier","E02")).is_equal(19)
	assert_str(combat._rack_source("cohesion-carrier","E02")).is_equal("rack-a")
	# Synthetic idle/future mount commitments isolate the unused-export branch;
	# real crew/reload/damage behavior is covered by the retained G23 suite.
	var mount: Dictionary = combat._mount("cohesion-carrier")
	before = Counter.totals()
	combat.advance_to(1.0)
	mount.reload_due.MG = 10.0
	combat.advance_to(9.0)
	assert_int(int(Counter.totals().get("identity/identity_ledger.gd::inspect_entity",0))-int(before.get("identity/identity_ledger.gd::inspect_entity",0))).is_equal(0)
	assert_float(mount.reload_due.MG).is_equal(10.0)
	assert_array(base.audit()).is_empty()

func _fixture() -> RefCounted:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	assert_bool(rear.ledger.add_place("cohesion-place","Actual test formation",Vector2(1500,91)).ok).is_true()
	assert_bool(rear.ledger.add_carrier("cohesion-carrier","cohesion-place",rear.PLAYER,rear.PLAYER).ok).is_true()
	var people: Array[String] = []
	for number in 8:
		var id := "cohesion-person-%d" % number
		assert_bool(rear.ledger.add_person(id,"cohesion-place",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok).is_true()
		assert_bool(rear.ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok).is_true()
		assert_bool(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok).is_true()
		people.append(id)
	assert_bool(rear.military.add_initial_squad("cohesion-squad","Rifle",people,"cohesion-company","cohesion-platoon",rear.PLAYER).ok).is_true()
	return base

func _legacy(rear: RefCounted, squad_id: String) -> Dictionary:
	# Preserve the pre-fix algorithm as an independent oracle; no new query calls.
	var row: Dictionary = rear.military.squads.get(squad_id,{})
	if row.is_empty() or row.state != "Active": return {"cohesion":0.0,"state":"Unavailable","blocked_reason":"No active actual squad."}
	var active := _legacy_members(rear,row,true)
	var dismounted: Array[String] = []
	var people := {}
	var boarded := 0
	for id in active:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		people[id] = person
		if rear.ledger.entity_kind(person.holder_id) == "CARRIER": boarded += 1
		else: dismounted.append(id)
	if boarded == active.size() and boarded > 0: return {"cohesion":1.0,"state":"Boarded","blocked_reason":"Dismount before infantry fire."}
	if dismounted.is_empty(): return {"cohesion":0.0,"state":"No active infantry","blocked_reason":"No active dismounted people."}
	var leader: Dictionary = people[row.leader] if people.has(row.leader) else rear.ledger.inspect_person_status(row.leader)
	var near := 0
	for id in dismounted:
		if not leader.is_empty() and leader.assignment == "Formation Duty" and leader.position.distance_to(people[id].position) <= 30.0: near += 1
	var value := float(near)/float(dismounted.size())
	var state := "Coherent"
	var reason := ""
	if value < 0.5:
		state = "Dispersed" if rear.combat.dispersed_since.has(squad_id) and rear.time-float(rear.combat.dispersed_since[squad_id]) >= 10.0 else "Regrouping"
		reason = "Offensive coordination paused; regroup around actual leader."
	return {"cohesion":value,"state":state,"blocked_reason":reason,"regroup_seconds":maxf(0.0,rear.time-float(rear.combat.dispersed_since[squad_id])) if rear.combat.dispersed_since.has(squad_id) else 0.0}

func _legacy_members(rear: RefCounted, row: Dictionary, include_boarded: bool) -> Array[String]:
	var active: Array[String] = []
	for id in row.roster:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if person.is_empty() or person.health <= 0 or person.assignment != "Formation Duty" or person.duty_id != row.id or not person.crew_station.is_empty(): continue
		var holder: String = rear.ledger.entity_kind(person.holder_id)
		if holder.is_empty() or (holder == "CARRIER" and (not include_boarded or person.holder_id != row.vehicle)): continue
		active.append(id)
	return active
