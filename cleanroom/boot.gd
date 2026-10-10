extends Node3D

const WORLD_SCRIPT := "res://lab.gd"
const BUILD_LABEL := "Starter Town v0.1.6 diagnostics"
const WATCHDOG_SECONDS := 12.0

var _panel: Panel
var _code_label: Label
var _detail_label: Label
var _debug_button: Button
var _last_code := "AF-BOOT-100"
var _last_detail := "Diagnostic bootstrap started."
var _elapsed := 0.0
var _startup_complete := false
var _startup_failed := false

func _ready() -> void:
    process_priority = -1000
    _build_diagnostic_ui()
    report_stage("AF-BOOT-100", "Diagnostic bootstrap is alive.")
    call_deferred("_start_world")

func _start_world() -> void:
    report_stage("AF-SCRIPT-110", "Loading the Starter Town controller script.")
    if not ResourceLoader.exists(WORLD_SCRIPT):
        report_failure("AF-SCRIPT-101", "The world controller file is missing: " + WORLD_SCRIPT)
        return
    var world_script = ResourceLoader.load(WORLD_SCRIPT, "Script", ResourceLoader.CACHE_MODE_IGNORE)
    if world_script == null:
        report_failure("AF-SCRIPT-102", "Godot could not parse or load lab.gd. This is usually a GDScript syntax/parse error.")
        return
    var world := Node3D.new()
    world.name = "StarterTownRuntime"
    world.set_script(world_script)
    report_stage("AF-WORLD-120", "World controller parsed. Attaching it to the scene tree.")
    add_child(world)

func report_stage(code: String, detail: String) -> void:
    if _startup_failed:
        return
    _last_code = code
    _last_detail = detail
    _elapsed = 0.0
    if code == "AF-READY-900":
        _startup_complete = true
        if _debug_button != null:
            _debug_button.text = "DEBUG OK"
    _refresh_diagnostic_text()

func report_failure(code: String, detail: String) -> void:
    if _startup_failed:
        return
    _startup_failed = true
    _last_code = code
    _last_detail = detail
    push_error("AETHERFALL_DIAGNOSTIC " + code + ": " + detail)
    if _debug_button != null:
        _debug_button.text = "ERROR " + code
    if _panel != null:
        _panel.visible = true
    _refresh_diagnostic_text()

func _process(delta: float) -> void:
    if _startup_complete or _startup_failed:
        return
    _elapsed += delta
    if _elapsed >= WATCHDOG_SECONDS:
        report_failure("AF-WATCH-500", "Startup stopped before READY. Last reported stage: " + _last_code + " - " + _last_detail)

func _build_diagnostic_ui() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    _debug_button = Button.new()
    _debug_button.text = "DEBUG BOOT"
    _debug_button.anchor_left = 0.5
    _debug_button.anchor_right = 0.5
    _debug_button.anchor_top = 1.0
    _debug_button.anchor_bottom = 1.0
    _debug_button.offset_left = -72.0
    _debug_button.offset_right = 72.0
    _debug_button.offset_top = -54.0
    _debug_button.offset_bottom = -10.0
    _debug_button.add_theme_font_size_override("font_size", 15)
    _debug_button.pressed.connect(_toggle_diagnostics)
    ui.add_child(_debug_button)

    _panel = Panel.new()
    _panel.anchor_left = 0.5
    _panel.anchor_right = 0.5
    _panel.anchor_top = 0.5
    _panel.anchor_bottom = 0.5
    _panel.offset_left = -360.0
    _panel.offset_right = 360.0
    _panel.offset_top = -145.0
    _panel.offset_bottom = 145.0
    _panel.visible = false
    ui.add_child(_panel)

    var title := Label.new()
    title.position = Vector2(22, 18)
    title.size = Vector2(676, 32)
    title.text = "AETHERFALL DIAGNOSTICS"
    title.add_theme_font_size_override("font_size", 22)
    _panel.add_child(title)

    _code_label = Label.new()
    _code_label.position = Vector2(22, 60)
    _code_label.size = Vector2(676, 36)
    _code_label.add_theme_font_size_override("font_size", 20)
    _panel.add_child(_code_label)

    _detail_label = Label.new()
    _detail_label.position = Vector2(22, 104)
    _detail_label.size = Vector2(676, 150)
    _detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detail_label.add_theme_font_size_override("font_size", 16)
    _panel.add_child(_detail_label)

func _toggle_diagnostics() -> void:
    if _panel != null:
        _panel.visible = not _panel.visible

func _refresh_diagnostic_text() -> void:
    if _code_label != null:
        _code_label.text = _last_code
    if _detail_label != null:
        var state := "STARTING"
        if _startup_complete:
            state = "READY - no startup errors detected"
        elif _startup_failed:
            state = "FAILED - photograph this panel"
        _detail_label.text = BUILD_LABEL + "\nState: " + state + "\n\n" + _last_detail + "\n\nLast reported stage: " + _last_code