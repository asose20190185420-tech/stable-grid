extends Building
class_name SolarPanel

var peak_output: float = 50.0  # watts at full sun

func _ready():
	building_type = "solar_pv_panel"
	cost = 100
	texture = preload("res://assets/renewables/pv1.png")

func get_output() -> float:  # matches parent signature
	if not is_active:
		return 0.0
	return peak_output * sun_intensity

func get_info() -> String:
	return "Solar Panel | Peak: %.0fW" % peak_output
