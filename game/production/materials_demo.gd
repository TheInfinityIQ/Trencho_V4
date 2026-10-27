extends "res://game/production/production_demo.gd"
## Separate declared working F13 and depot stock, not building construction.

const Materials = preload("res://game/production/r26_production.gd")


func _make_production() -> void:
	simulation = Rear.new("Empty")
	for index in 9: simulation.add_person("worker-%02d" % (index + 1))
	simulation.ledger.add_stock("fixture-metal", "M01", 30, 1, "depot", simulation.PLAYER)
	simulation.ledger.add_stock("fixture-timber", "M04", 70, 1, "depot", simulation.PLAYER)
	simulation.request_haul("depot", "materials_input", "M01", 30)
	simulation.request_haul("depot", "materials_input", "M04", 70)
	production = Materials.new(simulation)
	simulation.materials_production = production


func _initial_stock_note() -> String:
	return "Declared working F13; nine ordinary people, depot30 M01 +70 M04. Assign operators/hauling; no construction or refills."
