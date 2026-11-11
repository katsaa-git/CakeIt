class_name AudioManager
extends Node
## Plays the game's sounds, all made in code by Synth (no audio files).
##
## The sounds are built once, on a worker thread right after start-up (the
## launch fade-in covers it), so loading never hitches. Short sounds play on
## one polyphonic player; the continuous ones (the squeeze of the bag, the
## scraper, the dust brush, the turntable, the waves outside) are loops whose
## volume glides toward a goal the game sets every frame.
##
## Two buses under Master: "Effects" and "Ambience", with the player's
## volumes from Settings.

const BUS_EFFECTS: StringName = &"Effects"
const BUS_AMBIENCE: StringName = &"Ambience"
## Loops below this gain are paused (no work at all).
const SILENT: float = 0.002
const LOOPS: Array[StringName] = [&"squeeze", &"scrape", &"brush", &"spin", &"waves"]

var _streams: Dictionary = {}
var _task: int = -1
var _ready_to_play: bool = false
var _built: Dictionary = {}
var _oneshot: AudioStreamPlayer
var _playback: AudioStreamPlaybackPolyphonic
var _loops: Dictionary = {}
## Loop name -> [goal gain, current gain, goal pitch, how fast the goal fades (per second)]
var _loop_state: Dictionary = {}
var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0


func _ready() -> void:
	setup()


## Builds the buses and players and starts making the sounds (once).
func setup() -> void:
	if _oneshot != null:
		return
	name = "Audio"
	_rng.randomize()
	_ensure_bus(BUS_EFFECTS)
	_ensure_bus(BUS_AMBIENCE)
	Settings.ensure_loaded()
	apply_volumes()
	_oneshot = AudioStreamPlayer.new()
	_oneshot.name = "OneShots"
	var polyphonic := AudioStreamPolyphonic.new()
	polyphonic.polyphony = 32
	_oneshot.stream = polyphonic
	_oneshot.bus = BUS_EFFECTS
	add_child(_oneshot)
	for loop_name in LOOPS:
		var player := AudioStreamPlayer.new()
		player.name = String(loop_name).capitalize()
		player.bus = BUS_AMBIENCE if loop_name == &"waves" else BUS_EFFECTS
		player.volume_db = -80.0
		add_child(player)
		_loops[loop_name] = player
		_loop_state[loop_name] = [0.0, 0.0, 1.0, 6.0]
	# The sea is always there, quietly.
	_loop_state[&"waves"] = [0.7, 0.0, 1.0, 0.0]
	_task = WorkerThreadPool.add_task(_synthesize, false, "Synthesize sounds")


## True once every sound is built.
func is_ready() -> bool:
	return _ready_to_play


## Builds every sound (on a worker thread).
func _synthesize() -> void:
	var built: Dictionary = {}
	built[&"tap"] = [Synth.to_stream(Synth.tap(), Synth.RATE)]
	built[&"tok"] = [Synth.to_stream(Synth.tok(), Synth.RATE)]
	built[&"squish"] = [Synth.to_stream(Synth.squish(), Synth.RATE)]
	built[&"plip"] = [Synth.to_stream(Synth.plip(), Synth.RATE)]
	built[&"tick"] = []
	for v in range(5):
		built[&"tick"].append(Synth.to_stream(Synth.tick(v), Synth.RATE))
	built[&"tock"] = []
	for v in range(3):
		built[&"tock"].append(Synth.to_stream(Synth.tock(v), Synth.RATE))
	built[&"pat"] = []
	for v in range(3):
		built[&"pat"].append(Synth.to_stream(Synth.pat(v), Synth.RATE))
	built[&"swish"] = [Synth.to_stream(Synth.swish(), Synth.RATE)]
	built[&"pour"] = [Synth.to_stream(Synth.pour(), Synth.RATE)]
	built[&"thunk"] = [Synth.to_stream(Synth.thunk(), Synth.RATE)]
	built[&"coat"] = [Synth.to_stream(Synth.coat_swoosh(), Synth.RATE)]
	built[&"chime"] = [Synth.to_stream(Synth.chime(), Synth.RATE)]
	built[&"undo"] = [Synth.to_stream(Synth.whoosh(false), Synth.RATE)]
	built[&"redo"] = [Synth.to_stream(Synth.whoosh(true), Synth.RATE)]
	built[&"twinkle"] = []
	for v in range(4):
		built[&"twinkle"].append(Synth.to_stream(Synth.twinkle(v), Synth.RATE))
	built[&"squeeze"] = [Synth.to_stream(Synth.squeeze_loop(), Synth.LOOP_RATE, true)]
	built[&"scrape"] = [Synth.to_stream(Synth.scrape_loop(), Synth.LOOP_RATE, true)]
	built[&"brush"] = [Synth.to_stream(Synth.brush_loop(), Synth.RATE, true)]
	built[&"spin"] = [Synth.to_stream(Synth.spin_loop(), Synth.LOOP_RATE, true)]
	built[&"waves"] = [Synth.to_stream(Synth.waves_loop(), Synth.LOOP_RATE, true)]
	_built = built


