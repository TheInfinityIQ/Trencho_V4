extends CanvasLayer
## One actual startup draw, behind a loading cover; no gameplay rows or physics.
const Appearance = preload("res://game/construction/visuals/construction_appearance.gd")
const Shells = preload("res://game/preview_3d/facility_shells.gd")
const TruckArt = preload("res://game/preview_3d/t01_presentation.gd")
const WarehouseAssets = preload("res://game/warehousing/warehouse_assets.gd")
var elapsed_usec := 0
var resources: Array[Resource] = []

func prepare(camera: Camera3D) -> void:
	var started: int = Time.get_ticks_usec()
	layer = 100
	var cover := ColorRect.new()
	cover.color = Color("1a252b")
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "Preparing game visuals…"
	center.add_child(label)
	var stage := Node3D.new()
	camera.add_child(stage)
	stage.position = Vector3(0,0,-3)
	stage.scale = Vector3.ONE*0.08
	# Read-only geometry descriptor, never registered in ConstructionService.
	var exterior: Dictionary = Shells.new().build({"id":"render-preparation","kind":"construction","state":"Complete","center":Vector2.ZERO,"size":Vector2(10,8),"door":Vector2(-6,0)},false,false)
	assert(exterior.ok,"Construction render preparation requires its actual exterior")
	stage.add_child(exterior.node)
	resources.append(load(str(exterior.node.get_meta("model_path"))))
	var prepared: Dictionary = Appearance.prepare(stage,exterior.node,exterior.bounds)
	for material: ShaderMaterial in prepared.materials:
		material.set_shader_parameter("progress",0.5)
		resources.append(material)
	for file: String in ["pylon","tape_half","scissors","smoke"]:
		var packed := load("res://game/construction/assets/"+file+".glb") as PackedScene
		resources.append(packed)
		var prop := packed.instantiate() as Node3D
		stage.add_child(prop)
		prop.position = Vector3(-6.0+4.0*float(prop.get_index()%4),1,8)
		var materials: Array = Appearance.fade_materials(prop)
		for material: BaseMaterial3D in materials: resources.append(material)
		if file in ["pylon","tape_half"]:
			# Warm their actual opaque vertex-colour pass as well as fade variants.
			for material: BaseMaterial3D in materials:
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				var colour := material.albedo_color
				colour.a = 1.0
				material.albedo_color = colour
		if file == "smoke":
			var meshes: Array[Node] = prop.find_children("*","MeshInstance3D",true,false)
			if prop is MeshInstance3D: meshes.push_front(prop)
			for mesh: MeshInstance3D in meshes: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Natural completion also creates its office truck. Warm its actual original
	# static textured material, not only the construction/skin/fade variants.
	var truck_scene := load(TruckArt.MODEL_PATH) as PackedScene
	resources.append(truck_scene)
	var truck := truck_scene.instantiate() as Node3D
	stage.add_child(truck)
	truck.scale = Vector3.ONE*TruckArt.MODEL_SCALE
	truck.position = Vector3(10,1,0)
	_prepare_warehouse(stage)
	_prepare_supplier_shelves(stage)
	await RenderingServer.frame_post_draw
	elapsed_usec = Time.get_ticks_usec()-started
	stage.queue_free()
	queue_free()

func _prepare_warehouse(stage: Node3D) -> void:
	# Both real opaque/glass/emissive materials and construction variants are
	# drawn behind the existing cover. No modules, fixtures or stock are granted.
	for index in 2:
		var exterior: Dictionary = WarehouseAssets.shell({"quarter_turn":false,"door":Vector2(0,9),"center":Vector2.ZERO})
		if not exterior.ok: continue
		var shell: Node3D = exterior.node
		stage.add_child(shell)
		shell.position = Vector3(-8.0+16.0*index,0,-8)
		if index == 1:
			var prepared: Dictionary = Appearance.prepare(stage,shell,exterior.bounds)
			for material: ShaderMaterial in prepared.materials:
				material.set_shader_parameter("progress",0.5)
				resources.append(material)
	for file: String in ["warehouse_crate_rack_metal_access_v02.glb","warehouse_metal_lower_cassette_v01.glb","warehouse_metal_upper_cassette_v01.glb","warehouse_long_stock_rack.glb","small_crate.glb","medium_crate.glb","metal_stock.glb","closed_keg.glb","timber_bundle.glb","textile_bale.glb","fuel_can.glb"]:
		var model := WarehouseAssets.model(file)
		if model == null: continue
		stage.add_child(model)
		model.position = Vector3(-10.0+2.5*float(model.get_index()%9),1,4)
	var light := OmniLight3D.new()
	stage.add_child(light)
	light.position = Vector3(0,4,0)
	light.omni_range = 20.0
	light.shadow_enabled = false

func _prepare_supplier_shelves(stage: Node3D) -> void:
	# Draw the actual approved opaque/skinned resources under the existing cover;
	# no person or mechanism activity is registered in the simulation.
	for file: String in ["fixture_s4_full_review_v01.glb","worker_s4_full_review_v01.glb"]:
		var packed := load("res://game/supplier_transport/assets/s4_operator/"+file) as PackedScene
		resources.append(packed)
		var model := packed.instantiate() as Node3D
		WarehouseAssets.prepare(model)
		stage.add_child(model)
		model.position = Vector3(0,0,4)
