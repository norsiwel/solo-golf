# OWG Course Loading System
## Design Document & Implementation Guide

---

## Folder Structure Required in Godot Project

```
res://
├── courses/                        ← drop OWG-*.zip files here
│   └── OWG-The-Old-Course.zip
├── scenes/
│   ├── main.tscn                   ← already exists
│   ├── course_select.tscn          ← NEW - course selection screen
│   └── game.tscn                   ← NEW (or rename main.tscn)
├── scripts/
│   ├── main.gd                     ← already exists
│   ├── course_manager.gd           ← already exists - MODIFY
│   ├── course_loader.gd            ← NEW - the heavy lifter
│   ├── course_select.gd            ← NEW - selection screen logic
│   ├── terrain_generator.gd        ← already exists - MODIFY
│   ├── player.gd                   ← already exists
│   └── ball.gd                     ← already exists
└── assets/
    └── courses/                    ← extracted course data lands here at runtime
        └── (auto-created by loader)
```

---

## How It Works - Flow

```
Launch Game
    ↓
CourseSelectScreen
    ↓  (scans res://courses/ for OWG-*.zip files)
    ↓  (shows course name, splash image, hole count)
    ↓
Player picks a course → clicks Play
    ↓
CourseLoader.load_course(zip_path)
    ↓  1. Extracts zip to user://courses/<name>/
    ↓  2. Reads course.json
    ↓  3. Passes heightmap to TerrainGenerator
    ↓  4. Passes splat maps to terrain shader
    ↓  5. Passes textures to material system
    ↓  6. Emits signal: course_ready(course_data)
    ↓
CourseManager receives course_ready
    ↓  - Sets up tee positions
    ↓  - Sets up pin positions
    ↓  - Sets up hole sequence
    ↓
Game starts on Hole 1, Championship tee
```

---

## File 1: course_loader.gd
## (New file - the core extraction and loading engine)

