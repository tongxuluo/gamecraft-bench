extends SceneTree

# Headless screenshot helper for gamecraft_bench.
#
# Loads the project's main scene, runs it for a configurable number of frames,
# saves a PNG of the viewport, and exits. Designed for agents and verifiers
# that need a visual snapshot of the game without opening the editor.
#
# Usage:
#   godot --headless --path <project> --script /tools/screenshot.gd \
#        -- --out /tmp/frame.png [--frames 30] [--scene res://Main.tscn]
#
# The `--` separates Godot args from script args. Defaults pick up the
# project's `run/main_scene` if --scene isn't given.

const DEFAULT_FRAMES := 30


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var out_path: String = args.get("out", "")
	if out_path.is_empty():
		push_error("screenshot.gd: --out <path> is required")
		quit(2)
		return

	var frames: int = int(args.get("frames", DEFAULT_FRAMES))
	var scene_path: String = args.get(
		"scene", ProjectSettings.get_setting("application/run/main_scene", "")
	)
	if scene_path.is_empty():
		push_error("screenshot.gd: no scene specified and project has no main scene")
		quit(2)
		return

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("screenshot.gd: failed to load scene %s" % scene_path)
		quit(3)
		return

	var instance: Node = packed.instantiate()
	root.add_child(instance)

	# Let the scene tick so dynamic content (animations, ai, etc.) settles
	# into a representative frame before we capture.
	for _i in range(frames):
		await process_frame

	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("screenshot.gd: viewport returned no image (headless rendering may be disabled)")
		quit(4)
		return

	var err: int = image.save_png(out_path)
	if err != OK:
		push_error("screenshot.gd: save_png returned %d for %s" % [err, out_path])
		quit(5)
		return

	print("screenshot saved: %s (%dx%d)" % [out_path, image.get_width(), image.get_height()])
	quit(0)


# --foo=bar / --foo bar / --flag → {"foo": "bar"} / {"flag": "true"}
func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < argv.size():
		var a: String = argv[i]
		if not a.begins_with("--"):
			i += 1
			continue
		var key: String = a.substr(2)
		var value: String = "true"
		if "=" in key:
			var parts: PackedStringArray = key.split("=", true, 1)
			key = parts[0]
			value = parts[1]
		elif i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
			value = argv[i + 1]
			i += 1
		out[key] = value
		i += 1
	return out
