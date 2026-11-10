extends Node3D
## Persistent site presentation. Only ConstructionService can earn work/complete.
const Appearance = preload("res://game/construction/visuals/construction_appearance.gd")
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
	var prepared: Dictionary = Appearance.prepare(self,shell,exterior.bounds)
	_materials = prepared.materials
	_originals = prepared.originals
	_ghosts = prepared.ghosts

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
			_finish_reveal()
			if is_instance_valid(_ceremony): _ceremony.start()
	else:
		_label.text += " · %s" % str(row.state).replace("M11","materials")
		if row.state in ["Awaiting M11","Building"]: _label.text += " · %d%%" % roundi(progress*100)

func reconcile() -> void:
	_site_changed(site_id)

func _finish_reveal() -> void:
	for saved: Dictionary in _originals:
		var mesh: MeshInstance3D = saved.mesh
		# The warehouse has actual glass and illuminated lamp surfaces. Its
		# originals are explicitly drawn at startup before this completion swap.
		if bool(exterior.get("warehouse",false)):
			if saved.has("whole"): mesh.material_override = saved.whole
			else: mesh.set_surface_override_material(saved.surface,saved.override)
			continue
		if saved.has("whole"): continue
		# Keep the already rendered full-height material. Swapping back to an
		# unseen StandardMaterial at completion compiles new OpenGL variants.
		var material := mesh.get_surface_override_material(saved.surface) as ShaderMaterial
		if material != null: material.next_pass = null
	for ghost: MeshInstance3D in _ghosts: ghost.queue_free()
	_ghosts.clear()
	_materials.clear()
	_originals.clear()

func sync_speed() -> void:
	if is_instance_valid(_ceremony): _ceremony.sync_speed()

func _exit_tree() -> void:
	if simulation != null and simulation.rear.construction.site_changed.is_connected(_site_changed):
		simulation.rear.construction.site_changed.disconnect(_site_changed)
