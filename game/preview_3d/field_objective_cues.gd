extends Control
## Cached objective ownership/state labels and the same current pick points.
const Objectives = preload("res://game/preview_3d/field_objectives.gd")
var points: Dictionary[String,Vector2] = {}
var labels: Dictionary = {}
var colours: Dictionary[String,Color] = {}
var selected_id: String = ""
var _presenter: Objectives
var _camera: Camera3D
var _title: Callable
var _world_points: Dictionary[String,Vector3] = {}
var _projection_pending: bool = false
var _camera_transform: Transform3D
var _camera_projection: Projection
var _viewport_size: Vector2 = Vector2.ZERO
var _projection_valid: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func bind(presenter: Objectives, camera: Camera3D, title_formatter: Callable) -> void:
	if is_instance_valid(_presenter):
		if _presenter.changed.is_connected(_on_changed): _presenter.changed.disconnect(_on_changed)
		if _presenter.removing.is_connected(_on_removing): _presenter.removing.disconnect(_on_removing)
	points.clear()
	_world_points.clear()
	labels.clear()
	colours.clear()
	_presenter = presenter
	_camera = camera
	_title = title_formatter
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
	var view: Dictionary = _presenter.views[id]
	var lines: Array[String] = [str(_title.call(id)),"%s · %s" % [view.ownership_label,view.objective_state]]
	var colour: Color = view.ownership_colour
	if _world_points.has(id) and _world_points[id].is_equal_approx(at) and labels[id] == lines and colours[id] == colour: return
	_world_points[id] = at
	labels[id] = lines
	colours[id] = colour
	_project(id)
	queue_redraw()

func _on_removing(id: String, _anchor: Node3D) -> void:
	points.erase(id)
	_world_points.erase(id)
	labels.erase(id)
	colours.erase(id)
	queue_redraw()

func request_projection() -> void:
	if _projection_pending: return
	_projection_pending = true
	_refresh_projection.call_deferred()

func flush_projection() -> void:
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
	for id: String in _world_points: _project(id)
	queue_redraw()

func _project(id: String) -> void:
	points.erase(id)
	if not is_instance_valid(_camera): return
	var at: Vector3 = _world_points[id]
	if not at.is_finite() or _camera.is_position_behind(at): return
	var point: Vector2 = _camera.unproject_position(at)
	if point.is_finite() and get_viewport_rect().has_point(point): points[id] = point

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for id: String in points:
		var at: Vector2 = points[id]
		var colour: Color = colours[id]
		draw_arc(at,6,0,TAU,24,Color.BLACK,4,true)
		draw_arc(at,6,0,TAU,24,colour,2,true)
		if id == selected_id:
			draw_arc(at,9,0,TAU,24,Color.BLACK,4,true)
			draw_arc(at,9,0,TAU,24,colour,2,true)
		var lines: Array = labels[id]
		for index: int in lines.size():
			var text_at: Vector2 = at+Vector2(13,-12+index*18)
			draw_string_outline(font,text_at,str(lines[index]),HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color.BLACK)
			draw_string(font,text_at,str(lines[index]),HORIZONTAL_ALIGNMENT_LEFT,-1,14,colour)

func _exit_tree() -> void:
	bind(null,null,Callable())
