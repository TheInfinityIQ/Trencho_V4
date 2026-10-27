extends GdUnitTestSuite
## Component fixtures are explicit; the connected-chain case starts with zero goods.
const Fixed = preload("res://game/production/fixed_production.gd")
const Rear = preload("res://game/staffing/rear_simulation.gd")
const Workshop = preload("res://game/production/r01_production.gd")
const Munitions = preload("res://game/production/r02_production.gd")
const Support = preload("res://game/production/support_production.gd")
const Materials = preload("res://game/production/r26_production.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")
const ADDED: Array[String] = ["R03", "R04", "R05", "R06", "R08", "R19", "R07", "R14", "R24", "R11", "R12", "R15", "R16", "R17", "R18", "R20", "R21"]

func _component(id: String) -> Dictionary:
	var rear := Rear.new("Empty")
	var spec: Dictionary = Fixed.RECIPES[id]
	var owner: RefCounted
	match spec.duty:
		"workshop":
			owner = Workshop.new(rear, Workshop.CHOICES)
			rear.production = owner
		"munitions":
			owner = Munitions.new(rear, Munitions.CHOICES)
			rear.munitions_production = owner
		"support":
			owner = Support.new(rear, Support.CHOICES)
			rear.support_production = owner
		"materials":
			owner = Materials.new(rear)
			rear.materials_production = owner
	if owner.has_method("request_recipe"): assert_bool(owner.request_recipe(id).ok).is_true()
	owner.set_mode("Stock target")
	owner.set_stock_target(1)
	for index in 2: rear.add_person("operator-%d" % index, false, "None", "duty-" + spec.duty)
	rear.set_target(spec.duty, 2)
	return {"rear": rear, "owner": owner, "spec": spec}

func _seed(f: Dictionary, except: String = "", holder: String = "", owner: String = "army-blue") -> void:
	for code in f.spec.inputs:
		if code == except: continue
		assert_bool(f.rear.ledger.add_stock("component-" + str(f.rear.ledger.snapshot().entities.size()) + code, code, f.spec.inputs[code], 1.0, f.spec.input_store if holder.is_empty() else holder, owner).ok).is_true()

func test_all_23_specs_match_independent_canonical_gdd_rows_and_equipment_masses() -> void:
	var text := FileAccess.get_file_as_string("res://docs/game_design_document.md")
	var recipe_row := RegEx.create_from_string("^\\| (R[0-9]+) \\| ([0-9]+) ([A-Z][0-9]+) [^|]+ \\| ([^|]+) \\| ([^|]+) \\| ([0-9]+) \\|$")
	var item_row := RegEx.create_from_string("^\\| (E[0-9]+) \\| [^|]+ \\| ([0-9.]+) \\|")
	var ingredient := RegEx.create_from_string("([0-9]+) (M[0-9]+)")
	var masses := {"M06": 1.0, "M11": 1.0}
	for line in text.split("\n"):
		var item := item_row.search(line)
		if item != null: masses[item.get_string(1)] = float(item.get_string(2))
	var count := 0
	for line in text.split("\n"):
		var row := recipe_row.search(line)
		if row == null or row.get_string(5) == "Vehicle Works": continue
		var id := row.get_string(1)
		assert_bool(Fixed.RECIPES.has(id)).override_failure_message(id).is_true()
		var spec: Dictionary = Fixed.RECIPES[id]
		var inputs := {}
		for entry in ingredient.search_all(row.get_string(4)): inputs[entry.get_string(2)] = int(entry.get_string(1))
		assert_dict(spec.inputs).override_failure_message(id + " inputs").is_equal(inputs)
		assert_float(spec.work).override_failure_message(id + " work").is_equal(float(row.get_string(6)))
		assert_str(spec.output_type).is_equal(row.get_string(3))
		assert_int(spec.output_count).is_equal(int(row.get_string(2)))
		assert_float(spec.unit_mass).override_failure_message(id + " mass").is_equal(masses[spec.output_type])
		assert_str(spec.facility).is_equal({"Workshop": "F04", "Munitions Workshop": "F05", "Support Workshop": "F09", "Building Materials Plant": "F13"}[row.get_string(5)])
		count += 1
	assert_int(count).is_equal(23)
	assert_int(Fixed.RECIPES.values().filter(func(spec: Dictionary) -> bool: return not spec.get("heavy",false)).size()).is_equal(23)

