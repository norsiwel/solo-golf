extends Node
## ProfileManager — Autoload singleton
## Handles save/load/delete of golfer profiles from user://profiles/
## Add to Project Settings > Autoloads as "ProfileManager"

const PROFILES_DIR := "user://profiles/"
const LAST_ACTIVE_KEY := "last_active"

## Currently active profile data
var active: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PROFILES_DIR)
	)


## Returns Array of Dicts — all saved profiles, sorted alphabetically.
## Each dict: { name, sex, right_handed, last_active }
func list_profiles() -> Array:
	var profiles: Array = []
	var dir = DirAccess.open(PROFILES_DIR)
	if not dir:
		return profiles
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var data = _load_file(PROFILES_DIR + fname)
			if not data.is_empty():
				profiles.append(data)
		fname = dir.get_next()
	dir.list_dir_end()
	profiles.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
	return profiles


## Save a profile dict to disk. Creates or overwrites.
func save_profile(data: Dictionary) -> void:
	var fname = _safe_filename(data.name)
	var f = FileAccess.open(PROFILES_DIR + fname, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


## Mark one profile as last_active, clear flag on all others.
func set_active(profile_name: String) -> void:
	var profiles = list_profiles()
	for p in profiles:
		p[LAST_ACTIVE_KEY] = (p.name == profile_name)
		save_profile(p)
	# Load into active slot
	for p in profiles:
		if p.name == profile_name:
			active = p
			# Push into GameState
			GameState.player_name  = p.name
			GameState.player_sex   = p.get("sex", "M")
			GameState.right_handed = p.get("right_handed", true)
			return


## Delete a profile by name.
func delete_profile(profile_name: String) -> void:
	var fname = PROFILES_DIR + _safe_filename(profile_name)
	if FileAccess.file_exists(fname):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fname))
	if active.get("name", "") == profile_name:
		active = {}


## Returns the last-active profile dict, or empty dict if none.
func get_last_active() -> Dictionary:
	for p in list_profiles():
		if p.get(LAST_ACTIVE_KEY, false):
			return p
	return {}


## True if any profiles exist on disk.
func has_profiles() -> bool:
	return not list_profiles().is_empty()


# ── internal helpers ──────────────────────────────────────────────────────

func _load_file(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return {}
	f.close()
	var data = json.get_data()
	if data is Dictionary:
		return data
	return {}


func _safe_filename(profile_name: String) -> String:
	# Strip anything that isn't alphanumeric, space, dash, underscore
	var safe = ""
	for c in profile_name:
		if c.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789 -_":
			safe += c
	safe = safe.strip_edges().replace(" ", "_").to_lower()
	if safe == "":
		safe = "golfer"
	return safe + ".json"
