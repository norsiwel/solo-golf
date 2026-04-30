extends CanvasLayer

# Hole map overlay - models a paper scorecard pocket map
# Toggle with M key - shows in bottom-right corner
# Deliberately minimal - fairway shape, hazards, green, tee, player dot only

var visible_map := false
var map_control: Control
var player_ref = null

# Map data - set from hole metadata
var tee_pos := Vector2.ZERO
var green_pos := Vector2.ZERO
var fairway_points: Array[Vector2] = []
var bunkers: Array[Dictionary] = []   # {pos, size}
var water: Array[Dictionary] = []     # {points} polygons
var ob_lines: Array[Array] = []       # out of bounds boundary lines

func _ready():
	layer = 8
	visible = false
	_build_ui()
	call_deferred("_connect_scene")

func _connect_scene():
	player_ref = get_tree().current_scene.get_node_or_null("Player")
	_load_hole_data()

func _load_hole_data():
	# For hole 1 - hardcoded for now, will read from hole metadata later
	# All positions in world space, map will scale/fit them
	tee_pos = Vector2(0, 0)
	green_pos = Vector2(0, -165)  # 165m straight ahead

	# Fairway outline - simple straight corridor with slight variations
	fairway_points = [
		Vector2(-12, -5),   # tee left edge
		Vector2(12, -5),    # tee right edge
		Vector2(14, -80),   # mid right
		Vector2(10, -165),  # green right
		Vector2(-10, -165), # green left
		Vector2(-14, -80),  # mid left
		Vector2(-12, -5),   # back to start
	]

	# Bunkers - position and approximate radius
	bunkers = [
		{"pos": Vector2(-16, -163), "w": 8, "h": 5},
		{"pos": Vector2(14, -170),  "w": 6, "h": 5},
	]

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
				map_control.tee_pos = tee_pos
				map_control.green_pos = green_pos
				map_control.fairway_points = fairway_points
				map_control.bunkers = bunkers
				if player_ref:
					var wp = player_ref.global_position
					map_control.player_world = Vector2(wp.x, wp.z)
				map_control.queue_redraw()

func _process(_delta):
	if visible_map and map_control and player_ref:
		var wp = player_ref.global_position
		map_control.player_world = Vector2(wp.x, wp.z)
		map_control.queue_redraw()


