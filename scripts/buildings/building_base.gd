extends Sprite2D
class_name Building

var building_type: String = ""
var cost: int = 0
var is_active: bool = true
var sun_intensity: float = 0.0  # set by main each frame

func _ready():
	pass

func get_output() -> float:
	return 0.0

func get_info() -> String:
	return building_type
