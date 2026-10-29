extends SceneTree
func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var scene: PackedScene = load("res://game/rear_base/base_demo.tscn")
	var demo: Control = scene.instantiate()
	root.add_child(demo)
	await process_frame
	if demo.tabs.get_tab_count() != 9 or demo.construction_rows == null:
		push_error("Construction panel absent")
		quit(1)
		return
	demo.construction_x.value = 140
	demo.construction_y.value = 10
	var result: Dictionary = demo.simulation.rear.construction.preview("depot",Vector2(140,10))
	if not result.ok:
		push_error("Construction preview failed: "+str(result))
		quit(1)
		return
	demo._refresh()
	print("G05 construction UI smoke: ready, preview, refresh")
	quit(0)
