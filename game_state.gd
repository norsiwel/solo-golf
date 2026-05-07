extends Node
# Autoload — add in Project Settings → Autoloads as "GameState"
# Path: res://game_state.gd

var current_course: Dictionary = {}
var current_hole: int = 1
var current_tee_type: String = "Championship"
var current_pin_difficulty: String = "Medium"
var stroke_count: int = 0
var scorecard: Array = []


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
