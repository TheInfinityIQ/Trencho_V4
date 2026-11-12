extends Node3D
## Keyed warehouse presentation/collision. Never grants storage or delivered goods.
const Packages = preload("res://game/warehousing/material_packages.gd")
const Appearance = preload("res://game/construction/visuals/construction_appearance.gd")
const Assets = preload("res://game/warehousing/warehouse_assets.gd")
const SMOKE := "res://game/construction/assets/smoke.glb"
var _world: Node3D
var _model: RefCounted
var _service: RefCounted
var _modules: Dictionary = {}
var _bays: Dictionary = {}
var _pending: Dictionary = {}
var _scheduled := false
var _topology := -1
var _smoke_tweens: Dictionary = {}
var _inside: Dictionary = {}
var _cutaway_enabled := true
var _staging: Node3D

func bind(world: Node3D, model: RefCounted) -> void:
	_world = world
	_model = model
	_service = model.rear.warehouse
	set_meta("persistent_site",true)
	_service.changed.connect(_request_refresh)
	_request_refresh("")

func _request_refresh(id: String) -> void:
	_pending[id] = true
	if _scheduled: return
	_scheduled = true
	_refresh.call_deferred()

func _refresh() -> void:
	_scheduled = false
	if not is_inside_tree(): return
	var all: bool = _topology != int(_service.topology_revision) or _pending.has("")
	var pending: Dictionary = _pending
	_pending = {}
	if all:
		_topology = int(_service.topology_revision)
		for id: String in _modules.keys():
			if _service.modules.has(id): continue
			_modules[id].node.queue_free()
			_modules.erase(id)
		for id: String in _service.modules:
			if not _modules.has(id): _create_module(_service.modules[id])
			_rebuild_walls(id)
	for id: String in _service.bays:
		var bay: Dictionary = _service.bays[id]
		if bay.get("staging",false) and not _bays.has(id):
			_staging = Node3D.new()
			_staging.name = "RecoveryStaging"
			add_child(_staging)
			_world._box(_staging,Vector3(bay.center.x,0.01,bay.center.y),Vector3(6,0.02,4),Color("847b57"))
			_world._label(_staging,"TEMPORARY STORAGE",Vector3(bay.center.x,0.1,bay.center.y+1.8),0.006)
			_create_bay(bay,_staging)
		if all or pending.has(bay.module): _refresh_bay(bay)

func _create_module(module: Dictionary) -> void:
	var node := Node3D.new()
	node.name = str(module.id)
	node.set_meta("site_id",str(module.id))
	add_child(node)
	var solids := Node3D.new()
	solids.name = "WarehouseWalls"
	node.add_child(solids)
	var floor: MeshInstance3D = _world._box(node,Vector3(module.center.x,-0.1,module.center.y),Vector3(module.size.x,0.2,module.size.y),Color("8e9692"))
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2|8
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(module.size.x,4.4,module.size.y)
	shape.shape = box
	area.position = Vector3(module.center.x,2.2,module.center.y)
	area.add_child(shape)
	node.add_child(area)
	area.body_entered.connect(_module_body.bind(str(module.id),true))
	area.body_exited.connect(_module_body.bind(str(module.id),false))
	_modules[module.id] = {"node":node,"solids":solids,"floor":floor,"lit":false}
	for bay: Dictionary in _service.bays.values():
		if bay.module == module.id: _create_bay(bay,node)

func _rebuild_walls(id: String) -> void:
	var solids: Node3D = _modules[id].solids
	for child: Node in solids.get_children():
		solids.remove_child(child)
		child.queue_free()
	for box: Dictionary in _service.module_colliders(id):
		_world._box(solids,box.position,box.size,Color("b1b4a9"),true)
	_reconcile_shell(id)

