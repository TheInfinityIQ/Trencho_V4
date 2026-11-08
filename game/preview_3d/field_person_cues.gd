extends Control
## Screen primitives use cached permitted anchors, never ledger or holder reads.
const Persons = preload("res://game/preview_3d/field_persons.gd")
const CUE_RADIUS: float = 6.0
const NEAR_SIZE: float = 40.0
var points: Dictionary[String,Vector2] = {}
var selected_id: String = ""
var near_view: bool = false
var _presenter: Persons
var _camera: Camera3D
var _world_points: Dictionary[String,Vector3] = {}
var _status: Dictionary = {}
var _projection_pending: bool = false
var _camera_transform: Transform3D
var _camera_projection: Projection
var _viewport_size: Vector2 = Vector2.ZERO
var _projection_valid: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func bind(presenter: Persons, camera: Camera3D) -> void:
	if is_instance_valid(_presenter):
		if _presenter.changed.is_connected(_on_changed): _presenter.changed.disconnect(_on_changed)
		if _presenter.removing.is_connected(_on_removing): _presenter.removing.disconnect(_on_removing)
	points.clear()
	_world_points.clear()
	_status.clear()
	_presenter = presenter
	_camera = camera
	near_view = is_instance_valid(_camera) and _camera.size <= NEAR_SIZE
	_projection_valid = false
	if _presenter != null:
		_presenter.changed.connect(_on_changed)
		_presenter.removing.connect(_on_removing)
		for id: String in _presenter.anchors: _on_changed(id)
	request_projection()
	queue_redraw()

func set_selected(id: String) -> void:
	if selected_id == id: return
	selected_id = id
	queue_redraw()

func _on_changed(id: String) -> void:
	if not is_instance_valid(_presenter) or not _presenter.anchors.has(id): return
	var at: Vector3 = _presenter.anchors[id].global_position
	var row: Dictionary = _presenter.views[id]
	var status: Array = [row.assignment,bool(row.dead),bool(row.caution)]
	if _world_points.has(id) and _world_points[id].is_equal_approx(at) and _status[id] == status: return
	_world_points[id] = at
	_status[id] = status
	_project(id)
	queue_redraw()

func _on_removing(id: String, _anchor: Node3D) -> void:
	points.erase(id)
	_world_points.erase(id)
	_status.erase(id)
	queue_redraw()

func request_projection() -> void:
	if _projection_pending: return
	_projection_pending = true
	_refresh_projection.call_deferred()

func flush_projection() -> void:
	# Picking and drawing share this current-camera visibility/projection cache.
	_refresh_projection()

func _refresh_projection() -> void:
	_projection_pending = false
	if not is_inside_tree() or not is_instance_valid(_camera): return
	var at: Transform3D = _camera.get_camera_transform()
	var projection: Projection = _camera.get_camera_projection()
	var viewport_size: Vector2 = get_viewport_rect().size
	if _projection_valid and _camera_transform == at and _camera_projection == projection and _viewport_size == viewport_size: return
	_camera_transform = at
	_camera_projection = projection
	_viewport_size = viewport_size
	_projection_valid = true
	near_view = _camera.size <= NEAR_SIZE
	for id: String in _world_points: _project(id)
	queue_redraw()

func _project(id: String) -> void:
	points.erase(id)
	if _camera == null or not is_instance_valid(_camera): return
	var at: Vector3 = _world_points[id]
	if not at.is_finite() or _camera.is_position_behind(at): return
	var point: Vector2 = _camera.unproject_position(at)
	if point.is_finite() and get_viewport_rect().has_point(point): points[id] = point

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for id: String in points:
		var at: Vector2 = points[id]
		var status: Array = _status[id]
		var colour: Color = Color("aeb6bd") if status[1] else (Color("f4cd7c") if status[2] else Color("81d1e6"))
		var diamond: PackedVector2Array = PackedVector2Array([at+Vector2(0,-CUE_RADIUS),at+Vector2(CUE_RADIUS,0),at+Vector2(0,CUE_RADIUS),at+Vector2(-CUE_RADIUS,0)])
		var outline: PackedVector2Array = diamond.duplicate()
		outline.append(diamond[0])
		draw_polyline(outline,Color.BLACK,3.0,true)
		if status[1] or near_view: draw_polyline(outline,colour,1.5,true)
		else: draw_colored_polygon(diamond,colour)
		if id != selected_id: continue
		draw_arc(at,9,0,TAU,24,Color.BLACK,4,true)
		draw_arc(at,9,0,TAU,24,colour,2,true)
		var lines: Array[String] = ["Friendly person · "+id,str(status[0])]
		for index: int in lines.size():
			var text_at: Vector2 = at+Vector2(13,-12+index*20)
			draw_string(font,text_at+Vector2.ONE,lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.BLACK)
			draw_string(font,text_at,lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,16,colour)

func _exit_tree() -> void:
	bind(null,null)
