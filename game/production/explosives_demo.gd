extends "res://game/production/munitions_demo.gd"
## Declared F05 review: enough real inputs to cancel R02 then manufacture M06.


func _make_production() -> void:
	simulation = Rear.new("Empty")
	for index in 5: simulation.add_person("worker-%02d" % (index + 1))
	simulation.ledger.add_stock("fixture-metal", "M01", 4, 1, "depot", simulation.PLAYER)
	simulation.ledger.add_stock("fixture-powder", "M03", 12, 1, "depot", simulation.PLAYER)
	simulation.request_haul("depot", "munitions_input", "M01", 4)
	simulation.request_haul("depot", "munitions_input", "M03", 12)
	production = Munitions.new(simulation) # R02 remains the actual default.
	simulation.munitions_production = production


func _initial_stock_note() -> String:
	return "Declared F05 switch review: five ordinary people, 4 M01 + 12 M03 at depot; R02 selected. Assign real hauling; no refills."
