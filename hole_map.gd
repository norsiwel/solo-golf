extends CanvasLayer

var visible_map := false
var map_control: TextureRect

func _ready():
	layer = 8
	visible = false
	_build_ui()

func _build_ui():
	# Semi-dark full-screen backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchor(SIDE_LEFT, 0.0)
	backdrop.set_anchor(SIDE_TOP, 0.0)
	backdrop.set_anchor(SIDE_RIGHT, 1.0)
	backdrop.set_anchor(SIDE_BOTTOM, 1.0)
	add_child(backdrop)

	# Course map image — full-screen, aspect-ratio preserved
	map_control = TextureRect.new()
	map_control.name = "MapImage"
	map_control.set_anchor(SIDE_LEFT, 0.03)
	map_control.set_anchor(SIDE_TOP, 0.03)
	map_control.set_anchor(SIDE_RIGHT, 0.97)
	map_control.set_anchor(SIDE_BOTTOM, 0.94)
	map_control.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	map_control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex = load("res://assets/St.Andrews-course-map-1-18.png")
	if tex:
		map_control.texture = tex
	add_child(map_control)

	# Dismiss hint
	var hint := Label.new()
	hint.name = "CloseHint"
	hint.text = "M — close map"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchor(SIDE_LEFT, 0.3)
	hint.set_anchor(SIDE_TOP, 0.95)
	hint.set_anchor(SIDE_RIGHT, 0.7)
	hint.set_anchor(SIDE_BOTTOM, 1.0)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)

func set_map_image(path: String):
	if not map_control:
		return
		
	var img = Image.load_from_file(path)
	if img:
		var tex = ImageTexture.create_from_image(img)
		map_control.texture = tex
		print("HoleMap: Loaded map from " + path)
	else:
		push_warning("HoleMap: Failed to load map from " + path)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			visible_map = !visible_map
			visible = visible_map

# Keep load_hole stub so main.gd call doesn't error
func load_hole(_hole_num: int):
	pass
