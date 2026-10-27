extends "res://game/production/fixed_production.gd"
## One F05 owner: R02 by default, or R27 after a validated explicit selection.

const INPUTS := RECIPES.R02.inputs # Retain the accepted R02 public defaults.
const REQUIRED_WORK := 40.0
const OUTPUT_MASS := 2.0
const CHOICES: Array[String] = ["R02", "R27"]
var _saved: Dictionary = {}
var _pending: Dictionary = {}
var _request_sequence := 0


func _init(rear: RefCounted) -> void:
	super(rear, "R02")


func _record() -> Dictionary:
	return {"mode": mode, "stock_target": stock_target, "enabled": enabled, "paused": paused,
		"history": history.duplicate(true), "sequence": _sequence}


func _default_record() -> Dictionary:
	return {"mode": "Continuous", "stock_target": 0, "enabled": true, "paused": false, "history": [], "sequence": 0}


func request_recipe(recipe: String) -> Dictionary:
	if recipe not in CHOICES:
		return {"ok": false, "message": "F05 only releases R02 rounds and R27 explosives."}
	if recipe == _recipe:
		return {"ok": true, "message": recipe + " is already selected; nothing changed."}
	if batch.is_empty():
		_pending = {}
		return _select(recipe)
	var consumed: Array[String] = []
	for portion in batch.receipt: consumed.append("%d %s" % [portion.count, portion.type])
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
	_spec = RECIPES[recipe]
	mode = restored.mode
	stock_target = restored.stock_target
	enabled = restored.enabled
	paused = restored.paused
	history.assign(restored.history)
	_sequence = restored.sequence
	var rear: RefCounted = _rear_ref.get_ref()
	rear._settle()
	return {"ok": true, "message": "F05 selected " + recipe + "; only this recipe may work. Finished stock remains; actual local inputs, labour, access and space still govern starting."}


func snapshot() -> Dictionary:
	var view := super.snapshot()
	view.selected_recipe = _recipe
	view.recipe_choices = CHOICES.duplicate()
	view.pending_recipe_change = _pending.duplicate(true)
	var records: Dictionary = {}
	for recipe in CHOICES:
		records[recipe] = (_record() if recipe == _recipe else _saved.get(recipe, _default_record())).duplicate(true)
		records[recipe].active = recipe == _recipe
	view.recipe_records = records
	return view
