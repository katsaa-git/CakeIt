class_name DevRunner
extends Node
## Developer automation, only active when the game is started with extra
## arguments after "--". Used to take screenshots with the real renderer and
## to measure performance, without anyone clicking.
##
##   --shots=<folder>      save screenshots there, then quit
##   --scenario=<name>     empty | showcase | bench
##   --angles=<list>       comma list of: front, close, high, side, low
##
## Example:
##   Godot_v4.7.2-stable_win64_console.exe --path . -- --scenario=showcase --shots=C:/temp/shots

const ANGLES: Dictionary = {
	"front": [0.35, 0.36, 7.2, 0.0],
	"close": [0.6, 0.3, 4.2, 0.25],
	"high": [0.2, 0.95, 7.5, 0.0],
	"side": [1.4, 0.18, 6.0, 0.0],
	"low": [-0.3, 0.08, 5.4, -0.2],
	"wide": [0.35, 0.3, 11.5, 0.0],
	"overhead": [0.35, 1.2, 4.4, -0.1],
}

var main: Node3D
var args: Dictionary = {}


static func attach_if_requested(main_scene: Node3D) -> void:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			parsed[parts[0]] = parts[1] if parts.size() > 1 else "true"
	if parsed.is_empty():
		return
	var runner := DevRunner.new()
	runner.name = "DevRunner"
	runner.main = main_scene
	runner.args = parsed
	main_scene.add_child(runner)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scenario: String = args.get("scenario", "empty")
	var context: EditorContext = main.get("context")
	match scenario:
		"showcase":
			_build_showcase(context)
		"gallery":
			_build_gallery(context)
		"shimmer":
			_build_shimmer(context)
		"weave":
			_build_weave(context)
		"tips":
			_build_tip_sampler(context)
		"decorations":
			_build_decorated(context)
		"deco_bench":
			_build_decorated(context)
			await _wait_for_cake(context)
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			context.turntable.auto_spin = true
			await _measure(context, 1.0, func(_t: float) -> void: pass)
			print("BENCH decorated cake, spinning: %s" % _describe(await _measure(context, 5.0, func(_t: float) -> void: pass)))
		"tiers":
			await _build_tiers(context)
		"input_test":
			await _wait_for_cake(context)
			await _input_test(context)
		"sweep":
			await _wait_for_cake(context)
			await _settings_sweep(context)
		"set_sweep":
			_build_heavy(context)
			await _wait_for_cake(context)
			await _set_sweep(context)
		"shadow_sweep":
			_build_heavy(context)
			await _wait_for_cake(context)
			await _shadow_sweep(context)
		"bench":
			await _wait_for_cake(context)
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			var empty: Dictionary = await _measure(context, 3.0, func(_t: float) -> void: pass)
			print("BENCH empty cake: %s" % _describe(empty))
			_build_heavy(context)
	await _wait_for_cake(context)
	if scenario == "bench":
		await _benchmark(context)
	if args.has("tool"):
		(main.get("tools") as ToolController).select_tool(StringName(args["tool"]))
	if args.has("shots"):
		await _take_shots(context)
	if args.has("shots") or scenario == "bench" or scenario == "sweep" or scenario == "shadow_sweep" or scenario == "set_sweep" or scenario == "deco_bench" or scenario == "input_test":
		get_tree().quit()


func _wait_for_cake(context: EditorContext) -> void:
	for i in range(600):
		await get_tree().process_frame
		var stats: Dictionary = context.view.stats()
		if not context.view.is_building() and int(stats["pending_merge"]) == 0 and i > 20:
			break


func _take_shots(context: EditorContext) -> void:
	var folder: String = args["shots"]
	DirAccess.make_dir_recursive_absolute(folder)
	var names: PackedStringArray = String(args.get("angles", "front,close,high")).split(",")
	var hud: Node = main.get("hud")
	var with_tools: bool = args.get("tools", "false") == "true"
	if not with_tools:
		(main.get("tools") as ToolController).set_enabled(false)
	if args.get("ui", "false") != "true" and hud != null:
		hud.call("set_interface_visible", false)
	for angle_name in names:
		var angle: Array = ANGLES.get(angle_name, ANGLES["front"])
		var camera: OrbitCamera = context.camera
		camera.yaw_goal = angle[0]
		camera.pitch_goal = angle[1]
		camera.distance_goal = angle[2]
		camera.pan_goal = angle[3]
		camera.yaw = angle[0]
		camera.pitch = angle[1]
		camera.distance = angle[2]
		camera.pan = angle[3]
		# Wait in real time (the display may run at 60 or 120 Hz) so animations finish.
		await get_tree().create_timer(1.3).timeout
		if with_tools:
			# Point at the top tier's side facing this camera, so the bag shows there.
			var tier: TierData = context.model.tiers[context.model.tiers.size() - 1]
			var base: float = context.model.tier_base_y(tier.id)
			var a: float = _front_angle(context) - 0.25
			_send_motion(_screen_of(context, Vector3(cos(a) * tier.radius, base + tier.height * 0.62, sin(a) * tier.radius)), Vector2.ZERO, 0)
			await get_tree().create_timer(0.4).timeout
		await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = folder.path_join("%s_%s.png" % [args.get("scenario", "empty"), angle_name])
		image.save_png(path)
		print("SHOT ", path)


# --- Scenarios ---------------------------------------------------------------------

func _add(context: EditorContext, stroke: StrokeData) -> void:
	context.commands.run(AddStrokeCommand.new(stroke))


func _add_all(context: EditorContext, strokes: Array[StrokeData]) -> void:
	for stroke in strokes:
		_add(context, stroke)


