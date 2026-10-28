extends RefCounted
## Canonical GDD9.1/9.2/9.3/9.4 data. Mechanisms are integral, never spare inventory.
const TYPES := {
	"T01": {"mass":4000.0,"health":450,"footprint":Vector2(7,2.7),"passenger_seats":2,"payload":5000.0,"tank_capacity":40.0,"stations":["Driver"],"mechanisms":[],"rack_capacity":{}},
	"T02": {"mass":3200.0,"health":400,"footprint":Vector2(6.8,2.5),"passenger_seats":16,"payload":2000.0,"tank_capacity":40.0,"stations":["Driver"],"mechanisms":[],"rack_capacity":{}},
	"T03": {"mass":2000.0,"health":300,"footprint":Vector2(5.2,2.1),"passenger_seats":2,"payload":400.0,"tank_capacity":30.0,"stations":["Driver","Gunner"],"mechanisms":["Integral roof W02 and mounting"],"rack_capacity":{"E02":1200}},
	"T04": {"mass":14000.0,"health":650,"footprint":Vector2(7.5,3),"passenger_seats":8,"payload":1200.0,"tank_capacity":80.0,"stations":["Driver","Gunner","Commander"],"mechanisms":["Integral W06 cannon and mounting"],"rack_capacity":{"E26":240}},
	"T05": {"mass":30000.0,"health":1200,"footprint":Vector2(8.5,3.5),"passenger_seats":0,"payload":200.0,"tank_capacity":120.0,"stations":["Driver","Gunner","Loader","Commander"],"mechanisms":["Integral W07 cannon and mounting","Integral coaxial W02 and mounting"],"rack_capacity":{"E25":40,"E02":1200}},
}