func test_every_recipe_completes_only_full_operator_work_into_exact_unissued_physical_output_once() -> void:
	for id in Fixed.RECIPES:
		if Fixed.RECIPES[id].get("heavy",false): continue
		var f := _component(id)
		_seed(f)
		f.rear.advance_time(0)
		assert_float(f.owner.batch.work).override_failure_message(id).is_zero()
		assert_float(f.owner.snapshot().output_promise.mass).is_equal(f.spec.output_count * f.spec.unit_mass)
		assert_dict(f.rear.ledger.snapshot().consumed).is_equal(f.spec.inputs)
		f.rear.advance_time(f.spec.work / 2.0 - 0.001)
		assert_int(f.rear.ledger.total_stock(f.spec.output_type)).override_failure_message(id + " too early").is_zero()
		f.rear.advance_time(0.001)
		assert_int(f.owner.snapshot().physical_output).override_failure_message(id + " yield").is_equal(f.spec.output_count)
		assert_float(f.rear.ledger.loose_stock_mass_at(f.spec.output_store)).is_equal(f.spec.output_count * f.spec.unit_mass)
		assert_float(f.owner.history[0].work).is_equal(f.spec.work)
		var product: Dictionary = f.rear.ledger.inspect_entity(f.owner.history[0].output_id)
		assert_str(product.kind).is_equal("STOCK")
		assert_str(product.holder_id).is_equal(f.spec.output_store)
		assert_bool(product.loaded).is_false()
		f.rear.advance_time(1)
		assert_int(f.owner.history.size()).is_equal(1)
		assert_int(f.rear.actors.size()).is_equal(2)
		assert_array(f.rear.audit()).is_empty()

func test_each_added_ingredient_missing_reserved_foreign_remote_personal_and_carried_cannot_start() -> void:
	for id in ADDED:
		for code in Fixed.RECIPES[id].inputs:
			for condition in ["missing", "reserved", "foreign", "remote", "personal", "carried"]:
				var f := _component(id)
				_seed(f, code)
				if condition != "missing":
					var holder: String = "depot" if condition == "remote" else ("operator-0" if condition == "personal" else f.spec.input_store)
					f.rear.ledger.add_stock("ineligible", code, f.spec.inputs[code], 1.0, holder, "supplier" if condition == "foreign" else "army-blue")
					if condition in ["reserved", "carried"]:
						f.rear.ledger.request_stock("other", "ineligible", 1, "operator-0", "other use", "army-blue")
					if condition == "carried": assert_bool(f.rear.ledger.begin_carry("operator-0", "ineligible", 1, "other").ok).is_true()
				f.rear.advance_time(0)
				assert_dict(f.owner.batch).override_failure_message(id + " " + code + " " + condition).is_empty()
				assert_dict(f.rear.ledger.snapshot().consumed).is_empty()
				assert_dict(f.rear._output_promises).is_empty()

func test_default_essential_and_copied_expanded_access_do_not_grant_any_goods_or_live_unlocks() -> void:
	var essential := Base.new()
	var expanded := Base.new(true)
	assert_int(essential.rear.actors.size()).is_equal(12)
	assert_dict(essential.rear.ledger.snapshot().created).is_empty()
	assert_dict(expanded.rear.ledger.snapshot().created).is_empty()
	assert_float(expanded.receiving.snapshot().money).is_equal(2500.0)
	for activity in [essential.rear.production, essential.rear.munitions_production, essential.rear.support_production]:
		for id in activity.snapshot().recipe_choices:
			assert_bool(activity.recipe_accessible(id)).override_failure_message(id).is_equal(id in ["R01", "R08", "R02", "R27"])
	for activity in [expanded.rear.production, expanded.rear.munitions_production, expanded.rear.support_production]:
		for id in activity.snapshot().recipe_choices: assert_bool(activity.recipe_accessible(id)).is_true()
	var access: Array[String] = ["R03"]
	var selected := Workshop.new(essential.rear, access)
	access.clear()
	assert_bool(selected.recipe_accessible("R03")).is_true()
	var view: Dictionary = selected.snapshot()
	view.declared_recipe_access.clear()
	assert_bool(selected.recipe_accessible("R03")).is_true()
	assert_bool(selected.request_recipe("R05").ok).is_false()
	assert_bool(expanded.receiving.buy_resources({"M06": 1}).ok).is_false()
	assert_bool(expanded.receiving.buy_resources({"M11": 1}).ok).is_false()
	assert_bool(expanded.receiving.buy_resources({"M01":1,"M02":1,"M03":1,"M04":1,"M05":1,"M07":1,"M08":1,"M09":1,"M10":1}).ok).is_true()
	assert_float(expanded.receiving.snapshot().money).is_equal(2442.0)

