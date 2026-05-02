extends CanvasLayer

var visible_map := false
var map_control: Control
var player_ref = null
var current_hole := 1

# Map data - loaded from CourseManager
var tee_pos := Vector2.ZERO
var green_pos := Vector2.ZERO
var fairway_points: Array[Vector2] = []
var bunkers: Array[Dictionary] = []
var hole_number := 1
var par := 4
var yardage := 0
var course_name := ""

func _ready():
	layer = 8
	visible = false
	_build_ui()
	call_deferred("_connect_scene")

func _connect_scene():
	player_ref = get_tree().current_scene.get_node_or_null("Player")
	# Connect to course manager signals
	var cm = get_tree().current_scene.get_node_or_null("CourseManager")
	if cm and cm.has_signal("hole_changed"):
		cm.connect("hole_changed", _on_hole_changed)

func _on_hole_changed(hole_num: int, p: int, yds: int):
	load_hole(hole_num)

func load_hole(hole_num: int):
	# Read from CourseManager metadata
	var cm = get_tree().current_scene.get_node_or_null("CourseManager")
	if not cm:
		return

	var hole = cm.get_hole_data(hole_num)
	if hole.is_empty():
		return

	current_hole = hole_num
	hole_number = hole_num
	par = hole.get("par", 4)
	yardage = hole.get("yardage", 0)
	course_name = cm.get_course_name()

	# Get tee and pin world positions (already in Godot coords from manager)
	var tee = cm.get_tee_position(hole_num)
	var pin = cm.get_pin_position(hole_num)

	# Map uses X/Z (top-down view) — Y is elevation, ignore for 2D map
	tee_pos  = Vector2(tee.x, tee.z)
	green_pos = Vector2(pin.x, pin.z)

	# Generate fairway corridor from tee to green
	# Uses all tee variants and pin variants to get corridor width hints
	_build_fairway_from_metadata(hole)

	# Extract bunker hints from metadata if available
	bunkers.clear()
	for b in hole.get("bunkers", []):
		var bp = b.get("position", {})
		if not bp.is_empty():
			bunkers.append({
				"pos": Vector2(bp.get("x", 0), -bp.get("z", 0)),
				"w": b.get("width", 8),
				"h": b.get("height", 5)
			})

	if map_control:
		map_control.queue_redraw()

func _build_fairway_from_metadata(hole: Dictionary):
	# Build a fairway polygon from tee and pin positions
	# Uses all tee variants as the tee cluster, all pins as the green cluster
	# Connects them with a corridor of appropriate width

	var all_tees = hole.get("all_tees", [])
	var all_pins = hole.get("all_pins", [])

	# Gather tee cluster center
	var tee_pts: Array[Vector2] = []
	for t in all_tees:
		var p = t.get("position", {})
		if not p.is_empty():
			tee_pts.append(Vector2(p.get("x", 0), p.get("z", 0)))

	# Gather pin cluster center
	var pin_pts: Array[Vector2] = []
	for p in all_pins:
		var pos = p.get("position", {})
		if not pos.is_empty():
			pin_pts.append(Vector2(pos.get("x", 0), pos.get("z", 0)))

	# Use tee and green as corridor endpoints
	var t = tee_pos
	var g = green_pos

	# Corridor width — wider for longer holes
	var dist = t.distance_to(g)
	var width = clamp(dist * 0.12, 15.0, 35.0)

	# Direction vector
	var dir = (g - t).normalized()
	var perp = Vector2(-dir.y, dir.x)

	# Simple straight corridor — 6 points
	# For doglegs we'd need intermediate waypoints but this is the starter
	fairway_points.clear()
	fairway_points.append(t + perp * width * 0.5)
	fairway_points.append(t - perp * width * 0.5)
	fairway_points.append(g - perp * width * 0.4)
	fairway_points.append(g + perp * width * 0.4)

	# Check if there are intermediate waypoints (shots data) for doglegs
	# For now just use straight — dogleg support can come later

func _build_ui():
	map_control = HoleMapDrawing.new()
	map_control.name = "MapDrawing"
	map_control.set_anchor(SIDE_LEFT,   0.72)
	map_control.set_anchor(SIDE_TOP,    0.55)
	map_control.set_anchor(SIDE_RIGHT,  0.99)
	map_control.set_anchor(SIDE_BOTTOM, 0.99)
	add_child(map_control)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			visible_map = !visible_map
			visible = visible_map
			if visible_map and map_control:
				_push_to_drawing()
				map_control.queue_redraw()

func _push_to_drawing():
	map_control.tee_pos = tee_pos
	map_control.green_pos = green_pos
	map_control.fairway_points = fairway_points
	map_control.bunkers = bunkers
	map_control.hole_number = hole_number
	map_control.par = par
	map_control.yardage = yardage
	map_control.course_name = course_name
	if player_ref:
		var wp = player_ref.global_position
		map_control.player_world = Vector2(wp.x, wp.z)

func _process(_delta):
	if visible_map and map_control and player_ref:
		var wp = player_ref.global_position
		map_control.player_world = Vector2(wp.x, wp.z)
		_push_to_drawing()
		map_control.queue_redraw()


