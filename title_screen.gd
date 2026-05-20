extends Control

# Title screen — shows Open-world-title.png while preloading course zips,
# then displays "Press ENTER to continue" when ready.

@onready var title_image       = $TitleImage
@onready var loading_bar       = $BottomStrip/LoadingBar
@onready var loading_label     = $BottomStrip/LoadingLabel
@onready var press_enter_label = $BottomStrip/PressEnterLabel

var _ready_to_continue := false
var _preload_thread: Thread
var _courses_found: int = 0


func _ready():
	GameState.current_course = {}

	# Load title image
	var tex = load("res://Open-world-title.png")
	if tex:
		title_image.texture = tex
	else:
		push_warning("TitleScreen: Open-world-title.png not found")

	# Start background scan/preload of course list
	loading_label.text = "Scanning courses..."
	loading_bar.value = 0

	_preload_thread = Thread.new()
	_preload_thread.start(_preload_courses)


func _preload_courses():
	# Run on background thread — scan course zips and count them
	var dir = DirAccess.open("res://courses/")
	var count := 0
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".zip") and fname.begins_with("OWG-"):
				count += 1
			fname = dir.get_next()
		dir.list_dir_end()
	_courses_found = count
	call_deferred("_on_preload_done")


func _on_preload_done():
	_preload_thread.wait_to_finish()
	loading_bar.value = 100
	loading_label.visible = false
	press_enter_label.visible = true
	_ready_to_continue = true
	var plural := "course" if _courses_found == 1 else "courses"
	press_enter_label.text = "%d %s found  |  Press ENTER to continue" % [_courses_found, plural]


func _unhandled_input(event: InputEvent):
	if not _ready_to_continue:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_tree().change_scene_to_file("res://scenes/golfer_select.tscn")
