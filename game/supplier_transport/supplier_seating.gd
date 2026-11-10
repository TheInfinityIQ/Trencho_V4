extends RefCounted
## Retained v02 manifests: metres, Body_Pivot restY1.0. These are positions,
## not proof that a standing person can pass opposing occupied seats.
const ROW_Z: Array[float] = [0.90,1.62,2.34,3.06]
const EXIT_ORDER: Array[int] = [3,7,2,6,1,5,0,4]
const DRIVER := Vector3(-0.45,1.40,-0.23)

static func seat(index: int) -> Dictionary:
	assert(index >= 0 and index < 8)
	var left := index < 4
	return {"marker":"Passenger_Seat_%s_%02d" % ["Left" if left else "Right",index%4+1],
		"hip":Vector3(-0.73 if left else 0.73,1.427,ROW_Z[index%4]),
		"facing":-PI/2.0 if left else PI/2.0}
