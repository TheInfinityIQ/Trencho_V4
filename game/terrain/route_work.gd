extends RefCounted
## Request-local continuation of the ordinary T02 straight-lane calculation.
## No physical state is written. Every unit reads one captured world revision.
## The deadline is cooperative: bounded native allocation/hash operations cannot
## be preempted. Limits below bound their input sizes, not their measured latency.
## A scan unit may visit four SAT axes,16 region rows AND16 effect rows plus
## eight approach caps. Other units visit
## one obstacle/region/height cell,16 sort/sweep/fold entries, or one output part.
## Native active-array shifts touch at most256 IDs. Other arrays/hash tables can
## grow/free at most65536 entries (cuts/sort scratch/parts at most131074).
## Worlds: nonnegative, <=6000m per axis, coordinates <=1000000m; body diagonal
## <=64m; <=4096 rows in each world list; <=3 class entries; <=8 approach caps.
## These are explicit unsupported limits, never physical clearance denials.
## World mutations must advance revision. Arbitrary writes to public containers
## without revision are not detected; the admission owner must also revalidate
## command/session identity and terrain freshness before physical commitment.
const EPS := 0.0000001
const MAX_INTERVALS := 65536
const MAX_ACTIVE := 256
const MAX_WORLD_ITEMS := 4096
const BATCH := 16

enum Phase { START, OBSTACLES, REGIONS, SCAN, TILE, EFFECTS, HEIGHTS,
	SORT_CUTS, HOMOGENEOUS, CHECK_CUTS, PENDING, SORT_PENDING, SPAN,
	REMOVE, ACTIVATE, FOLD, PART }

# Merge steps move at most sixteen values. Equal starts may be activated in a
# different tie order than native sort; active IDs are still visited in original
# cell order. Equal cuts retain the same numeric span boundaries.
class Merge extends RefCounted:
	const VALUES_PER_UNIT := 16
	var values: Array
	var buffer: Array = []
	var intervals: Array[Dictionary]
	var indexed: bool
	var done := false
	var width := 1
	var first := 0
	var left := 0
	var right := 0
	var middle := 0
	var end := 0
	var output := 0
	var merging := false

	func _init(input: Array, rows: Array[Dictionary], by_start: bool) -> void:
		values = input
		intervals = rows
		indexed = by_start

	func unit() -> void:
		for _ignored in VALUES_PER_UNIT:
			if buffer.size() < values.size(): buffer.append(0); continue
			if width >= values.size(): done = true; return
			if not merging:
				if first >= values.size():
					var swap: Array = values
					values = buffer
					buffer = swap
					width *= 2
					first = 0
					continue
				left = first
				middle = mini(first+width,values.size())
				right = middle
				end = mini(first+2*width,values.size())
				output = first
				merging = true
			var take_right: bool = left >= middle
			if left < middle and right < end:
				take_right = intervals[values[right]].from < intervals[values[left]].from if indexed else values[right] < values[left]
			if right >= end: take_right = false
			if take_right:
				buffer[output] = values[right]
				right += 1
			else:
				buffer[output] = values[left]
				left += 1
			output += 1
			if output == end: first = end; merging = false

