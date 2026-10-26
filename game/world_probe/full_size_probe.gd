extends SceneTree
## D01 calibration data/query probe, adapted from the earlier ignored allocation
## probe. It creates no world nodes, renderer, navigation, save format or game.

const WIDTH: int = 4000
const HEIGHT: int = 6000
const CELLS: int = WIDTH * HEIGHT
const PATCH_EDGE: int = 64
const PATCH_CELLS: int = PATCH_EDGE * PATCH_EDGE
const QUERIES: int = 200000
const MODULUS: int = 2147483647
var _terrain := PackedByteArray()
var _heights := PackedFloat32Array()
var _flags := PackedByteArray()
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output := "res://.artifacts/d01/probe.json"
	for arg in args:
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var results := {"schema": 1, "scope": "D01 synthetic data/query only; no generated map, rendering, navigation, forces, saves or gameplay", "engine": Engine.get_version_info().string, "os": OS.get_name(), "cpu": OS.get_processor_name(), "baseline_only": "--baseline" in args, "engine_static_before_bytes": OS.get_static_memory_usage()}
	if not results.baseline_only: results.merge(_measure())
	results.checks = _checks
	results.failures = _failures
	results.valid = _failures == 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/d01"))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Unable to write D01 probe results")
		quit(1)
		return
	file.store_string(JSON.stringify(results, "\t") + "\n")
	print(JSON.stringify(results))
	quit(0 if results.valid else 1)


