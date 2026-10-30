extends RefCounted
## GDD 13.3 bridge dimensions and per-metre commitments.

const SPECS := {
	"B01": {"name":"Footbridge","width":2.0,"span":20,"load":1000.0,"m11":10,"work":10,"base_health":800,"health_per_m":20,"classes":[0]},
	"B02": {"name":"Light road bridge","width":6.0,"span":30,"load":10000.0,"m11":40,"work":20,"base_health":2000,"health_per_m":50,"classes":[0,1]},
	"B03": {"name":"Heavy road bridge","width":8.0,"span":60,"load":80000.0,"m11":80,"work":40,"base_health":4000,"health_per_m":100,"classes":[0,1,2]},
}