## Waits for the sounds to be built (tests, and before quitting).
func wait_until_ready() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_install()


func _install() -> void:
	_streams = _built
	for loop_name in LOOPS:
		var player: AudioStreamPlayer = _loops[loop_name]
		player.stream = _streams[loop_name][0]
	_ready_to_play = true


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _process(delta: float) -> void:
	_time += delta
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_install()
	if not _ready_to_play:
		return
	for loop_name in LOOPS:
		var state: Array = _loop_state[loop_name]
		var goal: float = state[0]
		var gain: float = move_toward(float(state[1]), goal, delta * (6.0 if goal > float(state[1]) else 3.0))
		state[1] = gain
		# Goals fade on their own unless something keeps setting them.
		state[0] = maxf(goal - delta * float(state[3]), 0.0)
		var player: AudioStreamPlayer = _loops[loop_name]
		if gain <= SILENT:
			if player.playing:
				player.stop()
			continue
		if not player.playing:
			player.play(_rng.randf() * player.stream.get_length() * 0.9)
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = lerpf(player.pitch_scale, float(state[2]), 1.0 - exp(-8.0 * delta))


## Plays a short sound. `volume_db` is relative; `jitter` varies the pitch a
## little each time so repeats never sound mechanical.
func play(cue: StringName, volume_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.04) -> void:
	if not _ready_to_play or not _streams.has(cue) or not is_inside_tree():
		return
	if _playback == null or not _oneshot.playing:
		_oneshot.play()
		_playback = _oneshot.get_stream_playback() as AudioStreamPlaybackPolyphonic
	var variants: Array = _streams[cue]
	var stream: AudioStream = variants[_rng.randi() % variants.size()]
	_playback.play_stream(stream, 0.0, volume_db, pitch * (1.0 + _rng.randf_range(-jitter, jitter)))


