extends Node3D
## Read-only authored occupant/handler animation. Activity owns root and custody.
const Assets = preload("res://game/warehousing/warehouse_assets.gd")
var person_id := ""
var _receiving: RefCounted
var _simulation: RefCounted
var _animator: AnimationPlayer
var _clips: Dictionary = {}
var _clip: StringName = &""
var _started := 0.0
var _duration := 0.0
var _loop := false
var _on_screen := false
var root_sampler: Callable
var _clip_window := Vector2.ZERO

func bind(receiving: RefCounted, simulation: RefCounted, id: String, scene: PackedScene) -> bool:
	if _animator != null or id.is_empty() or scene == null: return false
	person_id = id
	set_meta("person_id",id)
	_receiving = receiving
	_simulation = simulation
	var instance: Node = scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return false
	var art := instance as Node3D
	Assets.prepare(art)
	add_child(art)
	var players: Array[Node] = art.find_children("*","AnimationPlayer",true,false)
	var skeletons: Array[Node] = art.find_children("*","Skeleton3D",true,false)
	if players.size() != 1 or skeletons.size() != 1:
		push_error("Supplier actor requires the accepted one-player/one-skeleton export: "+id)
		art.queue_free()
		return false
	_animator = players[0] as AnimationPlayer
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.stop(true)
	for name: StringName in _animator.get_animation_list():
		if str(name).get_file() != "RESET": _clips[StringName(str(name).get_file())] = name
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-1.2,-0.5,-1.2),Vector3(2.4,3.2,2.4))
	notifier.screen_entered.connect(_screen_entered)
	notifier.screen_exited.connect(_screen_exited)
	add_child(notifier)
	visibility_changed.connect(sync_speed)
	set_process(false)
	return true

func has_clip(name: StringName) -> bool:
	return _clips.has(name)

func clip_duration(name: StringName) -> float:
	return _animator.get_animation(_clips[name]).length if _animator != null and _clips.has(name) else 0.0

func set_activity(name: StringName, started: float, duration: float, loop: bool = false, clip_from: float = 0.0, clip_to: float = -1.0) -> bool:
	if not _clips.has(name) or not is_finite(started) or not is_finite(duration) or duration <= 0.0 or not is_finite(clip_from) or not is_finite(clip_to):
		push_error("Missing supplier clip or invalid committed timing: %s / %s" % [person_id,name])
		return false
	var length := clip_duration(name)
	var end := length if clip_to < 0.0 else clip_to
	if clip_from < 0.0 or clip_from > length+0.00001 or end < clip_from-0.00001 or end > length+0.00001:
		push_error("Supplier clip window lies outside the authored action: %s / %s" % [person_id,name])
		return false
	_clip_window = Vector2(minf(clip_from,length),minf(end,length))
	_clip = name
	_started = started
	_duration = duration
	_loop = loop
	var selected: StringName = _clips[name]
	if _animator.current_animation != selected: _animator.play(selected)
	refresh_root()
	_render_pose() # Establish the correct paused/offscreen first pose once.
	sync_speed()
	return true

func set_root(pose: Transform3D) -> void:
	# The supplied transform includes actual support height and approved visual
	# root orientation. Never derive an authoritative path from an animation.
	transform = pose

func refresh_root() -> void:
	if root_sampler.is_valid(): global_transform = root_sampler.call()

func sync_speed() -> void:
	if _animator == null or _simulation == null: return
	set_process(not _clip.is_empty() and _on_screen and is_visible_in_tree() and int(_simulation.speed) > 0)

func _process(_delta: float) -> void:
	_render_pose()

func _render_pose() -> void:
	if _animator == null or _clip.is_empty(): return
	var elapsed := maxf(0.0,float(_receiving._time)-_started)
	var phase := fposmod(elapsed,_duration)/_duration if _loop else clampf(elapsed/_duration,0.0,1.0)
	# Update-only seeking skips authored method/audio callbacks. Clips never
	# create stock, move real people or decide that a handover completed.
	_animator.seek(lerpf(_clip_window.x,_clip_window.y,phase),true,true)
	if not _loop and phase >= 1.0: set_process(false)

func _screen_entered() -> void:
	_on_screen = true
	_render_pose()
	sync_speed()

func _screen_exited() -> void:
	_on_screen = false
	sync_speed()