var done := false
var invalidated := false
var result: Dictionary = {}
var last_step_units := 0
var world: RefCounted
var revision: int
var entity: Dictionary = {}
var destination: Vector2
var start: Vector2
var distance := 0.0
var bounds: Rect2i
var phase := Phase.START
var index := 0
var obstacle_count := 0
var region_count := 0
var effect_count := 0
var first_cell: Vector2i
var past_cell: Vector2i
var cell_area: Rect2i
var at: Vector2i
var interval: Vector2
var context: Array[Dictionary] = []
var regions: Array[Dictionary] = []
var region_cursor := 0
var tile: Dictionary = {}
var rule: Dictionary = {}
var shareable := true
var previous_tile: Dictionary = {}
var previous_rule: Dictionary = {}
var previous_shareable := false
var occupied: Dictionary = {}
var occupied_order: Array[Vector2i] = []
var intervals: Array[Dictionary] = []
var cuts: Array = [0.0,1.0]
var pending: Array = []
var sort_work: Merge
var homogeneous := true
var cursor := 0
var active: Array[int] = []
var furthest_end := -INF
var span := 0
var begin := 0.0
var end := 0.0
var middle := 0.0
var factor := INF
var burn := 0.0
var max_slope := 0.0
var speed_cap := INF
var surfaces: Array[String] = []
var fold_checked := false
var reuse_fold := false
var fold_ready := false
var saved_factor := INF
var saved_burn := 0.0
var saved_slope := 0.0
var saved_cap := INF
var saved_surface := ""
var parts: Array[Dictionary] = []
var seconds := 0.0
var fuel := 0.0

func _init(source: RefCounted, input: Dictionary, finish: Vector2) -> void:
	world = source
	revision = world.revision
	bounds = world.bounds
	destination = finish
	# Copy just scalar request facts; never duplicate caller-owned nested state.
	for key in ["position","facing","size","movement_class","base","rate"]:
		if not input.has(key): _unsupported("Missing T02 route fact: "+key); return
		entity[key] = input[key]
	for key in ["gross_mass_kg","bridge_existing_traffic"]:
		if input.has(key): entity[key] = input[key]
	var error: String = _input_error()
	if not error.is_empty(): _unsupported(error); return
	start = entity.position
	obstacle_count = world.obstacles.size()
	region_count = world.base_regions.size()
	effect_count = world.field_effects.size()
	if maxi(obstacle_count,maxi(region_count,effect_count)) > MAX_WORLD_ITEMS: _unsupported("World metadata exceeds4096 rows per collection")

func _input_error() -> String:
	if typeof(entity.position) != TYPE_VECTOR2 or typeof(entity.size) != TYPE_VECTOR2: return "Position and footprint must be Vector2 values"
	if not entity.position.is_finite() or not destination.is_finite() or not entity.size.is_finite(): return "Nonfinite position or footprint"
	# Capacity limits below are implementation support limits, not vehicle rules.
	# Use the caller's captured dimensions in every geometry calculation.
	if entity.size.x <= 0 or entity.size.y <= 0: return "Nonpositive footprint dimensions"
	if entity.size.length() > 64.0: return "Footprint diagonal exceeds64m"
	if typeof(entity.movement_class) != TYPE_INT or entity.movement_class != world.Catalog.VEHICLES.T02.class: return "Movement class differs from ordinary T02"
	for key in ["facing","base","rate","gross_mass_kg"]:
		if key == "gross_mass_kg" and not entity.has(key): continue
		if typeof(entity[key]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(entity[key])): return "Nonfinite or nonnumeric request fact: "+key
	if entity.base <= 0 or entity.rate < 0: return "Nonpositive speed or negative fuel rate"
	if entity.has("bridge_existing_traffic") and typeof(entity.bridge_existing_traffic) != TYPE_BOOL: return "Nonboolean bridge traffic fact"
	if bounds.position.x < 0 or bounds.position.y < 0 or bounds.size.x <= 0 or bounds.size.y <= 0: return "World needs a nonnegative origin and positive dimensions"
	if bounds.size.x > 6000 or bounds.size.y > 6000: return "World exceeds6000m per axis"
	if bounds.end.x > 1000000 or bounds.end.y > 1000000 or not _coordinate_supported(entity.position) or not _coordinate_supported(destination): return "World/request coordinates exceed1000000m"
	return ""

func _coordinate_supported(point: Vector2) -> bool:
	return absf(point.x) <= 1000000 and absf(point.y) <= 1000000

