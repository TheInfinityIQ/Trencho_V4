extends "res://game/production/selectable_production.gd"
## One exclusive F04 owner; essential R01/R08 and copied scenario access.
const INPUTS := RECIPES.R01.inputs
const REQUIRED_WORK := 40.0
const OUTPUT_MASS := 4.0
const CHOICES: Array[String] = ["R01", "R03", "R04", "R05", "R06", "R08", "R19"]

func _init(rear: RefCounted, declared_access: Array[String] = []) -> void:
	super(rear, "R01", CHOICES, ["R01", "R08"], declared_access)