```gdscript
extends Node
class_name CourseLoader

# Emitted when a course finishes loading
signal course_ready(course_data: Dictionary)
signal load_progress(step: String, percent: float)
signal load_failed(reason: String)

const COURSES_DIR = "res://courses/"
const EXTRACT_DIR = "user://courses/"

var current_course: Dictionary = {}


## Scan the courses directory and return a list of available courses
## Returns array of dicts: [{name, zip_path, splash_path, hole_count}]
func scan_available_courses() -> Array:
	var courses = []
	var dir = DirAccess.open(COURSES_DIR)
	if not dir:
		push_error("CourseLoader: courses directory not found at " + COURSES_DIR)
		return courses

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".zip") and file_name.begins_with("OWG-"):
			var zip_path = COURSES_DIR + file_name
			var info = _peek_course_zip(zip_path)
			if info:
				courses.append(info)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort alphabetically by name
	courses.sort_custom(func(a, b): return a.name < b.name)
	return courses


## Peek inside a zip to get course metadata without full extraction
func _peek_course_zip(zip_path: String) -> Dictionary:
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		push_error("CourseLoader: Cannot open " + zip_path)
		return {}

	# Read course.json for metadata
	if not reader.file_exists("course.json"):
		reader.close()
		return {}

	var json_bytes = reader.read_file("course.json")
	reader.close()

	var json = JSON.new()
	if json.parse(json_bytes.get_string_from_utf8()) != OK:
		return {}

	var data = json.get_data()
	return {
		"name": data.get("name", "Unknown"),
		"author": data.get("author", ""),
		"hole_count": data.get("hole_count", 18),
		"zip_path": zip_path,
		"zip_name": zip_path.get_file(),
		"splash_name": data.get("splash_image", ""),
		"terrain_size": data.get("terrain", {}).get("terrain_size_x", 0),
	}


## Main entry point - load a course from its zip path
func load_course(zip_path: String) -> void:
	emit_signal("load_progress", "Opening course package...", 0.0)

	var reader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		emit_signal("load_failed", "Cannot open: " + zip_path)
		return

	# Determine extract path
	var zip_name = zip_path.get_file().get_basename()  # e.g. OWG-The-Old-Course
	var extract_path = EXTRACT_DIR + zip_name + "/"

	# Create extract directory
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(extract_path)
	)

	emit_signal("load_progress", "Reading course data...", 0.1)

	# Extract course.json first
	var json_bytes = reader.read_file("course.json")
	var course_json_path = extract_path + "course.json"
	_write_file(course_json_path, json_bytes)

	# Parse course data
	var json = JSON.new()
	if json.parse(json_bytes.get_string_from_utf8()) != OK:
		emit_signal("load_failed", "Invalid course.json")
		reader.close()
		return

	current_course = json.get_data()
	emit_signal("load_progress", "Loading terrain...", 0.2)

	# Extract heightmap
	if reader.file_exists("terrain/heightmap.png"):
		var hm_bytes = reader.read_file("terrain/heightmap.png")
		_write_file(extract_path + "terrain/heightmap.png", hm_bytes)

	# Extract terrain meta
	if reader.file_exists("terrain/terrain_meta.json"):
		var tm_bytes = reader.read_file("terrain/terrain_meta.json")
		_write_file(extract_path + "terrain/terrain_meta.json", tm_bytes)

	emit_signal("load_progress", "Loading surface maps...", 0.4)

	# Extract splat maps
	for i in range(4):
		var splat_path = "terrain/splat/alphamap_%d.png" % i
		if reader.file_exists(splat_path):
			var bytes = reader.read_file(splat_path)
			_write_file(extract_path + splat_path, bytes)

	emit_signal("load_progress", "Loading textures...", 0.6)

	# Extract key textures (fairway, rough, bunker sand - not all 255)
	var priority_textures = [
		"textures/fairway2.png",
		"textures/grasstest.png",
		"textures/grasstest1.png",
		"textures/BunkerSandRake.png",
		"textures/GravelPath.png",
		"textures/Grass_normal_1.png",
		"textures/Grass_normal_3.png",
	]
	for tex_path in priority_textures:
		if reader.file_exists(tex_path):
			var bytes = reader.read_file(tex_path)
			_write_file(extract_path + tex_path, bytes)

	# Extract splash image
	var splash = current_course.get("splash_image", "")
	if splash != "" and reader.file_exists("images/" + splash):
		var bytes = reader.read_file("images/" + splash)
		_write_file(extract_path + "images/" + splash, bytes)
		current_course["splash_local_path"] = extract_path + "images/" + splash

	reader.close()

	emit_signal("load_progress", "Building terrain...", 0.8)

	# Store extract path in course data for other systems to use
	current_course["extract_path"] = extract_path
	current_course["heightmap_path"] = extract_path + "terrain/heightmap.png"

	emit_signal("load_progress", "Ready!", 1.0)
	emit_signal("course_ready", current_course)


## Helper - write bytes to a user:// path, creating dirs as needed
func _write_file(path: String, data: PackedByteArray) -> void:
	var global = ProjectSettings.globalize_path(path)
	var dir = global.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()


## Get a specific hole's championship tee position (Godot coords)
func get_tee_position(hole_number: int, tee_type: String = "Championship") -> Vector3:
	if current_course.is_empty():
		return Vector3.ZERO
	var holes = current_course.get("holes", [])
	for hole in holes:
		if hole.get("hole_number") == hole_number:
			for tee in hole.get("tees", []):
				if tee.get("type") == tee_type:
					var p = tee["position"]
					return Vector3(p.x, p.y, p.z)
	return Vector3.ZERO


## Get pin positions for a hole
func get_pin_positions(hole_number: int) -> Array:
	if current_course.is_empty():
		return []
	var holes = current_course.get("holes", [])
	for hole in holes:
		if hole.get("hole_number") == hole_number:
			var pins = []
			for pin in hole.get("pins", []):
				var p = pin["position"]
				pins.append({
					"position": Vector3(p.x, p.y, p.z),
					"difficulty": pin.get("difficulty", "Medium")
				})
			return pins
	return []
```

---

## File 2: course_select.gd
## (New file - course selection screen controller)

```gdscript
extends Control
class_name CourseSelectScreen

@onready var course_list = $VBoxContainer/CourseList        # ItemList node
@onready var course_name_label = $Panel/CourseName          # Label
@onready var author_label = $Panel/Author                   # Label
@onready var hole_count_label = $Panel/HoleCount            # Label
@onready var splash_image = $Panel/SplashImage              # TextureRect
@onready var play_button = $VBoxContainer/PlayButton        # Button
@onready var loading_label = $LoadingLabel                  # Label (hidden by default)

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
		course_list.add_item("No courses found - add OWG-*.zip to res://courses/")
		return

	for course in available_courses:
		course_list.add_item(course.name)

	# Auto-select first course
	if available_courses.size() > 0:
		course_list.select(0)
		_on_course_selected(0)


func _on_course_selected(index: int):
	selected_index = index
	if index < 0 or index >= available_courses.size():
		return

	var info = available_courses[index]
	course_name_label.text = info.name
	author_label.text = "by " + info.author
	hole_count_label.text = str(info.hole_count) + " holes"
	play_button.disabled = false

	# Load splash image if available
	# (peek at zip for the splash jpg)
	_load_splash_preview(info)


func _load_splash_preview(info: Dictionary):
	if info.splash_name == "":
		return
	var reader = ZIPReader.new()
	if reader.open(info.zip_path) != OK:
		return
	var img_path = "images/" + info.splash_name
	if reader.file_exists(img_path):
		var bytes = reader.read_file(img_path)
		reader.close()
		var img = Image.new()
		# Detect format from extension
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
	# Hand off to the main game scene
	# Store course data in a global autoload so game scene can access it
	GameState.current_course = course_data
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_load_failed(reason: String):
	loading_label.text = "Failed: " + reason
	play_button.disabled = false
```

