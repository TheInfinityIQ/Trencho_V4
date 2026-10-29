extends "res://game/production/fixed_production.gd"
## Existing confirmed-selection lifecycle shared by the three explicit facility owners.
var _choices: Array[String] = []
var _essential: Array[String] = []
var _declared_access: Array[String] = []
var _saved: Dictionary = {}
var _pending: Dictionary = {}
var _request_sequence := 0

func _init(rear: RefCounted, initial: String, choices: Array[String], essential: Array[String], declared: Array[String], instance_spec: Dictionary = {}) -> void:
	_choices.assign(choices)
	_essential.assign(essential)
	for recipe in declared:
		assert(recipe in choices, "Declared access must belong to this facility.")
	_declared_access.assign(declared)
	super(rear, initial, instance_spec)


func recipe_accessible(recipe: String) -> bool:
	return recipe in _choices and (recipe in _essential or recipe in _declared_access)


func _access() -> bool:
	return recipe_accessible(_recipe) and super._access()



func _record() -> Dictionary:
	return {"mode": mode, "stock_target": stock_target, "enabled": enabled, "paused": paused,
		"history": history.duplicate(true), "sequence": _sequence}


func _default_record() -> Dictionary:
	return {"mode": "Continuous", "stock_target": 0, "enabled": true, "paused": false, "history": [], "sequence": 0}


func request_recipe(recipe: String) -> Dictionary:
	if recipe not in _choices:
		return {"ok": false, "message": _spec.facility + " cannot select this recipe."}
	if not recipe_accessible(recipe):
		return {"ok": false, "message": recipe + " access absent in this declared fixture; no selection or goods changed. G31 cards remain separate."}
	if recipe == _recipe:
		return {"ok": true, "message": recipe + " is already selected; nothing changed."}
	if batch.is_empty():
		_pending = {}
		return _select(recipe)
	var totals: Dictionary = {}
	for portion in batch.receipt: totals[portion.type] = int(totals.get(portion.type, 0)) + portion.count
	var consumed: Array[String] = []
	for type in totals: consumed.append("%d %s" % [totals[type], type])
	_request_sequence += 1
	_pending = {"token": _request_sequence, "from": _recipe, "to": recipe, "batch_id": batch.id}
	return {"ok": true, "confirmation_required": true, "token": _request_sequence,
		"message": "Change %s to %s? Cancel consumed batch %s.\nConsumed %s are permanently lost, with no refund.\nOnly its unused output promise is released; finished goods remain.\nDeclining keeps the recipe, work, receipt and promise." % [_recipe, recipe, batch.id, ", ".join(consumed)]}


func decline_recipe(token: int) -> Dictionary:
	if _pending.get("token", -1) != token:
		return {"ok": false, "message": "This recipe-change request is no longer pending; nothing changed."}
	_pending = {}
	return {"ok": true, "message": "Recipe change declined; recipe, batch, consumed receipt, work and promise are unchanged."}


func confirm_recipe(token: int) -> Dictionary:
	if _pending.get("token", -1) != token:
		return {"ok": false, "message": "This recipe-change request is no longer pending; nothing changed."}
	var request := _pending.duplicate()
	_pending = {} # Consume the confirmation once, including stale requests.
	if request.from != _recipe or request.batch_id != batch.get("id", ""):
		return {"ok": false, "message": "The selected recipe or consumed batch changed. Request a fresh confirmation; nothing was cancelled."}
	return _select(request.to)


func _select(recipe: String) -> Dictionary:
	# Exactly one lifecycle/batch is attached to the rear clock. Inactive records
	# retain choices/history but own no consumed batch or output promise.
	var was_enabled := enabled
	if not batch.is_empty(): cancel()
	_saved[_recipe] = _record()
	_saved[_recipe].enabled = was_enabled
	var restored: Dictionary = _saved.get(recipe, _default_record()).duplicate(true)
	_recipe = recipe
	_spec = RECIPES[recipe].duplicate(true)
	_spec.merge(_instance_spec,true)
	mode = restored.mode
	stock_target = restored.stock_target
	enabled = restored.enabled
	paused = restored.paused
	history.assign(restored.history)
	_sequence = restored.sequence
	var rear: RefCounted = _rear_ref.get_ref()
	rear._settle()
	return {"ok": true, "message": _spec.facility + " selected " + recipe + "; only this recipe may work. Finished stock remains; actual local inputs, labour, access and space still govern starting."}


func snapshot() -> Dictionary:
	var view := super.snapshot()
	view.declared_recipe_access = _declared_access.duplicate()
	view.selected_recipe = _recipe
	view.recipe_choices = _choices.duplicate()
	view.pending_recipe_change = _pending.duplicate(true)
	var records: Dictionary = {}
	for recipe in _choices:
		records[recipe] = (_record() if recipe == _recipe else _saved.get(recipe, _default_record())).duplicate(true)
		records[recipe].active = recipe == _recipe
	view.recipe_records = records
	return view
