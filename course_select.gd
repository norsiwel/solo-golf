extends Control
## Course Select Screen
## Left panel: search + scrollable course list
## Right panel: splash image + course details
## Bottom: 9 Hole / 18 Hole toggle + Play button

@onready var search_box       = %SearchBox
@onready var course_list      = %CourseList
@onready var splash_img       = %SplashImage
@onready var no_splash_lbl    = %NoSplashLabel
@onready var course_name_lbl  = %CourseName
@onready var author_lbl       = %Author
@onready var hole_count_lbl   = %HoleCount
@onready var par_lbl          = %Par
@onready var counter_lbl      = %Counter
@onready var btn_9hole        = %Btn9Hole
@onready var btn_18hole       = %Btn18Hole
@onready var btn_random       = %BtnRandom
@onready var btn_play         = %BtnPlay
@onready var loading_overlay  = $LoadingOverlay
@onready var loading_name_lbl = $LoadingOverlay/VBox/CourseName
@onready var loading_pct_lbl  = $LoadingOverlay/VBox/PercentLabel
@onready var loading_label    = $LoadingOverlay/VBox/LoadingLabel
@onready var loading_bar      = $LoadingOverlay/VBox/LoadingBar
@onready var cancel_btn       = $LoadingOverlay/VBox/CancelButton
@onready var back_btn         = $BackButton
var loader: CourseLoader
var all_courses: Array = []
var filtered: Array = []
var selected_index: int = -1     # index into filtered[]
var play_holes: int = 18         # 9 or 18
var _splash_cache: Dictionary = {}
var _list_buttons: Array = []


func _ready():
	GameState.current_course = {}
	loader = CourseLoader.new()
	add_child(loader)
	loader.course_ready.connect(_on_course_ready)
	loader.load_progress.connect(_on_load_progress)
	loader.load_failed.connect(_on_load_failed)

	search_box.text_changed.connect(_on_search_changed)
	btn_9hole.pressed.connect(func(): _set_hole_mode(9))
	btn_18hole.pressed.connect(func(): _set_hole_mode(18))
	btn_random.pressed.connect(_on_random_pressed)
	btn_play.pressed.connect(_on_play_pressed)

	loading_overlay.visible = false
	btn_play.disabled = true
	_set_hole_mode(18)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)
	_apply_theme()
	_scan_courses()


## Build all UI styling in code — no image files needed.
func _apply_theme() -> void:
	# Play button — bold green
	var play_normal = StyleBoxFlat.new()
	play_normal.bg_color = Color(0.10, 0.45, 0.10, 1.0)
	play_normal.border_color = Color(0.4, 0.85, 0.3, 1.0)
	play_normal.set_border_width_all(2)
	play_normal.set_corner_radius_all(8)
	play_normal.content_margin_left = 16
	play_normal.content_margin_right = 16
	var play_hover = play_normal.duplicate()
	play_hover.bg_color = Color(0.15, 0.58, 0.15, 1.0)
	var play_disabled = play_normal.duplicate()
	play_disabled.bg_color = Color(0.08, 0.18, 0.08, 0.6)
	play_disabled.border_color = Color(0.25, 0.40, 0.25, 0.4)
	btn_play.add_theme_stylebox_override("normal",   play_normal)
	btn_play.add_theme_stylebox_override("hover",    play_hover)
	btn_play.add_theme_stylebox_override("disabled", play_disabled)
	btn_play.add_theme_color_override("font_color",          Color(0.95, 1.0, 0.7, 1))
	btn_play.add_theme_color_override("font_disabled_color", Color(0.4, 0.5, 0.4, 0.6))

	# Hole mode buttons — styled in _set_hole_mode(), just set font color here
	for btn in [btn_9hole, btn_18hole]:
		btn.add_theme_color_override("font_color", Color(0.88, 0.92, 0.75, 1))

	# Random button
	var rand_style = StyleBoxFlat.new()
	rand_style.bg_color = Color(0.28, 0.18, 0.05, 1.0)
	rand_style.border_color = Color(0.80, 0.55, 0.15, 0.9)
	rand_style.set_border_width_all(2)
	rand_style.set_corner_radius_all(8)
	rand_style.content_margin_left = 12
	rand_style.content_margin_right = 12
	var rand_hover = rand_style.duplicate()
	rand_hover.bg_color = Color(0.38, 0.25, 0.06, 1.0)
	btn_random.add_theme_stylebox_override("normal", rand_style)
	btn_random.add_theme_stylebox_override("hover",  rand_hover)
	btn_random.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35, 1))

	# Search box
	var search_style = StyleBoxFlat.new()
	search_style.bg_color = Color(0.06, 0.12, 0.06, 1.0)
	search_style.border_color = Color(0.35, 0.55, 0.30, 0.8)
	search_style.set_border_width_all(1)
	search_style.set_corner_radius_all(6)
	search_style.content_margin_left = 10
	search_box.add_theme_stylebox_override("normal", search_style)
	search_box.add_theme_stylebox_override("focus",  search_style)
	search_box.add_theme_color_override("font_color",             Color(0.90, 0.95, 0.80, 1))
	search_box.add_theme_color_override("font_placeholder_color", Color(0.45, 0.58, 0.42, 0.8))

	# Splash placeholder — shown when no splash image is in the zip
	var splash_bg = StyleBoxFlat.new()
	splash_bg.bg_color = Color(0.06, 0.14, 0.06, 1.0)
	splash_bg.border_color = Color(0.25, 0.42, 0.22, 0.6)
	splash_bg.set_border_width_all(1)
	splash_img.add_theme_stylebox_override("panel", splash_bg)


