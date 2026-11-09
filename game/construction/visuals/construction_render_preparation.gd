extends CanvasLayer
## One actual startup draw, behind a loading cover; no gameplay rows or physics.
const Appearance = preload("res://game/construction/visuals/construction_appearance.gd")
const Shells = preload("res://game/preview_3d/facility_shells.gd")
var elapsed_usec := 0

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
	var prepared: Dictionary = Appearance.prepare(stage,exterior.node,exterior.bounds)
	for material: ShaderMaterial in prepared.materials: material.set_shader_parameter("progress",0.5)
	for file: String in ["pylon","tape_half","scissors","smoke"]:
		var prop := (load("res://game/construction/assets/"+file+".glb") as PackedScene).instantiate() as Node3D
		stage.add_child(prop)
		prop.position.x = -1.5+float(prop.get_index()%4)
		var materials: Array = Appearance.fade_materials(prop)
		if file in ["pylon","tape_half"]:
			# Warm their actual opaque vertex-colour pass as well as fade variants.
			for material: BaseMaterial3D in materials:
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				var colour := material.albedo_color
				colour.a = 1.0
				material.albedo_color = colour
		if file == "smoke":
			for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await RenderingServer.frame_post_draw
	elapsed_usec = Time.get_ticks_usec()-started
	stage.queue_free()
	queue_free()
