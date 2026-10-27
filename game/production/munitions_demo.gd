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


var _recipe_dialog: ConfirmationDialog
var _confirmation_token := -1


func _add_recipe_controls(parent: Node) -> void:
	_recipe_dialog = ConfirmationDialog.new()
	_recipe_dialog.min_size = Vector2i(640, 240)
	_recipe_dialog.title = "Change F05 recipe?"
	_recipe_dialog.ok_button_text = "Confirm change"
	_recipe_dialog.cancel_button_text = "Keep current recipe"
	_recipe_dialog.dialog_autowrap = true
	_recipe_dialog.confirmed.connect(func() -> void:
		var result: Dictionary = production.confirm_recipe(_confirmation_token)
		_feedback.text = result.message
		_refresh())
	_recipe_dialog.canceled.connect(func() -> void:
		var result: Dictionary = production.decline_recipe(_confirmation_token)
		_feedback.text = result.message
		_refresh())
	add_child(_recipe_dialog)
	for recipe in Munitions.CHOICES:
		_button(parent, "Select " + recipe, func() -> Dictionary:
			var result: Dictionary = production.request_recipe(recipe)
			if result.get("confirmation_required", false):
				_confirmation_token = result.token
				_recipe_dialog.dialog_text = result.message
				_recipe_dialog.popup_centered(Vector2i(640, 240))
				return {"ok": true, "message": "Recipe change awaiting explicit confirmation; no change applied."}
			return result)