func _scan_courses() -> void:
	all_courses = loader.scan_available_courses()
	filtered = all_courses.duplicate()
	_rebuild_list()


func _on_search_changed(text: String) -> void:
	var q = text.strip_edges().to_lower()
	filtered = all_courses.filter(func(c):
		return q == "" or q in c.name.to_lower() or q in c.get("author","").to_lower()
	)
	_rebuild_list()


func _rebuild_list() -> void:
	# Clear existing buttons
	for child in course_list.get_children():
		child.queue_free()
	_list_buttons.clear()
	selected_index = -1
	btn_play.disabled = true
	splash_img.texture = null
	course_name_lbl.text = "Select a course"
	author_lbl.text = ""
	hole_count_lbl.text = ""
	par_lbl.text = ""

	counter_lbl.text = "%d courses" % filtered.size()

	if filtered.is_empty():
		var lbl = Label.new()
		lbl.text = "No courses match."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		course_list.add_child(lbl)
		return

	for i in range(filtered.size()):
		var info = filtered[i]
		var btn = Button.new()
		btn.text = info.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		btn.flat = true
		_style_list_btn(btn, false)
		var idx = i
		btn.pressed.connect(func(): _select_course(idx))
		course_list.add_child(btn)
		_list_buttons.append(btn)

	# Auto-select first
	_select_course(0)

