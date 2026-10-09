extends SceneTree
## CI test for side-docked creator and preview-camera presentation.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("STUDIO_TEST: cannot load main.tscn")
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var creator: CanvasLayer = game.get_node("Customizer")
	var hud: CanvasLayer = game.get_node("HUD")
	var player: CharacterBody3D = game.get_node("Player")
	var avatar: Node3D = player.get_node("Avatar")
	var overlay: Control = hud.get_node("Overlay")
	var panel: PanelContainer = creator.get_node("StudioOverlay/RightDockedCreator")
	var button: Button = creator.get_node("StudioOverlay").get_child(0)
	var arm: SpringArm3D = player.get_node("CameraYaw/CameraPitch/CameraArm")
	var old_length: float = arm.spring_length

	creator._set_open(true)
	await process_frame
	var open_ok := panel.visible and not overlay.visible and not button.visible
	var yaw: float = player.get_node("CameraYaw").rotation.y
	var faces_front := absf(wrapf(yaw - avatar.rotation.y - PI, -PI, PI)) < 0.02
	var zoom_ok := arm.spring_length < old_length
	creator._cycle("hair", 1)
	await process_frame
	var has_save := FileAccess.file_exists("user://aetherfall_appearance_v02.json")
	creator._set_open(false)
	await process_frame
	var closed_ok := not panel.visible and overlay.visible and button.visible
	print("STUDIO_TEST: open=%s front=%s zoom=%s saved=%s closed=%s" % [open_ok, faces_front, zoom_ok, has_save, closed_ok])
	if open_ok and faces_front and zoom_ok and has_save and closed_ok:
		quit(0)
	else:
		push_error("STUDIO_TEST_FAILED: control visibility / camera / appearance save regression")
		quit(1)
