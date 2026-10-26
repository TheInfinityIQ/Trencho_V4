extends RefCounted
## Scripted upstream inputs, not procurement, training, hauling AI or combat.

const Ledger = preload("res://game/identity/identity_ledger.gd")
const Records = preload("res://game/identity/identity_records.gd")

var ledger: Ledger


func reset() -> void:
	ledger = Ledger.new()
	# Separate storage and receiving holders share this fixture's handoff point.
	# The far HQ proves ownership alone cannot deliver to a remote location.
	_require(ledger.add_place("rear-store", "Safe rear storage", Vector2.ZERO))
	_require(ledger.add_place("receiving", "Receiving handoff point", Vector2.ZERO))
	_require(ledger.add_place("far-hq", "Distant HQ fixture", Vector2(2000.0, 0.0)))
	_require(ledger.add_carrier("supplier-truck", "receiving", "supplier", "army-blue"))
	_require(ledger.add_person("worker-01", "rear-store", "army-blue"))
	_require(ledger.add_person("person-02", "rear-store", "army-blue"))
	_require(ledger.add_person("person-03", "rear-store", "army-blue"))
	_require(ledger.request_assignment("worker-01", Records.Assignment.REAR_LABOUR, "haul-fixture"))
	_require(ledger.add_stock("steel-01", "M01 Steel", 5, 1.0, "rear-store", "army-blue"))
	_require(ledger.add_stock("rifles-01", "E01 Rifle", 10, 4.0, "rear-store", "army-blue"))
	_require(ledger.add_stock("rounds-01", "E02 Round", 60, 0.02, "person-02", "army-blue"))
	_require(ledger.add_weapon("rifle-11", "E01 Rifle", 4.0, "person-02", "army-blue", "E02 Round", 10))
	# The real weapon starts empty; 10 of the 60 existing rounds are loaded.
	_require(ledger.load_rounds("rifle-11", "rounds-01", 10))


func request_rifles(claim_id: String) -> Dictionary:
	return ledger.request_stock(claim_id, "rifles-01", 10, "Manifest " + claim_id,
		"Deployment rifle demand (fixture)", "army-blue")


func load_ten() -> Dictionary:
	var weapon := ledger.inspect_entity("rifle-11")
	for entity in ledger.snapshot().entities:
		if entity.kind == "STOCK" and entity.design_type == "E02 Round" and entity.holder_id == weapon.holder_id and entity.available >= 10:
			return ledger.load_rounds("rifle-11", entity.id, 10)
	return {"ok": false, "code": "NO_LOCAL_ROUNDS", "entity_id": "",
		"message": "This weapon's current holder has fewer than 10 unreserved loose rounds. Unload or physically deliver rounds first."}


func handoff_weapon() -> Dictionary:
	var holder: String = ledger.inspect_entity("rifle-11").holder_id
	var destination := "person-03" if holder == "person-02" else "person-02"
	return ledger.transfer_weapon("rifle-11", destination)


func loose_rounds_at(holder_id: String) -> int:
	var quantity: int = 0
	for entity in ledger.snapshot().entities:
		if entity.kind == "STOCK" and entity.design_type == "E02 Round" and entity.holder_id == holder_id:
			quantity += entity.quantity
	return quantity


func _require(result: Dictionary) -> void:
	if not result.ok:
		push_error("Fixture setup failed: " + result.message)