func _build_showcase(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var pink := Color(0.97, 0.78, 0.82)
	var cream := Color(1.0, 0.97, 0.92)
	var rose := Color(0.93, 0.56, 0.66)
	var bottom: TierData = model.tiers[0]
	context.commands.run(TierCommands.CoatTier.new(model, bottom.id, pink, true, 0.7))
	main.call("add_tier")
	var top: TierData = model.tiers[1]
	context.commands.run(TierCommands.CoatTier.new(model, top.id, pink, true, 0.7))
	for tier in [bottom, top]:
		_add(context, DemoCake.side_ring(model, tier, 0.05, &"open_star", 1, rose, 0.0, 0, 1.03))
		_add(context, DemoCake.top_ring(model, tier, tier.radius - 0.09, &"open_star", 0, cream, 1.03))
		_add_all(context, DemoCake.swags(model, tier, 8, 0.32, 0.22, &"round", 0, cream))
		_add_all(context, DemoCake.side_dots(model, tier, 8, tier.height - 0.2, &"open_star", 1, rose, 1.25))
	_add_all(context, DemoCake.top_dots(model, top, 7, top.radius * 0.45, &"open_star", 2, rose, 1.2))
	_add(context, DemoCake.rosette(model, top, Vector3(0.0, top.height, 0.0), &"open_star", 2, cream))


## A deliberately overloaded cake for performance measurements.
func _build_heavy(context: EditorContext) -> void:
	var model: CakeModel = context.model
	main.call("add_tier")
	main.call("add_tier")
	var colors: Array[Color] = [Color(1.0, 0.97, 0.92), Color(0.97, 0.76, 0.8), Color(0.73, 0.88, 0.8), Color(0.68, 0.82, 0.92)]
	var count: int = 0
	for t in range(model.tiers.size()):
		var tier: TierData = model.tiers[t]
		var rings: int = int(tier.height / 0.09)
		for i in range(rings):
			var tip: StringName = &"open_star" if i % 2 == 0 else &"round"
			_add(context, DemoCake.side_ring(model, tier, 0.06 + float(i) * 0.09, tip, 0, colors[i % colors.size()], 0.02, 9, 1.0))
			count += 1
		for k in range(4):
			_add(context, DemoCake.top_ring(model, tier, tier.radius * (0.3 + 0.17 * float(k)), &"open_star", 1, colors[k % colors.size()]))
			count += 1
		_add_all(context, DemoCake.swags(model, tier, 10, 0.25, 0.15, &"round", 0, colors[0]))
		_add_all(context, DemoCake.side_dots(model, tier, 60, tier.height * 0.5, &"round", 1, colors[1]))
		_add_all(context, DemoCake.top_dots(model, tier, 40, tier.radius * 0.85, &"open_star", 1, colors[2]))
		count += 110
	print("BENCH built heavy cake: %d strokes" % model.strokes.size())


func _benchmark(context: EditorContext) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vertices: int = 0
	for view in context.view.tier_views():
		for child in view.strokes.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
				vertices += ((child as MeshInstance3D).mesh as ArrayMesh).surface_get_array_len(0) if ((child as MeshInstance3D).mesh as ArrayMesh).get_surface_count() > 0 else 0
	print("BENCH stroke vertices: %d, chunks: %s" % [vertices, context.view.stats()])

	# 1. Idle decorated cake while the turntable spins and the camera orbits.
	context.turntable.auto_spin = true
	var result_spin: Dictionary = await _measure(context, 6.0, func(t: float) -> void:
		context.camera.yaw_goal = 0.35 + t * 0.3)
	print("BENCH spinning heavy cake: %s" % _describe(result_spin))
	context.turntable.auto_spin = false
	context.turntable.stop()

	# 2. Piping a long line live on top of the heavy cake (the real tool path).
	var tool: PipingTool = (main.get("tools") as ToolController).tools[&"pipe"]
	var tier: TierData = context.model.tiers[0]
	var view: TierView = context.view.view_for(tier.id)
	var builder := StrokeBuilder.new(Content.tip(&"open_star"), 0.07, Color(0.9, 0.6, 0.7), 1)
	var live := LiveStroke.new()
	live.setup(builder, Materials.buttercream())
	view.add_child(live)
	var frames: int = 900
	var frame_start: int = Time.get_ticks_usec()
	var worst: int = 0
	var total_cost: int = 0
	for i in range(frames):
		var a: float = float(i) * 0.012
		var y: float = 0.5 + 0.08 * sin(a * 5.0)
		var t0: int = Time.get_ticks_usec()
		builder.add_sample(Vector3(cos(a) * (tier.radius + 0.0), y, sin(a) * tier.radius), Vector3(cos(a), 0.0, sin(a)), 1.0)
		live.refresh()
		var cost: int = Time.get_ticks_usec() - t0
		total_cost += cost
		worst = maxi(worst, cost)
		await get_tree().process_frame
	var elapsed: float = float(Time.get_ticks_usec() - frame_start) / 1000000.0
	print("BENCH live piping (%d frames, %d verts): stroke cost avg %.2f ms, worst %.2f ms; scene %.1f fps" % [frames, builder.vertex_total(), float(total_cost) / frames / 1000.0, worst / 1000.0, frames / elapsed])

	# 3. Releasing the long stroke: hand-over to the merged batch.
	var release_start: int = Time.get_ticks_usec()
	builder.finish()
	var finish_cost: float = float(Time.get_ticks_usec() - release_start) / 1000.0
	var stroke := StrokeData.new()
	stroke.id = context.model.new_id()
	stroke.tier_id = tier.id
	stroke.tip_id = &"open_star"
	stroke.radius = 0.07
	builder.export_samples(stroke)
	context.view.offer_prebuilt(stroke.id, builder, live)
	var t_cmd: int = Time.get_ticks_usec()
	context.commands.run(AddStrokeCommand.new(stroke))
	var command_cost: float = float(Time.get_ticks_usec() - t_cmd) / 1000.0
	var release_cost: float = float(Time.get_ticks_usec() - release_start) / 1000.0
	# Printing to the console is slow on Windows, so print only after timing.
	print("BENCH   finish: %.2f ms, command+batch add: %.2f ms" % [finish_cost, command_cost])
	var worst_after: Dictionary = await _measure(context, 1.0, func(_t: float) -> void: pass)
	print("BENCH release long stroke: %.2f ms on release; next second worst frame %.2f ms" % [release_cost, worst_after["worst_ms"]])

	# 4. Undo and redo of that stroke.
	var undo_start: int = Time.get_ticks_usec()
	context.commands.undo()
	var undo_cost: float = float(Time.get_ticks_usec() - undo_start) / 1000.0
	var redo_start: int = Time.get_ticks_usec()
	context.commands.redo()
	var redo_cost: float = float(Time.get_ticks_usec() - redo_start) / 1000.0
	var after_undo: Dictionary = await _measure(context, 1.0, func(_t: float) -> void: pass)
	print("BENCH undo %.2f ms, redo %.2f ms; next second worst frame %.2f ms" % [undo_cost, redo_cost, after_undo["worst_ms"]])
	if tool == null:
		push_warning("piping tool missing")


func _describe(r: Dictionary) -> String:
	return "avg %.1f fps, 1%% low %.1f fps, worst frame %.1f ms (%d hitches), GPU %.2f ms, CPU render %.2f ms, scripts avg %.2f ms (worst %.2f ms), draw calls %d, primitives %d" % [r["avg_fps"], r["low_fps"], r["worst_ms"], r["hitches"], r["gpu_ms"], r["cpu_ms"], r["process_ms"], r["process_worst_ms"], r["draw_calls"], r["primitives"]]


## Times every node's _process each frame: the first probe runs before all
## other nodes, the second after them. (Godot's own TIME_PROCESS monitor is
## the worst frame of the last second, refreshed once a second, so it cannot
## be averaged per frame.)
class ProcessProbe extends Node:
	var started: int = 0
	var partner: ProcessProbe
	var samples := PackedFloat32Array()

	func _process(_delta: float) -> void:
		if partner == null:
			started = Time.get_ticks_usec()
		else:
			samples.append(float(Time.get_ticks_usec() - partner.started) / 1000.0)


func _measure(_context: EditorContext, seconds: float, each_frame: Callable) -> Dictionary:
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var first := ProcessProbe.new()
	first.process_priority = -1000000
	var last_probe := ProcessProbe.new()
	last_probe.process_priority = 1000000
	last_probe.partner = first
	add_child(first)
	add_child(last_probe)
	# The first frame after turning on render timing is always slow; skip it.
	await get_tree().process_frame
	var gpu_total: float = 0.0
	var cpu_total: float = 0.0
	var times: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var last: int = start
	var draw_calls: int = 0
	var primitives: int = 0
	while float(Time.get_ticks_usec() - start) / 1000000.0 < seconds:
		each_frame.call(float(Time.get_ticks_usec() - start) / 1000000.0)
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		if times[times.size() - 1] > 20.0:
			print("BENCH   slow frame %d: %.1f ms" % [times.size() - 1, times[times.size() - 1]])
		last = now
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives = maxi(primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		gpu_total += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
	var process_samples: PackedFloat32Array = last_probe.samples
	first.queue_free()
	last_probe.queue_free()
	var process_total: float = 0.0
	var process_worst: float = 0.0
	for t in process_samples:
		process_total += t
		process_worst = maxf(process_worst, t)
	times.sort()
	var total: float = 0.0
	for t in times:
		total += t
	var avg_ms: float = total / float(times.size())
	var low_index: int = int(float(times.size()) * 0.99)
	var low_ms: float = times[mini(low_index, times.size() - 1)]
	var hitches: int = 0
	for t in times:
		if t > maxf(avg_ms * 3.0, 20.0):
			hitches += 1
	return {
		"hitches": hitches,
		"avg_fps": 1000.0 / avg_ms,
		"low_fps": 1000.0 / low_ms,
		"worst_ms": times[times.size() - 1],
		"draw_calls": draw_calls,
		"primitives": primitives,
		"gpu_ms": gpu_total / float(times.size()),
		"cpu_ms": cpu_total / float(times.size()),
		"process_ms": process_total / float(maxi(process_samples.size(), 1)),
		"process_worst_ms": process_worst,
	}


## Measures the fixed rendering cost of each expensive setting on its own.
func _settings_sweep(context: EditorContext) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport: Viewport = get_viewport()
	var lighting: StudioLighting = main.get("lighting")
	var env: Environment = lighting.environment
	var camera: OrbitCamera = context.camera
	var steps: Array = [
		["baseline (all on)", func() -> void: pass],
		["shadow atlas 4096", func() -> void: RenderingServer.directional_shadow_atlas_set_size(4096, true)],
		["soft shadows quality low", func() -> void: RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)],
		["no light angular size", func() -> void: lighting.sun.light_angular_distance = 0.0],
		["2 shadow splits", func() -> void: lighting.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS],
		["SSAO medium", func() -> void: RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)],
		["DOF bokeh low", func() -> void: RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_LOW, true)],
		["MSAA 2x", func() -> void: viewport.msaa_3d = Viewport.MSAA_2X],
		["no glow", func() -> void: env.glow_enabled = false],
		["no SSAO", func() -> void: env.ssao_enabled = false],
		["no DOF", func() -> void: camera.attributes = null],
		["no MSAA", func() -> void: viewport.msaa_3d = Viewport.MSAA_DISABLED],
		["no shadows", func() -> void: lighting.sun.shadow_enabled = false],
	]
	for step: Array in steps:
		(step[1] as Callable).call()
		await _measure(context, 0.5, func(_t: float) -> void: pass)
		var result: Dictionary = await _measure(context, 2.0, func(_t: float) -> void: pass)
		print("SWEEP %-26s GPU %.2f ms  (%.0f fps)" % [step[0], result["gpu_ms"], result["avg_fps"]])


