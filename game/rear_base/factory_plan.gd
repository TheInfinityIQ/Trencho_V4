extends RefCounted
## Read the real factory owners without retaining or changing their state.
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Selectable = preload("res://game/production/selectable_production.gd")
const NAMES := {"materials":"Materials Plant", "munitions":"Munitions workshop", "M01":"Metal", "M04":"Timber", "M03":"Gunpowder"}

static func view(simulation: RefCounted) -> Dictionary:
	CallLog.record(&"rear_base/factory_plan.gd::view")
	var rear: RefCounted = simulation.rear
	var workers := {"present": simulation.receiving.rear_population(), "incoming": simulation.receiving.incoming_people()}
	var facilities := {"materials": {}, "munitions": {}}
	for id in rear.construction.instances:
		var row: Dictionary = rear.construction.instances[id]
		if row.kind not in facilities or row.state in ["Cancelled", "Destroyed", "Dismantled"]: continue
		var old: Dictionary = facilities[row.kind]
		if old.is_empty() or (row.state == "Complete" and old.state != "Complete"):
			facilities[row.kind] = {"id": str(id), "state": str(row.state), "blocker": str(row.get("blocker", ""))}
	for kind in facilities:
		var site: Dictionary = facilities[kind]
		if site.is_empty(): continue
		var activity: RefCounted = rear.construction.activities.get(site.id)
		if activity == null: continue
		site.operators = activity.operators().size()
		site.requested_operators = int(rear.requests.get(site.id,{}).get("target",0))
		site.missing_inputs = activity._missing()
		site.target = activity.stock_target
		site.target_covered = activity._target_satisfied()
		site.stored_output = rear.ledger.physical_quantity_at(activity._spec.output_store, "M11" if kind == "materials" else "E02", ["STOCK"],rear.PLAYER)
	var done := {"R26": false, "R02": false}
	for activity in rear._production_activities():
		if not (activity is Fixed): continue
		if activity._recipe in done and not done[activity._recipe]: done[activity._recipe] = _has_completed(activity.history,activity._recipe)
		if not done.R02 and activity is Selectable and activity._recipe != "R02":
			done.R02 = _has_completed(activity._saved.get("R02", {}).get("history", []),"R02")
		if done.R26 and done.R02: break
	var steps: Array = []
	steps.append({"id":"workers", "title":"Workers have arrived", "status":"complete" if workers.present > 0 else ("active" if workers.incoming > 0 else "todo")})
	for kind in ["materials", "munitions"]:
		var site: Dictionary = facilities[kind]
		steps.append({"id":kind, "title":"Build the " + NAMES[kind], "status":"todo" if site.is_empty() else ("complete" if site.state == "Complete" else "active")})
	for entry in [["materials_output", "R26", "materials"], ["ammunition_output", "R02", "munitions"]]:
		var site: Dictionary = facilities[entry[2]]
		var activity: RefCounted = rear.construction.activities.get(site.get("id", ""))
		var running: bool = activity != null and not activity.batch.is_empty() and activity.batch.get("recipe", "") == entry[1]
		var state := "complete" if done[entry[1]] else ("active" if running else "todo")
		steps.append({"id":entry[0], "title":"Manufacture Building Materials" if entry[1] == "R26" else "Manufacture rifle ammunition", "status":state})
	var action := {"panel":"", "building_kind":"", "facility_id":"", "label":"", "reason":""}
	if workers.present == 0:
		action = {"panel":"Workers/Jobs", "building_kind":"", "facility_id":"", "label":"View worker arrival" if workers.incoming > 0 else "Hire workers", "reason":"%d purchased people are still arriving; they can work after disembarking and reaching the rear." % workers.incoming if workers.incoming > 0 else "Hire workers through the existing purchase controls, then start 1x for their physical arrival."}
	else:
		for kind in ["materials", "munitions"]:
			var site: Dictionary = facilities[kind]
			if site.is_empty():
				action = {"panel":"Build", "building_kind":kind, "facility_id":"", "label":"Build " + NAMES[kind], "reason":"Place a site and request builders. Actual Building Materials must reach the site."}
				break
			if site.state != "Complete":
				action = {"panel":"Build", "building_kind":kind, "facility_id":site.id, "label":"Inspect construction", "reason":NAMES[kind] + ": check builders and construction materials. " + site.blocker}
				break
		if action.label.is_empty():
			for entry in [["materials", "R26"], ["munitions", "R02"]]:
				if done[entry[1]]: continue
				var site: Dictionary = facilities[entry[0]]
				var activity: RefCounted = rear.construction.activities.get(site.id)
				action = _production_action(simulation,site,activity,entry[0],entry[1])
				break
	var complete: bool = done.R26 and done.R02
	if complete: action = {"panel":"Work", "building_kind":"", "facility_id":"", "label":"Factory task complete", "reason":"You manufactured Building Materials and rifle ammunition this session. Consuming or shipping that output does not undo its completed batch history."}
	elif simulation.speed == 0: action.reason += " Game time is paused; use 1x when ready."
	return {"workers":workers, "facilities":facilities, "steps":steps, "next_action":action, "complete":complete}

