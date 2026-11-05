extends SceneTree
## Explicit opt-in capture. Never overwrite an existing behavioral baseline.
const Scenarios = preload("res://game/diagnostics/tests/gdunit/fixtures/read_path_scenarios.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")

func _initialize() -> void:
	var destination := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): destination = argument.trim_prefix("--out=")
	if destination.is_empty() or FileAccess.file_exists(destination):
		push_error("Provide --out=<new path>; existing baselines are never overwritten.")
		quit(2)
		return
	Counter.enabled = true
	Counter.capture_stacks = false
	var report := Scenarios.run()
	report.engine = Engine.get_version_info()
	report.source_sha256 = {}
	for path in ["game/identity/identity_ledger.gd", "game/military/organization.gd", "game/hq/hq_logistics.gd"]:
		report.source_sha256[path] = FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").sha256_text()
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create baseline file: " + destination)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	print("Read-path baseline captured: ", destination)
	print(JSON.stringify(report.measurements))
	quit(0)
