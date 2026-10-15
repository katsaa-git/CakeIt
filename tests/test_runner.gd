extends SceneTree
## Headless checks for the decorating core. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd
## Every file in tests/ ending in "_tests.gd" is a suite; every method in it
## starting with "test_" is run. Exits with code 0 when everything passes.

var _failures: int = 0
var _checks: int = 0
var _current: String = ""


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var files: Array = Array(DirAccess.get_files_at("res://tests/"))
	files.sort()
	for file: String in files:
		if not file.ends_with("_tests.gd"):
			continue
		var suite: Object = load("res://tests/" + file).new()
		suite.set("runner", self)
		print("- " + file.get_basename())
		for method in suite.get_method_list():
			var name: String = method["name"]
			if name.begins_with("test_"):
				_current = "%s.%s" % [file.get_basename(), name]
				suite.call(name)
	var ms: int = Time.get_ticks_msec() - started
	Content.clear_cache()
	if _failures == 0:
		print("ALL TESTS PASSED (%d checks in %d ms)" % [_checks, ms])
	else:
		printerr("%d CHECK(S) FAILED out of %d" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL [%s] %s" % [_current, message])
