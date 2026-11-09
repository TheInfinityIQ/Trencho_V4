extends Node3D
## Persistent site presentation. Only ConstructionService can earn work/complete.
const Reveal = preload("res://game/construction/visuals/build_reveal.gdshader")
const Hologram = preload("res://game/construction/visuals/build_hologram.gdshader")
const Outline = preload("res://game/construction/visuals/build_outline.gdshader")
const Celebration = preload("res://game/construction/visuals/construction_celebration.gd")
var simulation: RefCounted
var site_id: String
var exterior: Dictionary
var footprint: Vector2
var _materials: Array[ShaderMaterial] = []
var _originals: Array[Dictionary] = []
var _ghosts: Array[MeshInstance3D] = []
var _ceremony: Node3D
var _label: Label3D
var _was_unfinished := false
var _completed := false

func _ready() -> void:
	set_meta("site_id",site_id)
	var shell: Node3D = exterior.node
	shell.position = Vector3.ZERO
	add_child(shell)
	_label = Label3D.new()
	_label.position = exterior.label_anchor
	_label.pixel_size = 0.02
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_label)
	var row: Dictionary = simulation.rear.construction.instances[site_id]
	_was_unfinished = row.state in ["Awaiting M11","Building"]
	if _was_unfinished:
		_prepare_reveal(shell)
		_ceremony = Celebration.new()
		_ceremony.simulation = simulation
		_ceremony.footprint = footprint
		add_child(_ceremony)
		_ceremony.cleared.connect(func() -> void: _ceremony = null,CONNECT_ONE_SHOT)
	simulation.rear.construction.site_changed.connect(_site_changed)
	_site_changed(site_id)

func _prepare_reveal(shell: Node3D) -> void:
	var bounds: AABB = exterior.bounds
	var meshes: Array[Node] = shell.find_children("*","MeshInstance3D",true,false)
	for child: Node in meshes:
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		var outline := _shader(Outline,bounds)
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			_originals.append({"mesh":mesh,"surface":surface,"override":mesh.get_surface_override_material(surface)})
			var reveal := _shader(Reveal,bounds)
			if original is BaseMaterial3D:
				var standard := original as BaseMaterial3D
				reveal.set_shader_parameter("tint",standard.albedo_color)
				reveal.set_shader_parameter("vertex_colored",standard.vertex_color_use_as_albedo)
				if standard.albedo_texture != null:
					reveal.set_shader_parameter("albedo_map",standard.albedo_texture)
					reveal.set_shader_parameter("textured",true)
			reveal.next_pass = outline
			# Whole-mesh overrides would otherwise bypass the surface reveal.
			mesh.set_surface_override_material(surface,reveal)
		var whole: Material = mesh.material_override
		_originals.append({"mesh":mesh,"whole":whole})
		mesh.material_override = null
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh.mesh
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.material_override = _shader(Hologram,bounds)
		add_child(ghost)
		ghost.global_transform = mesh.global_transform
		_ghosts.append(ghost)

func _shader(shader: Shader, bounds: AABB) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_y",global_position.y+bounds.position.y)
	material.set_shader_parameter("height",bounds.size.y)
	_materials.append(material)
	return material

func _site_changed(id: String) -> void:
	if id != site_id: return
	var row: Dictionary = simulation.rear.construction.instances.get(site_id,{})
	if row.is_empty() or row.state in ["Cancelled","Dismantled"]:
		queue_free()
		return
	var progress: float = clampf(float(row.progress)/float(row.work),0.0,1.0)
	for material: ShaderMaterial in _materials: material.set_shader_parameter("progress",progress)
	_label.text = "%s · %s" % [site_id,str(row.kind).capitalize()]
	if row.state == "Complete":
		_label.text += " · Construction complete"
		if _was_unfinished and not _completed:
			_completed = true
			_restore_exterior()
			if is_instance_valid(_ceremony): _ceremony.start()
	else:
		_label.text += " · %s" % str(row.state).replace("M11","materials")
		if row.state in ["Awaiting M11","Building"]: _label.text += " · %d%%" % roundi(progress*100)

func reconcile() -> void:
	_site_changed(site_id)

func _restore_exterior() -> void:
	for saved: Dictionary in _originals:
		var mesh: MeshInstance3D = saved.mesh
		if saved.has("whole"): mesh.material_override = saved.whole
		else: mesh.set_surface_override_material(saved.surface,saved.override)
	for ghost: MeshInstance3D in _ghosts: ghost.queue_free()
	_ghosts.clear()
	_materials.clear()
	_originals.clear()

func sync_speed() -> void:
	if is_instance_valid(_ceremony): _ceremony.sync_speed()

func _exit_tree() -> void:
	if simulation != null and simulation.rear.construction.site_changed.is_connected(_site_changed):
		simulation.rear.construction.site_changed.disconnect(_site_changed)
