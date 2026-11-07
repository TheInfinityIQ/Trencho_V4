extends "res://game/staffing/rear_simulation.gd"
## Deterministic budget-exhaustion stimulus; never loaded by ordinary gameplay.
var settle_delay_usec := 0
var delayed_settlements := 0

func _init() -> void:
	super("Empty",false,true)

func _settle() -> void:
	if settle_delay_usec > 0:
		OS.delay_usec(settle_delay_usec)
		delayed_settlements += 1
	super._settle()
