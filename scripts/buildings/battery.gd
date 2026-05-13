extends Building
class_name Battery

var capacity: float = 500.0    # Wh total storage
var charge: float = 0.0        # current Wh stored
var charge_rate: float = 50.0  # max W in or out per second

func _ready():
	building_type = "chemical_battery"
	cost = 800

func store(amount: float) -> float:
	# Returns leftover that couldn't fit
	var space = capacity - charge
	var stored = min(amount, space, charge_rate)
	charge += stored
	return amount - stored

func draw(amount: float) -> float:
	# Returns how much was actually provided
	var drawn = min(amount, charge, charge_rate)
	charge -= drawn
	return drawn

func get_charge_percent() -> float:
	if capacity == 0:
		return 0.0
	return (charge / capacity) * 100.0

func get_info() -> String:
	return "Battery | %.0f%% (%.0f/%.0fWh)" % [get_charge_percent(), charge, capacity]