func _style_list_btn(btn: Button, selected: bool) -> void:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if selected:
		s.bg_color = Color(0.15, 0.32, 0.15, 1.0)
		s.border_color = Color(0.45, 0.80, 0.35, 1.0)
		s.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.55, 1))
	else:
		s.bg_color = Color(0.07, 0.12, 0.07, 0.9)
		s.border_color = Color(0.25, 0.40, 0.25, 0.5)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.82, 0.88, 0.76, 1))
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate()
	h.bg_color = Color(0.12, 0.22, 0.12, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	var p = s.duplicate()
	p.bg_color = Color(0.18, 0.38, 0.18, 1.0)
	btn.add_theme_stylebox_override("pressed", p)


func _select_course(index: int) -> void:
	if index < 0 or index >= filtered.size():
		return

	# Restyle buttons
	for i in range(_list_buttons.size()):
		_style_list_btn(_list_buttons[i], i == index)

	selected_index = index
	var info = filtered[index]

	course_name_lbl.text = info.name
	author_lbl.text = "by " + info.get("author", "Unknown")
	hole_count_lbl.text = "%d holes" % info.hole_count
	par_lbl.text = ""   # par not in peek data, leave blank
	btn_play.disabled = false

	# Scroll list to keep selection visible
	if index < _list_buttons.size():
		_list_buttons[index].grab_focus()

	# Load splash
	var zip_path: String = info.zip_path
	if zip_path in _splash_cache:
		splash_img.texture = _splash_cache[zip_path]
		no_splash_lbl.visible = false
	else:
		splash_img.texture = null
		no_splash_lbl.visible = true
		_load_splash(info)


func _load_splash(info: Dictionary) -> void:
	var reader = ZIPReader.new()
	if reader.open(info.zip_path) != OK:
		return
	var splash_name: String = info.get("splash_name", "")
	if splash_name == "":
		reader.close()
		return
	var img_path = "images/" + splash_name
	if not reader.file_exists(img_path):
		reader.close()
		return
	var bytes = reader.read_file(img_path)
	reader.close()
	var img = Image.new()
	var ext = splash_name.get_extension().to_lower()
	var err = ERR_UNAVAILABLE
	if ext in ["jpg", "jpeg"]:
		err = img.load_jpg_from_buffer(bytes)
	elif ext == "png":
		err = img.load_png_from_buffer(bytes)
	if err != OK:
		return
	var tex = ImageTexture.create_from_image(img)
	_splash_cache[info.zip_path] = tex
	if selected_index >= 0 and selected_index < filtered.size():
		if filtered[selected_index].zip_path == info.zip_path:
			splash_img.texture = tex
			splash_img.custom_minimum_size = Vector2(0, 160)
			no_splash_lbl.visible = false


func _set_hole_mode(holes: int) -> void:
	play_holes = holes
	GameState.play_mode = "nine" if holes == 9 else "full"
	# Visual feedback — highlight active button
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.18, 0.45, 0.18, 1.0)
	active_style.border_color = Color(0.5, 0.85, 0.35, 1.0)
	active_style.set_border_width_all(2)
	active_style.set_corner_radius_all(6)
	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.08, 0.16, 0.08, 0.9)
	inactive_style.border_color = Color(0.3, 0.5, 0.3, 0.6)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(6)
	btn_9hole.add_theme_stylebox_override("normal",  inactive_style if holes == 18 else active_style)
	btn_18hole.add_theme_stylebox_override("normal", inactive_style if holes == 9  else active_style)


func _on_random_pressed() -> void:
	if all_courses.is_empty():
		return
	# Pick from the full list regardless of current search filter
	var pick = randi() % all_courses.size()
	# Clear search so the picked course is visible in the list
	search_box.text = ""
	filtered = all_courses.duplicate()
	_rebuild_list()
	_select_course(pick)
	# Scroll to it
	if pick < _list_buttons.size():
		_list_buttons[pick].grab_focus()


func _on_cancel_pressed() -> void:
	# Stop the loader and go back to the selection UI
	loader.queue_free()
	loader = CourseLoader.new()
	add_child(loader)
	loader.course_ready.connect(_on_course_ready)
	loader.load_progress.connect(_on_load_progress)
	loader.load_failed.connect(_on_load_failed)
	loading_overlay.visible = false
	btn_play.disabled = false
	btn_9hole.disabled = false
	btn_18hole.disabled = false
	btn_random.disabled = false


func _on_play_pressed() -> void:
	if selected_index < 0 or selected_index >= filtered.size():
		return
	var info = filtered[selected_index]
	loading_overlay.visible = true
	loading_name_lbl.text = info.name
	loading_pct_lbl.text = "0%"
	loading_label.text = "Opening course package..."
	loading_bar.value = 0
	btn_play.disabled = true
	btn_9hole.disabled = true
	btn_18hole.disabled = true
	btn_random.disabled = true
	loader.load_course(info.zip_path)

func _on_load_progress(step: String, percent: float) -> void:
	var pct = int(percent * 100)
	loading_pct_lbl.text = "%d%%" % pct
	loading_label.text = step
	loading_bar.value = pct
	# Color shifts green → yellow → white as it approaches 100
	if pct < 50:
		loading_pct_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1))
	elif pct < 85:
		loading_pct_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.2, 1))
	else:
		loading_pct_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1))


func _on_course_ready(course_data: Dictionary) -> void:
	GameState.current_course = course_data
	get_tree().change_scene_to_file("res://intro.tscn")


func _on_load_failed(reason: String) -> void:
	loading_overlay.visible = false
	course_name_lbl.text = "Load failed: " + reason
	btn_play.disabled = false
	btn_9hole.disabled = false
	btn_18hole.disabled = false
	btn_random.disabled = false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if search_box.has_focus():
		return
	match event.keycode:
		KEY_UP:
			_select_course(max(selected_index - 1, 0))
		KEY_DOWN:
			_select_course(min(selected_index + 1, filtered.size() - 1))
		KEY_ENTER, KEY_KP_ENTER:
			_on_play_pressed()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
