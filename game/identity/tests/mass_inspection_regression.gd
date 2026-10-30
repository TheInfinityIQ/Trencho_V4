extends SceneTree
const Fixture = preload("res://game/identity/identity_fixture.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	var fixture := Fixture.new()
	fixture.reset()
	var ledger: RefCounted = fixture.ledger
	check(ledger.entity_kind("missing") == "","Unknown kind query remains empty")
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
	check(ledger.audit().is_empty(),"Mass inspections preserve all ledger invariants")
	print("Mass inspection regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func compare(ledger: RefCounted) -> void:
	for row in ledger.snapshot().entities:
		check(ledger.entity_kind(row.id) == row.kind,"Kind-only query equals the authoritative inspection kind")
		var expected: float = legacy(ledger,row.id)
		check(float(row.contents_mass_kg) == expected,"Snapshot keeps legacy exact subtree arithmetic for "+row.id)
		check(float(ledger.inspect_entity(row.id).contents_mass_kg) == expected,"Raw inspection keeps legacy exact subtree arithmetic for "+row.id)
func legacy(ledger: RefCounted, holder: String) -> float:
	var total := 0.0
	for entity in ledger._entities.values():
		if entity.holder_id == holder: total += entity.unit_mass_kg*entity.quantity+legacy(ledger,entity.id)
	return total
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
