extends SceneTree
## Headless regression test: title -> threaded loading -> studio -> title.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var code := change_scene_to_file("res://scenes/title_screen.tscn")
	if code != OK:
		_fail("title scene could not be requested")
		return
	await process_frame
	await process_frame
	var title := current_scene
	if title == null or title.get_node_or_null("CinematicAetherfallVista") == null:
		_fail("cinematic title background is missing")
		return
	if title.get_node_or_null("SceneTransitionVeil") == null:
		_fail("scene transition veil is missing")
		return
	if root.get_node_or_null("AetherfallAmbience") == null:
		_fail("ambient music singleton is missing")
		return
	title.call("_start","studio")
	var arrived := false
	for _i in range(120):
		await create_timer(.10).timeout
		if current_scene != null and current_scene.name == "AetherfallMovementLab":
			arrived = true
			break
	if not arrived:
		_fail("title -> load -> starter town timed out")
		return
	var game := current_scene
	var studio: PanelContainer = game.get_node_or_null("Customizer/StudioOverlay/RightDockedCreator") as PanelContainer
	var studio_open: bool = studio != null and studio.visible
	var menu_hud := game.get_node_or_null("HUD")
	if not studio_open or menu_hud == null:
		_fail("studio entry or gameplay menu missing")
		return
	menu_hud.emit_signal("menu_tapped")
	await process_frame
	await process_frame
	var returned := current_scene != null and current_scene.name == "AetherfallTitleScreen"
	if not returned:
		_fail("gameplay menu did not return to title")
		return
	print("TITLE_FLOW_TEST_OK: title + ambience + loader + studio + return to menu")
	quit(0)

func _fail(message: String) -> void:
	push_error("TITLE_FLOW_TEST_FAILED: "+message)
	quit(1)
