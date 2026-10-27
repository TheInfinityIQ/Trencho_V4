extends "res://game/production/production_demo.gd"
## Independent declared R02 review; it never refills or resets a live facility.

const Munitions = preload("res://game/production/r02_production.gd")


func _make_production() -> void:
	simulation = Rear.new("Empty")
	for index in 4: simulation.add_person("worker-%02d" % (index + 1))
	simulation.ledger.add_stock("fixture-metal", "M01", 1, 1, "depot", simulation.PLAYER)
	simulation.ledger.add_stock("fixture-powder", "M03", 1, 1, "depot", simulation.PLAYER)
	simulation.request_haul("depot", "munitions_input", "M01", 1)
	simulation.request_haul("depot", "munitions_input", "M03", 1)
	production = Munitions.new(simulation)
	simulation.munitions_production = production


func _initial_stock_note() -> String:
	return "Declared R02 setup: 1 M01 + 1 M03 at depot, four ordinary people. Assign operators and real hauling; no refills."
