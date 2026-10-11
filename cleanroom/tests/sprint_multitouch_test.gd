extends SceneTree
## Multi-touch sprint regression: second finger must not steal movement input.
func _initialize() -> void:
    call_deferred("_run")


func _touch(index: int, at: Vector2, down: bool) -> InputEventScreenTouch:
    var ev := InputEventScreenTouch.new()
    ev.index = index
    ev.position = at
    ev.pressed = down
    return ev


func _assert(cond: bool, msg: String) -> bool:
    if not cond:
        push_error("AETHERFALL_SPRINT_TOUCH_FAIL: " + msg)
        quit(1)
        return false
    return true


func _run() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _assert(false, "Scene could not load")
        return
    var town := scene.instantiate()
    root.add_child(town)
    for i in range(8):
        await process_frame
    var stick := town.get("_joystick_base") as Control
    var button := town.get("_sprint_button") as Button
    if not _assert(stick != null and button != null and bool(town.get("_loaded")), "Controls or model missing"):
        return
    var stick_down := stick.get_global_rect().get_center() + Vector2(0, -54)
    var sprint_pos := button.get_global_rect().get_center()
    if not _assert(not bool(town.get("_sprint_held")), "Sprint must start OFF"):
        return

    town.call("_input", _touch(7, stick_down, true))
    if not _assert(int(town.get("_move_touch")) == 7 and (town.get("_move_input") as Vector2).length() > 0.5, "First finger did not claim joystick"):
        return
    town.call("_input", _touch(8, sprint_pos, true))
    if not _assert(bool(town.get("_sprint_held")) and button.text == "SPRINT ON" and button.button_pressed, "Second finger failed to toggle ON"):
        return
    if not _assert(int(town.get("_move_touch")) == 7 and (town.get("_move_input") as Vector2).length() > 0.5, "Sprint stole joystick finger"):
        return
    town.call("_input", _touch(8, sprint_pos, false))
    if not _assert(bool(town.get("_sprint_held")) and int(town.get("_move_touch")) == 7, "Releasing Sprint unexpectedly disabled latch or joystick"):
        return
    town.call("_update_gameplay_movement", 0.30)
    if not _assert(String(town.get("_motion")) == "RUN", "Joystick did not run when sprint latched ON"):
        return

    # Re-tap with a different second finger while still steering: back to Walk.
    town.call("_input", _touch(9, sprint_pos, true))
    town.call("_input", _touch(9, sprint_pos, false))
    town.call("_update_gameplay_movement", 0.18)
    if not _assert(not bool(town.get("_sprint_held")) and button.text == "SPRINT OFF" and not button.button_pressed, "Retap failed to toggle OFF"):
        return
    if not _assert(String(town.get("_motion")) == "WALK" and int(town.get("_move_touch")) == 7, "Joystick did not continue walking after retap"):
        return

    # Releasing the stick must not change an enabled sprint latch.
    town.call("_input", _touch(10, sprint_pos, true))
    town.call("_input", _touch(10, sprint_pos, false))
    town.call("_input", _touch(7, stick_down, false))
    if not _assert(bool(town.get("_sprint_held")) and int(town.get("_move_touch")) == -1 and (town.get("_move_input") as Vector2).is_zero_approx(), "Stick release lost sprint latch"):
        return

    # Duplicate synthetic mouse events must not toggle the switch again.
    var synthetic_mouse := InputEventMouseButton.new()
    synthetic_mouse.device = InputEvent.DEVICE_ID_EMULATION
    synthetic_mouse.position = sprint_pos
    synthetic_mouse.button_index = MOUSE_BUTTON_LEFT
    synthetic_mouse.pressed = true
    town.call("_input", synthetic_mouse)
    if not _assert(bool(town.get("_sprint_held")), "Emulated mouse caused duplicate toggle"):
        return

    # Desktop mouse click still works with a non-interactive visual button.
    var desktop_mouse := InputEventMouseButton.new()
    desktop_mouse.position = sprint_pos
    desktop_mouse.button_index = MOUSE_BUTTON_LEFT
    desktop_mouse.pressed = true
    town.call("_input", desktop_mouse)
    if not _assert(not bool(town.get("_sprint_held")), "Physical mouse click failed to toggle OFF"):
        return
    print("AETHERFALL_SPRINT_TOUCH_OK: separate joystick finger, Sprint ON/OFF while moving, latch persists, synthetic mouse filtered")
    town.queue_free()
    quit(0)
