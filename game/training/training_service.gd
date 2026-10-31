extends RefCounted
## F06: actual twelve students, two actual instructors and elapsed course time.
const COURSES := {
	"P01":{"name":"Basic infantry","seconds":120.0,"recipes":[]},
	"P02":{"name":"Engineer","seconds":180.0,"recipes":["R08"]},
	"P03":{"name":"Medic","seconds":180.0,"recipes":["R11"]},
	"P04":{"name":"Heavy weapons","seconds":180.0,"recipes":["R05","R06","R29"]},
	"P05":{"name":"Artillery","seconds":180.0,"recipes":["R13"]},
	"P06":{"name":"Drone operator","seconds":180.0,"recipes":["R16"]},
	"P07":{"name":"Marksman","seconds":180.0,"recipes":["R19"]},
	"P08":{"name":"Vehicle crew","seconds":240.0,"recipes":["R25"]},
}
const STUDENT_LIMIT := 12
var _rear_ref: WeakRef
var _recipe_access: Callable
var rows: Array[Dictionary] = []
var _sequence := 0
var accessible := true
var training_sites: Array[Dictionary] = [{"id":"initial-training","center":Vector2(55,110),"duty":"training","active":true}]

func _init(rear: RefCounted, access: Callable) -> void:
	_rear_ref = weakref(rear)
	_recipe_access = access
	rear.requests.students = {"id":"students","target":0,"positions":12,"priority":1,"created":0.0,"order":rear._next(),"place":"duty-training"}

func add_training_site(id: String, center: Vector2, duty: String) -> void:
	training_sites.append({"id":id,"center":center,"duty":duty,"active":true})
	_rear_ref.get_ref().requests.students.positions += STUDENT_LIMIT

func site_busy(id: String) -> bool:
	for index in training_sites.size():
		if training_sites[index].id != id: continue
		for row in _unfinished():
			if row.seat >= index*STUDENT_LIMIT and row.seat < (index+1)*STUDENT_LIMIT: return true
	return false

func retire_training_site(id: String) -> bool:
	if site_busy(id): return false
	for site in training_sites:
		if site.id == id and site.active:
			site.active = false
			_rear_ref.get_ref().requests.students.positions -= STUDENT_LIMIT
			return true
	return false

func _seat_capacity() -> int:
	var count := 0
	for site in training_sites:
		if site.active: count += STUDENT_LIMIT
	return count

func course_accessible(course: String) -> bool:
	if not COURSES.has(course): return false
	if course == "P01": return true
	for recipe in COURSES[course].recipes:
		if _recipe_access.call(recipe): return true
	return false

func request_course(course: String, count: int) -> Dictionary:
	if not course_accessible(course): return _result(false,"Course access absent; requires available declared recipe access, not a selected production recipe.")
	if count <= 0 or count > _seat_capacity() - _unfinished().size(): return _result(false,"Course requests must fit actual reserved student places, including queued/reporting people.")
	var rear: RefCounted = _rear_ref.get_ref()
	for index in count:
		_sequence += 1
		rows.append({"id":"course-%04d"%_sequence,"course":course,"person_id":"","seat":-1,"sequence":_sequence,"requested_at":rear.time,"work":0.0,"required":COURSES[course].seconds,"state":"Queued","reason":"Waiting for eligible actual person"})
	rear._settle()
	return _result(true,"Requested %d %s course places; real people must safely leave work and report."%[count,course])

func _unfinished() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in rows:
		if row.state not in ["Completed","Withdrawn"]: result.append(row)
	return result

func _eligible(person: Dictionary, course: String) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if not rear._eligible(person,"Available") or person.assignment == "Training" or person.duty_id == "training" or person.pending_assignment != "None" or not person.crew_station.is_empty(): return false
	return not person.basic_training if course == "P01" else person.basic_training and person.qualification == "None"

