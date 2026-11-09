extends Node3D
## Presentation only: clips follow committed activity; they never move game state.
@export var soldier := false
@export var carry_bone: StringName = &"RightHand"
@export var carry_transform := Transform3D.IDENTITY
@export var rifle_transform := Transform3D.IDENTITY
var simulation: RefCounted
var animation_enabled := true
var animator: AnimationPlayer
var skeleton: Skeleton3D
var clips: Dictionary[StringName,StringName] = {}
var action: StringName = &""
var _base_action: StringName = &"idle"
var _phase_started := 0.0
var _phase_seconds := 0.0
var _motion_speed := 0.0
var _shot := false
var _on_screen := false
var _carry: MeshInstance3D
var _rifle: Node3D
const LOOPS: Array[StringName] = [&"idle",&"walk",&"run",&"carry_walk",&"carry_idle",&"construct",&"wounded"]

func _ready() -> void:
	var players := find_children("*","AnimationPlayer",true,false)
	var bones := find_children("*","Skeleton3D",true,false)
	assert(players.size() == 1 and bones.size() == 1,"Character export requires one animator and skeleton")
	animator = players[0] as AnimationPlayer
	skeleton = bones[0] as Skeleton3D
	animator.stop(true)
	animator.playback_default_blend_time = 0.12
	for name: StringName in animator.get_animation_list():
		var key: StringName = StringName(str(name).get_file())
		if key == &"RESET": continue
		if key == &"wounded_idle": key = &"wounded"
		clips[key] = name
		# Clip resources are shared and immutable during playback. Configure the
		# same declared loop semantics once; do not duplicate keys per person.
		var clip: Animation = animator.get_animation(name)
		clip.loop_mode = Animation.LOOP_LINEAR if key in LOOPS else Animation.LOOP_NONE
	var required: Array = [&"idle",&"walk",&"run",&"fire",&"death",&"wounded"] if soldier else [&"idle",&"walk",&"carry_idle",&"carry_walk",&"pickup",&"unload",&"construct"]
	for key: StringName in required: assert(clips.has(key),"Required authored clip missing: "+str(key))
	assert(skeleton.find_bone(carry_bone) >= 0,"Required hand attachment bone missing")
	animator.animation_finished.connect(_animation_finished)
	var socket := BoneAttachment3D.new()
	socket.name = "HandSocket"
	socket.bone_name = carry_bone
	skeleton.add_child(socket)
	_carry = MeshInstance3D.new()
	_carry.name = "CarriedCargo"
	var box := BoxMesh.new()
	box.size = Vector3.ONE*0.35
	_carry.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b79b69")
	material.roughness = 1.0
	_carry.material_override = material
	_carry.transform = carry_transform
	_carry.visible = false
	socket.add_child(_carry)
	_bind_cargo_tracks()
	if soldier:
		_rifle = (load("res://game/characters/assets/rifle.glb") as PackedScene).instantiate()
		_rifle.transform = rifle_transform
		_rifle.visible = false
		socket.add_child(_rifle)
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.7,0,-0.7),Vector3(1.4,2.4,1.4))
	notifier.screen_entered.connect(_screen_entered)
	notifier.screen_exited.connect(_screen_exited)
	add_child(notifier)
	visibility_changed.connect(sync_playback)
	_play(&"idle")
	animator.advance(0.0) # Correct first paused-frame pose, including hidden views.
	sync_playback()

func set_activity(next: StringName, motion_speed: float = 0.0, started: float = -1.0, seconds: float = 0.0) -> void:
	_base_action = next
	_motion_speed = motion_speed
	_phase_seconds = seconds
	if next != action or started >= 0.0: _phase_started = started if started >= 0.0 else simulation.rear.time
	if next in [&"death",&"wounded"]: _shot = false
	if not _shot: _play(next)
	sync_playback()

func set_cargo(count: int) -> void:
	# A pickup's already-claimed source parcel becomes visible at contact;
	# its actual custody still changes only at the service's2s boundary.
	if action == &"pickup": return
	_carry.visible = count > 0 and action not in [&"death",&"wounded"]

func _bind_cargo_tracks() -> void:
	var animation_root: Node = animator.get_node(animator.root_node)
	var path := NodePath(str(animation_root.get_path_to(_carry))+":visible")
	for key: StringName in clips:
		var clip: Animation = animator.get_animation(clips[key])
		if clip.find_track(path,Animation.TYPE_VALUE) >= 0: continue
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track,path)
		clip.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
		clip.track_insert_key(track,0.0,key in [&"carry_idle",&"carry_walk",&"unload"])
		if key == &"pickup": clip.track_insert_key(track,clip.length*0.5,true)

func set_armed(armed: bool) -> void:
	if _rifle != null: _rifle.visible = armed and _base_action not in [&"death",&"wounded"]

func fire() -> void:
	if _base_action in [&"death",&"wounded"] or not clips.has(&"fire"): return
	_shot = true
	_phase_started = simulation.rear.time
	# An actual shot may restart the visible recoil; animation changes no ammo.
	animator.stop(true)
	action = &""
	_play(&"fire")
	sync_playback()

func _play(next: StringName) -> void:
	if action == next and animator.assigned_animation == clips.get(next,&""): return
	assert(clips.has(next),"Missing authored character clip: "+str(next))
	action = next
	animator.play(clips[next])
	animator.advance(0.0)

func sync_playback() -> void:
	if animator == null or simulation == null: return
	var rate := 1.0
	if action in [&"walk",&"run",&"carry_walk"]:
		var nominal := 1.2 if action == &"carry_walk" else (2.75 if action == &"run" else 1.5)
		rate = maxf(0.01,_motion_speed/nominal)
	elif _phase_seconds > 0.0 and action in [&"pickup",&"unload"]:
		rate = animator.get_animation(clips[action]).length/_phase_seconds
	animator.speed_scale = float(simulation.speed)*rate
	animator.active = animation_enabled and _on_screen and is_visible_in_tree()
	if not animation_enabled and action in [&"death",&"wounded"]:
		animator.seek(animator.get_animation(clips[action]).length,true,true)

func _screen_entered() -> void:
	_on_screen = true
	# Hidden scenes do not spend bone-evaluation work; resume the real timed
	# phase rather than replaying an old pickup/death from its beginning.
	var clip: Animation = animator.get_animation(clips[action])
	var elapsed: float = maxf(0.0,simulation.rear.time-_phase_started)
	if action not in LOOPS: animator.seek(minf(elapsed,clip.length),true,true)
	sync_playback()

func _screen_exited() -> void:
	_on_screen = false
	sync_playback()

func _animation_finished(_name: StringName) -> void:
	if not _shot: return # Pickup/death hold until their actual activity changes.
	_shot = false
	_play(_base_action)
	sync_playback()