---

## File 3: game_state.gd
## (New Autoload - global state shared between scenes)

```gdscript
extends Node
# Add this as an Autoload in Project Settings → Autoloads
# Name it: GameState
# Path: res://scripts/game_state.gd

var current_course: Dictionary = {}
var current_hole: int = 1
var current_tee_type: String = "Championship"
var current_pin_difficulty: String = "Medium"
var stroke_count: int = 0
var scorecard: Array = []  # array of stroke counts per hole


func reset_round():
	current_hole = 1
	stroke_count = 0
	scorecard = []
	scorecard.resize(current_course.get("hole_count", 18))
	scorecard.fill(0)


func advance_hole():
	scorecard[current_hole - 1] = stroke_count
	current_hole += 1
	stroke_count = 0


func get_current_par() -> int:
	var holes = current_course.get("holes", [])
	for hole in holes:
		if hole.get("hole_number") == current_hole:
			for tee in hole.get("tees", []):
				if tee.get("type") == current_tee_type:
					return int(tee.get("par", "4"))
	return 4
```

---

## Changes to existing course_manager.gd

Add this to your existing CourseManager - connect it to the loader:

```gdscript
# Add to course_manager.gd

var loader: CourseLoader

func _ready():
	# If we came from course select screen, course is already loaded
	if not GameState.current_course.is_empty():
		_setup_from_course_data(GameState.current_course)
	else:
		# Dev mode - load default course directly
		loader = CourseLoader.new()
		add_child(loader)
		loader.course_ready.connect(_setup_from_course_data)
		loader.load_course("res://courses/OWG-The-Old-Course.zip")


func _setup_from_course_data(course_data: Dictionary):
	# Pass heightmap to terrain generator
	var heightmap_path = course_data.get("heightmap_path", "")
	if heightmap_path != "":
		$TerrainGenerator.load_heightmap(heightmap_path)

	# Set up hole 1 starting position
	var tee_pos = _get_tee_vec3(course_data, 1, "Championship")
	$Player.global_position = tee_pos

	# Set up first pin
	var pins = _get_pins(course_data, 1)
	if pins.size() > 0:
		$Pin.global_position = pins[0].position

	print("CourseManager: Loaded ", course_data.get("name", "Unknown"))


func _get_tee_vec3(course_data: Dictionary, hole_num: int, tee_type: String) -> Vector3:
	for hole in course_data.get("holes", []):
		if hole.hole_number == hole_num:
			for tee in hole.tees:
				if tee.type == tee_type:
					return Vector3(tee.position.x, tee.position.y, tee.position.z)
	return Vector3.ZERO


func _get_pins(course_data: Dictionary, hole_num: int) -> Array:
	for hole in course_data.get("holes", []):
		if hole.hole_number == hole_num:
			return hole.get("pins", [])
	return []
```

---

## Changes to terrain_generator.gd

Add a load_heightmap function that accepts a path:

```gdscript
# Add to terrain_generator.gd

func load_heightmap(path: String) -> void:
	# Load the 16-bit PNG heightmap from the extracted course
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_error("TerrainGenerator: Failed to load heightmap from " + path)
		return

	# Read terrain meta for scale values
	var meta_path = path.get_base_dir() + "/terrain_meta.json"
	var meta = _load_json(meta_path)

	var scale_y = meta.get("scale_y", 50.0)
	var scale_xz = meta.get("scale_x", 1.1)

	# Apply to your existing heightmap processing
	# (hook into whatever _setup_terrain or equivalent you already have)
	_build_terrain_from_image(img, scale_y, scale_xz)


func _load_json(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json = JSON.new()
	json.parse(f.get_as_text())
	return json.get_data()
```

---

## Setup Checklist for Claude Code

Give CC this list in order:

1. Create `res://courses/` directory
2. Create `res://scripts/course_loader.gd` (full file above)
3. Create `res://scripts/game_state.gd` (full file above)
4. Add GameState as Autoload in project.godot
5. Create `res://scenes/course_select.tscn` with UI nodes matching course_select.gd
6. Create `res://scripts/course_select.gd` (full file above)
7. Modify `course_manager.gd` to add the new functions above
8. Modify `terrain_generator.gd` to add load_heightmap function
9. Set course_select.tscn as the main scene (or first scene)
10. Copy OWG-The-Old-Course.zip to res://courses/

---

## Course Select UI Node Structure

```
CourseSelectScreen (Control)
├── Background (ColorRect)
├── VBoxContainer
│   ├── TitleLabel ("Open World Golf")
│   ├── CourseList (ItemList)
│   └── PlayButton (Button) text="Play Round"
├── Panel (Panel - right side preview)
│   ├── SplashImage (TextureRect)
│   ├── CourseName (Label)
│   ├── Author (Label)
│   └── HoleCount (Label)
└── LoadingLabel (Label) visible=false
```
