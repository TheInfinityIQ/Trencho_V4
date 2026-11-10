extends RefCounted
## Whole-kilogram cargo units and physical OUTER envelopes, not literal item counts.
## Local X = package length, Y = height, Z = depth; dimensions are metres.
const TYPES: Dictionary = {
	"M01":{"name":"Metal","kg":25,"size":Vector3(0.60,0.06,0.20),"shape":"stock"},
	"M02":{"name":"Components","kg":24,"size":Vector3(0.40,0.24,0.30),"shape":"crate"},
	"M03":{"name":"Gunpowder","kg":25,"size":Vector3(0.40,0.50,0.40),"shape":"keg"},
	"M04":{"name":"Timber","kg":50,"size":Vector3(2.00,0.24,0.32),"shape":"timber"},
	"M05":{"name":"Textiles","kg":25,"size":Vector3(0.60,0.40,0.40),"shape":"bale"},
	"M06":{"name":"Explosives","kg":24,"size":Vector3(0.40,0.24,0.30),"shape":"crate"},
	"M07":{"name":"Electronics","kg":16,"size":Vector3(0.60,0.32,0.40),"shape":"crate"},
	"M08":{"name":"Fuel","kg":20,"size":Vector3(0.40,0.42,0.30),"shape":"can"},
	"M09":{"name":"Medical compound","kg":16,"size":Vector3(0.40,0.24,0.30),"shape":"crate"},
	"M10":{"name":"Battery cells","kg":24,"size":Vector3(0.40,0.24,0.30),"shape":"crate"},
	"M11":{"name":"Building Materials","kg":24,"size":Vector3(0.60,0.32,0.40),"shape":"crate"},
}
const PLANK_SIZE := Vector3(2.00,0.05,0.15)
const MODELS := {"M01":"metal_stock.glb","M03":"closed_keg.glb","M04":"timber_bundle.glb","M05":"textile_bale.glb","M08":"fuel_can.glb"}

static func model_file(code: String) -> String:
	if MODELS.has(code): return str(MODELS[code])
	return "medium_crate.glb" if TYPES[code].size.x > 0.5 else "small_crate.glb"

static func capacity(code: String) -> int:
	return int(TYPES.get(code,{}).get("kg",0))

static func fixture_family(code: String) -> String:
	return "timber" if code == "M04" else "crates" if TYPES.has(code) else ""

static func split(code: String, quantity: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var limit := capacity(code)
	if quantity <= 0 or limit <= 0: return result
	var remaining := quantity
	while remaining > 0:
		var amount := mini(limit,remaining)
		result.append({"code":code,"quantity":amount,"capacity":limit,"size":TYPES[code].size})
		remaining -= amount
	return result

static func label(code: String, quantity: int) -> String:
	return "%s: %d / %d kg" % [str(TYPES.get(code,{}).get("name",code)),quantity,capacity(code)]
