extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Map = preload("res://game/battlefield/farmland_scenario.gd")
const View = preload("res://game/battlefield/battlefield_view.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var base := Base.new(false,false,false,Map.BLUE_HQ)
	Map.apply(base.rear.combat.world)
	Map.initialize_defences(base.rear)
	for objective in Map.OBJECTIVES:
		base.rear.ledger.add_place(objective.id,objective.kind,objective.position)
		base.rear.objectives.register(objective.id,objective.kind)
	base.rear.ledger.add_place("enemy-hq","Enemy HQ",Map.RED_HQ)
	base.rear.orders.register_enemy_hq("enemy-hq")
	var view := View.instantiate()
	view.simulation = base
	root.add_child(view)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.artifacts")
	root.get_texture().get_image().save_png("res://.artifacts/farmland-overview.png")
	view.zoom = 5.0
	view.pan = Vector2(0,0)
	view.selected_id = "observation-central"
	view._refresh()
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/farmland-centre.png")
	print("Farmland render probe: overview and centre captured")
	quit()
