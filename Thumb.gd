# ==============================================================================
class_name Thumbnail
extends TextureButton

# ==============================================================================
var img_path = ""

# ==============================================================================
func _ready():
	connect("pressed", self, "OpenPath")
	connect("mouse_entered", self, "Effect", [1])
	connect("mouse_exited", self, "Effect", [0])
	
	hint_tooltip = img_path.get_file()
	
# ==============================================================================
func Effect(arg):
	if arg:
		rect_position += Vector2(1, 1)
	else:
		rect_position -= Vector2(1, 1)

# ==============================================================================
func OpenPath():
	if img_path:
		var _error = OS.shell_open(img_path)
		if _error:
			print(_error)
