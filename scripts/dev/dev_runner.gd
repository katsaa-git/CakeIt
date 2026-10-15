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
		"tiers":
			await _build_tiers(context)
		"input_test":
			await _wait_for_cake(context)
			await _input_test(context)
		"sweep":
			await _wait_for_cake(context)
			await _settings_sweep(context)
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
	if args.has("shots") or scenario == "bench" or scenario == "sweep" or scenario == "input_test":
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
	if args.get("tools", "false") != "true":
		(main.get("tools") as ToolController).set_enabled(false)
	else:
		var tier: TierData = context.model.tiers[context.model.tiers.size() - 1]
		var yaw: float = context.camera.yaw
		var a: float = atan2(cos(yaw), sin(yaw)) - 0.25
		var base: float = context.model.tier_base_y(tier.id)
		_send_motion(_screen_of(context, Vector3(cos(a) * tier.radius, base + tier.height * 0.62, sin(a) * tier.radius)), Vector2.ZERO, 0)
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
	print("BENCH   finish: %.2f ms" % (float(Time.get_ticks_usec() - release_start) / 1000.0))
	var stroke := StrokeData.new()
	stroke.id = context.model.new_id()
	stroke.tier_id = tier.id
	stroke.tip_id = &"open_star"
	stroke.radius = 0.07
	builder.export_samples(stroke)
	context.view.offer_prebuilt(stroke.id, builder, live)
	var t_cmd: int = Time.get_ticks_usec()
	context.commands.run(AddStrokeCommand.new(stroke))
	print("BENCH   command+batch add: %.2f ms" % (float(Time.get_ticks_usec() - t_cmd) / 1000.0))
	var release_cost: float = float(Time.get_ticks_usec() - release_start) / 1000.0
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
	return "avg %.1f fps, 1%% low %.1f fps, GPU %.2f ms, CPU render %.2f ms, draw calls %d, primitives %d" % [r["avg_fps"], r["low_fps"], r["gpu_ms"], r["cpu_ms"], r["draw_calls"], r["primitives"]]


func _measure(_context: EditorContext, seconds: float, each_frame: Callable) -> Dictionary:
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
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
		last = now
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives = maxi(primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		gpu_total += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
	times.sort()
	var total: float = 0.0
	for t in times:
		total += t
	var avg_ms: float = total / float(times.size())
	var low_index: int = int(float(times.size()) * 0.99)
	var low_ms: float = times[mini(low_index, times.size() - 1)]
	return {
		"avg_fps": 1000.0 / avg_ms,
		"low_fps": 1000.0 / low_ms,
		"worst_ms": times[times.size() - 1],
		"draw_calls": draw_calls,
		"primitives": primitives,
		"gpu_ms": gpu_total / float(times.size()),
		"cpu_ms": cpu_total / float(times.size()),
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
