extends Node
# Autoload — add in Project Settings → Autoloads as "GameState"

var current_course: Dictionary = {}
var current_hole: int = 1
var current_tee_type: String = "Championship"
var current_pin_difficulty: String = "Medium"
var play_mode: String = "full"
var stroke_count: int = 0
var scorecard: Array = []

# Pre-loaded course assets — populated by CoursePreloader before main.tscn loads
var preloaded_heightmap:     Image         = null
var preloaded_terrain_meta:  Dictionary    = {}
var preloaded_textures:      Dictionary    = {}  # surface → ImageTexture
var preloaded_splatmap:      ImageTexture  = null
var preloaded_splatmap_img:  Image         = null
var preloaded_holes:         Dictionary    = {}  # hole_num → {tee, pin, par, ...}

# Player profile — set on player setup screen
var player_name:   String = "Player"
var player_sex:    String = "M"
var right_handed:  bool   = true


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