func student_position(id: String) -> Vector2:
	for row in _unfinished():
		if row.person_id == id and row.seat >= 0:
			var site_index: int = row.seat / STUDENT_LIMIT
			var seat: int = row.seat % STUDENT_LIMIT
			var center: Vector2 = training_sites[site_index].center
			return center + Vector2(-15 - floorf(float(seat) / 6.0) * 2,-6 + (seat % 6) * 2)
	return Vector2(44,110)

func _seat_free() -> int:
	var occupied: Array[int] = []
	for row in _unfinished():
		if row.seat >= 0: occupied.append(row.seat)
	for index in training_sites.size():
		if not training_sites[index].active: continue
		for seat in STUDENT_LIMIT:
			var global_seat: int = index*STUDENT_LIMIT+seat
			if global_seat not in occupied: return global_seat
	return -1

func instructors() -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Array[String] = []
	for id in rear.actors:
		var p: Dictionary = rear.ledger.inspect_person_status(id)
		if p.owner == rear.PLAYER and p.basic_training and p.health > 0 and p.assignment == "Rear Labour" and p.pending_assignment == "None" and p.carrying_stock_id.is_empty() and p.crew_station.is_empty() and rear.actors[id].phase == "Idle" and rear.requests.has(p.duty_id) and p.position.is_equal_approx(rear.ledger.inspect_entity(rear.requests[p.duty_id].place).position) and _training_duty(p.duty_id):
			result.append(id)
	return result

func _training_duty(duty: String) -> bool:
	for site in training_sites:
		if site.active and site.duty == duty: return true
	return false

func _present(row: Dictionary) -> bool:
	if row.person_id.is_empty(): return false
	var rear: RefCounted = _rear_ref.get_ref()
	var p: Dictionary = rear.ledger.inspect_person_status(row.person_id)
	return p.assignment == "Training" and p.duty_id == "students" and p.pending_assignment == "None" and p.health > 0 and p.carrying_stock_id.is_empty() and rear.actors[p.id].phase == "Idle" and p.position.is_equal_approx(student_position(p.id))

func _active() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not accessible: return result
	var coverage: Dictionary = {}
	for id in instructors():
		var duty: String = _rear_ref.get_ref().ledger.inspect_person_status(id).duty_id
		coverage[duty] = int(coverage.get(duty,0))+6
	# Each actual instructor covers only students seated at that same F06.
	for row in _unfinished():
		if row.seat < 0 or not _present(row) or not course_accessible(row.course): continue
		var duty: String = training_sites[int(row.seat / STUDENT_LIMIT)].duty
		if int(coverage.get(duty,0)) <= 0: continue
		coverage[duty] -= 1
		result.append(row)
	return result

func next_boundary() -> float:
	var next := INF
	var rear: RefCounted = _rear_ref.get_ref()
	for row in _active(): next = minf(next,rear.time + maxf(0.0,row.required-row.work))
	return next

func advance_work(seconds: float) -> void:
	for row in _active():
		row.work = minf(row.required,row.work + seconds)
		if row.required-row.work <= _rear_ref.get_ref().EPS: row.work = row.required

func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var changed := false
	for row in _unfinished():
		if not row.person_id.is_empty():
			var p: Dictionary = rear.ledger.inspect_entity(row.person_id)
			if p.duty_id != "students" and p.pending_duty != "students":
				_withdraw(row,"Actual duty changed; unfinished course progress lost")
				changed = true
	for row in _active():
		if row.work >= row.required:
			var result: Dictionary = rear.ledger.complete_training(row.person_id,row.course)
			if not result.ok:
				_withdraw(row,result.message)
			else:
				row.state = "Completed"
				row.completed_at = rear.time
				row.reason = "Same person completed; qualification retained, no equipment granted"
				row.seat = -1
				rear.reassign_person(row.person_id,"Available")
			changed = true
	if changed: rear._rebalance()
	for row in _unfinished():
		if not row.person_id.is_empty() or not course_accessible(row.course): continue
		var people: Array[Dictionary] = []
		for id in rear.actors:
			var p: Dictionary = rear.ledger.inspect_entity(id)
			if _eligible(p,row.course): people.append(p)
		people.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var arank: int = 0 if a.assignment == "Available" else (1 if rear.actors[a.id].phase == "Idle" else 2)
			var brank: int = 0 if b.assignment == "Available" else (1 if rear.actors[b.id].phase == "Idle" else 2)
			return arank < brank if arank != brank else a.id < b.id)
		if people.is_empty(): continue
		row.person_id = people[0].id
		row.seat = _seat_free()
		var result: Dictionary = rear.reassign_person(row.person_id,"students")
		if not result.ok:
			row.person_id = ""
			row.seat = -1
		else: changed = true
	_refresh_states()
	return changed

