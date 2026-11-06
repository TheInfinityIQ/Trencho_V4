extends SceneTree
## Brief current-change demonstration only. No gameplay time, fixture grants or full-chain claim.
const GameScene = preload("res://game/main/main.tscn")
const Base = preload("res://game/rear_base/base_demo.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = GameScene.instantiate()
	root.add_child(game)
	game._session.set_physics_process(false)
	game._session.set_speed(0)
	var base: Control = game._base
	base.show_panel("Supplies")
	base._supply_views.current_tab = 2
	await process_frame
	base.army_request_count.value = 100
	base.army_request_button.pressed.emit()
	var first: String = game._session.automatic_logistics.requests.keys()[-1]
	base.army_request_count.value = 37
	base.army_request_button.pressed.emit()
	var second: String = game._session.automatic_logistics.requests.keys()[-1]
	var selected: String = base._army_request_ids[base.army_request_rows.get_selected_items()[0]]
	if first == second or selected != second or not base.army_request_status.text.contains("0 / 37 physically unloaded at HQ"):
		push_error("New normal request click must select and render its own paused receipt.")
		quit(1)
		return
	print("TRUCK_FEEDBACK_REQUEST " + JSON.stringify({"first":first,"new":second,"selected":selected,"receipt":base.army_request_status.text,"simulation_seconds":base.simulation.rear.time}))
	var row := {"state":"In F10","hull":{"design_type":"T01","fuel":0.0,"vehicle_spec":{"tank_capacity":100.0}},"readiness":{"driver":true},"fuel_claims":[{"units":25,"claim":"supplied-reservation","source":"supplied-stock"}]}
	var reserved: String = Base._transport_truck_status(row,{})
	row.fuel_claims = [{"units":25,"claim":"","carried":"supplied-carried-stock"}]
	var carried: String = Base._transport_truck_status(row,{"state":"Loading","handling":"Cargo pickup","blocker":"Supplied loading blocker"})
	if not reserved.contains("Fuel reserved: 25") or not carried.contains("Fuel carried: 25") or not carried.contains("tank handoff pending") or not carried.contains("Cargo pickup") or not carried.contains("Supplied loading blocker") or not carried.contains("Fuel 0.0 / 100"):
		push_error("Supplied-fact presentation must distinguish tank, reservation, carry and actual shipment handling/blocker.")
		quit(1)
		return
	print("TRUCK_FEEDBACK_SUPPLIED_FACTS " + JSON.stringify({"reserved":reserved,"carried":carried}))
	print("TRUCK_FEEDBACK_PASS: actual paused request selection and pure supplied-fact text only; no physical deliveries, fuel carry, extraction, native input or FPS acceptance.")
	game.queue_free()
	await process_frame
	quit(0)