func _measure() -> Dictionary:
	var before: int = OS.get_static_memory_usage()
	var start: int = Time.get_ticks_usec()
	_terrain.resize(CELLS)
	_terrain.fill(1)
	_heights.resize(CELLS)
	_heights.fill(0.0)
	_flags.resize(CELLS)
	_flags.fill(0)
	var filled: int = Time.get_ticks_usec()
	# Twelve disjoint authored squares, not a terrain generator. Each carries a
	# distinct TR02..TR13 byte and exact float32 plateau height 2..24 metres.
	for patch in range(1, 13):
		var rectangle := _patch(patch)
		for y in range(rectangle.position.y, rectangle.end.y):
			for x in range(rectangle.position.x, rectangle.end.x):
				var index := y * WIDTH + x
				_terrain[index] = patch + 1
				_heights[index] = float(patch * 2)
				_flags[index] = 1 << (patch % 3)
	var painted: int = Time.get_ticks_usec()
	var after_payload: int = OS.get_static_memory_usage()
	_check(_terrain.size() == CELLS and _heights.size() == CELLS and _flags.size() == CELLS, "All24million entries allocated in each packed field")
	var counts: Array[int] = []
	for code in range(1, 14):
		var expected := CELLS - 12 * PATCH_CELLS if code == 1 else PATCH_CELLS
		var count := _terrain.count(code)
		counts.append(count)
		_check(count == expected, "Whole terrain field has exact class count")
		_check(_heights.count(float((code - 1) * 2)) == expected, "Whole height field contains exact finite plateaux, not length alone")
	_check(_flags.count(0) == CELLS - 12 * PATCH_CELLS, "Unpainted flags remain zero")
	for flag in [1, 2, 4]: _check(_flags.count(flag) == 4 * PATCH_CELLS, "Whole flag field count")
	for point in [Vector2i(0, 0), Vector2i(3999, 0), Vector2i(0, 5999), Vector2i(3999, 5999), Vector2i(0, 1), Vector2i(3999, 5998)]:
		_check(_sample_matches(_index(point.x, point.y)), "World edge and row-stride sample")
	for point in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(4000, 0), Vector2i(0, 6000), Vector2i(4000, 6000)]:
		_check(_read(point.x, point.y).is_empty(), "Out-of-bounds coordinates refuse aliasing or negative-index wrap")
	for patch in range(1, 13):
		var rectangle := _patch(patch)
		for point in [rectangle.position, rectangle.end - Vector2i.ONE, rectangle.position - Vector2i.ONE, rectangle.end]:
			_check(_sample_matches(_index(point.x, point.y)), "Patch inside/outside boundary sample")
	var calibration := _index(50, 100)
	var old_terrain: int = _terrain[calibration]
	_terrain[calibration] = 0
	_check(not _sample_matches(calibration), "Verifier detects a changed terrain byte")
	_terrain[calibration] = old_terrain
	var old_height: float = _heights[calibration]
	_heights[calibration] += 1.0
	_check(not _sample_matches(calibration), "Verifier detects changed actual height")
	_heights[calibration] = old_height
	var old_flag: int = _flags[calibration]
	_flags[calibration] ^= 1
	_check(not _sample_matches(calibration), "Verifier detects changed flag")
	_flags[calibration] = old_flag
	var verified: int = Time.get_ticks_usec()
	var indices := PackedInt32Array()
	indices.resize(QUERIES)
	var seed: int = 0x13579bdf
	var expected_checksum: int = 0
	for query in QUERIES:
		seed = (1664525 * seed + 1013904223) & 0xffffffff
		var index: int = seed % CELLS
		if query % 4 == 0:
			var rectangle := _patch((query / 4) % 12 + 1)
			index = _index(rectangle.position.x + seed % PATCH_EDGE, rectangle.position.y + (seed >> 8) % PATCH_EDGE)
		indices[query] = index
		var expected := _expected(index)
		expected_checksum = _checksum(expected_checksum, index, expected[0], expected[1], expected[2])
	var workload_ready: int = Time.get_ticks_usec()
	var actual_checksum: int = 0
	for index in indices:
		actual_checksum = _checksum(actual_checksum, index, _terrain[index], int(_heights[index]), _flags[index])
	var queried: int = Time.get_ticks_usec()
	_check(actual_checksum == expected_checksum, "Actual indexed queries match independent rectangular calibration oracle")
	return {"width_metres": WIDTH, "height_metres": HEIGHT, "cell_edge_metres": 1, "cells": CELLS, "layout_bytes": {"terrain_u8": CELLS, "height_f32": CELLS * 4, "flags_u8": CELLS}, "raw_payload_bytes": CELLS * 6, "patches": 12, "patch_edge_metres": PATCH_EDGE, "terrain_counts": counts, "queries": QUERIES, "query_mix": "25% explicit patch hits;75% seeded full-extent indices;LCG0x13579bdf", "query_checksum": actual_checksum, "expected_query_checksum": expected_checksum, "allocate_fill_ms": float(filled - start) / 1000.0, "paint_ms": float(painted - filled) / 1000.0, "verify_ms": float(verified - painted) / 1000.0, "build_workload_oracle_ms": float(workload_ready - verified) / 1000.0, "indexed_queries_ms": float(queried - workload_ready) / 1000.0, "engine_static_payload_before_bytes": before, "engine_static_payload_after_bytes": after_payload, "engine_static_payload_delta_bytes": after_payload - before, "engine_static_with_queries_bytes": OS.get_static_memory_usage()}


func _patch(number: int) -> Rect2i:
	return Rect2i(50 + ((number - 1) % 4) * 900, 100 + ((number - 1) / 4) * 1800, PATCH_EDGE, PATCH_EDGE)


func _index(x: int, y: int) -> int:
	return -1 if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT else y * WIDTH + x


func _read(x: int, y: int) -> Dictionary:
	var index := _index(x, y)
	if index < 0: return {}
	return {"terrain": _terrain[index], "height": _heights[index], "flags": _flags[index]}


func _expected(index: int) -> Vector3i:
	var point := Vector2i(index % WIDTH, index / WIDTH)
	for number in range(1, 13):
		if _patch(number).has_point(point): return Vector3i(number + 1, number * 2, 1 << (number % 3))
	return Vector3i(1, 0, 0)


func _sample_matches(index: int) -> bool:
	if index < 0 or index >= CELLS: return false
	var expected := _expected(index)
	return _terrain[index] == expected.x and _heights[index] == expected.y and _flags[index] == expected.z


func _checksum(previous: int, index: int, terrain: int, height: int, flags: int) -> int:
	return (previous * 31 + terrain * 13 + height * 7 + flags + index) % MODULUS


func _check(condition: bool, reason: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + reason)
