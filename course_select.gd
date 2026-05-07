extends Control
class_name CourseSelectScreen

# Attach to a Control node in course_select.tscn.
# Expected node tree (see owg_course_system.md for full spec):
#   CourseSelectScreen (Control)
#   ├── Background (ColorRect)
#   ├── VBoxContainer
#   │   ├── TitleLabel
#   │   ├── CourseList (ItemList)
#   │   └── PlayButton (Button)
#   ├── Panel
#   │   ├── SplashImage (TextureRect)
#   │   ├── CourseName (Label)
#   │   ├── Author (Label)
#   │   └── HoleCount (Label)
#   └── LoadingLabel (Label)

@onready var course_list    = $VBoxContainer/CourseList
@onready var course_name_label = $Panel/CourseName
@onready var author_label   = $Panel/Author
@onready var hole_count_label = $Panel/HoleCount
@onready var splash_image   = $Panel/SplashImage
@onready var play_button    = $VBoxContainer/PlayButton
@onready var loading_label  = $LoadingLabel

var loader: CourseLoader
var available_courses: Array = []
var selected_index: int = -1


func _ready():
	loader = CourseLoader.new()
	add_child(loader)
	loader.course_ready.connect(_on_course_ready)
	loader.load_progress.connect(_on_load_progress)
	loader.load_failed.connect(_on_load_failed)

	play_button.disabled = true
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
	play_button.disabled = false

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


func _on_play_pressed():
	if selected_index < 0:
		return
	var info = available_courses[selected_index]
	play_button.disabled = true
	loading_label.visible = true
	loading_label.text = "Loading course..."
	loader.load_course(info.zip_path)


func _on_load_progress(step: String, percent: float):
	loading_label.text = step + " (" + str(int(percent * 100)) + "%)"


func _on_course_ready(course_data: Dictionary):
	GameState.current_course = course_data
	get_tree().change_scene_to_file("res://main.tscn")


func _on_load_failed(reason: String):
	loading_label.text = "Failed: " + reason
	play_button.disabled = false
