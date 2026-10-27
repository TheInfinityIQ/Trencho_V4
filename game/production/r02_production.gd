extends "res://game/production/fixed_production.gd"
## Fixed F05 activity: one whole 100-round R02 batch, never loaded ammunition.

const INPUTS := RECIPES.R02.inputs
const OUTPUT_MASS := 2.0


func _init(rear: RefCounted) -> void:
	super(rear, "R02")
