extends RefCounted
## GDD 13.2 S01–S12 fixed field specifications.
const SPECS := {
	"S01":{"name":"Trench","size":Vector2(20,2),"m11":100,"work":200.0,"health":1500,"occupants":8},
	"S02":{"name":"Sandbags","size":Vector2(10,1),"m11":25,"work":60.0,"health":500,"occupants":0},
	"S03":{"name":"Bunker","size":Vector2(8,6),"m11":300,"work":400.0,"health":3000,"occupants":8},
	"S04":{"name":"Wire","size":Vector2(20,2),"m11":20,"work":40.0,"health":250,"occupants":0},
	"S05":{"name":"Vehicle obstacle","size":Vector2(10,4),"m11":150,"work":180.0,"health":1800,"occupants":0},
	"S06":{"name":"Forward cache","size":Vector2(6,6),"m11":100,"work":150.0,"health":600,"occupants":16,"storage_kg":2000.0},
	"S07":{"name":"Forward supply depot","size":Vector2(12,12),"m11":300,"work":480.0,"health":1500,"occupants":0,"storage_kg":10000.0,"berths":2},
	"S08":{"name":"Aid post","size":Vector2(8,8),"m11":150,"work":200.0,"health":800,"occupants":8},
	"S09":{"name":"Repair point","size":Vector2(10,10),"m11":200,"work":240.0,"health":1200,"occupants":0,"bays":1},
	"S10":{"name":"Lookout post","size":Vector2(4,4),"m11":60,"work":120.0,"health":600,"occupants":1},
	"S11":{"name":"Road segment","size":Vector2(20,6),"m11":40,"work":80.0,"health":0,"occupants":0},
	"S12":{"name":"Causeway segment","size":Vector2(20,6),"m11":100,"work":160.0,"health":1200,"occupants":0,"load_kg":8000.0},
}
