extends RefCounted
## GDD 5.1/5.2 purchase catalogue and deterministic per-vehicle quotes.

const TRUCK_KG: int = 5000
const TRANSPORT_FEE: int = 20
const MATERIALS: Dictionary = {
	"M01": {"name": "Metal", "price": 2},
	"M02": {"name": "Components", "price": 4},
	"M03": {"name": "Gunpowder", "price": 1},
	"M04": {"name": "Timber", "price": 1},
	"M05": {"name": "Textiles", "price": 2},
	"M07": {"name": "Electronics", "price": 12},
	"M08": {"name": "Fuel", "price": 2},
	"M09": {"name": "Medical compound", "price": 6},
	"M10": {"name": "Battery cells", "price": 8},
}


static func quote(cart: Dictionary, vehicle_limit: int) -> Dictionary:
	if cart.is_empty() or vehicle_limit <= 0:
		return _reject("EMPTY_ORDER", "Select at least one purchased resource and an available delivery place.")
	var total_kg: int = 0
	for code in cart:
		if typeof(code) != TYPE_STRING or not MATERIALS.has(code):
			return _reject("NOT_PURCHASABLE", "Buy M01–M05 or M07–M10. M06 Explosives and M11 Building Materials require manufacture.")
		if typeof(cart[code]) != TYPE_INT or cart[code] <= 0:
			return _reject("INVALID_QUANTITY", "Purchase positive whole kilograms; each resource unit is one kg.")
		# Bound work before packing or multiplication, including enormous invalid inputs.
		if cart[code] > vehicle_limit * TRUCK_KG - total_kg:
			return _reject("FREIGHT_QUEUE_FULL", "The order needs more vehicles than reserved Receiving places permit.")
		total_kg += cart[code]
	var vehicles: Array[Dictionary] = []
	var codes: Array = cart.keys()
	codes.sort()
	for code in codes:
		var remaining: int = cart[code]
		while remaining > 0:
			if vehicles.is_empty() or vehicles.back().mass_kg == TRUCK_KG:
				vehicles.append({"cargo": {}, "mass_kg": 0, "goods_cost": 0, "fee": TRANSPORT_FEE})
			var vehicle: Dictionary = vehicles.back()
			var amount := mini(remaining, TRUCK_KG - int(vehicle.mass_kg))
			vehicle.cargo[code] = amount
			vehicle.mass_kg += amount
			vehicle.goods_cost += amount * int(MATERIALS[code].price)
			remaining -= amount
	var cost: int = 0
	for vehicle in vehicles:
		vehicle.cost = vehicle.goods_cost + vehicle.fee
		cost += vehicle.cost
	return {"ok": true, "code": "OK", "message": "Quote only; no debit or reservation yet.",
		"vehicles": vehicles, "vehicle_count": vehicles.size(), "mass_kg": total_kg,
		"transport_fees": vehicles.size() * TRANSPORT_FEE, "cost": cost}


static func _reject(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
