extends Node3D
## Read-only paired shelf/operator export; Receiving owns deadlines and people.
const ActorView = preload("res://game/supplier_transport/supplier_actor_view.gd")
const Shelves = preload("res://game/supplier_transport/supplier_shelves.gd")
const Assets = preload("res://game/warehousing/warehouse_assets.gd")
const ROOT := "res://game/supplier_transport/assets/s4_operator/"
static var _fixture_scene: PackedScene
static var _worker_scene: PackedScene
var _receiving: RefCounted
var _model: RefCounted
var _player: AnimationPlayer
var _clip: StringName
var _actor: ActorView
var _state := ""
var _started := 0.0
var _visible_on_screen := false

func bind(receiving: RefCounted, model: RefCounted) -> void:
	_receiving = receiving
	_model = model
	if _fixture_scene == null: _fixture_scene = load(ROOT+"fixture_s4_full_review_v01.glb") as PackedScene
	if _worker_scene == null: _worker_scene = load(ROOT+"worker_s4_full_review_v01.glb") as PackedScene
	var fixture := _fixture_scene.instantiate() as Node3D
	Assets.prepare(fixture)
	add_child(fixture)
	_player = fixture.find_child("AnimationPlayer",true,false) as AnimationPlayer
	assert(_player != null,"Approved S4 fixture requires its actual AnimationPlayer")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name: StringName in _player.get_animation_list():
		if str(name).get_file() == "fixture_s4_full_review_v01": _clip = name
	assert(not _clip.is_empty(),"Approved S4 full fixture clip is missing")
	_player.play(_clip)
	# The approved moving fixture excludes the original travel restraints.
	# Preserve their actual meshes/transforms, with the existing unlock visibility.
	var original := (load("res://game/supplier_transport/assets/s4_protectedcargo_v01.glb") as PackedScene).instantiate() as Node3D
	Assets.prepare(original)
	add_child(original)
	for restraint: Node in original.find_children("Restraint_*","MeshInstance3D",true,false):
		restraint.reparent(self,true)
	original.queue_free()
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-1.2,0,-0.5),Vector3(2.4,2.5,1.0))
	notifier.screen_entered.connect(_entered)
	notifier.screen_exited.connect(_exited)
	add_child(notifier)
	visibility_changed.connect(sync_speed)
	set_process(false)

func refresh(row: Dictionary) -> void:
	var state := str(row.get("state","Closed"))
	var started := float(row.get("started",0.0))
	if state == _state and is_equal_approx(started,_started): return
	_state = state
	_started = started
	if _actor != null:
		_actor.hide()
		_actor.queue_free()
		_actor = null
	if _state in ["Opening","Closing"]:
		_actor = ActorView.new()
		add_child(_actor)
		assert(_actor.bind(_receiving,_model,str(row.operator),_worker_scene),"Approved S4 operator failed to bind")
		var begin := Shelves.CLOSE_START if _state == "Closing" else 0.0
		var end := Shelves.CLOSE_END if _state == "Closing" else Shelves.OPEN_END
		_actor.set_activity(&"worker_s4_full_review_v01",_started,end-begin,false,begin,end)
	_render()
	sync_speed()

func sync_speed() -> void:
	if _model == null: return
	if _actor != null: _actor.sync_speed()
	set_process(_visible_on_screen and is_visible_in_tree() and int(_model.speed) > 0 and _state in ["Opening","Closing"])

func _render() -> void:
	var seconds := 0.0
	if _state == "Parked": seconds = Shelves.OPEN_END
	elif _state == "Opening": seconds = minf(Shelves.OPEN_END,maxf(0.0,float(_receiving._time)-_started))
	elif _state == "Closing": seconds = minf(Shelves.CLOSE_END,Shelves.CLOSE_START+maxf(0.0,float(_receiving._time)-_started))
	_player.seek(seconds,true,true)

func _process(_delta: float) -> void:
	_render()

func _entered() -> void:
	_visible_on_screen = true
	_render()
	sync_speed()

func _exited() -> void:
	_visible_on_screen = false
	sync_speed()
