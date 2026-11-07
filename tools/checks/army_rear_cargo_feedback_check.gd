extends SceneTree
## Disconnected dispatch component with explicit fixture inputs; not ordinary production or an Army shortage.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Reader = preload("res://game/logistics/army_supply_view.gd")
var observations: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _observe(rear: RefCounted, row: Dictionary, label: String) -> void:
	var holders: Array = rear.stores.keys()
	holders.append("hq-stock")
	var counts: Dictionary = rear.ledger.available_stock_counts(holders,"E02",rear.PLAYER)
	var stock := {"rear":0,"hq":int(counts.get("hq-stock",0)),"forward":0}
	for id in rear.stores:
		if id != "hq-stock" and rear.stores[id].accessible: stock.rear += int(counts.get(id,0))
	var reserved := 0
	var onboard := 0
	for item in row.stock_items:
		reserved += int(rear.ledger.inspect_claim(item.claim).get("reserved",0)) if not str(item.claim).is_empty() else 0
		if rear.ledger.inspect_entity(item.id,{},false).get("holder_id","") == row.hull: onboard += int(item.quantity)
	var feedback: Dictionary = Reader._supply_feedback(20,20,stock,0,false,true)
	observations.append({"label":label,"requested":int(row.cargo.E02),"stock":stock,"reserved":reserved,"onboard":onboard,"departed":bool(row.departed),"manifest_state":str(row.state),"feedback":feedback})

func _run() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	# Existing dispatch-regression fixture pattern, with explicitly supplied inputs.
	var heavy: RefCounted = rear.heavy_production
	if not _require(heavy.request_recipe("R28").ok,"Select the component's actual transport recipe."): return
	heavy.set_mode("Continuous")
	if not _require(heavy.accept_order().ok,"Admit the same hull's real output-bay claim."): return
	for type in Fixed.RECIPES.R28.inputs:
		if not _require(rear.ledger.add_stock("review-input-"+str(type),type,Fixed.RECIPES.R28.inputs[type],1.0,"vehicle_input",rear.PLAYER).ok,"Explicitly arrange component recipe inputs."): return
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var hull: String = heavy.bay_occupant
	if not _require(not hull.is_empty(),"Actual manufactured component hull must occupy the output bay."): return
	rear.add_person("review-driver",true,"P08")
	if not _require(rear.vehicles.assign_station(hull,"review-driver","Driver").ok,"Seat the actual qualified Driver on the same hull."): return
	rear.advance_time(160)
	if not _require(rear.ledger.add_stock("review-fuel","M08",12,1.0,"depot",rear.PLAYER).ok,"Explicitly arrange component fuel."): return
	if not _require(rear.vehicles.request_refuel(hull,"base-person-11",12).ok,"Use the real local refuel handling owner."): return
	rear.advance_time(200)
	if not _require(rear.vehicles.start_drive(hull).ok,"Drive the same hull through its real parking route."): return
	rear.advance_time(100)
	if not _require(rear.vehicles.vehicles[hull].state == "Parked","The real hull must reach parking before dispatch."): return
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	var request_only: Dictionary = rear.dispatch.accept(hull,"Strategic Delivery",[],{"E02":20})
	if not _require(request_only.ok,"A requested manifest may exist before ammunition is available."): return
	var first: Dictionary = rear.dispatch.manifests[request_only.id]
	if not _require(first.stock_items.is_empty(),"Requested amount alone must not create or prove physical ammunition."): return
	_observe(rear,first,"Request only, no physical ammunition")
	# Keep the separately recorded approach-cancellation defect outside this feedback fixture.
	rear.advance_time(60)
	if not _require(first.state == "Staging","The same hull must finish its actual approach before this cancellation case."): return
	if not _require(rear.dispatch.cancel(request_only.id).ok,"Predeparture cancellation must release the existing request."): return
	rear.advance_time(200)
	if not _require(first.state == "Cancelled" and rear.vehicles.vehicles[hull].state == "Parked","Existing cancellation must finish the same hull's physical return."): return
	if not _require(rear.ledger.add_stock("review-rounds","E02",20,0.02,"dispatch",rear.PLAYER).ok,"Explicitly arrange just20 real component rounds."): return
	var accepted: Dictionary = rear.dispatch.accept(hull,"Strategic Delivery",[],{"E02":20})
	if not _require(accepted.ok,"Reserve the real component ammunition on the same parked hull."): return
	var row: Dictionary = rear.dispatch.manifests[accepted.id]
	_observe(rear,row,"Actual reservation")
	if not _require(observations[-1].reserved == 20 and observations[-1].stock.rear == 0,"Reserved physical stock must be excluded from available rear stock."): return
	rear.advance_time(600)
	if not _require(row.state == "Loaded Waiting Dispatch","Actual worker handling must load the same hull."): return
	_observe(rear,row,"Physically loaded")
	if not _require(observations[-1].onboard == 20 and observations[-1].stock.hq == 0,"Loaded cargo must exist on the same hull and must not be credited at HQ."): return
	if not _require(rear.dispatch.depart(accepted.id).ok,"Admit the actual loaded, driven, fuelled physical departure."): return
	rear.advance_time(1)
	if not _require(not rear.dispatch.cancel(accepted.id).ok,"Departure cannot be recalled through predeparture cancellation."): return
	_observe(rear,row,"Departed; cancellation rejected")
	if not _require(observations[-1].departed and observations[-1].onboard == 20,"Rejected cancellation must preserve actual departed cargo."): return
	print(JSON.stringify({"component_observations":observations}))
	for observation in observations:
		if not _require(observation.feedback.state == "Review rear deliveries" and "rear-to-HQ cargo is not counted" in observation.feedback.detail and "Review production and labour for that gap" not in observation.feedback.detail,"Incomplete coverage must not assert manufacture for requested, reserved, loaded or departed rear cargo."): return
	if not _require(base.audit().is_empty(),"Real reservation, cancellation, loading and departure must preserve physical invariants."): return
	print(JSON.stringify({"result":"PASS","scope":"Disconnected real dispatch request/reservation/loading/departure and rejected cancellation; conservative pure feedback with explicit omitted rear-cargo coverage. No ordinary production, natural Army need or full delivery chain claim."}))
	quit(0)