func _create_bay(bay: Dictionary, parent: Node3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(bay.center.x,0,bay.center.y)
	node.rotation.y = -float(bay.rotation)
	parent.add_child(node)
	var fixtures := Node3D.new()
	fixtures.name = "Fixture"
	node.add_child(fixtures)
	var cargo := Node3D.new()
	cargo.name = "Packages"
	node.add_child(cargo)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2|8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6,1.8,1.0)
	collision.shape = shape
	area.position.y = 1.3
	area.add_child(collision)
	node.add_child(area)
	area.body_entered.connect(_slot_body.bind(str(bay.id),true))
	area.body_exited.connect(_slot_body.bind(str(bay.id),false))
	_bays[bay.id] = {"node":node,"fixture":fixtures,"cargo":cargo,"state":"","family":"","fixture_visible":false,"packages":{}}

func _refresh_bay(bay: Dictionary) -> void:
	if not _bays.has(bay.id): return
	var view: Dictionary = _bays[bay.id]
	var old_fixture: bool = bay.has("previous_family") and bay.state in ["Reserved","Preparing"]
	var visual_family: String = str(bay.previous_family) if old_fixture else str(bay.family)
	var visible_fixture: bool = old_fixture or bay.state in ["Revealed","Ready"]
	if view.fixture_visible != visible_fixture or view.family != visual_family:
		for child: Node in view.fixture.get_children():
			view.fixture.remove_child(child)
			child.queue_free()
		if visible_fixture: _fixture(view.fixture,visual_family)
		view.fixture_visible = visible_fixture
	if bay.state == "Preparing" and view.state != "Preparing": _smoke(bay,view.node)
	view.state = bay.state
	view.family = visual_family
	var present := {}
	for index in bay.cells.size():
		var cell: Dictionary = bay.cells[index]
		var quantity: int = _service._cell_quantity(cell)
		if quantity <= 0: continue
		present[index] = true
		var code: String = str(cell.code)
		if view.packages.has(index) and view.packages[index].code != code:
			view.packages[index].node.queue_free()
			view.packages.erase(index)
		if not view.packages.has(index):
			var node := Node3D.new()
			node.position = cell.offset
			view.cargo.add_child(node)
			var dimensions: Vector3 = Packages.TYPES[code].size
			var visual: Node3D = Assets.model(Packages.model_file(code))
			var labels: Array[Label3D] = []
			if visual != null:
				node.add_child(visual)
				for marker_name: String in ["Quantity_Label_Front","Quantity_Label_Back"]:
					var marker := visual.find_child(marker_name,true,false) as Node3D
					if marker == null: continue
					var label := Label3D.new()
					label.pixel_size = 0.0015
					label.font_size = 24
					marker.add_child(label)
					labels.append(label)
			else: _world._box(node,Vector3(0,dimensions.y/2.0,0),dimensions,Color("a3865e"))
			if labels.is_empty(): labels.append(_world._label(node,"",Vector3(0,dimensions.y+0.08,0),0.004))
			var body := StaticBody3D.new()
			node.add_child(body)
			_shape(body,Vector3(0,dimensions.y/2.0,0),dimensions)
			view.packages[index] = {"node":node,"labels":labels,"code":code}
		for label: Label3D in view.packages[index].labels: label.text = Packages.label(code,quantity)
	for index: int in view.packages.keys():
		if present.has(index): continue
		view.packages[index].node.queue_free()
		view.packages.erase(index)

func _fixture(parent: Node3D, family: String) -> void:
	var visual := Assets.model("warehouse_long_stock_rack.glb" if family == "timber" else "warehouse_crate_rack_metal_access_v02.glb")
	if visual != null:
		parent.add_child(visual)
		if family != "timber":
			Assets.add_static_collision(visual)
			return
	for x: float in [-1.27,1.27]:
		for z: float in [-0.47,0.47]:
			if visual == null: _world._box(parent,Vector3(x,0.9,z),Vector3(0.06,1.8,0.06),Color("536363"))
	for y: float in [0.25,0.95]:
		if family == "timber":
			for x: float in [-0.25,0.25]:
				if visual == null: _world._box(parent,Vector3(x,y-0.03,0),Vector3(0.08,0.06,0.9),Color("536363"))
		elif visual == null: _world._box(parent,Vector3(0,y-0.015,0),Vector3(2.5,0.03,0.9),Color("697879"))
	var body := StaticBody3D.new()
	parent.add_child(body)
	for x: float in [-1.27,1.27]:
		for z: float in [-0.47,0.47]: _shape(body,Vector3(x,0.9,z),Vector3(0.06,1.8,0.06))
	for y: float in [0.25,0.95]:
		if family == "timber":
			for x: float in [-0.25,0.25]: _shape(body,Vector3(x,y-0.03,0),Vector3(0.10,0.06,0.9))
		else: _shape(body,Vector3(0,y-0.015,0),Vector3(2.5,0.03,0.9))