func step(max_units: int = 128, budget_usec: int = 4000) -> void:
	last_step_units = 0
	if world.revision != revision: _invalidate(); return
	if done or max_units <= 0 or budget_usec <= 0: return
	var deadline: int = Time.get_ticks_usec()+mini(budget_usec,4000)
	while not done and last_step_units < mini(max_units,128) and Time.get_ticks_usec() < deadline:
		if world.revision != revision: _invalidate(); return
		_unit()
		last_step_units += 1
	if world.revision != revision: _invalidate()

func _invalidate() -> void:
	invalidated = true
	done = true
	result = {"ok":false,"reason":"Terrain changed during bounded route work","revision":revision}

func _blocked(reason: String) -> void:
	done = true
	result = {"ok":false,"reason":reason}

func _unsupported(reason: String) -> void:
	_blocked("Bounded T02 route unsupported: "+reason)
	result["unsupported"] = true

func _unit() -> void:
	match phase:
		Phase.START: _start()
		Phase.OBSTACLES: _obstacle()
		Phase.REGIONS: _region()
		Phase.SCAN: _scan()
		Phase.TILE: _find_tile()
		Phase.EFFECTS: _effects()
		Phase.HEIGHTS: _height()
		Phase.SORT_CUTS, Phase.SORT_PENDING:
			sort_work.unit()
			if sort_work.done:
				if phase == Phase.SORT_CUTS:
					cuts = sort_work.values
					phase = Phase.HOMOGENEOUS
				else:
					pending = sort_work.values
					phase = Phase.SPAN
				index = 0
		Phase.HOMOGENEOUS: _homogeneous()
		Phase.CHECK_CUTS:
			if index < cuts.size():
				if not is_finite(cuts[index]): homogeneous = false
				index += 1
			else: phase = Phase.PENDING; index = 0; fold_checked = not homogeneous
		Phase.PENDING:
			if index < intervals.size(): pending.append(index); index += 1
			else: sort_work = Merge.new(pending,intervals,true); phase = Phase.SORT_PENDING
		Phase.SPAN: _span()
		Phase.REMOVE: _remove()
		Phase.ACTIVATE: _activate()
		Phase.FOLD: _fold()
		Phase.PART: _part()

func _start() -> void:
	distance = start.distance_to(destination)
	if distance <= EPS: _blocked("Choose a distinct lane endpoint"); return
	var direction: Vector2 = (destination-start)/distance
	if absf(direction.cross(Vector2.from_angle(entity.facing))) > EPS: _blocked("Declared straight lane requires current hull alignment; no turn planner"); return
	for point in world.footprint(entity,start)+world.footprint(entity,destination):
		if point.x < bounds.position.x-EPS or point.y < bounds.position.y-EPS or point.x > bounds.end.x+EPS or point.y > bounds.end.y+EPS: _blocked("Whole footprint exceeds declared world"); return
	var minimum: Vector2 = start.min(destination)-Vector2(entity.size.length(),entity.size.length())*0.5
	var maximum: Vector2 = start.max(destination)+Vector2(entity.size.length(),entity.size.length())*0.5
	first_cell = Vector2i(maxi(bounds.position.x,int(floor(minimum.x))),maxi(bounds.position.y,int(floor(minimum.y))))
	past_cell = Vector2i(mini(bounds.end.x,int(ceil(maximum.x))),mini(bounds.end.y,int(ceil(maximum.y))))
	cell_area = Rect2i(first_cell,past_cell-first_cell)
	context = world._cell_overlap_context(entity,start,destination)
	phase = Phase.OBSTACLES
	index = 0

func _classes_supported(classes: Variant) -> bool:
	if not classes is Array or classes.size() > 3: return false
	for value in classes:
		if typeof(value) != TYPE_INT or value < 0 or value > 2: return false
	return true

