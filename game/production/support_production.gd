extends "res://game/production/selectable_production.gd"
## One F09 owner. Content access is fixed when the session is created.
const CHOICES: Array[String] = ["R11", "R12", "R15", "R16", "R17", "R18", "R20", "R21"]

func _init(rear: RefCounted, declared_access: Array[String] = []) -> void:
	super(rear, "R11", CHOICES, [], declared_access)
