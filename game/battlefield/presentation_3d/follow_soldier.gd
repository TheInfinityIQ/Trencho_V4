extends Node
## Camera-only following of one permitted current field-person anchor.
signal state_changed
const Persons = preload("res://game/preview_3d/field_persons.gd")
var followed_id := ""
var status := ""
var _presenter: Persons
var _camera: Camera3D
var _inspect: Callable
var _player := ""
var _anchor: Node3D
var _offset := Vector3.ZERO

func bind(presenter: Persons, camera: Camera3D, permitted_inspect: Callable, player: String) -> void:
	stop("Follow stopped: battlefield session changed.")
	_disconnect_presenter()
	_presenter = presenter
	_camera = camera
	_inspect = permitted_inspect
	_player = player
	if is_instance_valid(_presenter):
		_presenter.changed.connect(_on_person_changed)
		_presenter.removing.connect(_on_person_removing)

func start(id: String) -> bool:
	if not is_instance_valid(_presenter) or not is_instance_valid(_camera) or not _inspect.is_valid(): return false
	var row: Dictionary = _inspect.call(id)
	if row.get("kind","") != "PERSON" or row.get("owner","") != _player or bool(row.get("aboard",false)) or int(row.get("health",0)) <= 0 or not _presenter.anchors.has(id):
		status = "Cannot follow: choose a visible friendly soldier on foot."
		state_changed.emit()
		return false
	var anchor: Node3D = _presenter.anchors[id]
	if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
		status = "Cannot follow: that soldier is not visible in the battlefield."
		state_changed.emit()
		return false
	followed_id = id
	_anchor = anchor
	_offset = _camera.global_position - anchor.global_position
	status = "Following friendly soldier: "+id
	state_changed.emit()
	return true

func stop(reason: String) -> void:
	if followed_id.is_empty(): return
	followed_id = ""
	_anchor = null
	status = reason
	state_changed.emit()

func _on_person_changed(id: String) -> void:
	if id != followed_id: return
	if not is_instance_valid(_presenter) or not _presenter.anchors.has(id) or _presenter.anchors[id] != _anchor or not is_instance_valid(_anchor) or not _anchor.is_visible_in_tree() or not is_instance_valid(_camera):
		stop("Follow stopped: the selected soldier is unavailable.")
		return
	var view: Dictionary = _presenter.views.get(id,{})
	if view.is_empty() or bool(view.get("dead",false)) or int(view.get("health",0)) <= 0:
		stop("Follow stopped: the selected soldier is unavailable.")
		return
	_camera.global_position = _anchor.global_position + _offset

func _on_person_removing(id: String, anchor: Node3D) -> void:
	if id == followed_id and anchor == _anchor: stop("Follow stopped: the selected soldier boarded or became unavailable.")

func _disconnect_presenter() -> void:
	if is_instance_valid(_presenter):
		if _presenter.changed.is_connected(_on_person_changed): _presenter.changed.disconnect(_on_person_changed)
		if _presenter.removing.is_connected(_on_person_removing): _presenter.removing.disconnect(_on_person_removing)
	_presenter = null

func _exit_tree() -> void:
	_disconnect_presenter()
	_camera = null
	_anchor = null
	_inspect = Callable()
