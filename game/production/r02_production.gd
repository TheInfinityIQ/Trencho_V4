extends "res://game/production/selectable_production.gd"
## One exclusive F05 owner, retaining its accepted defaults and shell diagnostics.
const INPUTS := RECIPES.R02.inputs
const REQUIRED_WORK := 40.0
const OUTPUT_MASS := 2.0
const CHOICES: Array[String] = ["R02", "R27", "R32", "R33", "R07", "R14", "R24"]

func _init(rear: RefCounted, declared_access: Array[String] = []) -> void:
	super(rear, "R02", CHOICES, ["R02", "R27"], declared_access)

func snapshot() -> Dictionary:
	var view := super.snapshot()
	view.declared_shell_access = _declared_access.filter(func(id: String) -> bool: return id in ["R32", "R33"])
	return view
