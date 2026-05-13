extends TileMap

func _ready():
    for x in range(100):
        for y in range(100):
            set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))