class HoleMapDrawing extends Control:
	var tee_pos := Vector2.ZERO
	var green_pos := Vector2(0, -165)
	var fairway_points: Array[Vector2] = []
	var bunkers: Array[Dictionary] = []
	var player_world := Vector2.ZERO
	var hole_number := 1
	var par := 4
	var yardage := 0
	var course_name := ""

	const COL_PAPER   := Color(0.94, 0.90, 0.78, 0.92)
	const COL_INK     := Color(0.15, 0.12, 0.08, 1.0)
	const COL_FAIRWAY := Color(0.55, 0.72, 0.40, 0.85)
	const COL_GREEN   := Color(0.30, 0.62, 0.28, 0.95)
	const COL_SAND    := Color(0.82, 0.74, 0.48, 0.90)
	const COL_PLAYER  := Color(0.90, 0.20, 0.10, 1.0)
	const MAP_PADDING := 14.0

	func _world_to_map(world_pt: Vector2, bounds_min: Vector2, bounds_max: Vector2, map_rect: Rect2) -> Vector2:
		var range_w = max(bounds_max.x - bounds_min.x, 1.0)
		var range_h = max(bounds_max.y - bounds_min.y, 1.0)
		var nx = (world_pt.x - bounds_min.x) / range_w
		var ny = (world_pt.y - bounds_min.y) / range_h
		return Vector2(
			map_rect.position.x + nx * map_rect.size.x,
			map_rect.position.y + ny * map_rect.size.y
		)

	func _draw():
		var w = size.x
		var h = size.y

		# Paper background
		draw_rect(Rect2(0, 0, w, h), COL_PAPER)
		draw_rect(Rect2(2, 2, w-4, h-4), COL_INK, false, 1.5)
		draw_rect(Rect2(4, 4, w-8, h-8), COL_INK, false, 0.5)

		# Collect all points for bounds
		var all_pts: Array[Vector2] = [tee_pos, green_pos]
		for p in fairway_points: all_pts.append(p)
		for b in bunkers: all_pts.append(b["pos"])

		var min_x = all_pts[0].x; var max_x = all_pts[0].x
		var min_y = all_pts[0].y; var max_y = all_pts[0].y
		for p in all_pts:
			min_x = min(min_x, p.x); max_x = max(max_x, p.x)
			min_y = min(min_y, p.y); max_y = max(max_y, p.y)

		min_x -= 30; max_x += 30; min_y -= 30; max_y += 30
		var bounds_min = Vector2(min_x, min_y)
		var bounds_max = Vector2(max_x, max_y)
		var map_rect = Rect2(MAP_PADDING, MAP_PADDING + 16, w - MAP_PADDING*2, h - MAP_PADDING*2 - 16)

		# Fairway
		if fairway_points.size() >= 3:
			var mapped: PackedVector2Array = []
			for p in fairway_points:
				mapped.append(_world_to_map(p, bounds_min, bounds_max, map_rect))
			draw_colored_polygon(mapped, COL_FAIRWAY)
			draw_polyline(mapped, COL_INK, 1.0, true)

		# Bunkers
		for b in bunkers:
			var bc = _world_to_map(b["pos"], bounds_min, bounds_max, map_rect)
			var sx = map_rect.size.x / max(bounds_max.x - bounds_min.x, 1.0)
			var sy = map_rect.size.y / max(bounds_max.y - bounds_min.y, 1.0)
			var bw = b.get("w", 8) * sx * 0.5
			var bh = b.get("h", 5) * sy * 0.5
			var pts: PackedVector2Array = []
			for i in 12:
				var a = i * TAU / 12
				pts.append(bc + Vector2(cos(a)*bw, sin(a)*bh))
			draw_colored_polygon(pts, COL_SAND)
			draw_polyline(pts, COL_INK, 0.8, true)

		# Green circle
		var gm = _world_to_map(green_pos, bounds_min, bounds_max, map_rect)
		draw_circle(gm, 9.0, COL_GREEN)
		draw_arc(gm, 9.0, 0, TAU, 12, COL_INK, 1.2)

		# Tee square
		var tm = _world_to_map(tee_pos, bounds_min, bounds_max, map_rect)
		var ts = 5.0
		draw_rect(Rect2(tm.x-ts, tm.y-ts, ts*2, ts*2), COL_FAIRWAY)
		draw_rect(Rect2(tm.x-ts, tm.y-ts, ts*2, ts*2), COL_INK, false, 1.2)

		# Player dot
		var pm = _world_to_map(player_world, bounds_min, bounds_max, map_rect)
		draw_circle(pm, 4.5, COL_PLAYER)
		draw_arc(pm, 4.5, 0, TAU, 8, Color(0,0,0,0.5), 1.0)

		# Crosshatch rough hint
		for i in 4:
			var hx = map_rect.position.x + map_rect.size.x * (0.05 + i * 0.07)
			draw_line(Vector2(hx, map_rect.position.y+4), Vector2(hx-5, map_rect.position.y+14),
				Color(0.4, 0.35, 0.25, 0.25), 0.7)

		# Top rule line for label area
		draw_line(Vector2(w*0.1, 12), Vector2(w*0.9, 12), COL_INK, 0.8)