func _shape(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.position = at
	collision.shape = shape
	body.add_child(collision)

func _smoke(bay: Dictionary, parent: Node3D) -> void:
	var scene: PackedScene = load(SMOKE) as PackedScene
	var puff := scene.instantiate() as Node3D
	puff.position.y = 0.65
	parent.add_child(puff)
	var materials: Array = Appearance.fade_materials(puff)
	puff.scale = Vector3.ONE*0.15
	var tween := create_tween().set_parallel(true)
	tween.tween_property(puff,"scale",Vector3(2.7,1.9,1.9),1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_smoke_alpha.bind(materials),0.0,0.85,0.2)
	tween.tween_method(_smoke_alpha.bind(materials),0.85,0.0,0.5).set_delay(1.0)
	tween.chain().tween_callback(puff.queue_free)
	_smoke_tweens[bay.id] = tween
	sync_speed()

func _smoke_alpha(alpha: float, materials: Array) -> void:
	for material: BaseMaterial3D in materials:
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color

func sync_speed() -> void:
	for id: String in _smoke_tweens.keys():
		var tween: Tween = _smoke_tweens[id]
		if not tween.is_valid():
			_smoke_tweens.erase(id)
			continue
		if _model.speed == 0: tween.pause()
		else:
			tween.set_speed_scale(float(_model.speed))
			tween.play()

func _slot_body(body: Node3D, id: String, inside: bool) -> void:
	_service.set_slot_body(id,body.get_instance_id(),inside)

func _module_body(body: Node3D, id: String, inside: bool) -> void:
	_service.set_module_body(id,body.get_instance_id(),inside)
	if not _inside.has(id): _inside[id] = {}
	if inside: _inside[id][body.get_instance_id()] = true
	else: _inside[id].erase(body.get_instance_id())
	_reconcile_shell(id)

func set_cutaway_enabled(enabled: bool) -> void:
	if _cutaway_enabled == enabled: return
	_cutaway_enabled = enabled
	for id: String in _modules: _reconcile_shell(id)

func _reconcile_shell(id: String) -> void:
	if not _service.modules.has(id) or not _world._site_visuals.has(id): return
	var shell: Node3D = _world._site_visuals[id].exterior.node
	var visual: Node3D = shell.get_meta("warehouse_model",null) as Node3D
	if visual == null: return
	if _modules.has(id):
		_modules[id].floor.hide()
		for wall: Node3D in _modules[id].solids.get_children(): wall.hide()
		if not _modules[id].lit:
			# Actual authored fixture anchors, transformed with the whole module.
			# Bounded range and no dynamic shadow maps keep joined modules local.
			for index in 8:
				var marker := visual.find_child("Light_Anchor_%02d" % index,true,false) as Node3D
				if marker == null: continue
				var light := OmniLight3D.new()
				light.position = _modules[id].node.to_local(marker.global_position)
				# Farthest central floor point is~5.73m from its nearest
				# ceiling anchor; leave coverage across the walking aisle.
				light.omni_range = 6.5
				light.light_color = Color("fff0cb")
				light.light_energy = 0.55
				light.shadow_enabled = false
				_modules[id].node.add_child(light)
			_modules[id].lit = true
	var hidden: Dictionary = _service.hidden_boundaries(id)
	for name: String in ["Boundary_Front","Boundary_Back","Boundary_Left","Boundary_Right"]:
		var group := visual.find_child(name,true,false) as Node3D
		if group != null: group.visible = not hidden.has(name)
	var roof := visual.find_child("Roof",true,false) as Node3D
	if roof != null: roof.visible = not _cutaway_enabled or _inside.get(id,{}).is_empty()

func _exit_tree() -> void:
	if _service != null and _service.changed.is_connected(_request_refresh): _service.changed.disconnect(_request_refresh)
