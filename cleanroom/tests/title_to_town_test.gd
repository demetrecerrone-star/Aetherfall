extends SceneTree
## The newer cleanroom town must boot from its own title screen, not the legacy
## main-scene character lab. Run only after the CI asset preparation/import.
func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var code := change_scene_to_file("res://title_screen.tscn")
	if code != OK:
		_fail("The Starter Town title screen did not open")
		return
	await process_frame
	await process_frame
	var title: Node = current_scene
	if title == null or title.name != "AetherfallTitleScreen":
		_fail("Unexpected startup scene")
		return
	if title.get_node_or_null("CinematicAetherfallVista") == null:
		_fail("Missing fantasy backdrop")
		return
	if root.get_node_or_null("AetherfallAmbience") == null:
		_fail("Missing soundtrack autoload")
		return
	var adventure_found := false
	for control in title.find_children("*", "Button", true, false):
		var button: Button = control as Button
		if button == null:
			continue
		if button.text == "BEGIN ADVENTURE":
			adventure_found = true
		if button.text == "CHARACTER STUDIO":
			_fail("Old character-studio button must not ship with Starter Town")
			return
	if not adventure_found:
		_fail("Begin Adventure button missing")
		return
	title.call("_start")
	for _i in range(160):
		await create_timer(.15).timeout
		if current_scene != null and current_scene.name == "AetherfallStarterTown":
			break
	if current_scene == null or current_scene.name != "AetherfallStarterTown":
		_fail("Title did not enter real Starter Town")
		return
	var world := current_scene
	if world.get_node_or_null("TripoActor") == null or world.get_node_or_null("OrbitCamera") == null:
		_fail("World is not the newer cleanroom scene")
		return
	print("AETHERFALL_CLEANROOM_TITLE_OK: cinematic menu -> loader -> real starter town")
	quit(0)

func _fail(reason: String) -> void:
	push_error("AETHERFALL_CLEANROOM_TITLE_FAIL: " + reason)
	quit(1)