func _withdraw(row: Dictionary, reason: String) -> void:
	row.lost_work = row.work
	row.work = 0.0
	row.state = "Withdrawn"
	row.reason = reason
	row.seat = -1

func withdraw(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	for row in _unfinished():
		if row.id != id: continue
		_withdraw(row,"Withdrawn: only unfinished course time lost; previous qualifications retained")
		if not row.person_id.is_empty():
			var p: Dictionary = rear.ledger.inspect_entity(row.person_id)
			if p.pending_duty == "students": rear.ledger.cancel_assignment_request(p.id)
			elif p.duty_id == "students": rear.reassign_person(p.id,"Available")
		rear._rebalance()
		rear._settle()
		return _result(true,row.reason)
	return _result(false,"Choose an unfinished queued or actual student course.")

func set_access(value: bool) -> Dictionary:
	accessible = value
	_rear_ref.get_ref()._settle()
	return _result(true,"Training access updated; completed qualifications and current elapsed work retained.")

func _refresh_states() -> void:
	var active := _active()
	for row in _unfinished():
		if row.person_id.is_empty():
			row.state = "Queued"
			row.reason = "Waiting for eligible untrained person" if row.course == "P01" else "Waiting for basic-trained person with no specialist qualification"
		elif not _present(row):
			row.state = "Reporting"
			row.reason = "Finish safe old duty/carry and physically report to student place"
		elif not accessible or not course_accessible(row.course):
			row.state = "Paused"
			row.reason = "Facility or declared recipe access absent"
		elif row not in active:
			row.state = "Paused"
			row.reason = "Instructor coverage shortage — newest students pause first"
		else:
			row.state = "Active"
			row.reason = "Actual student covered by physically present instructor"

func snapshot() -> Dictionary:
	_refresh_states()
	var counts := {"Queued":0,"Reporting":0,"Active":0,"Paused":0,"Completed":0,"Withdrawn":0}
	for row in rows: counts[row.state] += 1
	return {"accessible":accessible,"courses":COURSES.duplicate(true),"rows":rows.duplicate(true),"counts":counts,"student_places":_seat_capacity(), "training_sites":training_sites.duplicate(true),"reserved_student_places":_unfinished().size(),"instructors":instructors(),"coverage":instructors().size()*6,"instructor_target":_rear_ref.get_ref().requests.training.target}

func audit() -> Array[String]:
	var failures: Array[String] = []
	var people: Array[String] = []
	var seats: Array[int] = []
	if _unfinished().size()>_seat_capacity() or instructors().size()>training_sites.size()*2: failures.append("F06 capacity overbooked")
	if _active().size()>instructors().size()*6: failures.append("Training exceeds actual instructor coverage")
	for row in _unfinished():
		if not row.person_id.is_empty():
			if row.person_id in people or row.seat in seats: failures.append("Duplicate student identity or physical seat")
			people.append(row.person_id)
			seats.append(row.seat)
		if row.work < 0 or row.work > row.required: failures.append("Invalid training time")
	return failures

func _result(ok: bool,message: String) -> Dictionary:
	return {"ok":ok,"message":message}
