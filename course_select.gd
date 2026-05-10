extends Control
class_name CourseSelectScreen

# Course selector — each course gets its own card with a Play button.
# Clicking a card previews it; clicking Play on the card loads it.
# Keyboard: arrow keys move selection, Enter plays selected course.

@onready var cards_container   = $HSplitContainer/LeftPanel/ScrollContainer/CardsContainer
@onready var course_name_label = $HSplitContainer/RightPanel/CourseName
@onready var author_label      = $HSplitContainer/RightPanel/Author
@onready var hole_count_label  = $HSplitContainer/RightPanel/HoleCount
@onready var splash_image      = $HSplitContainer/RightPanel/SplashImage
@onready var loading_label     = $HSplitContainer/LeftPanel/LoadingLabel

var loader: CourseLoader
var available_courses: Array = []
var selected_index: int = -1
var _card_buttons: Array = []   # play buttons, indexed parallel to available_courses


func _ready():
	GameState.current_course = {}

	loader = CourseLoader.new()
	add_child(loader)
	loader.course_ready.connect(_on_course_ready)
	loader.load_progress.connect(_on_load_progress)
	loader.load_failed.connect(_on_load_failed)

	loading_label.visible = false
	_populate_cards()


func _populate_cards():
	# Clear old cards
	for child in cards_container.get_children():
		child.queue_free()
	_card_buttons.clear()

	available_courses = loader.scan_available_courses()

	if available_courses.is_empty():
		var lbl = Label.new()
		lbl.text = "No courses found.\nAdd OWG-*.zip files to res://courses/"
		lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards_container.add_child(lbl)
		return

	for i in range(available_courses.size()):
		var info = available_courses[i]
		var card = _build_card(info, i)
		cards_container.add_child(card)

	# Auto-select first course
	_select_course(0)


func _build_card(info: Dictionary, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.08, 0.95)
	style.border_color = Color(0.3, 0.55, 0.25, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	card.name = "Card_%d" % index

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Course info column
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = info.name
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.6))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "by %s  ·  %d holes" % [info.get("author", "Unknown"), info.hole_count]
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55, 0.9))
	vbox.add_child(sub_lbl)

	# Play button
	var play_btn = Button.new()
	play_btn.text = "▶  Play"
	play_btn.custom_minimum_size = Vector2(90, 0)
	play_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play_btn.add_theme_font_size_override("font_size", 14)
	play_btn.disabled = true  # enabled when this card is selected

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.38, 0.12, 0.9)
	btn_style.border_color = Color(0.4, 0.75, 0.3, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(5)
	play_btn.add_theme_stylebox_override("normal", btn_style)
	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color(0.18, 0.52, 0.18, 0.95)
	play_btn.add_theme_stylebox_override("hover", hover_style)

	play_btn.pressed.connect(func(): _start_load(index))
	hbox.add_child(play_btn)
	_card_buttons.append(play_btn)

	# Clicking the card itself selects it
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_course(index)
	)

	return card


func _select_course(index: int):
	if index < 0 or index >= available_courses.size():
		return

	# Update card styles
	for i in range(cards_container.get_child_count()):
		var card = cards_container.get_child(i)
		if not card is PanelContainer:
			continue
		var style = StyleBoxFlat.new()
		if i == index:
			style.bg_color = Color(0.12, 0.22, 0.12, 0.98)
			style.border_color = Color(0.5, 0.85, 0.35, 1.0)
			style.border_width_left = 3
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
		else:
			style.bg_color = Color(0.08, 0.14, 0.08, 0.95)
			style.border_color = Color(0.3, 0.55, 0.25, 0.7)
			style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)

	# Enable only the selected card's play button
	for i in range(_card_buttons.size()):
		_card_buttons[i].disabled = (i != index)

	selected_index = index
	var info = available_courses[index]
	course_name_label.text = info.name
	author_label.text = "by " + info.get("author", "")
	hole_count_label.text = str(info.hole_count) + " holes"
	_load_splash_preview(info)


func _load_splash_preview(info: Dictionary):
	splash_image.texture = null
	if info.get("splash_name", "") == "":
		return
	var reader = ZIPReader.new()
	if reader.open(info.zip_path) != OK:
		return
	var img_path = "images/" + info.splash_name
	if not reader.file_exists(img_path):
		reader.close()
		return
	var bytes = reader.read_file(img_path)
	reader.close()
	var img = Image.new()
	var ext = info.splash_name.get_extension().to_lower()
	var err = ERR_UNAVAILABLE
	if ext in ["jpg", "jpeg"]:
		err = img.load_jpg_from_buffer(bytes)
	elif ext == "png":
		err = img.load_png_from_buffer(bytes)
	if err == OK:
		splash_image.texture = ImageTexture.create_from_image(img)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_DOWN:
			_select_course(min(selected_index + 1, available_courses.size() - 1))
		KEY_UP:
			_select_course(max(selected_index - 1, 0))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if selected_index >= 0:
				_start_load(selected_index)


func _start_load(index: int) -> void:
	if index < 0 or index >= available_courses.size():
		return
	GameState.play_mode = "full"
	var info = available_courses[index]
	for btn in _card_buttons:
		btn.disabled = true
	loading_label.visible = true
	loading_label.text = "Loading %s..." % info.name
	loader.load_course(info.zip_path)


func _on_load_progress(step: String, percent: float):
	loading_label.text = "%s  (%d%%)" % [step, int(percent * 100)]


func _on_course_ready(course_data: Dictionary):
	GameState.current_course = course_data
	get_tree().change_scene_to_file("res://main.tscn")


func _on_load_failed(reason: String):
	loading_label.text = "Failed: " + reason
	_select_course(selected_index)  # re-enable buttons
