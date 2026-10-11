extends CanvasLayer
## One-scene-at-a-time area transfers. The town gate never animates or opens.
## This overlay can show area-specific artwork when it becomes available.
## Session data survives change_scene_to_packed via this preloaded script class.
static var session_state: Dictionary = {}
static var return_spawn: String = "town_gate"
static var source_area: String = "starter_town"

var _busy := false
var _panel: Panel
var _area_label: Label
var _message: Label
var _load_bar: ProgressBar
var _is_hint := false
var _notice: Label

func _ready() -> void:
    name = "AetherfallZoneTransfer"
    layer = 105
    _panel = Panel.new()
    _panel.name = "AreaLoadingOverlay"
    _panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _panel.visible = false
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_panel)
    _notice = Label.new()
    _notice.name = "ZonePreviewNotice"
    _notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _notice.offset_left = -270.0
    _notice.offset_right = 270.0
    _notice.offset_top = -145.0
    _notice.offset_bottom = -88.0
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _notice.add_theme_font_size_override("font_size", 18)
    _notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _notice.visible = false
    add_child(_notice)
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#111c25")
    _panel.add_theme_stylebox_override("panel", background)
    var frame := VBoxContainer.new()
    frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    frame.custom_minimum_size = Vector2(520, 220)
    frame.offset_left = -260.0
    frame.offset_top = -110.0
    frame.offset_right = 260.0
    frame.offset_bottom = 110.0
    frame.add_theme_constant_override("separation", 14)
    _panel.add_child(frame)
    _area_label = Label.new()
    _area_label.name = "DestinationAreaName"
    _area_label.text = "AETHERFALL"
    _area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _area_label.add_theme_font_size_override("font_size", 30)
    frame.add_child(_area_label)
    _message = Label.new()
    _message.name = "LoadingStatus"
    _message.text = "Preparing area..."
    _message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message.add_theme_font_size_override("font_size", 18)
    frame.add_child(_message)
    _load_bar = ProgressBar.new()
    _load_bar.name = "AreaLoadProgress"
    _load_bar.custom_minimum_size = Vector2(500, 25)
    _load_bar.show_percentage = false
    _load_bar.min_value = 0.0
    _load_bar.max_value = 100.0
    frame.add_child(_load_bar)

func has_destination(scene_path: String) -> bool:
    return ResourceLoader.exists(scene_path)

func attempt_transfer(scene_path: String, display_name: String, state: Dictionary, spawn_tag: String = "arrival") -> bool:
    if _busy:
        return false
    if not ResourceLoader.exists(scene_path):
        # Gate is still closed. The next explorable area has not been made yet.
        # A friendly notice is safer than a broken or fake loading destination.
        _is_hint = true
        _notice.text = display_name + " — area not available yet."
        _notice.visible = true
        _panel.visible = false
        return false
    session_state = state.duplicate(true)
    return_spawn = spawn_tag
    source_area = "starter_town"
    _busy = true
    _is_hint = false
    _notice.visible = false
    _load_bar.value = 0.0
    _load_bar.visible = true
    _area_label.text = display_name
    _message.text = "Traveling to " + display_name + "..."
    _panel.visible = true
    var fade := create_tween()
    _panel.modulate.a = 0.0
    fade.tween_property(_panel, "modulate:a", 1.0, 0.24)
    fade.tween_callback(Callable(self, "_load_area").bind(scene_path))
    return true

func _load_area(scene_path: String) -> void:
    var load_error := ResourceLoader.load_threaded_request(scene_path)
    if load_error != OK:
        _fail_transfer("Could not prepare the next region.")
        return
    _poll_area_load(scene_path)

func _poll_area_load(scene_path: String) -> void:
    # Avoid waiting synchronously on Android asset import at a zone boundary.
    # Keep the loading overlay responsive while the destination scene loads.
    while is_inside_tree():
        var progress: Array = []
        var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
        if not progress.is_empty():
            _load_bar.value = float(progress[0]) * 100.0
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
            if packed == null:
                _fail_transfer("The next region could not be opened.")
                return
            var error := get_tree().change_scene_to_packed(packed)
            if error != OK:
                _fail_transfer("The region transition failed.")
            return
        if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _fail_transfer("The next region failed to load.")
            return
        await get_tree().process_frame

func _fail_transfer(detail: String) -> void:
    _busy = false
    _load_bar.visible = false
    _is_hint = true
    _message.text = detail

func clear_hint() -> void:
    if _is_hint and not _busy:
        _panel.visible = false
        _notice.visible = false
        _panel.modulate.a = 1.0
        _is_hint = false

func is_transferring() -> bool:
    return _busy
