extends CanvasLayer
## One actual startup draw, behind a loading cover; no gameplay rows or physics.
const Appearance = preload("res://game/construction/visuals/construction_appearance.gd")
const Shells = preload("res://game/preview_3d/facility_shells.gd")
const TruckArt = preload("res://game/preview_3d/t01_presentation.gd")
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
	label.text = "Preparing construction visuals…"
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
	# The personal pickup can start outside the manager's first view as well.
	var personal_scene := load("res://game/player_vehicle/assets/pickup.glb") as PackedScene
	resources.append(personal_scene)
	var personal := personal_scene.instantiate() as Node3D
	stage.add_child(personal)
	personal.position = Vector3(-10,1,8)
	await RenderingServer.frame_post_draw
	elapsed_usec = Time.get_ticks_usec()-started
	stage.queue_free()
	queue_free()