func test_all_added_recipes_need_whole_output_space_and_finish_active_work_after_target_lowering() -> void:
	for id in ADDED:
		var f := _component(id)
		_seed(f)
		var mass: float = f.spec.output_count * f.spec.unit_mass
		f.rear.set_store(f.spec.output_store, true, mass - 0.01)
		f.rear.advance_time(0)
		assert_dict(f.owner.batch).override_failure_message(id).is_empty()
		assert_dict(f.rear.ledger.snapshot().consumed).is_empty()
		f.rear.set_store(f.spec.output_store, true, mass)
		f.owner.set_stock_target(0)
		var consumed: Dictionary = f.rear.ledger.snapshot().consumed
		f.rear.advance_time(f.spec.work)
		assert_dict(f.rear.ledger.snapshot().consumed).is_equal(consumed)
		assert_int(f.owner.snapshot().physical_output).is_equal(f.spec.output_count)
		assert_int(f.owner.history.size()).is_equal(1)
		assert_array(f.rear.audit()).is_empty()

func test_confirmed_selection_pause_history_unique_ids_and_stale_tokens_for_each_facility() -> void:
	for pair in [["R03", "R08"], ["R24", "R07"], ["R11", "R17"]]:
		var f := _component(pair[0])
		_seed(f)
		f.rear.advance_time(f.spec.work / 4.0)
		f.owner.set_paused(true)
		var before: Dictionary = f.owner.snapshot()
		var request: Dictionary = f.owner.request_recipe(pair[1])
		assert_bool(request.confirmation_required).is_true()
		assert_bool(f.owner.decline_recipe(request.token).ok).is_true()
		assert_dict(f.owner.snapshot().batch).is_equal(before.batch)
		request = f.owner.request_recipe(pair[1])
		assert_bool(f.owner.confirm_recipe(request.token).ok).is_true()
		assert_bool(f.owner.confirm_recipe(request.token).ok).is_false()
		assert_int(f.rear.ledger.total_stock(f.spec.output_type)).is_zero()
		var next_spec: Dictionary = Fixed.RECIPES[pair[1]]
		f.spec = next_spec
		f.owner.set_mode("Stock target")
		f.owner.set_stock_target(1)
		_seed(f)
		f.rear.advance_time(0)
		var stale: Dictionary = f.owner.request_recipe(pair[0])
		f.rear.advance_time(next_spec.work / 2.0)
		assert_bool(f.owner.confirm_recipe(stale.token).ok).is_false()
		assert_int(f.rear.ledger.total_stock(next_spec.output_type)).is_equal(next_spec.output_count)
		f.owner.request_recipe(pair[0])
		assert_bool(f.owner.paused).is_true()
		assert_int(f.owner.history.size()).is_equal(1)
		assert_str(f.owner.history[0].state).is_equal("Cancelled")
		f.spec = Fixed.RECIPES[pair[0]]
		_seed(f)
		f.owner.resume()
		f.rear.advance_time(f.spec.work / 2.0)
		assert_str(f.owner.history[1].id).is_not_equal(f.owner.history[0].id)
		assert_array(f.rear.audit()).is_empty()

func test_four_facilities_share_clock_with_disjoint_actual_operators_and_recover_from_interruption() -> void:
	var base := Base.new(true)
	var duties: Array[String] = ["workshop", "munitions", "support", "materials"]
	var ids: Array[String] = ["R05", "R24", "R15", "R26"]
	var used: Array[String] = []
	for index in 4:
		var owner: RefCounted = [base.rear.production,base.rear.munitions_production,base.rear.support_production,base.rear.materials_production][index]
		if owner.has_method("request_recipe"): owner.request_recipe(ids[index])
		owner.set_mode("Stock target")
		owner.set_stock_target(1)
		for p in 3: base.rear.ledger.move_entity("base-person-%02d" % (index * 3 + p + 1), "rear", base.rear.Layout.door(duties[index]))
		base.rear.set_target(duties[index], 3)
		_seed({"rear":base.rear,"spec":Fixed.RECIPES[ids[index]]})
	base.rear.advance_time(10)
	for owner in base.rear._production_activities():
		if owner == base.rear.heavy_production: continue
		assert_float(owner.batch.work).is_equal(30.0)
		for id in owner.operators():
			assert_array(used).not_contains(id)
			used.append(id)
	base.rear.support_production.set_paused(true)
	base.rear.set_store("workshop_output", false)
	base.rear.advance_time(5)
	assert_float(base.rear.support_production.batch.work).is_equal(30.0)
	assert_float(base.rear.production.batch.work).is_equal(30.0)
	base.rear.set_store("workshop_output", true)
	base.rear.support_production.resume()
	base.rear.reassign_person(base.rear.production.operators()[0], "support")
	assert_int(base.rear.production.operators().size()).is_equal(2)
	base.rear.advance_time(150)
	for owner in base.rear._production_activities():
		if owner == base.rear.heavy_production: continue assert_int(owner.history.size()).is_equal(1)
	assert_array(base.audit()).is_empty()

