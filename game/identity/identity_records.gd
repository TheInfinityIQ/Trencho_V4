extends RefCounted
## Internal records. The ledger returns detached inspection snapshots, never these objects.

enum Kind { PLACE, CARRIER, PERSON, STOCK, WEAPON, HEAVY_OBJECT }
enum Assignment {
	AVAILABLE, REAR_LABOUR, TRAINING, STRATEGIC_CREW, AWAITING_DEPLOYMENT,
	PASSENGER, HQ_RESERVE, HQ_DUTY, FORMATION_DUTY, WOUNDED, RECOVERY, DEAD,
}
const ASSIGNMENT_NAMES: Array[String] = [
	"Available", "Rear Labour", "Training", "Strategic Crew", "Awaiting Deployment",
	"Passenger", "HQ Reserve", "HQ Duty", "Formation Duty", "Wounded", "Recovery", "Dead",
]


class Entity extends RefCounted:
	var id: String
	var design_type: String
	var description: String
	var kind: Kind
	var owner: String
	var controller: String
	var holder_id: String
	var position := Vector2.ZERO
	var created_at: float
	var state_entered_at: float
	var state := "Present"
	var unit_mass_kg: float
	var quantity: int = 1
	var origin_id: String
	var fleet_domain := "External service"
	var vehicle_spec: Dictionary = {}
	var fuel: float = 0.0
	var health: int = 100
	var ammo_type: String
	var loaded_capacity: int


class Person extends Entity:
	var assignment: Assignment = Assignment.AVAILABLE
	var rear_place := "None" # Occupied, Held Home, or None; one place per identity.
	var duty_id: String
	var pending_assignment: int = -1
	var pending_duty: String
	var carrying_stock_id: String
	var carrying_weapon_id: String
	var basic_training := false
	var qualification := "None"
	var crew_station := ""
	var morale: int = 60
	var suppression: int = 0
	var service_seconds: float = 0.0
	var leader_appointment := "None"
	var bleed_until: float = INF
	var loss_recorded := false


class Claim extends RefCounted:
	var id: String
	var claimant: String
	var purpose: String
	var source_id: String
	var requested: int
	var reserved: int
	var fulfilled: int
	var created_at: float
	var cancelled := false