## Plays a short sound at most every `gap` seconds (sprinkles, glints).
func play_limited(cue: StringName, gap: float, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _time - float(_last_played.get(cue, -10.0)) < gap:
		return
	_last_played[cue] = _time
	play(cue, volume_db, pitch, 0.08)


## Keeps a loop going at `gain` (0..1) for now; it fades out by itself at
## `fade` per second unless set again.
func hold_loop(loop_name: StringName, gain: float, pitch: float = 1.0, fade: float = 6.0) -> void:
	var state: Array = _loop_state.get(loop_name, [])
	if state.is_empty():
		return
	state[0] = maxf(float(state[0]), clampf(gain, 0.0, 1.0))
	state[2] = pitch
	state[3] = fade


static func apply_volumes() -> void:
	_set_bus(&"Master", Settings.master)
	_set_bus(BUS_EFFECTS, Settings.effects)
	_set_bus(BUS_AMBIENCE, Settings.ambience)


static func _set_bus(bus_name: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.001)


static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


# --- What makes which sound ------------------------------------------------------

## Connects the sounds to the decorating scene's tools, cake and interface.
func attach(main: Node) -> void:
	var context: EditorContext = main.get("context")
	var tools: ToolController = main.get("tools")
	var piping := tools.tools.get(&"pipe") as PipingTool
	if piping != null:
		piping.stroke_started.connect(func(_p: Vector3, _n: Vector3, _c: Color) -> void: play(&"squish", -4.0))
		piping.stroke_finished.connect(func(_s: StrokeData) -> void: play(&"plip", -8.0))
		piping.flow_changed.connect(func(flow: float) -> void: hold_loop(&"squeeze", flow * 0.55, 0.85 + 0.3 * flow, 20.0))
	var decorate := tools.tools.get(&"decorate") as DecorationTool
	if decorate != null:
		decorate.piece_placed.connect(_on_piece_placed)
	var coat := tools.tools.get(&"coat") as CoatTool
	if coat != null:
		coat.coat_applied.connect(func(_p: Vector3, _c: Color) -> void: play(&"coat", -3.0))
	var spatula := tools.tools.get(&"spatula") as SpatulaTool
	if spatula != null:
		spatula.smoothing.connect(func(_p: Vector3, speed: float) -> void: hold_loop(&"scrape", clampf(speed * 0.5, 0.15, 0.6), 0.9 + clampf(speed * 0.1, 0.0, 0.2), 5.0))
		spatula.fully_smooth.connect(func(_p: Vector3) -> void: play(&"chime", -6.0, 1.0, 0.0))
	var dust := tools.tools.get(&"dust") as DustTool
	if dust != null:
		dust.dusting.connect(func(_p: Vector3) -> void:
			hold_loop(&"brush", 0.5, 1.0, 4.0)
			if _rng.randf() < 0.08:
				play_limited(&"twinkle", 0.18, -14.0, _rng.randf_range(0.9, 1.15)))
	var tiers := tools.tools.get(&"tiers") as TierTool
	if tiers != null:
		tiers.tier_removed.connect(func() -> void: play(&"undo", -6.0, 0.8))
		tiers.tier_resized.connect(func(_id: int) -> void: play(&"pat", -4.0, 0.7))
	tools.undo_performed.connect(func(_c: CakeCommand) -> void: play(&"undo", -6.0))
	tools.redo_performed.connect(func(_c: CakeCommand) -> void: play(&"redo", -6.0))
	context.tool_changed.connect(func(_t: StringName) -> void: play(&"tok", -6.0))
	var view: CakeView = main.get("cake_view")
	view.tier_added_visual.connect(func(_v: TierView) -> void:
		# The thunk comes as the tier lands, not as it starts to fall.
		get_tree().create_timer(0.36).timeout.connect(func() -> void: play(&"thunk", -2.0, 1.0, 0.03)))
	var turntable: Turntable = main.get("turntable")
	set_meta("turntable", turntable)
	var hud: Node = main.get("hud")
	if hud != null:
		_attach_buttons(hud)
		hud.get_tree().node_added.connect(func(node: Node) -> void:
			if hud.is_ancestor_of(node):
				_attach_button(node))


func _physics_process(_delta: float) -> void:
	var turntable := get_meta("turntable", null) as Turntable
	if turntable != null:
		var speed: float = absf(turntable.velocity)
		if speed > 0.05:
			hold_loop(&"spin", clampf(speed / 6.0, 0.0, 0.35), 0.8 + clampf(speed / 8.0, 0.0, 0.5), 3.0)


func _on_piece_placed(definition: DecorationDefinition, _world_position: Vector3) -> void:
	match definition.placement:
		DecorationDefinition.Placement.SCATTER:
			play_limited(&"tick", 0.035, -16.0 + _rng.randf_range(-4.0, 0.0), _rng.randf_range(0.85, 1.2))
		DecorationDefinition.Placement.RIM:
			play(&"pour", -4.0)
		DecorationDefinition.Placement.BAND:
			play(&"swish", -4.0)
		_:
			if definition.category in [&"sweets", &"party"] or definition.metallic > 0.5:
				play(&"tock", -6.0)
			else:
				play(&"pat", -5.0, _rng.randf_range(0.9, 1.1))


func _attach_buttons(root: Node) -> void:
	_attach_button(root)
	for child in root.get_children():
		_attach_buttons(child)


## Every button in the interface answers with a soft tap (swatches a little
## higher, shelf cards a little lower). Tool buttons are quiet: changing
## tool has its own tok.
func _attach_button(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta("sound_attached") or button.has_meta("silent"):
		return
	button.set_meta("sound_attached", true)
	var pitch: float = 1.0
	if button is SwatchButton:
		pitch = 1.25
	elif button is TipCard:
		pitch = 0.85
	button.pressed.connect(func() -> void: play(&"tap", -10.0, pitch))
