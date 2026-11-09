extends HBoxContainer
## Native GUI drag data contains stable IDs, never a simulation/node reference.
signal selected(id: String)
signal moved(source: String, target: String, after: bool)
signal drag_state(active: bool)
var task_id := ""
var caption: Label
var _insertion := -1.0

func setup(id: String, title: String) -> void:
	task_id = id
	custom_minimum_size.y = 38
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var grip := Control.new()
	grip.custom_minimum_size = Vector2(30,38)
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grip)
	caption = Label.new()
	caption.text = title
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	tooltip_text = "Drag the six-dot handle to change priority. Top is highest."
	focus_entered.connect(func() -> void: selected.emit(task_id); queue_redraw())
	focus_exited.connect(queue_redraw)
	mouse_exited.connect(func() -> void: _insertion = -1; queue_redraw())

func _draw() -> void:
	if has_focus(): draw_rect(Rect2(Vector2.ZERO,size),Color(0.2,0.4,0.32,0.22))
	for column in 2:
		for row in 3: draw_circle(Vector2(10+column*7,12+row*7),1.5,Color("7a8791"))
	if _insertion >= 0: draw_line(Vector2(0,_insertion),Vector2(size.x,_insertion),Color("7fc9ac"),2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		selected.emit(task_id)

func _get_drag_data(at: Vector2) -> Variant:
	if at.x > 30: return null
	selected.emit(task_id)
	drag_state.emit(true)
	var preview := Label.new()
	preview.text = caption.text
	preview.modulate = Color("b9e4d1")
	set_drag_preview(preview)
	return {"hauling_owner":get_parent().get_instance_id(),"task":task_id}

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var valid: bool = data is Dictionary and data.get("hauling_owner",-1) == get_parent().get_instance_id() and data.get("task","") != task_id
	valid = valid and get_parent().get_children().any(func(row: Node) -> bool: return row.task_id == data.get("task",""))
	_insertion = (0.0 if at.y < size.y/2 else size.y) if valid else -1.0
	queue_redraw()
	return valid

func _drop_data(at: Vector2, data: Variant) -> void:
	if not _can_drop_data(at,data): return
	moved.emit(str(data.task),task_id,at.y >= size.y/2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_insertion = -1
		drag_state.emit(false)
		queue_redraw()
