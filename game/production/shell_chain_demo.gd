extends "res://game/production/munitions_demo.gd"
## Controlled-access manufacturing fixture. No live cards or granted ammunition.

@export_enum("R32", "R33") var shell_recipe := "R32"


func _make_production() -> void:
	simulation = Rear.new("Empty")
	for index in 5: simulation.add_person("worker-%02d" % (index + 1))
	var metal := 140 if shell_recipe == "R32" else 70
	simulation.ledger.add_stock("fixture-metal", "M01", metal, 1, "depot", simulation.PLAYER)
	simulation.ledger.add_stock("fixture-powder", "M03", 200, 1, "depot", simulation.PLAYER)
	simulation.request_haul("depot", "munitions_input", "M01", metal)
	simulation.request_haul("depot", "munitions_input", "M03", 200)
	production = Munitions.new(simulation, [shell_recipe])
	simulation.munitions_production = production


func _initial_stock_note() -> String:
	return "Declared %s access, no cards. Five ordinary people; depot %d M01 + 200 M03; no M06/ammo. Manufacture and haul explosives." % [shell_recipe, 140 if shell_recipe == "R32" else 70]


func _add_recipe_controls(parent: Node) -> void:
	super(parent)
	_button(parent, "M06 to input", func() -> Dictionary: return simulation.request_haul("munitions_output", "munitions_input", "M06", 20))
