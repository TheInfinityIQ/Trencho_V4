extends "res://game/production/fixed_production.gd"
## Fixed F04 activity; public constants retained for the accepted R01 contract.

const INPUTS := RECIPES.R01.inputs
const OUTPUT_MASS := 4.0


func _init(rear: RefCounted) -> void:
	super(rear, "R01")
