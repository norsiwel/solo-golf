extends Control
class_name CourseSelectScreen

# Node tree (scenes/course_select.tscn):
#   CourseSelectScreen (Control)
#   ├── Background (ColorRect)
#   ├── VBoxContainer
#   │   ├── TitleLabel
#   │   ├── CourseList (ItemList)           ← expands to fill space
#   │   ├── ModeButtons (HBoxContainer)
#   │   │   ├── QuickRoundButton (Button)
#   │   │   ├── NineHolesButton (Button)
#   │   │   └── FullRoundButton (Button)
#   │   └── LoadingLabel (Label)
#   └── Panel
#       ├── SplashImage (TextureRect)
#       ├── CourseName (Label)
#       ├── Author (Label)
#       └── HoleCount (Label)

@onready var course_list       = $VBoxContainer/CourseList
@onready var course_name_label = $Panel/CourseName
@onready var author_label      = $Panel/Author
@onready var hole_count_label  = $Panel/HoleCount
@onready var splash_image      = $Panel/SplashImage
@onready var quick_button      = $VBoxContainer/ModeButtons/QuickRoundButton
@onready var nine_button       = $VBoxContainer/ModeButtons/NineHolesButton
@onready var full_button       = $VBoxContainer/ModeButtons/FullRoundButton
@onready var loading_label     = $VBoxContainer/LoadingLabel

var loader: CourseLoader
var available_courses: Array = []
var selected_index: int = -1


func _ready():
	loader = CourseLoader.new()
	add_child(loader)
	loader.course_ready.connect(_on_course_ready)
	loader.load_progress.connect(_on_load_progress)
	loader.load_failed.connect(_on_load_failed)

	quick_button.pressed.connect(func(): _start_load("quick"))
	nine_button.pressed.connect(func(): _start_load("nine"))
	full_button.pressed.connect(func(): _start_load("full"))

	_set_buttons_disabled(true)
	loading_label.visible = false

	_populate_course_list()


func _populate_course_list():
	course_list.clear()
	available_courses = loader.scan_available_courses()

	if available_courses.is_empty():
		course_list.add_item("No courses found — add OWG-*.zip to res://courses/")
		return

	for course in available_courses:
		course_list.add_item(course.name)

	course_list.item_selected.connect(_on_course_selected)

	if available_courses.size() > 0:
		course_list.select(0)
		_on_course_selected(0)


func _on_course_selected(index: int):
	selected_index = index
	if index < 0 or index >= available_courses.size():
		return

	var info = available_courses[index]
	course_name_label.text = info.name
	author_label.text = "by " + info.get("author", "")
	hole_count_label.text = str(info.hole_count) + " holes"
	_set_buttons_disabled(false)

	_load_splash_preview(info)


func _load_splash_preview(info: Dictionary):
	if info.get("splash_name", "") == "":
		return
	var reader = ZIPReader.new()
	if reader.open(info.zip_path) != OK:
		return
	var img_path = "images/" + info.splash_name
	if reader.file_exists(img_path):
		var bytes = reader.read_file(img_path)
		reader.close()
		var img = Image.new()
		var ext = info.splash_name.get_extension().to_lower()
		var err = ERR_UNAVAILABLE
		if ext == "jpg" or ext == "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		elif ext == "png":
			err = img.load_png_from_buffer(bytes)
		if err == OK:
			splash_image.texture = ImageTexture.create_from_image(img)
	else:
		reader.close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and selected_index >= 0:
			_start_load("full")


func _start_load(mode: String) -> void:
	if selected_index < 0:
		return
	GameState.play_mode = mode
	var info = available_courses[selected_index]
	_set_buttons_disabled(true)
	loading_label.visible = true
	loading_label.text = "Loading course..."
	loader.load_course(info.zip_path)


func _set_buttons_disabled(is_disabled: bool) -> void:
	quick_button.disabled = is_disabled
	nine_button.disabled = is_disabled
	full_button.disabled = is_disabled


func _on_load_progress(step: String, percent: float):
	loading_label.text = step + " (" + str(int(percent * 100)) + "%)"


func _on_course_ready(course_data: Dictionary):
	GameState.current_course = course_data
	get_tree().change_scene_to_file("res://main.tscn")


func _on_load_failed(reason: String):
	loading_label.text = "Failed: " + reason
	_set_buttons_disabled(false)
