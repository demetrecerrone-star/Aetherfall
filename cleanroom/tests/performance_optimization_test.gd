extends SceneTree
## Regression QA for the conservative Android OpenGL optimisation pass.
## This verifies software settings; actual FPS must be measured on the phone.
const GraphicsQuality = preload("res://graphics_quality.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var packed := load("res://starter_town.tscn") as PackedScene
    if packed == null:
        _fail("Could not load existing starter town")
        return
    var town := packed.instantiate() as Node3D
    root.add_child(town)
    for i in range(12):
        await process_frame
    var sun := town.get("_sun_light") as DirectionalLight3D
    var actor := town.get("_actor") as Node3D
    var camera := town.get("_camera") as Camera3D
    if sun == null or actor == null or camera == null:
        _fail("Graphics optimisation removed existing sun / character / camera")
        return

    var shadow_settings := {
        "PERFORMANCE": [1024, RenderingServer.SHADOW_QUALITY_SOFT_LOW],
        "BALANCED": [2048, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM],
        "QUALITY": [4096, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
    }
    for preset in ["PERFORMANCE", "BALANCED", "QUALITY"]:
        town.call("_set_graphics_preset", preset, false)
        var shadow: Array = shadow_settings[preset]
        if int(town.get_meta("graphics_shadow_atlas", -1)) != shadow[0]:
            _fail("Wrong shadow atlas in " + preset)
            return
        if int(town.get_meta("graphics_shadow_filter", -1)) != int(shadow[1]):
            _fail("Expensive HIGH filter still active in " + preset)
            return
        if not sun.shadow_enabled:
            _fail("Sun shadows were disabled, not optimised")
            return
        if str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) != "gl_compatibility":
            _fail("Renderer was switched away from safe OpenGL baseline")
            return
        var expected_scale: float = GraphicsQuality.resolution_scale(preset)
        if absf(float(town.get_meta("graphics_3d_resolution_scale", -1.0)) - expected_scale) > 0.002:
            _fail("Existing graphics resolution scale changed unexpectedly")
            return
    town.call("_set_graphics_preset", "PERFORMANCE", false)
    var panel := town.find_child("PerformanceStatsPanel", true, false) as Panel
    var details := town.find_child("PerformanceStatsText", true, false) as Label
    var fps := town.find_child("GraphicsFpsLabel", true, false) as Label
    if panel == null or details == null or fps == null:
        _fail("Missing optional tap-to-toggle performance diagnostics")
        return
    if panel.visible or bool(town.get_meta("performance_monitor_enabled", true)):
        _fail("Instrumentation adds an intrusive panel by default")
        return
    var touch := InputEventScreenTouch.new()
    touch.index = 8
    touch.position = fps.get_global_rect().get_center()
    touch.pressed = true
    town.call("_input", touch)
    if not panel.visible or not bool(town.get_meta("performance_monitor_enabled", false)):
        _fail("FPS label failed to toggle performance panel on")
        return
    if int(town.get("_camera_touch")) == 8 or int(town.get("_move_touch")) == 8:
        _fail("Performance tap stole joystick or camera touch ownership")
        return
    if not details.text.contains("DRAW:") or not details.text.contains("CPU PROCESS:"):
        _fail("Live diagnostics missing draw and CPU monitors")
        return
    if int(town.get_meta("performance_draw_calls", -1)) < 0:
        _fail("Draw-call monitor not collected")
        return
    town.call("_input", touch)
    if panel.visible:
        _fail("Performance diagnostics cannot be dismissed")
        return
    if town.get("_camera") != camera or town.get("_actor") != actor:
        _fail("Toggling graphics instrumentation changed camera or actor")
        return
    var baseline_batches := int(town.get_meta("graphics_cached_meadow_batches", 0))
    if baseline_batches < 30 or int(town.get_meta("graphics_meadow_total", 0)) < 10000:
        _fail("Conservative optimisations removed the thick MultiMesh grass")
        return
    print("AETHERFALL_PERFORMANCE_OPT_OK: lower preset shadow samples, preserved OpenGL/grass/camera, opt-in draw call monitoring and touch safety")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_PERFORMANCE_OPT_FAIL: " + message)
    quit(1)
