extends RefCounted
## Development acceptance budgets. A frame over budget is a failure, not an average.
const MINIMUM_FPS := 60.0
const MAX_FRAME_MS := 1000.0 / MINIMUM_FPS
const MAX_ACTION_MS := MAX_FRAME_MS

static func capped_limit(value: float, ceiling: float) -> float:
	# Direct editor/GdUnit environment settings may tighten the policy, never
	# restore the old 100 ms limit or disable it with zero/nonfinite values.
	return clampf(value,0.01,ceiling) if is_finite(value) else ceiling