static func _has_completed(history: Array, recipe: String) -> bool:
	# The newest completed matching batch is enough; do not rescan an entire
	# long-running production history after success has already been established.
	for index in range(history.size()-1,-1,-1):
		var batch: Dictionary = history[index]
		if batch.get("state","") == "Completed" and batch.get("recipe","") == recipe: return true
	return false

static func _production_action(simulation: RefCounted, site: Dictionary, activity: RefCounted, kind: String, recipe: String) -> Dictionary:
	var result := {"panel":"Work", "building_kind":kind, "facility_id":site.id, "focus":"target", "label":"Set a production target", "reason":"Choose the required recipe, request operators and apply an output target in this facility's existing controls."}
	if activity == null: return result
	if activity._recipe != recipe:
		result.label = "Choose rifle-ammunition recipe" if recipe == "R02" else "Choose Building Materials recipe"
		result.focus = "recipe"
		result.reason = "Choose %s. Changing a batch already in progress still asks for confirmation." % ("rifle ammunition" if recipe == "R02" else "Building Materials")
	elif not activity.enabled:
		result.label = "Review stopped production"
		result.focus = "enable"
		result.reason = "This facility is stopped. Use Enable facility to allow production when its requirements are met."
	elif activity.paused:
		result.label = "Review paused production"
		result.focus = "pause"
		result.reason = "This facility is paused. Use Pause / resume facility to resume it; workers, inputs and output space are still required."
	elif activity.mode == "Stock target" and activity.stock_target <= 0:
		result.reason = "Apply a minimum output-stock target to request this facility's first batch. Starting or committed stock already counts toward that minimum."
	elif activity.batch.is_empty() and site.target_covered:
		result.label = "Raise production target"
		result.reason = "The requested minimum of %d is already covered by existing rear stock or committed output. Raise the minimum to request newly manufactured goods." % site.target
	elif site.requested_operators == 0:
		result.label = "Assign operators"
		result.focus = "staff"
		result.reason = "Request workers for this exact facility. Workers must physically report before they can produce."
	elif site.operators == 0:
		result.label = "Inspect operator assignments"
		result.focus = "staff"
		result.reason = "Workers are requested but none are presently eligible at the facility. Check reporting and other commitments."
	elif not activity._access():
		result.label = "Inspect facility access"
		result.reason = "The selected facility's input or output store is inaccessible. Work cannot advance while access is blocked."
	elif not activity.batch.is_empty():
		result.label = "Inspect production"
		result.reason = "A real batch is active. The production controls show earned work and any current completion blocker."
	elif not site.missing_inputs.is_empty():
		var names: Array[String] = []
		for type in site.missing_inputs: names.append("%d %s" % [int(site.missing_inputs[type]),NAMES.get(type,type)])
		result.label = "Review missing inputs"
		result.reason = "Missing locally: %s. Check purchased deliveries and hauling; incoming or reserved goods are not local ingredients yet." % ", ".join(names)
		if simulation.rear.requests.hauling.target == 0:
			result.label = "Manage hauling workers"
			result.panel = "Workers/Jobs"
			result.reason += " No hauling workers are requested."
	return result