class HoleMapDrawing extends Control:
	var tee_pos := Vector2.ZERO
	var green_pos := Vector2(0, -165)
	var fairway_points: Array[Vector2] = []
	var bunkers: Array[Dictionary] = []
	var player_world := Vector2.ZERO

	# Paper colors
	const COL_PAPER    := Color(0.94, 0.90, 0.78, 0.92)  # aged paper
	const COL_INK      := Color(0.15, 0.12, 0.08, 1.0)   # dark ink
	const COL_FAIRWAY  := Color(0.55, 0.72, 0.40, 0.85)  # muted green
	const COL_GREEN    := Color(0.30, 0.62, 0.28, 0.95)  # darker green
	const COL_SAND     := Color(0.82, 0.74, 0.48, 0.90)  # sand tan
	const COL_WATER    := Color(0.35, 0.55, 0.82, 0.85)  # muted blue
	const COL_OB       := Color(0.80, 0.15, 0.10, 0.90)  # red OB
	const COL_PLAYER   := Color(0.90, 0.20, 0.10, 1.0)   # red dot
	const COL_TEE      := Color(0.15, 0.12, 0.08, 1.0)   # ink
	const MAP_PADDING  := 16.0

	func _world_to_map(world_pt: Vector2, bounds_min: Vector2, bounds_max: Vector2, map_rect: Rect2) -> Vector2:
		var range_w = bounds_max.x - bounds_min.x
		var range_h = bounds_max.y - bounds_min.y
		if range_w < 1: range_w = 1
		if range_h < 1: range_h = 1
		var nx = (world_pt.x - bounds_min.x) / range_w
		var ny = (world_pt.y - bounds_min.y) / range_h
		return Vector2(
			map_rect.position.x + nx * map_rect.size.x,
			map_rect.position.y + ny * map_rect.size.y
		)

	func _draw():
		var w = size.x
		var h = size.y

		# Paper background with rounded corners
		draw_rect(Rect2(0, 0, w, h), COL_PAPER)
		# Border - ink line, slightly rough feel
		draw_rect(Rect2(2, 2, w-4, h-4), COL_INK, false, 1.5)
		draw_rect(Rect2(4, 4, w-8, h-8), COL_INK, false, 0.5)

		# Hole number top center
		# (draw_string needs a font ref which is complex - skip for now)

		# Calculate world bounds from all points
		var all_pts: Array[Vector2] = []
		all_pts.append(tee_pos)
		all_pts.append(green_pos)
		for p in fairway_points:
			all_pts.append(p)
		for b in bunkers:
			all_pts.append(b["pos"])

		var min_x = all_pts[0].x
		var max_x = all_pts[0].x
		var min_y = all_pts[0].y
		var max_y = all_pts[0].y
		for p in all_pts:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)

		# Add padding to bounds
		min_x -= 20; max_x += 20
		min_y -= 20; max_y += 20

		var bounds_min = Vector2(min_x, min_y)
		var bounds_max = Vector2(max_x, max_y)
		var map_rect = Rect2(MAP_PADDING, MAP_PADDING + 14,
							 w - MAP_PADDING*2, h - MAP_PADDING*2 - 14)

		# Draw fairway filled polygon
		if fairway_points.size() >= 3:
			var mapped: PackedVector2Array = []
			for p in fairway_points:
				mapped.append(_world_to_map(p, bounds_min, bounds_max, map_rect))
			draw_colored_polygon(mapped, COL_FAIRWAY)
			# Ink outline
			draw_polyline(mapped, COL_INK, 1.0, true)

		# Draw bunkers as oval blobs
		for b in bunkers:
			var bc = _world_to_map(b["pos"], bounds_min, bounds_max, map_rect)
			# Scale bunker size to map
			var scale_x = map_rect.size.x / (bounds_max.x - bounds_min.x)
			var scale_y = map_rect.size.y / (bounds_max.y - bounds_min.y)
			var bw = b["w"] * scale_x * 0.5
			var bh = b["h"] * scale_y * 0.5
			# Draw as an ellipse using polygon
			var bunker_pts: PackedVector2Array = []
			for i in 12:
				var a = i * TAU / 12
				bunker_pts.append(bc + Vector2(cos(a)*bw, sin(a)*bh))
			draw_colored_polygon(bunker_pts, COL_SAND)
			draw_polyline(bunker_pts, COL_INK, 0.8, true)

		# Draw green as circle
		var green_map = _world_to_map(green_pos, bounds_min, bounds_max, map_rect)
		draw_circle(green_map, 8.0, COL_GREEN)
		draw_arc(green_map, 8.0, 0, TAU, 12, COL_INK, 1.2)

		# Draw tee as small square
		var tee_map = _world_to_map(tee_pos, bounds_min, bounds_max, map_rect)
		var ts = 5.0
		draw_rect(Rect2(tee_map.x - ts, tee_map.y - ts, ts*2, ts*2), COL_FAIRWAY)
		draw_rect(Rect2(tee_map.x - ts, tee_map.y - ts, ts*2, ts*2), COL_INK, false, 1.2)

		# Draw player position as red dot
		var player_map = _world_to_map(player_world, bounds_min, bounds_max, map_rect)
		draw_circle(player_map, 4.5, COL_PLAYER)
		draw_arc(player_map, 4.5, 0, TAU, 8, Color(0,0,0,0.5), 1.0)

		# Crosshatch hint in rough areas (outside fairway) - just a few lines
		# to evoke the paper map feel without being distracting
		for i in 3:
			var hx = map_rect.position.x + map_rect.size.x * (0.1 + i * 0.08)
			draw_line(Vector2(hx, map_rect.position.y + 5),
					  Vector2(hx - 6, map_rect.position.y + 18),
					  Color(0.4, 0.35, 0.25, 0.3), 0.7)

		# "HOLE 1" label area - small ink marks at top
		draw_line(Vector2(w*0.3, 10), Vector2(w*0.7, 10), COL_INK, 0.8)
