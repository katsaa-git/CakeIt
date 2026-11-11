class_name Settings
extends RefCounted
## Player settings kept between sessions in user://settings.cfg: for now the
## sound volumes (0..1). Read once at start-up; saved whenever they change.

const PATH: String = "user://settings.cfg"

## Defaults: effects fairly present, the seaside ambience barely there.
static var master: float = 0.8
static var effects: float = 0.8
static var ambience: float = 0.45

static var _loaded: bool = false


static func load_settings(path: String = PATH) -> void:
	_loaded = true
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	master = clampf(float(file.get_value("sound", "master", master)), 0.0, 1.0)
	effects = clampf(float(file.get_value("sound", "effects", effects)), 0.0, 1.0)
	ambience = clampf(float(file.get_value("sound", "ambience", ambience)), 0.0, 1.0)


static func save_settings(path: String = PATH) -> void:
	var file := ConfigFile.new()
	file.load(path)
	file.set_value("sound", "master", snappedf(master, 0.01))
	file.set_value("sound", "effects", snappedf(effects, 0.01))
	file.set_value("sound", "ambience", snappedf(ambience, 0.01))
	file.save(path)


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


## A volume by name ("master", "effects" or "ambience").
static func volume(key: String) -> float:
	ensure_loaded()
	match key:
		"master":
			return master
		"effects":
			return effects
		"ambience":
			return ambience
	return 0.0


static func set_volume(key: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match key:
		"master":
			master = value
		"effects":
			effects = value
		"ambience":
			ambience = value
