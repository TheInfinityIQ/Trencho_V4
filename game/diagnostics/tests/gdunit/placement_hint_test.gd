extends GdUnitTestSuite
## Provisional read contracts, current-pose admission and matched query timings.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Catalog = preload("res://game/construction/construction_catalogue.gd")
const Trace = preload("res://game/diagnostics/tests/gdunit/fixtures/placement_trace.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")

func test_00_all_buildable_kinds_and_rotations_have_detached_read_only_hints() -> void:
	var base := _fixture()
	var service: RefCounted = base.rear.construction
	var ledger_before: Dictionary = base.rear.ledger.snapshot(false)
	var sites_before: Dictionary = service.instances.duplicate(true)
	for kind in Catalog.SPECS:
		if Catalog.SPECS[kind].get("fixed",false): continue
		for turned in [false,true]:
			var hint: Dictionary = service.placement_hint(kind,Vector2(190,130),turned)
			var full: Dictionary = service.preview(kind,Vector2(190,130),turned)
			assert_bool(hint.ok and hint.provisional and full.ok).override_failure_message(str([kind,turned,hint,full])).is_true()
			assert_that(hint.footprint).is_equal(full.footprint)
			assert_that(hint.size).is_equal(Catalog.footprint(kind,turned))
			hint.center = Vector2.ZERO
			hint.message = "caller mutation"
	assert_that(service.instances).is_equal(sites_before)
	assert_that(base.rear.ledger.snapshot(false)).is_equal(ledger_before)
	assert_float(base.rear.time).is_equal(0.0)

func test_01_fixed_nonfinite_and_edge_violations_remain_rejected() -> void:
	var base := _fixture()
	var service: RefCounted = base.rear.construction
	for kind in ["terminal","personnel","missing-kind"]:
		assert_bool(service.placement_hint(kind,Vector2(100,40)).ok).is_false()
	for point in [Vector2(NAN,40),Vector2(INF,40),Vector2(-1,40),Vector2(239,179),Vector2.ZERO]:
		assert_bool(service.placement_hint("construction",point).ok).is_false()
		assert_bool(service.place("construction",point).ok).is_false()
	assert_bool(service.instances.is_empty()).is_true()

func test_02_cancelled_footprint_tracks_current_retained_stock_without_a_cache() -> void:
	var base := _fixture()
	var service: RefCounted = base.rear.construction
	var ledger: RefCounted = base.rear.ledger
	var point := Vector2(80,40)
	var placed: Dictionary = service.place("construction",point)
	assert_bool(placed.ok).is_true()
	assert_bool(service.placement_hint("construction",point).ok).is_false()
	assert_bool(service.cancel(placed.id).ok).is_true()
	assert_bool(service.placement_hint("construction",point).ok).is_true()
	# Explicit stock fixture: a cancelled site retains its footprint while real
	# loose material remains. No delayed collider/cache refresh may change this.
	assert_bool(ledger.add_stock("retained-material","M11",1,1.0,placed.id,base.rear.PLAYER).ok).is_true()
	assert_bool(service.placement_hint("construction",point).ok).is_false()
	assert_bool(ledger.consume_local_batch(placed.id,base.rear.PLAYER,{"M11":1},"Test cleanup").ok).is_true()
	assert_bool(service.placement_hint("construction",point).ok).is_true()

func test_03_hints_never_run_full_preview_or_route_searches() -> void:
	var base := _fixture()
	var service := Trace.new(base.rear)
	base.rear.construction = service
	for step in 128:
		service.placement_hint("workshop",Vector2(50+step,40))
	assert_int(service.hints).is_equal(128)
	assert_int(service.full_previews).is_equal(0)
	assert_int(service.path_queries).is_equal(0)
	assert_bool(service.preview("workshop",Vector2(100,40)).ok).is_true()
	assert_int(service.full_previews).is_equal(1)
	assert_int(service.path_queries).is_greater(0)

func test_04_provisional_success_never_authorizes_blocked_or_stale_placement() -> void:
	var base := _fixture()
	var service: RefCounted = base.rear.construction
	var lane := Vector2(18,100)
	assert_bool(service.placement_hint("construction",lane).ok).is_true()
	assert_bool(service.preview("construction",lane).ok).is_false()
	assert_bool(service.place("construction",lane).ok).is_false()
	assert_bool(service.instances.is_empty()).is_true()
	var point := Vector2(100,40)
	var stale: Dictionary = service.placement_hint("construction",point)
	assert_bool(stale.ok).is_true()
	assert_bool(service.place("construction",point).ok).is_true()
	assert_bool(service.place("construction",point).ok).is_false()
	assert_int(service.instances.size()).is_equal(1)
	assert_bool(service.placement_hint("construction",point).ok).is_false()

func test_05_matched_populated_query_benchmark() -> void:
	var fixtures := {"preview":_fixture(),"placement_hint":_fixture()}
	var before := {}
	for mode in fixtures:
		var base: RefCounted = fixtures[mode]
		var service: RefCounted = base.rear.construction
		for point in [Vector2(50,30),Vector2(85,30),Vector2(120,30),Vector2(155,30),Vector2(50,140),Vector2(85,140)]:
			assert_bool(service.place("construction",point).ok).is_true()
		before[mode] = {"sites":service.instances.duplicate(true),"ledger":base.rear.ledger.snapshot(false)}
		for warmup in 8: service.call(mode,"workshop",Vector2(190,130),false)
	var previous_enabled := Counter.enabled
	Counter.enabled = false
	var runs: Array = []
	# Identical poses on separate equivalent fixtures. Alternate order for drift.
	# CPU-only query timings are separate from the actual-game 1x frame test.
	for replication in 3:
		var full_usec: Array[int] = []
		var hint_usec: Array[int] = []
		for sample in 192:
			var point := Vector2(70.125+fposmod(sample*1.375,100),40.375+fposmod(sample*0.625,85))
			for mode in (["preview","placement_hint"] if replication%2 == 0 else ["placement_hint","preview"]):
				var service: RefCounted = fixtures[mode].rear.construction
				var started := Time.get_ticks_usec()
				service.call(mode,"workshop",point,false)
				var elapsed := Time.get_ticks_usec()-started
				if mode == "preview": full_usec.append(elapsed)
				else: hint_usec.append(elapsed)
		runs.append({"replication":replication,"full_preview_usec":full_usec,"footprint_hint_usec":hint_usec})
	Counter.enabled = previous_enabled
	for mode in fixtures:
		assert_that(fixtures[mode].rear.construction.instances).is_equal(before[mode].sites)
		assert_that(fixtures[mode].rear.ledger.snapshot(false)).is_equal(before[mode].ledger)
		assert_float(fixtures[mode].rear.time).is_equal(0.0)
	var directory := OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("placement-query-benchmark.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"sites":6,"separate_equivalent_fixtures":true,"warmup_calls_per_mode":8,"counters_enabled":false,"unit":"microseconds","runs":runs}))

func _fixture() -> RefCounted:
	return Base.new(false,false,false,Vector2(1640,91),false,{},true)
