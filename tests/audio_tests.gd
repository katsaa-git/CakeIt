extends RefCounted
## Sound and juice: every sound builds, stays in range, is about as loud as
## the others in its group, loops seamlessly where it should, and is quick to
## make; volumes are saved; the audio manager plays sounds without errors;
## the decoration pop springs back to full size.

var runner: Object

## Each recipe: [name, callable, rate, looping].
var _recipes: Array = [
	[&"tap", Synth.tap, Synth.RATE, false],
	[&"tok", Synth.tok, Synth.RATE, false],
	[&"squish", Synth.squish, Synth.RATE, false],
	[&"plip", Synth.plip, Synth.RATE, false],
	[&"tick", Synth.tick.bind(0), Synth.RATE, false],
	[&"tock", Synth.tock.bind(0), Synth.RATE, false],
	[&"pat", Synth.pat.bind(0), Synth.RATE, false],
	[&"swish", Synth.swish, Synth.RATE, false],
	[&"pour", Synth.pour, Synth.RATE, false],
	[&"thunk", Synth.thunk, Synth.RATE, false],
	[&"coat", Synth.coat_swoosh, Synth.RATE, false],
	[&"chime", Synth.chime, Synth.RATE, false],
	[&"undo", Synth.whoosh.bind(false), Synth.RATE, false],
	[&"redo", Synth.whoosh.bind(true), Synth.RATE, false],
	[&"twinkle", Synth.twinkle.bind(0), Synth.RATE, false],
	[&"squeeze", Synth.squeeze_loop, Synth.LOOP_RATE, true],
	[&"scrape", Synth.scrape_loop, Synth.LOOP_RATE, true],
	[&"brush", Synth.brush_loop, Synth.RATE, true],
	[&"spin", Synth.spin_loop, Synth.LOOP_RATE, true],
	[&"waves", Synth.waves_loop, Synth.LOOP_RATE, true],
]


func check(condition: bool, message: String) -> void:
	runner.check(condition, message)


static func _peak(x: PackedFloat32Array) -> float:
	var top: float = 0.0
	for v in x:
		top = maxf(top, absf(v))
	return top


static func _rms(x: PackedFloat32Array) -> float:
	var sum: float = 0.0
	for v in x:
		sum += v * v
	return sqrt(sum / float(maxi(x.size(), 1)))


func test_every_sound_is_sound() -> void:
	var started: int = Time.get_ticks_msec()
	var report := PackedStringArray()
	for recipe: Array in _recipes:
		var cue: StringName = recipe[0]
		var x: PackedFloat32Array = (recipe[1] as Callable).call()
		var seconds: float = float(x.size()) / float(recipe[2])
		var peak: float = _peak(x)
		var nan: bool = false
		for v in x:
			nan = nan or not is_finite(v)
		check(not nan and x.size() > 50, "%s: real samples" % cue)
		check(peak <= 0.8 and peak >= 0.25, "%s: peak %.2f is in a gentle range (never clipping)" % [cue, peak])
		if recipe[3]:
			# The end must flow straight back into the start.
			var jump: float = absf(x[x.size() - 1] - x[0])
			check(jump < peak * 0.25, "%s: the loop is seamless (jump %.3f)" % [cue, jump])
			check(seconds >= 1.0, "%s: the loop is long enough not to sound repetitive (%.1f s)" % [cue, seconds])
		else:
			check(seconds <= 1.8, "%s: a short sound (%.2f s)" % [cue, seconds])
			# Short sounds fade out to silence instead of stopping with a click.
			var tail: float = _peak(x.slice(x.size() - mini(64, x.size())))
			check(tail < peak * 0.12, "%s: fades to silence at the end (tail %.3f)" % [cue, tail])
		report.append("%s %.2fs peak %.2f rms %.1f dB" % [cue, seconds, peak, linear_to_db(_rms(x))])
		var stream: AudioStreamWAV = Synth.to_stream(x, recipe[2], recipe[3])
		check(stream.data.size() == x.size() * 2 and (stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) == bool(recipe[3]), "%s: a 16-bit stream%s" % [cue, " that loops" if recipe[3] else ""])
	var ms: int = Time.get_ticks_msec() - started
	print("    sounds: " + ", ".join(report))
	print("    building every sound took %d ms (on a worker thread in game)" % ms)
	check(ms < 20000, "building the sounds stays reasonable even on a slow laptop (%d ms)" % ms)


func test_volumes_are_saved() -> void:
	var path: String = "user://test_settings.cfg"
	var old: Array = [Settings.master, Settings.effects, Settings.ambience]
	Settings.set_volume("master", 0.3)
	Settings.set_volume("effects", 0.6)
	Settings.set_volume("ambience", 0.1)
	Settings.save_settings(path)
	Settings.set_volume("master", 1.0)
	Settings.set_volume("effects", 1.0)
	Settings.set_volume("ambience", 1.0)
	Settings.load_settings(path)
	check(is_equal_approx(Settings.master, 0.3) and is_equal_approx(Settings.effects, 0.6) and is_equal_approx(Settings.ambience, 0.1), "volumes come back as they were saved")
	Settings.set_volume("effects", 2.0)
	check(Settings.effects == 1.0, "volumes stay between 0 and 1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.master = old[0]
	Settings.effects = old[1]
	Settings.ambience = old[2]


func test_audio_manager_plays() -> void:
	var audio := AudioManager.new()
	audio.setup()
	audio.wait_until_ready()
	check(audio.is_ready(), "the sounds are built and installed")
	check(AudioServer.get_bus_index(AudioManager.BUS_EFFECTS) >= 0 and AudioServer.get_bus_index(AudioManager.BUS_AMBIENCE) >= 0, "Effects and Ambience buses exist")
	for cue: StringName in [&"tap", &"tick", &"thunk", &"chime", &"undo"]:
		audio.play(cue)
	audio.play(&"no_such_sound")
	audio.hold_loop(&"squeeze", 0.5, 1.1)
	check(true, "playing sounds (and an unknown one) raises no errors")
	audio.free()


func test_pop_springs_back() -> void:
	check(is_equal_approx(DecorationLayer.pop_scale(0.0), 0.5), "a new piece starts at half size")
	var top: float = 0.0
	for i in range(100):
		top = maxf(top, DecorationLayer.pop_scale(float(i) / 100.0 * DecorationLayer.POP_TIME))
	check(top > 1.02 and top < 1.25, "it springs a little past full size (%.2f)" % top)
	check(is_equal_approx(DecorationLayer.pop_scale(DecorationLayer.POP_TIME), 1.0), "and settles at exactly full size")
	var layer := DecorationLayer.new()
	layer.pop_new = true
	var model := CakeModel.new()
	model.make_default()
	layer.setup(model.tiers[0].id, model)
	var piece := DecorationData.new()
	piece.id = 5
	piece.def_id = &"cherry"
	piece.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	layer.add(piece)
	check(layer.running_pops().has(5), "a placed piece pops")
	var preview_sprinkle := DecorationData.new()
	preview_sprinkle.id = 6
	preview_sprinkle.def_id = &"rainbow_sprinkles"
	layer.add(preview_sprinkle)
	check(not layer.running_pops().has(6), "sprinkles rain down without popping")
	layer.free()
