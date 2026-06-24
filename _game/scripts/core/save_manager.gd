## Purpose: Serialise and deserialise all persistent game data. Stub — flesh out after core loop.
extends Node

const SAVE_PATH: String = "user://savegame.cfg"
const SAVE_VERSION: int = 1

var _data: Dictionary = {}

func _ready() -> void:
	load_save()

func save() -> void:
	_data["meta"] = {"version": SAVE_VERSION}
	var file := ConfigFile.new()
	for section: String in _data:
		for key: String in _data[section]:
			file.set_value(section, key, _data[section][key])
	file.save(SAVE_PATH)

func load_save() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for section: String in file.get_sections():
		_data[section] = {}
		for key: String in file.get_section_keys(section):
			_data[section][key] = file.get_value(section, key)
	_migrate_if_needed()

# Brings an older save up to the current schema. v0 (pre-versioning) → v1 is a
# no-op stamp; future schema changes branch here before the data is used.
func _migrate_if_needed() -> void:
	var meta: Dictionary = _data.get("meta", {})
	var v: int = meta.get("version", 0)
	if v == SAVE_VERSION:
		return
	_data["meta"] = {"version": SAVE_VERSION}

func get_value(section: String, key: String, default: Variant = null) -> Variant:
	if _data.has(section) and _data[section].has(key):
		return _data[section][key]
	return default

func set_value(section: String, key: String, value: Variant) -> void:
	if not _data.has(section):
		_data[section] = {}
	_data[section][key] = value

func delete_save() -> void:
	_data.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