func test_connected_raw_purchases_make_multiple_workshop_support_outputs_and_real_explosive_fed_bombs() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for row in [[rear.production,"R03",1],[rear.munitions_production,"R27",10],[rear.support_production,"R11",1]]:
		row[0].request_recipe(row[1])
		row[0].set_mode("Stock target")
		row[0].set_stock_target(row[2])
	rear.materials_production.set_stock_target(100)
	assert_bool(base.receiving.buy_resources({"M01":64,"M02":5,"M03":100,"M04":70,"M05":2,"M07":3,"M08":1,"M09":6,"M10":5}).ok).is_true()
	for duty in {"receiving":1,"hauling":3,"workshop":2,"munitions":2,"support":2,"materials":2}: rear.set_target(duty,{"receiving":1,"hauling":3,"workshop":2,"munitions":2,"support":2,"materials":2}[duty])
	for row in [["workshop_input","M01",4],["workshop_input","M02",3],["support_input","M02",2],["support_input","M05",2],["support_input","M10",5],["munitions_input","M01",30],["munitions_input","M03",100],["materials_input","M01",30],["materials_input","M04",70]]: rear.request_haul("receiving",row[0],row[1],row[2])
	rear.advance_time(1600)
	assert_int(rear.ledger.total_stock("E03")).is_equal(1)
	assert_int(rear.ledger.total_stock("E11")).is_equal(1)
	assert_int(rear.ledger.total_stock("M06")).is_equal(10)
	assert_int(rear.ledger.total_stock("M11")).is_equal(100)
	rear.production.request_recipe("R08")
	rear.production.set_mode("Stock target")
	rear.production.set_stock_target(1)
	rear.support_production.request_recipe("R17")
	rear.support_production.set_mode("Stock target")
	rear.support_production.set_stock_target(5)
	rear.munitions_production.request_recipe("R07")
	rear.munitions_production.set_mode("Stock target")
	rear.munitions_production.set_stock_target(10)
	assert_dict(rear.munitions_production.batch).is_empty()
	assert_int(rear.ledger.available_stock_at("munitions_input","M06")).is_zero()
	rear.request_haul("munitions_output","munitions_input","M06",10)
	rear.advance_time(300)
	assert_int(rear.ledger.total_stock("E08")).is_equal(1)
	assert_int(rear.ledger.total_stock("E17")).is_equal(5)
	assert_int(rear.ledger.total_stock("E07")).is_equal(10)
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01":64,"M02":5,"M03":100,"M04":70,"M05":2,"M06":10,"M10":5})
	assert_int(rear.munitions_production.snapshot().recipe_records.R27.history.size()).is_equal(10)
	assert_array(base.audit()).is_empty()

func test_mixed_finished_types_and_reserved_goods_do_not_satisfy_another_selected_output_minimum() -> void:
	for pair in [["R03", "R08"], ["R24", "R07"], ["R11", "R17"]]:
		var f := _component(pair[0])
		_seed(f)
		f.rear.advance_time(f.spec.work / 2.0)
		var old_type: String = f.spec.output_type
		f.owner.request_recipe(pair[1])
		f.spec = Fixed.RECIPES[pair[1]]
		f.owner.set_mode("Stock target")
		f.owner.set_stock_target(f.spec.output_count)
		assert_int(f.owner.stock_coverage().available).is_zero()
		_seed(f)
		f.rear.advance_time(f.spec.work / 2.0)
		assert_int(f.owner.stock_coverage().available).is_equal(f.spec.output_count)
		var product: String = f.owner.history[0].output_id
		f.rear.ledger.request_stock("shipment", product, 1, "manifest", "another use", "army-blue")
		_seed(f)
		f.rear.advance_time(0)
		assert_int(f.owner.stock_coverage().available).is_equal(f.spec.output_count - 1)
		assert_int(f.owner.stock_coverage().planned).is_equal(f.spec.output_count)
		assert_int(f.rear.ledger.total_stock(old_type)).is_greater(0)
		assert_int(f.owner.batch.receipt.size()).is_greater(0)
		assert_array(f.rear.audit()).is_empty()