func _obstacle() -> void:
	if index >= obstacle_count: phase = Phase.REGIONS; index = region_count-1; return
	var item: Dictionary = world.obstacles[index]
	index += 1
	if not _classes_supported(item.get("classes",[0,1,2])): _unsupported("Obstacle needs at most3 integer movement-class entries"); return
	if not item.get("rect") is Rect2: _unsupported("Custom obstacle rectangle"); return
	if not item.rect.position.is_finite() or not item.rect.size.is_finite(): _unsupported("Nonfinite obstacle rectangle"); return
	if typeof(item.get("id")) != TYPE_STRING or item.id.length() > 256: _unsupported("Obstacle identity exceeds256 characters or is not a string"); return
	if item.solid and int(entity.movement_class) in item.get("classes",[0,1,2]) and world._overlap_interval(entity,start,destination,item.rect).x >= 0: _blocked("Footprint blocked by %s" % item.id)

func _region() -> void:
	if index < 0: phase = Phase.SCAN; at = first_cell; return
	var row: Dictionary = world.base_regions[index]
	index -= 1
	if not row.get("area") is Rect2i or not row.get("tile") is Dictionary: _unsupported("Custom base region metadata"); return
	var area: Rect2i = row.area
	if area.size.x < 0 or area.size.y < 0 or int(area.position.x)+int(area.size.x) > 2147483647 or int(area.position.y)+int(area.size.y) > 2147483647: _unsupported("Nonordinary base region rectangle"); return
	if area.size.x > 0 and area.size.y > 0 and cell_area.size.x > 0 and cell_area.size.y > 0 and not area.intersects(cell_area): return
	regions.append(row)

func _scan() -> void:
	if at.y >= past_cell.y or first_cell.x >= past_cell.x: phase = Phase.HEIGHTS; index = 0; return
	interval = world._cell_overlap_interval(entity,start,destination,Rect2(Vector2(at),Vector2.ONE),context)
	if interval.x < 0: _next_cell(); return
	if not interval.is_finite() or interval.x >= interval.y: _unsupported("Nonfinite or degenerate SAT interval"); return
	if world.cells.has(at):
		tile = world.cells[at]
		_begin_rule()
	else:
		region_cursor = 0
		_find_tile()

func _find_tile() -> void:
	for _ignored in BATCH:
		if region_cursor >= regions.size(): tile = {"terrain":"TR01"}; _begin_rule(); return
		var row: Dictionary = regions[region_cursor]
		region_cursor += 1
		if row.area.has_point(at): tile = row.tile; _begin_rule(); return
	phase = Phase.TILE

func _tile_error() -> String:
	if typeof(tile.get("terrain")) != TYPE_STRING or not world.Catalog.SURFACES.has(tile.terrain): return "Tile surface is not a catalogue code"
	if not _classes_supported(tile.get("classes",[])): return "Tile needs at most3 integer movement-class entries"
	if typeof(tile.get("gradient",Vector2.ZERO)) != TYPE_VECTOR2 or not Vector2(tile.get("gradient",Vector2.ZERO)).is_finite(): return "Nonfinite or nonvector tile gradient"
	for key in ["height","depth"]:
		if tile.has(key) and (typeof(tile[key]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(tile[key]))): return "Nonfinite or nonnumeric tile "+key
	if not tile.get("overlay",{}) is Dictionary: return "Custom overlay container"
	var overlay: Dictionary = tile.get("overlay",{})
	if not _classes_supported(overlay.get("classes",[])): return "Overlay needs at most3 integer movement-class entries"
	if typeof(overlay.get("code","")) != TYPE_STRING or str(overlay.get("code","")).length() > 128: return "Overlay code exceeds128 characters or is not a string"
	for key in ["height","load_kg","width","speed_cap"]:
		if overlay.has(key) and (typeof(overlay[key]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(overlay[key]))): return "Nonfinite or nonnumeric overlay "+key
	return ""

