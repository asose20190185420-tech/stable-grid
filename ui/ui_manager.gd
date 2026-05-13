 extends CanvasLayer

# List of building types mapped to button labels
var building_buttons = [
	{"label": "☀ Solar Panel",    "type": "solar_pv_panel"},
	{"label": "🔋 Battery",        "type": "chemical_battery"},
	{"label": "⚡ Turbine",        "type": "turbine"},
	{"label": "🏭 Coal Plant",     "type": "coal_power_plant"},
	{"label": "❄ Cooling Tower",  "type": "cooling_tower"},
	{"label": "🗄 Coal Storage",   "type": "coal_storage"},
]

var selected_type: String = "solar_pv_panel"
var buttons_list: Array = []

func _ready():
	_build_buttons()

func _build_buttons():
	var vbox = $Panel/VBoxContainer

	# Clear existing children first
	for child in vbox.get_children():
		child.queue_free()

	# Title label
	var title = Label.new()
	title.text = "Buildings"
	vbox.add_child(title)

	# One button per building type
	for b in building_buttons:
		var btn = Button.new()
		btn.text = b["label"]
		btn.pressed.connect(_on_button_pressed.bind(b["type"]))
		vbox.add_child(btn)
		buttons_list.append(btn)

	_highlight_selected()

func _on_button_pressed(type: String):
	selected_type = type
	# Tell main which building to place
	get_parent().current_building_type = type
	print("Selected building: ", type)
	_highlight_selected()

func _highlight_selected():
	for i in range(buttons_list.size()):
		var btn = buttons_list[i]
		if building_buttons[i]["type"] == selected_type:
			btn.modulate = Color(1.0, 0.8, 0.0)  # yellow = selected
		else:
			btn.modulate = Color(1, 1, 1)
