extends Node2D

@onready var camera = $Camera2D
@onready var status_label = get_node_or_null("StatusLabel")
@onready var world_tint = get_node_or_null("CanvasModulate")

# --- Phase 1: Foundations & Environment ---
var time_of_day: float = 12.0
var sun_intensity: float = 0.0
var wind_speed: float = 0.0

# --- Solar Simulation State ---
var solar_output: float = 0.0
var battery_charge: float = 0.0
var battery_capacity: float = 0.0
var power_demand: float = 100.0
var has_power: bool = false

# --- Grid & Placement Logic ---
var last_snapped_pos = Vector2.ZERO
var camera_speed = 500.0
var grid_size = 16
var occupied_cells = {}

# --- Building Data (textures, scale, cost) ---
var current_building_type = "solar_pv_panel"
var building_data = {
	# Heat Generation
	"coal_power_plant":        { "category": "heat_generation",  "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 5000  },
	"nuclear_power_plant":     { "category": "heat_generation",  "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 50000 },
	"geothermal_extraction":   { "category": "heat_generation",  "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 15000 },

	# Power Storage
	"chemical_battery":        { "category": "power_storage",    "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 800   },
	"physical_battery":        { "category": "power_storage",    "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 2000  },
	"capacitor":               { "category": "power_storage",    "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 300   },

	# Power Generation
	"solar_pv_panel":          {"category":"power_generation","footprint": 2,"texture":preload("res://assets/renewables/pv1.png"),"scale": 0.045,"cost":100},
	"turbine":                 { "category": "power_generation", "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 3000  },
	"peltier_module":          { "category": "power_generation", "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 200   },

	# Auxiliary
	"emergency_diesel_gen":    { "category": "auxiliary",        "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 1200  },
	"resistor_bank":           { "category": "auxiliary",        "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 150   },
	"power_dump":              { "category": "auxiliary",        "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 250   },

	# Support
	"cooling_tower":           { "category": "support",          "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 1000  },
	"water_body_heat_transfer":{ "category": "support",          "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 700   },
	"condenser":               { "category": "support",          "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 600   },
	"pressure_relief_valve":   { "category": "support",          "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 50    },

	# Fuel Storage
	"coal_storage":            { "category": "storage",          "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 400   },
	"gas_storage":             { "category": "storage",          "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 600   },

	# Disposal
	"spent_fuel_disposal":     { "category": "disposal",         "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 10000 },

	# Warehouse
	"spare_parts_warehouse":   { "category": "warehouse",        "texture": preload("res://icon.svg"), "scale": 0.125, "cost": 500   },
}

# -------------------------------------------------------
func _ready():
	camera.position = Vector2(800, 800)
	$Sprite2D.modulate.a = 0.5
	if status_label:
		status_label.z_index = 10

func _process(delta):
	_handle_camera_movement(delta)
	_update_environment(delta)
	_simulate_solar(delta)
	_update_ghost_and_ui()

# -------------------------------------------------------
func _handle_camera_movement(delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"): direction.x += 1
	if Input.is_action_pressed("move_left"):  direction.x -= 1
	if Input.is_action_pressed("move_down"):  direction.y += 1
	if Input.is_action_pressed("move_up"):    direction.y -= 1
	camera.position += direction.normalized() * camera_speed * delta

# -------------------------------------------------------
func _update_environment(delta):
	time_of_day = fmod(time_of_day + delta * 0.5, 24.0)
	sun_intensity = clamp(sin((time_of_day - 6.0) * PI / 12.0), 0.0, 1.0)

	if world_tint:
		var night_color = Color(0.2, 0.2, 0.4)
		var day_color   = Color(1.0, 1.0, 0.95)
		world_tint.color = night_color.lerp(day_color, sun_intensity)

# -------------------------------------------------------
func _simulate_solar(delta):
	solar_output = 0.0
	battery_capacity = 0.0
	var batteries: Array = []

	for building in occupied_cells.values():
		if building is SolarPanel:
			building.sun_intensity = sun_intensity
			solar_output += building.get_output()
		elif building is Battery:
			battery_capacity += building.capacity
			batteries.append(building)

	battery_charge = 0.0
	for bat in batteries:
		battery_charge += bat.charge

	var surplus = solar_output - power_demand  # watts
	var energy = surplus * delta               # Wh this frame

	for bat in batteries:
		if energy > 0:
			energy = bat.store(energy)   # pass Wh, get leftover Wh back
		elif energy < 0:
			var drawn = bat.draw(abs(energy))
			energy += drawn

	has_power = solar_output >= power_demand or battery_charge > 0

# -------------------------------------------------------
func _update_ghost_and_ui():
	var mouse_pos   = get_global_mouse_position()
	var snapped_pos = Vector2(
		round(mouse_pos.x / grid_size) * grid_size,
		round(mouse_pos.y / grid_size) * grid_size
	)

	var current_data = building_data[current_building_type]
	$Sprite2D.texture = current_data["texture"]
	$Sprite2D.scale   = Vector2(current_data["scale"], current_data["scale"])
	$Sprite2D.position = snapped_pos
	last_snapped_pos   = snapped_pos

	var cell_key    = Vector2i(snapped_pos)
	var is_occupied = occupied_cells.has(cell_key)
	$Sprite2D.modulate.a = 0.2 if is_occupied else 0.5

	if status_label:
		var charge_pct = 0.0
		if battery_capacity > 0:
			charge_pct = (battery_charge / battery_capacity) * 100.0

		var power_str = "☀ %.0fW" % solar_output
		if battery_capacity > 0:
			power_str += " | 🔋 %.0f%%" % charge_pct
		if not has_power:
			power_str += " | ⚠ NO POWER"

		var info = "%02d:00 | Sun: %d%% | %s" % [int(time_of_day), sun_intensity * 100, power_str]
		if is_occupied:
			info = "Occupied! | " + info

		status_label.text = info
		status_label.global_position = mouse_pos + Vector2(15, -25)

# -------------------------------------------------------
func _input(event):
	if event.is_action_pressed("zoom_in"):
		camera.zoom *= 1.1
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))
	if event.is_action_pressed("zoom_out"):
		camera.zoom *= 0.9
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell_key = Vector2i(last_snapped_pos)
			if occupied_cells.has(cell_key):
				print("Occupied!")
			else:
				place_building(last_snapped_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			remove_building(last_snapped_pos)

# -------------------------------------------------------
func place_building(pos: Vector2):
	var cell_key = Vector2i(pos)
	var data = building_data[current_building_type]
	
	# Check all 4 cells are free first
	var footprint = get_footprint(pos, data.get("footprint", 1))
	for cell in footprint:
		if occupied_cells.has(cell):
			print("Blocked!")
			return
	
	var building: Building
	match current_building_type:
		"solar_pv_panel":
			building = SolarPanel.new()
		"chemical_battery", "physical_battery":
			building = Battery.new()
		_:
			building = Building.new()
			building.building_type = current_building_type

	building.texture = data["texture"]
	building.position = pos
	building.scale = Vector2(data["scale"], data["scale"])
	$Buildings.add_child(building)

	# Mark all cells occupied
	for cell in footprint:
		occupied_cells[cell] = building

func get_footprint(pos: Vector2, size: int) -> Array:
	var cells = []
	for x in range(size):
		for y in range(size):
			cells.append(Vector2i(pos) + Vector2i(x * 16, y * 16))
	return cells
# -------------------------------------------------------
func remove_building(pos: Vector2):
	var cell_key = Vector2i(pos)
	if occupied_cells.has(cell_key):
		var building = occupied_cells[cell_key]
		var data = building_data[building.building_type]
		var footprint = get_footprint(building.position, data.get("footprint", 1))
		for cell in footprint:
			occupied_cells.erase(cell)
		building.queue_free()
		