func _begin_rule() -> void:
	if typeof(tile.get("closed_project","")) != TYPE_STRING: _unsupported("Nonstring project closure metadata"); return
	if not str(tile.get("closed_project","")).is_empty(): _blocked("Active project closes this segment to traffic"); return
	var error: String = _tile_error()
	if not error.is_empty(): _unsupported(error); return
	rule = world._support_from_tile(tile,entity.movement_class)
	if not rule.ok: _blocked("Cell %s: %s" % [at,rule.reason]); return
	shareable = true
	index = 0
	_effects()

func _effects() -> void:
	for _ignored in BATCH:
		if index >= effect_count: _finish_cell(); return
		var effect: Dictionary = world.field_effects[index]
		index += 1
		if not effect.get("area") is Rect2: _unsupported("Custom field-effect area"); return
		if not effect.area.position.is_finite() or not effect.area.size.is_finite(): _unsupported("Nonfinite field-effect rectangle"); return
		if not effect.area.has_point(Vector2(at)+Vector2(0.5,0.5)): continue
		shareable = false
		if effect.code == "S02" and entity.movement_class == 0: rule.factor *= 0.8
		if effect.code == "S05" and entity.movement_class == 0: rule.factor *= 0.7
		if effect.code == "S04" and entity.movement_class == 2: rule.factor *= 0.25
	phase = Phase.EFFECTS

func _finish_cell() -> void:
	var overlay: Dictionary = tile.get("overlay",{})
	if overlay.get("complete",false) and overlay.get("kind","") == "causeway" and entity.has("gross_mass_kg") and float(entity.gross_mass_kg) > float(overlay.get("load_kg",8000.0))+EPS:
		_blocked("Causeway gross-load limit excludes this actual body and contents"); return
	if overlay.get("complete",false) and overlay.get("kind","") == "crossing" and overlay.has("code"):
		if entity.has("gross_mass_kg") and not entity.get("bridge_existing_traffic",false) and float(entity.gross_mass_kg) > float(overlay.load_kg)+EPS: _blocked("%s gross-load limit excludes this actual body and contents" % overlay.code); return
		if entity.size.y > float(overlay.width)+EPS: _blocked("%s deck is narrower than the actual footprint" % overlay.code); return
		rule["speed_cap"] = float(overlay.speed_cap)
	elif world.bridge_approaches.has(at):
		shareable = false
		if not world.bridge_approaches[at] is Dictionary: _unsupported("Custom approach cap metadata"); return
		var caps: Dictionary = world.bridge_approaches[at]
		if caps.size() > 8: _unsupported("More than8 approach caps on a cell"); return
		var approach_cap := INF
		for cap in caps.values():
			if typeof(cap) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(cap)): _unsupported("Nonfinite or nonnumeric approach cap"); return
			approach_cap = minf(approach_cap,float(cap))
		rule["speed_cap"] = approach_cap
	if shareable and previous_shareable and is_same(tile,previous_tile): rule = previous_rule
	previous_tile = tile
	previous_rule = rule
	previous_shareable = shareable
	if intervals.size() >= MAX_INTERVALS: _unsupported("More than65536 occupied footprint cells"); return
	occupied[at] = tile
	occupied_order.append(at)
	intervals.append({"from":interval.x,"to":interval.y,"rule":rule})
	cuts.append(interval.x)
	cuts.append(interval.y)
	_next_cell()

func _next_cell() -> void:
	at.x += 1
	if at.x >= past_cell.x: at.x = first_cell.x; at.y += 1
	phase = Phase.SCAN

func _height() -> void:
	if index >= occupied_order.size(): sort_work = Merge.new(cuts,intervals,false); phase = Phase.SORT_CUTS; return
	var here_at: Vector2i = occupied_order[index]
	index += 1
	for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
		if not occupied.has(here_at+offset): continue
		var here: Dictionary = occupied[here_at]
		var there: Dictionary = occupied[here_at+offset]
		if is_same(here,there): continue
		var edge := Vector2(here_at+offset)
		var tangent := Vector2.DOWN if offset == Vector2i.RIGHT else Vector2.RIGHT
		for point in [edge,edge+tangent]:
			if absf(world._tile_height(here,point)-world._tile_height(there,point)) > 0.00001: _blocked("Disconnected height support at %s" % here_at); return