# --- End-to-end input test --------------------------------------------------------

var _input_failures: int = 0


func _expect(condition: bool, message: String) -> void:
	print("INPUT_TEST %s %s" % ["ok  " if condition else "FAIL", message])
	if not condition:
		_input_failures += 1


## Window position of a cake-frame point (injected events use window coordinates,
## which differ from the 1920x1080 canvas when the window is another size).
## Angle (in the spinning cake frame) of the side currently facing the camera.
func _front_angle(context: EditorContext) -> float:
	var yaw: float = context.camera.yaw
	return atan2(cos(yaw), sin(yaw)) + context.turntable.angle


func _screen_of(context: EditorContext, cake_point: Vector3) -> Vector2:
	var on_canvas: Vector2 = context.camera.unproject_position(context.picker.to_world(cake_point))
	return get_viewport().get_final_transform() * on_canvas


func _send_motion(position: Vector2, relative: Vector2, pressed_mask: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = relative
	motion.button_mask = pressed_mask
	Input.parse_input_event(motion)


func _send_button(position: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.position = position
	button.global_position = position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(button)


func _send_key(keycode: Key, ctrl: bool) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.ctrl_pressed = ctrl
		key.pressed = pressed
		Input.parse_input_event(key)


## Drags the mouse through screen points, one per frame, with the left button held.
func _drag(points: Array[Vector2]) -> void:
	_send_motion(points[0], Vector2.ZERO, 0)
	await get_tree().process_frame
	_send_button(points[0], true)
	await get_tree().process_frame
	for i in range(1, points.size()):
		_send_motion(points[i], points[i] - points[i - 1], MOUSE_BUTTON_MASK_LEFT)
		await get_tree().process_frame
	_send_button(points[points.size() - 1], false)
	await get_tree().process_frame


func _input_test(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var tier: TierData = model.tiers[0]
	var front: float = _front_angle(context)

	# 1. Pipe a line across the front of the bottom tier.
	var path: Array[Vector2] = []
	for i in range(50):
		var a: float = front - 0.5 + float(i) * 0.02
		path.append(_screen_of(context, Vector3(cos(a) * tier.radius, tier.height * 0.5, sin(a) * tier.radius)))
	await _drag(path)
	for i in range(5):
		await get_tree().process_frame
	_expect(model.strokes.size() == 1, "a drag across the tier pipes one stroke (got %d)" % model.strokes.size())
	if model.strokes.size() == 1:
		var stroke: StrokeData = model.strokes[0]
		_expect(stroke.tier_id == tier.id, "stroke belongs to the bottom tier")
		_expect(stroke.points.size() > 10, "stroke has a real path (%d samples)" % stroke.points.size())
		_expect(absf(stroke.points[0].y - tier.height * 0.5) < 0.05, "stroke sits where the mouse was (y %.3f)" % stroke.points[0].y)
		_expect(stroke.tip_id == context.tip.id, "stroke uses the selected tip")

	# 2. A single click makes a dot.
	var dot_point: Vector2 = _screen_of(context, Vector3(cos(front) * tier.radius, tier.height * 0.8, sin(front) * tier.radius))
	await _drag([dot_point] as Array[Vector2])
	await get_tree().process_frame
	_expect(model.strokes.size() == 2, "a click pipes a dot (strokes %d)" % model.strokes.size())

	# 3. Undo and redo with the keyboard.
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(model.strokes.size() == 1, "Ctrl+Z undoes the dot")
	_send_key(KEY_Y, true)
	await get_tree().process_frame
	_expect(model.strokes.size() == 2, "Ctrl+Y brings it back")

	# 4. Pipe on top of the first stroke: the new one should land on it.
	var on_stroke: Vector2 = _screen_of(context, Vector3(cos(front - 0.3) * tier.radius, tier.height * 0.5, sin(front - 0.3) * tier.radius))
	for i in range(20):
		await get_tree().process_frame
	var hit: CakePicker.Hit = context.picker.pick(get_viewport().get_final_transform().affine_inverse() * on_stroke)
	_expect(hit != null and hit.kind == &"stroke", "piping can land on existing piping (hit %s)" % (hit.kind if hit != null else "nothing"))

	# 5. Spin the turntable by dragging its rim.
	var angle_before: float = context.turntable.angle
	var rim: Array[Vector2] = []
	var rim_radius: float = Turntable.PLATE_RADIUS - 0.15
	# Grab the rim off to the side: the front edge sits behind the bottom shelf.
	for i in range(12):
		var a: float = front + 0.75 + float(i) * 0.05
		rim.append(_screen_of(context, Vector3(cos(a) * rim_radius, 0.0, sin(a) * rim_radius)))
	await _drag(rim)
	_expect(absf(context.turntable.angle - angle_before) > 0.2, "dragging the rim spins the stand (%.2f rad)" % (context.turntable.angle - angle_before))
	_expect(model.strokes.size() == 2, "spinning does not pipe")
	for i in range(30):
		await get_tree().process_frame
	_expect(absf(context.turntable.velocity) > 0.0 or absf(context.turntable.angle - angle_before) > 0.3, "a flick keeps it turning a little")

	# 6. Add a tier through the same path as the button, and undo it.
	main.call("add_tier")
	_expect(model.tiers.size() == 2, "add tier")
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(model.tiers.size() == 1, "undo add tier")
	await _input_test_tools(context)
	await _input_test_decorations(context)
	print("INPUT_TEST %s (%d failures)" % ["PASSED" if _input_failures == 0 else "FAILED", _input_failures])


func _click(position: Vector2) -> void:
	await _drag([position] as Array[Vector2])


func _front_of(context: EditorContext, tier: TierData, height01: float, offset: float = 0.0) -> Vector2:
	var a: float = _front_angle(context) + offset
	var base: float = context.model.tier_base_y(tier.id)
	return _screen_of(context, Vector3(cos(a) * tier.radius, base + tier.height * height01, sin(a) * tier.radius))


func _input_test_tools(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var tools: ToolController = main.get("tools")
	var tier: TierData = model.tiers[0]
	for i in range(30):
		await get_tree().process_frame

	# Coat: pick a colour, press C, click the tier.
	var mint: Color = (Content.palette(&"frosting") as SwatchPalette).colors[7]
	context.set_color(mint)
	_send_key(KEY_C, false)
	await get_tree().process_frame
	_expect(context.tool_id == &"coat", "C selects the coat tool")
	await _click(_front_of(context, tier, 0.4))
	_expect(tier.coat_color.is_equal_approx(mint) and tier.coated, "clicking a tier coats it in the chosen colour")
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(not model.tiers[0].coat_color.is_equal_approx(mint), "undo takes the coat back off")
	_send_key(KEY_Y, true)

	# Tiers: select by clicking, resize, check the piping follows.
	_send_key(KEY_T, false)
	await get_tree().process_frame
	_expect(context.tool_id == &"tiers", "T selects the tier tool")
	await _click(_front_of(context, tier, 0.5))
	_expect(context.selected_tier_id == tier.id, "clicking a tier selects it")
	var tier_tool: TierTool = tools.tools[&"tiers"]
	var stroke_before: StrokeData = model.strokes[0]
	var old_radius: float = tier.radius
	tier_tool.set_width(1.6)
	var resized: TierData = model.tier_by_id(tier.id)
	_expect(is_equal_approx(resized.radius, 1.6), "width preset resizes the tier")
	var moved: StrokeData = model.strokes_on(tier.id)[0]
	var p: Vector3 = moved.points[moved.points.size() / 2]
	_expect(absf(Vector2(p.x, p.z).length() - 1.6) < 0.02, "piping moves out with the tier's side (r %.3f)" % Vector2(p.x, p.z).length())
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(is_equal_approx(model.tier_by_id(tier.id).radius, old_radius) and model.strokes.has(stroke_before), "undo restores the size and the original piping")
	tier_tool.add_tier()
	_expect(model.tiers.size() == 2, "add a tier on top")
	tier_tool.remove_selected()
	_expect(model.tiers.size() == 1, "remove the selected tier")
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(model.tiers.size() == 2, "undo brings the removed tier back")
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(model.tiers.size() == 1, "undo the added tier too")

	# Spatula: hold against the side while the cake spins.
	_send_key(KEY_F, false)
	await get_tree().process_frame
	tier = model.tiers[0]
	var smooth_before: float = tier.smoothness
	context.turntable.auto_spin = true
	for i in range(30):
		await get_tree().process_frame
	var spot: Vector2 = _front_of(context, tier, 0.75)
	_send_motion(spot, Vector2.ZERO, 0)
	await get_tree().process_frame
	_send_button(spot, true)
	for i in range(90):
		await get_tree().process_frame
	_send_button(spot, false)
	await get_tree().process_frame
	context.turntable.auto_spin = false
	context.turntable.stop()
	_expect(model.tiers[0].smoothness > smooth_before + 0.02, "the scraper smooths the coat as the cake spins (%.2f -> %.2f)" % [smooth_before, model.tiers[0].smoothness])
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(is_equal_approx(model.tiers[0].smoothness, smooth_before), "undo the smoothing")

	# Turntable ring: dragging its bottom edge to the right turns the front of
	# the cake to the right, the same way as dragging the stand's front rim.
	_send_key(KEY_B, false)
	await get_tree().process_frame
	var front: float = _front_angle(context)
	var rim_radius: float = Turntable.PLATE_RADIUS - 0.15
	var rim: Array[Vector2] = []
	for i in range(10):
		var a: float = front + 0.85 - float(i) * 0.05
		rim.append(_screen_of(context, Vector3(cos(a) * rim_radius, 0.0, sin(a) * rim_radius)))
	var rim_dx: float = rim[rim.size() - 1].x - rim[0].x
	var before_rim: float = context.turntable.angle
	await _drag(rim)
	var rim_change: float = context.turntable.angle - before_rim
	context.turntable.stop()
	for i in range(5):
		await get_tree().process_frame
	var dial: Control = (main.get("hud") as Hud).get_node("Root/TurntableDial")
	var dial_rect: Rect2 = dial.get_global_rect()
	var to_window: Transform2D = get_viewport().get_final_transform()
	var bottom: Vector2 = dial_rect.get_center() + Vector2(0.0, dial_rect.size.y * 0.5 - 14.0)
	var arc: Array[Vector2] = []
	for i in range(10):
		var a: float = PI * 0.5 + 0.5 - float(i) * 0.1
		arc.append(to_window * (dial_rect.get_center() + Vector2(cos(a), sin(a)) * (dial_rect.size.x * 0.5 - 14.0)))
	var before_dial: float = context.turntable.angle
	await _drag(arc)
	var dial_change: float = context.turntable.angle - before_dial
	_expect(absf(dial_change) > 0.2, "dragging the turntable ring spins the cake (%.2f rad)" % dial_change)
	print("INPUT_TEST info rim_change %.3f rim_dx %.1f dial_change %.3f arc_dx %.1f" % [rim_change, rim_dx, dial_change, arc[arc.size() - 1].x - arc[0].x])
	_expect(signf(dial_change) == signf(rim_change) * signf(rim_dx) * signf(arc[arc.size() - 1].x - arc[0].x), "ring and stand rim spin the same way for the same hand motion")
	context.turntable.stop()
	if bottom == Vector2.ZERO:
		pass


## Three tiers in different sizes and coats, with one coat caught mid-sweep.
func _build_tiers(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var tier_tool: TierTool = (main.get("tools") as ToolController).tools[&"tiers"]
	var palette: SwatchPalette = Content.palette(&"frosting")
	var bottom: TierData = model.tiers[0]
	context.commands.run(TierCommands.ResizeTier.new(model, bottom.id, 1.6, 1.05))
	context.commands.run(TierCommands.CoatTier.new(model, bottom.id, palette.colors[0], false, 0.45))
	tier_tool.add_tier()
	tier_tool.add_tier()
	var middle: TierData = model.tiers[1]
	var top: TierData = model.tiers[2]
	context.commands.run(TierCommands.CoatTier.new(model, middle.id, palette.colors[7], true, 0.9))
	context.commands.run(TierCommands.ResizeTier.new(model, top.id, top.radius, 1.45))
	for i in range(60):
		await get_tree().process_frame
	context.commands.run(TierCommands.CoatTier.new(model, top.id, palette.colors[2], true, 0.45))
	if args.get("midsweep", "false") == "true":
		await get_tree().create_timer(0.42).timeout
		get_tree().paused = false
		var image: Image = get_viewport().get_texture().get_image()
		var folder: String = args.get("shots", OS.get_user_data_dir())
		DirAccess.make_dir_recursive_absolute(folder)
		image.save_png(folder.path_join("tiers_midsweep.png"))
		print("SHOT midsweep")


## Compares shadow layouts on a heavy cake (each measured twice, interleaved,
## so a laptop changing speed does not skew the result).
func _shadow_sweep(context: EditorContext) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sun: DirectionalLight3D = (main.get("lighting") as StudioLighting).sun
	var layouts: Array = [
		["2 splits, 22, split 0.25", func() -> void:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 22.0
			sun.directional_shadow_split_1 = 0.25],
		["2 splits, 16, split 0.6", func() -> void:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 16.0
			sun.directional_shadow_split_1 = 0.6],
		["orthogonal, 16", func() -> void:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 16.0],
		["no sun shadow", func() -> void:
			sun.shadow_enabled = false],
		["shadow back on, orthogonal 16", func() -> void:
			sun.shadow_enabled = true],
	]
	for round_index in range(2):
		for layout: Array in layouts:
			(layout[1] as Callable).call()
			await _measure(context, 0.4, func(_t: float) -> void: pass)
			var r: Dictionary = await _measure(context, 1.5, func(_t: float) -> void: pass)
			print("SHADOWS %-32s GPU %.2f ms  primitives %d  draw calls %d" % [layout[0], r["gpu_ms"], r["primitives"], r["draw_calls"]])


## What each part of the bakery set and its lighting costs on the GPU, on the
## heavy cake: every part is switched off on its own and measured, twice,
## interleaved with the full scene so a laptop changing speed shows up.
func _set_sweep(context: EditorContext) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var lighting: StudioLighting = main.get("lighting")
	var env: Environment = lighting.environment
	var set_node: Node3D = main.get_node("BakerySet")
	var by_name: Callable = func(root: Node, wanted: String) -> Array[Node]:
		var out: Array[Node] = []
		for child in root.get_children():
			if String(child.name).contains(wanted):
				out.append(child)
		return out
	var toggle_nodes: Callable = func(nodes: Array[Node], on: bool) -> void:
		for node in nodes:
			(node as Node3D).visible = on
	var props: Array[Node] = []
	for child in set_node.get_children():
		if child is Node3D and not (child is MeshInstance3D):
			props.append(child)
	var parts: Array = [
		["fog", func(on: bool) -> void: env.fog_enabled = on],
		["colour adjustment", func(on: bool) -> void: env.adjustment_enabled = on],
		["glow", func(on: bool) -> void: env.glow_enabled = on],
		["SSAO", func(on: bool) -> void: env.ssao_enabled = on],
		["window glow light", func(on: bool) -> void: toggle_nodes.call(by_name.call(lighting, "WindowGlow"), on)],
		["front fill light", func(on: bool) -> void: lighting.fill.visible = on],
		["reflection probe", func(on: bool) -> void: toggle_nodes.call(by_name.call(lighting, "RoomReflections"), on)],
		["dust motes", func(on: bool) -> void: lighting.dust.visible = on],
		["vignette", func(on: bool) -> void: (lighting.get_node("Vignette") as CanvasLayer).visible = on],
		["curtains", func(on: bool) -> void: toggle_nodes.call(by_name.call(set_node, "Curtain"), on)],
		["window view", func(on: bool) -> void: toggle_nodes.call(by_name.call(set_node, "WindowView"), on)],
		["cloth", func(on: bool) -> void: toggle_nodes.call(by_name.call(set_node, "Cloth"), on)],
		["props (jars, jug, bowl...)", func(on: bool) -> void: toggle_nodes.call(props, on)],
		["whole set", func(on: bool) -> void: set_node.visible = on],
		["depth of field", func(on: bool) -> void: context.camera.attributes = context.camera.dof if on else null],
	]
	for round_index in range(2):
		await _measure(context, 0.4, func(_t: float) -> void: pass)
		var base: Dictionary = await _measure(context, 1.5, func(_t: float) -> void: pass)
		print("SET   full scene                    GPU %.2f ms  draw calls %d" % [base["gpu_ms"], base["draw_calls"]])
		for part: Array in parts:
			(part[1] as Callable).call(false)
			await _measure(context, 0.3, func(_t: float) -> void: pass)
			var r: Dictionary = await _measure(context, 1.5, func(_t: float) -> void: pass)
			(part[1] as Callable).call(true)
			print("SET   without %-24s GPU %.2f ms  (saves %.2f)  draw calls %d" % [part[0], r["gpu_ms"], base["gpu_ms"] - r["gpu_ms"], r["draw_calls"]])


## One shelf tab's decorations laid out on a plain cake for close-up
## judging: a grid on top (sprays as small drifts, strings as three in a
## row), ribbons round the side, and word pieces also on the side to show
## them bending. `--tab=fruit` picks the tab.
func _build_gallery(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var tool: DecorationTool = (main.get("tools") as ToolController).tools[&"decorate"]
	var tier: TierData = model.tiers[0]
	context.commands.run(TierCommands.ResizeTier.new(model, tier.id, 1.6, 1.05))
	tier = model.tiers[0]
	context.commands.run(TierCommands.CoatTier.new(model, tier.id, Color(0.99, 0.95, 0.88), true, 0.95, false))
	var tab := StringName(args.get("tab", "fruit"))
	var defs: Array[DecorationDefinition] = []
	for res in Content.decorations():
		if (res as DecorationDefinition).category == tab:
			defs.append(res)
	var palette: Array[Color] = [Color(0.97, 0.72, 0.78), Color(0.72, 0.86, 0.78), Color(0.99, 0.84, 0.62), Color(0.74, 0.8, 0.95), Color(0.85, 0.74, 0.93), Color(0.93, 0.4, 0.45)]
	var on_top: Array[DecorationDefinition] = []
	var band_y: float = 0.08
	for def in defs:
		if def.placement == DecorationDefinition.Placement.BAND:
			context.set_color(palette[on_top.size() % palette.size()])
			tool.wrap_ribbon(def, tier.id, band_y, _front_angle(context) - 1.2, _front_angle(context) - 1.2 + TAU)
			band_y += 0.36
		elif def.placement == DecorationDefinition.Placement.RIM:
			tool.pour_drip(def, tier.id, 0.0, TAU)
		else:
			on_top.append(def)
	var columns: int = ceili(sqrt(float(on_top.size())))
	var rows: int = ceili(float(on_top.size()) / float(maxi(columns, 1)))
	var step: float = minf(2.1 / float(maxi(columns, 1)), 0.75)
	var front: float = _front_angle(context)
	# Grid axes on the top, lined up with the camera.
	var right := Vector3(cos(front + PI * 0.5), 0.0, sin(front + PI * 0.5))
	var toward := Vector3(cos(front), 0.0, sin(front))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(on_top.size()):
		var def: DecorationDefinition = on_top[i]
		context.set_color(palette[i % palette.size()])
		context.decoration_text = "LOVE" if def.builder is LetterBuilder else "Happy Days"
		var cell := Vector2(float(i % columns) - float(columns - 1) * 0.5, float(i / columns) - float(rows - 1) * 0.5) * step
		var spot: Vector3 = right * cell.x - toward * cell.y + Vector3(0.0, tier.height, 0.0)
		match def.placement:
			DecorationDefinition.Placement.SCATTER:
				for k in range(int(clampf(def.rate * 0.35, 8.0, 70.0))):
					var a: float = rng.randf() * TAU
					var d: float = sqrt(rng.randf()) * step * 0.32
					tool.place_one(def, tier.id, spot + Vector3(cos(a) * d, 0.0, sin(a) * d), Vector3.UP)
			DecorationDefinition.Placement.LINE:
				for k in range(3):
					tool.place_one(def, tier.id, spot + right * (float(k) - 1.0) * def.radius() * def.spacing, Vector3.UP)
			_:
				tool.place_one(def, tier.id, spot, Vector3.UP)
		if def.uses_text() or (def.category == &"fondant" and not def.top_only and i % 2 == 0):
			# Also on the side, facing the camera, to show it hugging the curve.
			var a: float = front + (float(i % 5) - 2.0) * 0.32
			var n := Vector3(cos(a), 0.0, sin(a))
			tool.place_one(def, tier.id, n * tier.radius + Vector3(0.0, tier.height * (0.5 if def.uses_text() else 0.3), 0.0), n)
	context.set_color(Color(1.0, 0.97, 0.92))
	print("GALLERY %s: %d decorations" % [tab, defs.size()])


## Lustre dust and metallic colours: a two-tier cake with piping and sugar
## flowers, gold dust brushed in a band across the front of the bottom tier
## (over coat, piping and pearls alike), pearl dust over the top tier, gold
## painted roses, gold leaf stars and a metallic piped scroll.
func _build_shimmer(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var deco: DecorationTool = (main.get("tools") as ToolController).tools[&"decorate"]
	var dust: DustTool = (main.get("tools") as ToolController).tools[&"dust"]
	var gold := Color(1.0, 0.8, 0.42)
	var pearl := Color(0.97, 0.95, 0.92)
	var bottom: TierData = model.tiers[0]
	context.commands.run(TierCommands.CoatTier.new(model, bottom.id, Color(0.98, 0.86, 0.87), true, 0.9, false))
	main.call("add_tier")
	var top: TierData = model.tiers[1]
	context.commands.run(TierCommands.CoatTier.new(model, top.id, Color(1.0, 0.97, 0.93), true, 0.9, false))
	_add(context, DemoCake.side_ring(model, bottom, 0.06, &"shell", 1, Color(1.0, 0.97, 0.93), 0.0, 0, 1.0))
	_add(context, DemoCake.top_ring(model, bottom, bottom.radius - 0.07, &"rope", 0, Color(1.0, 0.97, 0.93), 1.03))
	_add(context, DemoCake.side_ring(model, top, 0.06, &"bead", 0, Color(0.98, 0.86, 0.87), 0.0, 0, 1.0))
	_add_all(context, DemoCake.swags(model, bottom, 9, 0.22, 0.2, &"round", 0, Color(1.0, 0.97, 0.93)))
	var front: float = _front_angle(context)
	# A metallic gold scroll piped across the top tier's front.
	var scroll := DemoCake.side_ring(model, top, top.height * 0.55, &"round", 0, gold, 0.06, 7, 1.0)
	scroll.shine = 1.0
	_add(context, scroll)
	# Gold leaf stars and pearls on the bottom tier's side.
	context.set_color(gold, 1.0)
	for i in range(5):
		var a: float = front - 0.8 + float(i) * 0.4
		var n := Vector3(cos(a), 0.0, sin(a))
		deco.place_one(Content.decoration(&"fondant_star"), bottom.id, n * bottom.radius + Vector3(0.0, bottom.height * 0.42, 0.0), n)
	context.set_color(Color(1.0, 0.99, 0.96))
	for i in range(18):
		var a: float = front - 1.1 + float(i) * 0.13
		var n := Vector3(cos(a), 0.0, sin(a))
		deco.place_one(Content.decoration(&"sugar_pearls"), bottom.id, n * bottom.radius + Vector3(0.0, bottom.height * 0.7, 0.0), n)
	# Roses on the ledge, then painted gold with dust.
	var ledge: float = (bottom.radius + top.radius) * 0.5
	context.set_color(Color(1.0, 0.97, 0.93))
	for i in range(7):
		var a: float = front - 0.9 + float(i) * 0.3
		deco.place_one(Content.decoration(&"rose"), bottom.id, Vector3(cos(a) * ledge, bottom.height, sin(a) * ledge), Vector3.UP)
	# Shimmer: a band of gold dust across the bottom tier's front...
	context.set_color(gold, 1.0)
	context.set_dust(2, 1, false)
	var band := PackedVector3Array()
	# Three even passes back and forth, like brushing by hand.
	for pass_index in range(3):
		for k in range(60):
			var t: float = float(k) / 59.0 if pass_index % 2 == 0 else 1.0 - float(k) / 59.0
			var a: float = front - 0.9 + t * 1.8
			band.append(Vector3(cos(a) * bottom.radius, bottom.height * (0.36 + 0.14 * float(pass_index)), sin(a) * bottom.radius))
	dust.brush_path(bottom.id, band, 0.08)
	# ...rich gold paint over the roses on the ledge...
	context.set_dust(1, 2, false)
	var roses := PackedVector3Array()
	for k in range(40):
		var a: float = front - 1.0 + float(k) / 39.0 * 2.0
		roses.append(Vector3(cos(a) * ledge, bottom.height + 0.08, sin(a) * ledge))
	dust.brush_path(bottom.id, roses, 0.3)
	# ...and a whisper of pearl dust over the whole top tier.
	context.set_color(pearl, 0.5)
	context.set_dust(2, 0, false)
	var veil := PackedVector3Array()
	for k in range(120):
		var t: float = float(k) / 119.0
		var a: float = t * TAU * 1.5
		var r: float = top.radius * (0.2 + 0.75 * fmod(t * 3.0, 1.0))
		veil.append(Vector3(cos(a) * r, top.height, sin(a) * r))
	dust.brush_path(top.id, veil, 0.2)
	context.set_color(Color(1.0, 0.97, 0.92))


## A basket cake: the whole side woven with the serrated basketweave tip
## (upright stripes, then short bars across them, alternating), with a rope
## border at the top edge. `--tip=basketweave` weaves with the plain tip.
func _build_weave(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var tier: TierData = model.tiers[0]
	context.commands.run(TierCommands.CoatTier.new(model, tier.id, Color(0.86, 0.68, 0.48), true, 0.9, false))
	var tip_id := StringName(args.get("tip", "basketweave_comb"))
	var tip: TipDefinition = Content.tip(tip_id)
	var color := Color(0.88, 0.7, 0.5)
	var radius: float = tip.preset_size(1)
	var bar: float = tip.click_length * radius
	var columns: int = int(TAU * tier.radius / (bar * 0.6))
	var row_height: float = radius * 2.0
	var rows: int = int((tier.height - 0.04) / row_height)
	for c in range(columns):
		var a: float = TAU * (float(c) + 0.5) / float(columns)
		var normal := Vector3(cos(a), 0.0, sin(a))
		var stripe := StrokeData.new()
		stripe.id = model.new_id()
		stripe.tier_id = tier.id
		stripe.tip_id = tip_id
		stripe.radius = radius
		stripe.color = color
		stripe.rng_seed = stripe.id
		var y: float = 0.03
		while y <= tier.height - 0.03:
			stripe.add_sample(normal * tier.radius + Vector3(0.0, y, 0.0), normal, 1.0)
			y += radius * 0.2
		_add(context, stripe)
	for c in range(columns):
		for row in range(rows):
			if (row + c) % 2 != 0:
				continue
			# Bars sit between two stripes, covering the one behind.
			var a: float = TAU * float(c) / float(columns)
			var normal := Vector3(cos(a), 0.0, sin(a))
			var piece := StrokeData.new()
			piece.id = model.new_id()
			piece.tier_id = tier.id
			piece.tip_id = tip_id
			piece.radius = radius
			piece.color = color
			piece.rng_seed = piece.id
			piece.forward = Vector3(-sin(a), 0.0, cos(a))
			# A click piece starts at the click and runs on along `forward`.
			piece.add_sample(normal * (tier.radius + radius * 0.3) - piece.forward * bar * 0.35 + Vector3(0.0, 0.04 + (float(row) + 0.5) * row_height, 0.0), normal, 1.0)
			_add(context, piece)
	_add(context, DemoCake.top_ring(model, tier, tier.radius - 0.05, &"rope", 1, Color(0.8, 0.6, 0.4), 1.03))


## The original ten tips (page 1 of the tip sampler); page 2 shows the rest.
const FIRST_TIPS: Array[StringName] = [&"round", &"open_star", &"closed_star", &"shell", &"drop_flower", &"leaf", &"petal", &"ruffle", &"basketweave", &"grass"]


## Ten tips on one cake: a line and a click of each on the top (two columns
## of five, in shelf order), and borders around the side. `--page=2` shows
## the E2 tips, with a two-tone bag on a few of them.
func _build_tip_sampler(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var page: int = int(args.get("page", "1"))
	var tier: TierData = model.tiers[0]
	context.commands.run(TierCommands.ResizeTier.new(model, tier.id, 1.6, 1.05))
	tier = model.tiers[0]
	context.commands.run(TierCommands.CoatTier.new(model, tier.id, Color(0.99, 0.95, 0.88), true, 0.9, false))
	var colors: Array[Color] = [Color(0.97, 0.72, 0.78), Color(0.72, 0.86, 0.78), Color(0.99, 0.84, 0.62), Color(0.74, 0.8, 0.95), Color(0.85, 0.74, 0.93)]
	var tips: Array[TipDefinition] = []
	for tip in Content.tips():
		if (tip.id in FIRST_TIPS) == (page == 1):
			tips.append(tip)
	var two_tone: Array[StringName] = [&"russian_flower", &"triple_line", &"rosette"]
	var per_column: int = ceili(float(tips.size()) / 2.0)
	for i in range(tips.size()):
		var tip: TipDefinition = tips[i]
		var column: float = -1.0 if i < per_column else 1.0
		var row: float = float(i % per_column)
		var z: float = -0.92 + row * 1.84 / float(maxi(per_column - 1, 1))
		var x0: float = column * 0.42
		var x1: float = column * 1.0
		var stroke := StrokeData.new()
		stroke.id = model.new_id()
		stroke.tier_id = tier.id
		stroke.tip_id = tip.id
		stroke.size_index = 1
		stroke.radius = tip.preset_size(1)
		stroke.color = colors[i % colors.size()]
		stroke.rng_seed = stroke.id * 7919
		if tip.id in two_tone:
			stroke.stripe = Color(1.0, 0.97, 0.93)
		var steps: int = 60
		for k in range(steps + 1):
			var t: float = float(k) / float(steps)
			var p := Vector3(lerpf(x0, x1, t), tier.height, z + sin(t * TAU) * 0.06)
			if Vector2(p.x, p.z).length() > tier.radius - 0.12:
				break
			stroke.add_sample(p, Vector3.UP, 1.0)
		_add(context, stroke)
		var click := StrokeData.new()
		click.id = model.new_id()
		click.tier_id = tier.id
		click.tip_id = tip.id
		click.size_index = 1
		click.radius = tip.preset_size(1)
		click.color = stroke.color
		click.rng_seed = click.id * 7919
		click.stripe = stroke.stripe
		# Clicks sit in the middle, pointing out toward their line.
		click.forward = Vector3(column, 0.0, 0.0)
		click.add_sample(Vector3(column * 0.16, tier.height, z), Vector3.UP, 1.2)
		_add(context, click)
	if page == 1:
		# Around the side: a shell border at the bottom, ruffles, a row of drop
		# flowers, and a closed-star rope at the top edge.
		_add(context, DemoCake.side_ring(model, tier, 0.07, &"shell", 1, Color(1.0, 0.97, 0.92), 0.0, 0, 1.0))
		_add(context, DemoCake.side_ring(model, tier, 0.42, &"ruffle", 1, Color(0.97, 0.72, 0.78), 0.0, 0, 1.0))
		_add(context, DemoCake.side_ring(model, tier, 0.78, &"drop_flower", 1, Color(0.74, 0.8, 0.95), 0.0, 0, 1.0))
		_add(context, DemoCake.top_ring(model, tier, tier.radius - 0.06, &"closed_star", 0, Color(1.0, 0.97, 0.92), 1.03))
	else:
		# A bead border at the bottom, lace scallops hanging from the top, a
		# row of chrysanthemums and a twisted rope round the top edge.
		_add(context, DemoCake.side_ring(model, tier, 0.06, &"bead", 1, Color(1.0, 0.97, 0.92), 0.0, 0, 1.0))
		_add(context, DemoCake.side_ring(model, tier, 0.4, &"chrysanthemum", 0, Color(0.99, 0.84, 0.62), 0.0, 0, 1.0))
		_add(context, DemoCake.side_ring(model, tier, 0.86, &"lace_scallop", 1, Color(1.0, 0.97, 0.93), 0.0, 0, 1.0))
		_add(context, DemoCake.top_ring(model, tier, tier.radius - 0.07, &"rope", 0, Color(0.74, 0.8, 0.95), 1.03))


## A two-tier cake wearing every kind of decoration: a chocolate drip, candles
## and a sign on top, roses, daisies and berries between the tiers, a pearl
## string, fondant shapes and dragees on the sides, sprinkles and curls.
func _build_decorated(context: EditorContext) -> void:
	var model: CakeModel = context.model
	var tool: DecorationTool = (main.get("tools") as ToolController).tools[&"decorate"]
	var bottom: TierData = model.tiers[0]
	context.commands.run(TierCommands.CoatTier.new(model, bottom.id, Color(0.98, 0.84, 0.86), true, 0.85, false))
	main.call("add_tier")
	var top: TierData = model.tiers[1]
	context.commands.run(TierCommands.CoatTier.new(model, top.id, Color(1.0, 0.96, 0.9), true, 0.9, false))
	var d: Callable = func(id: StringName) -> DecorationDefinition: return Content.decoration(id) as DecorationDefinition
	var front: float = _front_angle(context)
	# Ganache over the top tier, all the way round.
	context.set_color(Color(0.36, 0.22, 0.15))
	tool.pour_drip(d.call(&"ganache_drip"), top.id, 0.0, TAU)
	# Candles in an arc at the front of the top, the sign standing behind them
	# and a cherry in the middle.
	context.set_color(Color(0.62, 0.78, 0.95))
	for i in range(5):
		var a: float = front + (float(i) - 2.0) * 0.42
		tool.place_one(d.call(&"candle"), top.id, Vector3(cos(a) * 0.55, top.height + 0.03, sin(a) * 0.55), Vector3.UP)
	context.set_color(Color(1.0, 0.97, 0.92))
	context.decoration_text = "Happy Birthday!"
	tool.place_one(d.call(&"topper_sign"), top.id, Vector3(cos(front + PI) * 0.5, top.height + 0.03, sin(front + PI) * 0.5), Vector3.UP)
	tool.place_one(d.call(&"cherry"), top.id, Vector3(0.0, top.height + 0.03, 0.0), Vector3.UP)
	# Flowers and fruit on the ledge between the tiers.
	var ledge: float = (bottom.radius + top.radius) * 0.5
	var flowers: Array[StringName] = [&"rose", &"raspberry", &"daisy", &"blueberry", &"rose", &"cherry", &"daisy", &"raspberry"]
	for i in range(16):
		var a: float = front - 1.2 + float(i) * 0.16
		var id: StringName = flowers[i % flowers.size()]
		context.set_color(Color(0.93, 0.5, 0.6) if id == &"rose" else Color(1.0, 0.98, 0.95))
		tool.place_one(d.call(id), bottom.id, Vector3(cos(a) * ledge, bottom.height, sin(a) * ledge), Vector3.UP)
	# A string of pearls round the bottom of the bottom tier.
	context.set_color(Color(1.0, 0.98, 0.95))
	var pearls: DecorationDefinition = d.call(&"sugar_pearls")
	var step: float = pearls.spacing * pearls.radius() / bottom.radius
	var angle: float = 0.0
	while angle < TAU:
		var n := Vector3(cos(angle), 0.0, sin(angle))
		tool.place_one(pearls, bottom.id, n * bottom.radius + Vector3(0.0, 0.08, 0.0), n)
		angle += step
	# Fondant shapes and gold dragees on the sides.
	context.set_color(Color(0.98, 0.98, 0.96))
	var shapes: Array[StringName] = [&"fondant_heart", &"fondant_star", &"fondant_blossom"]
	for i in range(9):
		var a: float = front - 1.0 + float(i) * 0.25
		var n := Vector3(cos(a), 0.0, sin(a))
		tool.place_one(d.call(shapes[i % 3]), bottom.id, n * bottom.radius + Vector3(0.0, bottom.height * 0.5, 0.0), n)
		tool.place_one(d.call(&"gold_dragees"), bottom.id, n * bottom.radius + Vector3(0.0, bottom.height * 0.5 + 0.18, 0.0), n)
	# Rainbow sprinkles on the stand's plate, and chocolate curls.
	var sprinkles: DecorationDefinition = d.call(&"rainbow_sprinkles")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(260):
		var a: float = front - 1.3 + rng.randf() * 2.6
		var r: float = rng.randf_range(bottom.radius + 0.12, Turntable.PLATE_RADIUS - 0.15)
		tool.place_one(sprinkles, CakeModel.BOARD_ID, Vector3(cos(a) * r, 0.0, sin(a) * r), Vector3.UP)
	for i in range(6):
		var a: float = front + 0.9 + float(i) * 0.12
		tool.place_one(d.call(&"chocolate_curls"), CakeModel.BOARD_ID, Vector3(cos(a) * 1.85, 0.0, sin(a) * 1.85), Vector3.UP)
	context.set_color((Content.palette(&"frosting") as SwatchPalette).colors[0])
	print("DECORATED: %d decorations" % model.decorations.size())


## Decorations through real mouse and keyboard input: a click places a
## cherry, a sprinkle drag is one undo step, a drag along the rim pours a
## drip, and a candle is refused on the side of a tier.
func _input_test_decorations(context: EditorContext) -> void:
	var model: CakeModel = context.model
	context.turntable.stop()
	_send_key(KEY_V, false)
	await get_tree().process_frame
	_expect(context.tool_id == &"decorate", "V selects the decorations tool")
	var tier: TierData = model.tiers[0]
	var front: float = _front_angle(context)
	var on_top: Callable = func(r: float, offset: float) -> Vector2:
		var a: float = front + offset
		return _screen_of(context, Vector3(cos(a) * r, model.tier_base_y(tier.id) + tier.height, sin(a) * r))

	context.set_decoration(Content.decoration(&"cherry"))
	var before: int = model.decorations.size()
	await _click(on_top.call(tier.radius * 0.5, 0.0))
	_expect(model.decorations.size() == before + 1, "a click places a cherry")
	if model.decorations.size() == before + 1:
		var cherry: DecorationData = model.decorations[model.decorations.size() - 1]
		_expect(cherry.tier_id == tier.id and absf(cherry.transform.origin.y - tier.height) < 0.05, "the cherry sits on top of the tier (y %.3f)" % cherry.transform.origin.y)
		_expect(cherry.color.is_equal_approx((Content.decoration(&"cherry") as DecorationDefinition).colors[0]), "a cherry keeps its own red")
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(model.decorations.size() == before, "undo takes the cherry off")
	_send_key(KEY_Y, true)
	await get_tree().process_frame

	context.set_decoration(Content.decoration(&"rainbow_sprinkles"))
	before = model.decorations.size()
	var path: Array[Vector2] = []
	for i in range(40):
		path.append(on_top.call(tier.radius * 0.45, -0.4 + float(i) * 0.02))
	await _drag(path)
	var sprayed: int = model.decorations.size() - before
	_expect(sprayed > 10, "a drag sprinkles lots of sprinkles (%d)" % sprayed)
	_send_key(KEY_Z, true)
	await get_tree().process_frame
	_expect(model.decorations.size() == before, "one undo takes the whole sprinkle drag back")

	context.set_decoration(Content.decoration(&"ganache_drip"))
	before = model.decorations.size()
	var rim: Array[Vector2] = []
	for i in range(30):
		rim.append(on_top.call(tier.radius - 0.06, -0.45 + float(i) * 0.03))
	await _drag(rim)
	_expect(model.decorations.size() == before + 1, "a drag along the rim pours one drip")
	if model.decorations.size() == before + 1:
		var drip: DecorationData = model.decorations[model.decorations.size() - 1]
		var span: Vector2 = DripBuilder.span(drip.path)
		_expect(span.y - span.x > 0.5, "the drip covers the dragged stretch of rim (%.2f rad)" % (span.y - span.x))
	_send_key(KEY_Z, true)
	await get_tree().process_frame

	context.set_decoration(Content.decoration(&"candle"))
	before = model.decorations.size()
	var side: Vector2 = _front_of(context, tier, 0.5)
	await _click(side)
	_expect(model.decorations.size() == before, "a candle is not placed on the side of a tier")
	_send_key(KEY_B, false)
	await get_tree().process_frame
