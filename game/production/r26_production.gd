extends "res://game/production/fixed_production.gd"
## Fixed pre-existing F13 owner; manufacturing materials does not construct buildings.

const INPUTS := RECIPES.R26.inputs
const REQUIRED_WORK := 100.0
const OUTPUT_MASS := 100.0


func _init(rear: RefCounted) -> void:
	super(rear, "R26")