func _homogeneous() -> void:
	if intervals.is_empty(): homogeneous = false
	if not homogeneous or index >= intervals.size(): phase = Phase.CHECK_CUTS; index = 0; return
	var row: Dictionary = intervals[index]
	if not is_same(row.rule,intervals[0].rule) or typeof(row.from) != TYPE_FLOAT or typeof(row.to) != TYPE_FLOAT or not is_finite(row.from) or not is_finite(row.to) or row.from >= row.to: homogeneous = false
	index += 1

func _span() -> void:
	if span >= cuts.size()-1:
		done = true
		result = {"ok":true,"reason":"Whole straight lane supported","parts":parts,"seconds":seconds,"distance":distance,"fuel":fuel,"revision":revision}
		return
	begin = cuts[span]
	end = cuts[span+1]
	span += 1
	if end-begin <= EPS: return
	middle = (begin+end)*0.5
	index = active.size()-1
	phase = Phase.ACTIVATE if homogeneous else Phase.REMOVE

func _remove() -> void:
	for _ignored in BATCH:
		if index < 0: phase = Phase.ACTIVATE; return
		if intervals[active[index]].to < middle: active.remove_at(index)
		index -= 1

func _activate() -> void:
	for _ignored in BATCH:
		if cursor >= pending.size() or intervals[pending[cursor]].from > middle:
			if homogeneous:
				if cursor > 0 and furthest_end >= middle:
					if active.is_empty(): active.append(0)
				else: active.clear()
			_begin_fold()
			return
		var id: int = pending[cursor]
		if homogeneous: furthest_end = maxf(furthest_end,intervals[id].to)
		elif intervals[id].to >= middle:
			if active.size() >= MAX_ACTIVE: _unsupported("More than256 simultaneously occupied cells"); return
			active.insert(active.bsearch(id),id)
		cursor += 1

func _begin_fold() -> void:
	factor = INF
	burn = 0.0
	surfaces = []
	max_slope = 0.0
	speed_cap = INF
	if not fold_checked and not active.is_empty(): fold_checked = true; reuse_fold = world._scalar_route_rule(intervals[0].rule)
	if reuse_fold and fold_ready and not active.is_empty():
		factor = saved_factor
		burn = saved_burn
		max_slope = saved_slope
		speed_cap = saved_cap
		surfaces.append(saved_surface)
		phase = Phase.PART
	else: previous_rule = {}; index = 0; phase = Phase.FOLD

func _fold() -> void:
	for _ignored in BATCH:
		if index >= active.size():
			if reuse_fold and not fold_ready and not active.is_empty():
				saved_factor = factor
				saved_burn = burn
				saved_slope = max_slope
				saved_cap = speed_cap
				saved_surface = surfaces[0]
				fold_ready = true
			phase = Phase.PART
			return
		var row: Dictionary = intervals[active[index]].rule
		index += 1
		if is_same(row,previous_rule): continue
		previous_rule = row
		factor = minf(factor,row.factor)
		burn = maxf(burn,row.fuel)
		max_slope = maxf(max_slope,row.slope)
		speed_cap = minf(speed_cap,float(row.get("speed_cap",INF)))
		if row.surface not in surfaces: surfaces.append(row.surface)

func _part() -> void:
	var length: float = (end-begin)*distance
	var speed: float = minf(entity.base*factor,speed_cap)
	var used: float = length*entity.rate*burn/1000.0
	parts.append({"from":start.lerp(destination,begin),"to":start.lerp(destination,end),"distance":length,"speed":speed,"seconds":length/speed,"fuel":used,"surfaces":surfaces,"slope":max_slope})
	seconds += length/speed
	fuel += used
	phase = Phase.SPAN
