extends Node3D
const SceneryReplacement = preload("res://scenery_replacements.gd")
const HangingShopSigns = preload("res://hanging_shop_signs.gd")
const NatureReplacement = preload("res://nature_replacements.gd")
const GateAshlar = preload("res://gate_ashlar.gd")
const GrassField = preload("res://grass_field.gd")
const GraphicsQuality = preload("res://graphics_quality.gd")
# Runtime .bin holds the same optimized GLB bytes and is explicitly
# bundled in the Android export (Godot does not reliably preload raw .glb).
const FOUNTAIN_RUNTIME_PATH := "res://models/fountain/MedievalFountain.bin"
const FountainWater = preload("res://fountain_water.gd")
# Midpoint between market stall rows (z=-6.10 and z=+2.45), x=0.
const FOUNTAIN_CENTER := Vector2(0.0, -1.825)
const FOUNTAIN_SCALE := 3.55 # +10.9% from approved Pass 9 size
const FOUNTAIN_BASIN_RADIUS := 1.79
const RoadNetwork = preload("res://road_network.gd")
const MountainValley = preload("res://mountain_valley.gd")
const ZoneTransfer = preload("res://zone_transfer.gd")
const NEXT_ZONE_SCENE := "res://areas/valley_outskirts.tscn"
const NEXT_ZONE_NAME := "Valley Outskirts"
## Runtime Tripo/Mixamo QA scene for Aetherfall character pass.
## Loads the supplied GLB directly and adds game-ready preview behavior:
## gameplay locomotion test: touch movement, camera orbit, auto animation states, grounding.

# Same verified Mixamo/Tripo skin and rig, now with seven authored clips.
# Raw GLB bytes are copied into this .bin path during CI before Android export.
# Godot imports .glb as a resource and may omit the raw source from Android PCKs;
# the unrecognized .bin extension is included as a non-resource by export filters.
const MALE_MODEL_PATH := "res://models/adventurer_runtime.bin"
const FEMALE_MODEL_PATH := "res://models/adventurer_female_runtime.bin"
const IDLE_OPTIONS := ["standing_relax", "idle", "look_around"]
const MOTION_BLEND_TIME := 0.24
const WALK_SPEED := 0.92
const RUN_SPEED := 1.06
const ACTOR_SCALE := 1.62
# Shared male/female scale: ~4.7% smaller without altering rig or foot-sole math.
# Mixamo joint origins sit above the visible boot sole in this specific model.
# Source-model measurements: Foot ~= 0.067 m above sole, ToeBase ~= 0.017 m.
const FOOT_TO_SOLE_SOURCE_Y := 0.067
const TOE_TO_SOLE_SOURCE_Y := 0.017
const SOLE_CLEARANCE_WORLD := 0.010
const WALK_WORLD_SPEED := 1.75
const RUN_WORLD_SPEED := 4.15
const MOVE_ACCEL := 7.5
const MOVE_DECEL := 10.5
const TURN_RATE := 9.0
const STICK_DEADZONE := 0.10
const STICK_RADIUS := 68.0
const HDRI_PATH := "res://environment/kloppenheim_03_puresky_1k.hdr"

# Starter-town world dimensions. The hard bounds are authoritative: even if a
# decorative wall has a mesh gap, the player cannot leave this rectangle.
const TOWN_MIN_X := -27.0
const TOWN_MAX_X := 27.0
const TOWN_MIN_Z := -25.0
const TOWN_MAX_Z := 25.0
const PLAYER_WORLD_RADIUS := 0.34
const CAMERA_WALL_GAP := 0.16
const CAMERA_FADE_START := 1.85
const CAMERA_FADE_FULL := 0.95
const CAMERA_FADE_RETURN_SPEED := 3.0

var _actor: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _animation: AnimationPlayer
var _neutral_pose: Array[Transform3D] = []
var _transition_from: Array[Transform3D] = []
var _transition_elapsed := 0.0
var _transitioning := false

var _hips_index := -1
var _spine_index := -1
var _spine1_index := -1
var _head_index := -1
var _left_foot_index := -1
var _right_foot_index := -1
var _left_toe_index := -1
var _right_toe_index := -1
var _left_arm_index := -1
var _right_arm_index := -1
var _left_forearm_index := -1
var _right_forearm_index := -1
var _left_hand_index := -1
var _right_hand_index := -1
var _left_finger_bones: Array[int] = []
var _right_finger_bones: Array[int] = []
var _neutral_hips_origin := Vector3.ZERO
var _neutral_model_position := Vector3.ZERO
var _base_actor_y := 0.0

var _ground_contact_shadow: MeshInstance3D
var _town_textures: Dictionary = {}
var _camera: Camera3D
var _status: Label
var _detail: Label
var _motion := "IDLE"
var _paused := false
var _loaded := false

# Gameplay locomotion harness.
var _move_input := Vector2.ZERO
var _move_touch := -1
var _camera_touch := -1
var _sprint_held := false
var _move_speed := 0.0
var _travel_direction := Vector3(0.0, 0.0, -1.0)
var _camera_yaw := 0.0
var _camera_pitch := 0.18
var _camera_distance := 4.0
var _drag_mouse := false
var _joystick_base: Panel
var _joystick_knob: Panel
var _sprint_button: Button
var _graphics_button: Button
var _graphics_fps: Label
var _performance_panel: Panel
var _performance_details: Label
var _performance_stats_visible := false
var _graphics_preset := "BALANCED"
var _graphics_lod_batches: Array[Dictionary] = []
var _graphics_lod_accum := 0.0
var _graphics_last_lod: Dictionary = {}
var _sun_light: DirectionalLight3D
var _pose_button: Button
var _character_button: Button
var _character_variant := "male"
var _idle_option_index := 0
var _world_blockers: Array[Rect2] = []
var _circle_blockers: Array[Vector3] = []
var _oriented_blockers: Array[Dictionary] = []
var _house_blockers: Array[Dictionary] = []
var _road_door_anchors: Array[Vector2] = []
var _road_regions: Array[Rect2] = []
# Only used to keep grass blades out of foliage meshes; these are NOT player blockers.
var _foliage_grass_masks: Array[Rect2] = []
var _camera_obstacles: Array[AABB] = []
# Towers are round; square camera volumes erroneously envelop players at corners.
var _camera_cylinders: Array[Dictionary] = []
# Per-surface material overrides allow alpha fade in GL Compatibility on Android.
var _camera_fade_surfaces: Array[Dictionary] = []
var _camera_fade_alpha := 1.0
var _door_step_surfaces: Array[Dictionary] = []
var _boundary_flash := 0.0
var _zone_transfer: Node
var _gate_zone_latched := false

# Permanent on-device startup diagnostics. Parse errors are blocked by CI before
# an APK is shipped; runtime startup stages are shown here on the phone.
var _diag_panel: Panel
var _diag_code_label: Label
var _diag_detail_label: Label
var _diag_button: Button
var _diag_code := "AF-BOOT-100"
var _diag_detail_text := "Starter Town controller loaded."
var _startup_elapsed := 0.0
var _startup_complete := false
var _startup_failed := false
const STARTUP_WATCHDOG_SECONDS := 12.0

func _ready() -> void:
    # Keep the same direct-scene startup path as the proven v0.1.3 build.
    # The diagnostic overlay is created first so later runtime failures remain visible.
    process_priority = 1000
    _build_diagnostic_overlay()
    _diag_stage("AF-WORLD-200", "Starter Town controller entered _ready().")

    _diag_stage("AF-TEX-210", "Loading seven compact CC0 texture maps.")
    _load_town_textures()
    _diag_stage("AF-TOWN-220", "Building Starter Town geometry and collision blockers.")
    _build_stage()
    _diag_stage("AF-TOWN-221", "Starter Town geometry finished successfully.")

    # Area transition controller can show a custom loading screen once
    # the next region exists. Until then, the closed gate gives a notice.
    _zone_transfer = ZoneTransfer.new()
    add_child(_zone_transfer)

    _diag_stage("AF-PLAYER-230", "Creating player actor root.")
    _actor = Node3D.new()
    _actor.name = "TripoActor"
    _actor.scale = Vector3.ONE * ACTOR_SCALE
    _actor.position = Vector3(0.0, 0.0, 18.0)
    add_child(_actor)
    _build_ground_contact_shadow()

    _diag_stage("AF-CAMERA-240", "Creating third-person camera.")
    _camera = Camera3D.new()
    _camera.name = "OrbitCamera"
    _camera.current = true
    _camera.fov = 52.0
    _camera.near = 0.03
    _camera.far = 160.0
    add_child(_camera)

    _diag_stage("AF-UI-250", "Building gameplay HUD and touch controls.")
    _build_ui()
    _set_graphics_preset(GraphicsQuality.restored(), false)
    _set_status("LOADING", "Diagnostics active • reading embedded Tripo GLB…")
    _update_camera(1.0)
    _diag_stage("AF-MODEL-300", "Town is visible. Loading embedded character GLB next.")
    call_deferred("_load_runtime_glb")

func _build_diagnostic_overlay() -> void:
    var layer := CanvasLayer.new()
    layer.name = "DiagnosticsLayer"
    layer.layer = 100
    add_child(layer)

    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    _diag_button = Button.new()
    _diag_button.text = "DEBUG BOOT"
    _diag_button.anchor_left = 0.5
    _diag_button.anchor_right = 0.5
    _diag_button.anchor_top = 1.0
    _diag_button.anchor_bottom = 1.0
    _diag_button.offset_left = -76.0
    _diag_button.offset_right = 76.0
    _diag_button.offset_top = -52.0
    _diag_button.offset_bottom = -8.0
    _diag_button.add_theme_font_size_override("font_size", 14)
    _diag_button.pressed.connect(_toggle_diagnostics)
    ui.add_child(_diag_button)

    _diag_panel = Panel.new()
    _diag_panel.anchor_left = 0.5
    _diag_panel.anchor_right = 0.5
    _diag_panel.anchor_top = 0.5
    _diag_panel.anchor_bottom = 0.5
    _diag_panel.offset_left = -360.0
    _diag_panel.offset_right = 360.0
    _diag_panel.offset_top = -145.0
    _diag_panel.offset_bottom = 145.0
    _diag_panel.visible = false
    ui.add_child(_diag_panel)

    var title := Label.new()
    title.position = Vector2(22, 18)
    title.size = Vector2(676, 32)
    title.text = "AETHERFALL DIAGNOSTICS"
    title.add_theme_font_size_override("font_size", 22)
    _diag_panel.add_child(title)

    _diag_code_label = Label.new()
    _diag_code_label.position = Vector2(22, 60)
    _diag_code_label.size = Vector2(676, 34)
    _diag_code_label.add_theme_font_size_override("font_size", 20)
    _diag_panel.add_child(_diag_code_label)

    _diag_detail_label = Label.new()
    _diag_detail_label.position = Vector2(22, 104)
    _diag_detail_label.size = Vector2(676, 150)
    _diag_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _diag_detail_label.add_theme_font_size_override("font_size", 16)
    _diag_panel.add_child(_diag_detail_label)
    _refresh_diagnostics()

func _diag_stage(code: String, detail: String) -> void:
    if _startup_failed:
        return
    _diag_code = code
    _diag_detail_text = detail
    _startup_elapsed = 0.0
    if code == "AF-READY-900":
        _startup_complete = true
        if _diag_button != null:
            _diag_button.text = "DEBUG OK"
    _refresh_diagnostics()

func _diag_failure(code: String, detail: String) -> void:
    if _startup_failed:
        return
    _startup_failed = true
    _diag_code = code
    _diag_detail_text = detail
    push_error("AETHERFALL_DIAGNOSTIC " + code + ": " + detail)
    if _diag_button != null:
        _diag_button.text = "ERROR " + code
    if _diag_panel != null:
        _diag_panel.visible = true
    _refresh_diagnostics()

func _toggle_diagnostics() -> void:
    if _diag_panel != null:
        _diag_panel.visible = not _diag_panel.visible

func _refresh_diagnostics() -> void:
    if _diag_code_label != null:
        _diag_code_label.text = _diag_code
    if _diag_detail_label != null:
        var state := "STARTING"
        if _startup_complete:
            state = "READY - no startup errors detected"
        elif _startup_failed:
            state = "FAILED - photograph this panel"
        _diag_detail_label.text = "Starter Town Pass 3 diagnostics\nState: " + state + "\n\n" + _diag_detail_text + "\n\nLast stage: " + _diag_code

func _load_town_textures() -> void:
    _town_textures.clear()
    for kind in ["cobble", "grass", "dirt", "plaster", "wood", "roof", "stone"]:
        var filename: String = "res://textures/" + String(kind) + ".bin"
        if not FileAccess.file_exists(filename):
            push_warning("Town texture not available: " + filename)
            continue
        var img := Image.new()
        if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(filename)) != OK:
            push_warning("Could not decode texture: " + filename)
            continue
        img.generate_mipmaps()
        _town_textures[kind] = ImageTexture.create_from_image(img)


func _town_texture_group(name: String) -> String:
    var n := name.to_lower()
    if n == "townground":
        # The multi-mesh grass is actual vegetation. Soil showing between its
        # stems must be dark earth, not a stretched green lawn bitmap.
        return "dirt"
    if n == "grasspatch":
        return "grass"
    if n.contains("shoulder") or n == "treedirt":
        return "dirt"
    if n.begins_with("roof") or n.begins_with("gateroof") or n == "doorhood":
        return "roof"
    if n == "plasterwalls":
        return "plaster"
    if n.begins_with("closedwoodgate") or n.begins_with("timbergate") or n.begins_with("gatehouse") or n.begins_with("gatediagonal"):
        return "wood"
    if n in ["roadstone", "squarestone", "entryroad", "crossroad", "marketsquare"]:
        return "cobble"
    if n.contains("foundation") or n.contains("cornerstone") or n.contains("wallcap") or n.contains("buttress") or n == "townwall" or n.begins_with("stonegate") or n.begins_with("gatepier") or n.begins_with("gatetower") or n.begins_with("chimney") or n == "rock":
        return "stone"
    for prefix in ["frontpost", "sidepost", "frontband", "sideband", "brace", "eavetrim", "fascia", "windowtrim", "sidewindowtrim", "windowcross", "sidewindowcross", "door", "shutter", "flowerbox", "counter", "shelf", "gatebar", "gatecrossbar", "barrel", "trunk", "branch", "shop", "benchseat", "benchback", "stallpost", "crate", "carvedtrestle", "trestlepost", "diagonalwoodbrace", "solidoakseat", "roundedseatedge", "backbeam", "carvedbackcap", "backtrestle", "oaklampmast", "lampcrossbeam", "lampdiagonalbrace"]:
        if n.begins_with(prefix):
            return "wood"
    return ""


func _town_mat(name: String, color: Color, roughness: float, size: Vector3) -> StandardMaterial3D:
    var mat := _mat(color, roughness)
    var kind := _town_texture_group(name)
    if kind.is_empty() or not _town_textures.has(kind):
        return mat
    mat.albedo_texture = _town_textures[kind] as Texture2D
    # Pale source grass needs a stronger green tint; hold stone/plaster neutral.
    var strength := 0.22
    if kind == "grass":
        strength = 0.64
    elif kind == "dirt":
        # Source texture is quite light; favour a warm brown soil tint so
        # sand/olive tones do not dominate the exposed meadow ground.
        strength = 0.83
    elif kind == "plaster":
        strength = 0.36
    elif kind == "roof":
        strength = 0.52
    elif kind == "wood":
        strength = 0.31
    elif kind == "cobble" or kind == "stone":
        strength = 0.25
    mat.albedo_color = Color.WHITE.lerp(color, strength)
    var meters := 2.3
    if kind == "plaster":
        meters = 2.8
    elif kind == "wood" or kind == "roof":
        meters = 1.9
    elif kind == "cobble":
        meters = 1.65
    mat.uv1_scale = Vector3(maxf(1.0, size.x / meters), maxf(1.0, maxf(size.y, size.z) / meters), 1.0)
    # BoxMesh UVs differ by face. A 52m side wall uses the 1.2m X dimension
    # for the facade U axis and the 52m Z dimension for its vertical V axis,
    # compressing the stone into horizontal streaks. Uniform triplanar stone
    # projection keeps mortar joints the same scale on every face and corner.
    if kind == "stone" and name.to_lower() in ["townwall", "wallcap"]:
        mat.uv1_triplanar = true
        mat.uv1_scale = Vector3(1.05, 1.05, 1.05)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return mat


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _box(parent: Node, name: String, size: Vector3, position: Vector3, color: Color, rotation_degrees: Vector3 = Vector3.ZERO, roughness: float = 0.9) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.rotation_degrees = rotation_degrees
    mesh_instance.material_override = _town_mat(name, color, roughness, size)
    parent.add_child(mesh_instance)
    return mesh_instance

func _cylinder(parent: Node, name: String, radius: float, height: float, position: Vector3, color: Color, roughness: float = 0.9) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 18
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _town_mat(name, color, roughness, Vector3(radius * 2.0, height, radius * 2.0))
    parent.add_child(mesh_instance)
    return mesh_instance

func _tapered_cylinder(parent: Node, name: String, bottom_radius: float, top_radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := CylinderMesh.new()
    mesh.top_radius = top_radius
    mesh.bottom_radius = bottom_radius
    mesh.height = height
    mesh.radial_segments = 14
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _town_mat(name, color, 0.95, Vector3(bottom_radius * 2.0, height, bottom_radius * 2.0))
    parent.add_child(mesh_instance)
    return mesh_instance

func _sphere(parent: Node, name: String, radius: float, position: Vector3, color: Color, roughness: float = 0.88) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _town_mat(name, color, roughness, Vector3(radius * 2.0, radius * 2.0, radius * 2.0))
    parent.add_child(mesh_instance)
    return mesh_instance

func _add_blocker(center: Vector2, size: Vector2, padding: float = PLAYER_WORLD_RADIUS) -> void:
    _world_blockers.append(Rect2(center - size * 0.5 - Vector2.ONE * padding, size + Vector2.ONE * padding * 2.0))

func _add_circle_blocker(center: Vector2, radius: float, padding: float = PLAYER_WORLD_RADIUS) -> void:
    _circle_blockers.append(Vector3(center.x, center.y, radius + padding))

func _add_oriented_blocker(center: Vector2, size: Vector2, yaw: float, padding: float = PLAYER_WORLD_RADIUS) -> void:
    _oriented_blockers.append({
        "center": center,
        "half": size * 0.5 + Vector2.ONE * padding,
        "yaw": deg_to_rad(yaw)
    })

func _add_camera_obstacle(center: Vector3, size: Vector3) -> void:
    _camera_obstacles.append(AABB(center - size * 0.5, size))


func _add_camera_cylinder(center: Vector3, radius: float, height: float) -> void:
    _camera_cylinders.append({"center": center, "radius": radius, "height": height})


func _camera_cylinder_hit_distance(target: Vector3, direction: Vector3, max_distance: float, cylinder: Dictionary) -> float:
    # Check curved sides AND top/bottom caps. Unlike a box, an empty corner
    # beside the cylindrical gate tower cannot trigger a false camera hit.
    var center: Vector3 = cylinder["center"]
    var radius: float = cylinder["radius"]
    var half_height: float = float(cylinder["height"]) * 0.5
    var bottom := center.y - half_height
    var top := center.y + half_height
    var radial := Vector2(target.x - center.x, target.z - center.z)
    var planar_dir := Vector2(direction.x, direction.z)
    if radial.length_squared() <= radius * radius and target.y >= bottom and target.y <= top:
        return 0.0
    var nearest := max_distance
    var a := planar_dir.length_squared()
    if a > 0.000001:
        var b := 2.0 * radial.dot(planar_dir)
        var c := radial.length_squared() - radius * radius
        var discriminant := b * b - 4.0 * a * c
        if discriminant >= 0.0:
            var root := sqrt(discriminant)
            for candidate in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
                var t: float = float(candidate)
                if t >= 0.0 and t <= nearest:
                    var hit_y: float = target.y + t * direction.y
                    if hit_y >= bottom and hit_y <= top:
                        nearest = t
    if absf(direction.y) > 0.000001:
        for cap_y in [bottom, top]:
            var t: float = (float(cap_y) - target.y) / direction.y
            if t >= 0.0 and t <= nearest:
                var hit: Vector3 = target + direction * t
                if Vector2(hit.x - center.x, hit.z - center.z).length_squared() <= radius * radius:
                    nearest = t
    return nearest


func _add_door_step_surface(center: Vector2, size: Vector2, height: float) -> void:
    _door_step_surfaces.append({"rect": Rect2(center - size * 0.5, size), "height": height})


func _camera_safe_goal(target: Vector3, desired: Vector3) -> Vector3:
    # Keep the camera in front of obstacles; towers use their actual curved
    # footprint, rather than the diagonally oversized AABB they previously had.
    var offset := desired - target
    var distance := offset.length()
    if distance < 0.001:
        return desired
    var direction := offset / distance
    var nearest := distance
    for obstacle in _camera_obstacles:
        var hit: Variant = obstacle.intersects_segment(target, desired)
        if hit is Vector3:
            nearest = minf(nearest, target.distance_to(hit as Vector3))
    for cylinder in _camera_cylinders:
        nearest = minf(nearest, _camera_cylinder_hit_distance(target, direction, distance, cylinder))
    if nearest < distance:
        return target + direction * maxf(0.12, nearest - CAMERA_WALL_GAP)
    return desired


func _window_frame(parent: Node, center: Vector3, width: float, height: float) -> void:
    var frame := Color("#3a2a22")
    _box(parent, "WindowGlass", Vector3(width, height, 0.09), center, Color("#8cc8d8"), Vector3.ZERO, 0.22)
    _box(parent, "WindowTrimT", Vector3(width + 0.18, 0.10, 0.13), center + Vector3(0, height * 0.5 + 0.05, 0.02), frame)
    _box(parent, "WindowTrimB", Vector3(width + 0.18, 0.10, 0.13), center + Vector3(0, -height * 0.5 - 0.05, 0.02), frame)
    _box(parent, "WindowTrimL", Vector3(0.10, height, 0.13), center + Vector3(-width * 0.5 - 0.05, 0, 0.02), frame)
    _box(parent, "WindowTrimR", Vector3(0.10, height, 0.13), center + Vector3(width * 0.5 + 0.05, 0, 0.02), frame)
    _box(parent, "WindowCrossV", Vector3(0.055, height * 0.92, 0.14), center + Vector3(0, 0, 0.03), frame)
    _box(parent, "WindowCrossH", Vector3(width * 0.92, 0.055, 0.14), center + Vector3(0, 0, 0.03), frame)

func _window_frame_side(parent: Node, center: Vector3, width: float, height: float) -> void:
    var frame := Color("#3a2a22")
    _box(parent, "SideWindowGlass", Vector3(0.09, height, width), center, Color("#8cc8d8"), Vector3.ZERO, 0.22)
    _box(parent, "SideWindowTrimT", Vector3(0.13, 0.10, width + 0.18), center + Vector3(0.02, height * 0.5 + 0.05, 0), frame)
    _box(parent, "SideWindowTrimB", Vector3(0.13, 0.10, width + 0.18), center + Vector3(0.02, -height * 0.5 - 0.05, 0), frame)
    _box(parent, "SideWindowTrimL", Vector3(0.13, height, 0.10), center + Vector3(0.02, 0, -width * 0.5 - 0.05), frame)
    _box(parent, "SideWindowTrimR", Vector3(0.13, height, 0.10), center + Vector3(0.02, 0, width * 0.5 + 0.05), frame)
    _box(parent, "SideWindowCrossV", Vector3(0.14, height * 0.92, 0.055), center + Vector3(0.03, 0, 0), frame)
    _box(parent, "SideWindowCrossH", Vector3(0.14, 0.055, width * 0.92), center + Vector3(0.03, 0, 0), frame)

func _front_shutters(parent: Node, center: Vector3, width: float, height: float) -> void:
    var wood := Color("#5b3b2d")
    var offset := width * 0.5 + 0.18
    _box(parent, "ShutterL", Vector3(0.25, height * 0.92, 0.10), center + Vector3(-offset, 0, 0.08), wood, Vector3.ZERO, 0.84)
    _box(parent, "ShutterR", Vector3(0.25, height * 0.92, 0.10), center + Vector3(offset, 0, 0.08), wood, Vector3.ZERO, 0.84)
    _box(parent, "ShutterBarL", Vector3(0.29, 0.07, 0.12), center + Vector3(-offset, 0, 0.10), Color("#34251f"))
    _box(parent, "ShutterBarR", Vector3(0.29, 0.07, 0.12), center + Vector3(offset, 0, 0.10), Color("#34251f"))

func _flower_box(parent: Node, center: Vector3, width: float) -> void:
    _box(parent, "FlowerBox", Vector3(width, 0.24, 0.28), center, Color("#5b3b2d"), Vector3.ZERO, 0.90)
    for i in range(3):
        var fx := -width * 0.28 + float(i) * width * 0.28
        _sphere(parent, "Flower", 0.11, center + Vector3(fx, 0.20, 0.02), [Color("#c85d64"), Color("#d9a84d"), Color("#7c79c9")][i % 3], 0.9)

func _add_house(position: Vector3, body_size: Vector3, wall_color: Color, roof_color: Color, title: String = "") -> Node3D:
    var house := Node3D.new()
    house.name = title if not title.is_empty() else "House_%d_%d" % [roundi(position.x * 100.0), roundi(position.z * 100.0)]
    house.position = position
    add_child(house)
    var width := body_size.x
    var depth := body_size.z
    var body_center_y := 0.52 + body_size.y * 0.5
    var front_z := depth * 0.505
    var stone := Color("#66655f")
    var stone_light := Color("#85827a")
    var beam := Color("#34251f")
    var door_wood := Color("#4c3022")

    _box(house, "Foundation", Vector3(width + 0.52, 0.56, depth + 0.52), Vector3(0, 0.28, 0), stone)
    _box(house, "FoundationCourse", Vector3(width + 0.58, 0.10, depth + 0.58), Vector3(0, 0.52, 0), stone_light)
    _box(house, "PlasterWalls", body_size, Vector3(0, body_center_y, 0), wall_color, Vector3.ZERO, 0.98)

    # Strong timber silhouette: corners, floor band, ridge band, and diagonal braces.
    for x in [-width * 0.45, 0.0, width * 0.45]:
        _box(house, "FrontPost", Vector3(0.15, body_size.y + 0.08, 0.17), Vector3(x, body_center_y, front_z), beam)
    _box(house, "FrontBandLow", Vector3(width * 0.94, 0.14, 0.17), Vector3(0, 1.42, front_z), beam)
    _box(house, "FrontBandHigh", Vector3(width * 0.94, 0.14, 0.17), Vector3(0, body_size.y + 0.26, front_z), beam)
    _box(house, "BraceL", Vector3(0.13, 1.55, 0.18), Vector3(-width * 0.31, 2.15, front_z + 0.01), beam, Vector3(0, 0, -28))
    _box(house, "BraceR", Vector3(0.13, 1.55, 0.18), Vector3(width * 0.31, 2.15, front_z + 0.01), beam, Vector3(0, 0, 28))

    # Old procedural entrance steps were misaligned with the imported doors.
    # Ground-level thresholds belong to the actual buildings, not this fallback.
    var door_face := depth * 0.515 + 0.08
    _box(house, "Door", Vector3(1.05, 1.95, 0.16), Vector3(0, 1.46, depth * 0.515), door_wood, Vector3.ZERO, 0.72)

    var left_front_window := Vector3(-width * 0.27, 2.10, depth * 0.518)
    var right_front_window := Vector3(width * 0.27, 2.10, depth * 0.518)
    _window_frame(house, left_front_window, 0.72, 0.82)
    _window_frame(house, right_front_window, 0.72, 0.82)
    _front_shutters(house, left_front_window, 0.72, 0.82)
    _front_shutters(house, right_front_window, 0.72, 0.82)
    _flower_box(house, left_front_window + Vector3(0, -0.58, 0.14), 0.84)
    _flower_box(house, right_front_window + Vector3(0, -0.58, 0.14), 0.84)

    # Side elevations: timber posts/bands and one framed window per side prevent blank box walls.
    for side_index in range(2):
        var side: float = -1.0 if side_index == 0 else 1.0
        var sx: float = side * width * 0.505
        for z_index in range(3):
            var z: float = [-depth * 0.34, 0.0, depth * 0.34][z_index]
            _box(house, "SidePost", Vector3(0.17, body_size.y + 0.08, 0.15), Vector3(sx, body_center_y, z), beam)
        _box(house, "SideBandLow", Vector3(0.17, 0.14, depth * 0.92), Vector3(sx, 1.42, 0), beam)
        _box(house, "SideBandHigh", Vector3(0.17, 0.14, depth * 0.92), Vector3(sx, body_size.y + 0.26, 0), beam)
        _window_frame_side(house, Vector3(sx + side * 0.012, 2.05, -depth * 0.08), 0.74, 0.80)

    # Stone quoins at the four corners break up the foundation/plaster transition.
    for sx_index in range(2):
        var corner_x: float = -1.0 if sx_index == 0 else 1.0
        for sz_index in range(2):
            var corner_z: float = -1.0 if sz_index == 0 else 1.0
            var corner: Vector3 = Vector3(corner_x * width * 0.505, 1.02, corner_z * depth * 0.505)
            _box(house, "CornerStoneLow", Vector3(0.30, 0.32, 0.30), corner, stone_light)
            _box(house, "CornerStoneHigh", Vector3(0.26, 0.28, 0.26), corner + Vector3(0, 0.36, 0), stone)

    # Door frame, lintel and visible handle add scale cues at character eye level.
    _box(house, "DoorFrameL", Vector3(0.12, 2.08, 0.20), Vector3(-0.60, 1.50, depth * 0.526), beam)
    _box(house, "DoorFrameR", Vector3(0.12, 2.08, 0.20), Vector3(0.60, 1.50, depth * 0.526), beam)
    _box(house, "DoorLintel", Vector3(1.32, 0.13, 0.20), Vector3(0, 2.49, depth * 0.526), beam)
    _sphere(house, "DoorHandle", 0.06, Vector3(0.32, 1.48, door_face + 0.025), Color("#b58a45"), 0.38)

    # Deep eaves, ridge cap, and fascia make the simple roof read as an intentional stylized asset.
    _box(house, "RoofLeft", Vector3(width * 0.64, 0.34, depth + 1.05), Vector3(-width * 0.245, body_size.y + 1.08, 0), roof_color, Vector3(0, 0, 25), 0.82)
    _box(house, "RoofRight", Vector3(width * 0.64, 0.34, depth + 1.05), Vector3(width * 0.245, body_size.y + 1.08, 0), roof_color, Vector3(0, 0, -25), 0.82)
    _box(house, "RoofRidge", Vector3(0.26, 0.30, depth + 1.12), Vector3(0, body_size.y + 1.62, 0), roof_color.darkened(0.18), Vector3.ZERO, 0.78)
    # Thin, subdued tile courses make each pitched roof read as shingles.
    # These are visual details only; the building dimensions and blockers stay fixed.
    var roof_courses := maxi(4, mini(9, int(ceil(depth / 0.85))))
    for course_i in range(1, roof_courses):
        var z_course := -depth * 0.5 + float(course_i) * depth / float(roof_courses)
        for side_i in [-1, 1]:
            var side: float = float(side_i)
            var roof_angle := -25.0 if side > 0.0 else 25.0
            var ridge := _box(house, "RoofCourse", Vector3(width * 0.60, 0.016, 0.035), Vector3(side * width * 0.245, body_size.y + 1.269, z_course), roof_color.darkened(0.21), Vector3(0, 0, roof_angle), 0.96)
            ridge.material_override = _mat(roof_color.darkened(0.20), 0.93)
    _box(house, "FasciaFront", Vector3(width + 0.58, 0.16, 0.18), Vector3(0, body_size.y + 0.76, depth * 0.57), beam)
    _box(house, "FasciaBack", Vector3(width + 0.58, 0.16, 0.18), Vector3(0, body_size.y + 0.76, -depth * 0.57), beam)
    _box(house, "EaveTrimL", Vector3(0.14, 0.18, depth + 1.02), Vector3(-width * 0.51, body_size.y + 0.78, 0), beam)
    _box(house, "EaveTrimR", Vector3(0.14, 0.18, depth + 1.02), Vector3(width * 0.51, body_size.y + 0.78, 0), beam)

    _box(house, "Chimney", Vector3(0.52, 1.28, 0.52), Vector3(width * 0.25, body_size.y + 1.63, -depth * 0.18), Color("#5f5c58"))
    _box(house, "ChimneyCap", Vector3(0.68, 0.15, 0.68), Vector3(width * 0.25, body_size.y + 2.29, -depth * 0.18), Color("#474744"))

    # Pass 4.1 replaces flat ShopSign and floating Label3D with physical
    # carved hanging signs after imported facade sizing is finalized.

    # Import at a human-scale door height, then fit collision to the rendered
    # exterior, NOT the old procedural house dimensions (or stair footprints).
    var facade := "House_%d" % (1 + absi(roundi(position.x * 13.0 + position.z * 7.0)) % 4)
    if title == "THE INN":
        facade = "Inn"
    elif title == "BLACKSMITH":
        facade = "Blacksmith"
    var landmark := not title.is_empty()
    # Match imported doorway clearance to a standing adventurer. The former
    # height left several low arches at the player's shoulder level.
    var doorway_scale := 1.22 if landmark else 1.26
    var desired_size := Vector3(
        width + (0.72 if landmark else 0.38),
        (body_size.y + (3.55 if landmark else 2.72)) * doorway_scale,
        depth + (0.66 if landmark else 0.36)
    )
    var imported := SceneryReplacement.place(house, facade, desired_size)
    var collision_size := Vector3(width + 0.50, body_size.y + 1.7, depth + 0.50)
    if imported:
        collision_size = house.get_meta("scenery_model_size", desired_size)
    if landmark:
        # Imported Quaternius roofs/awnings vary in width and depth. Anchor the
        # wrought-iron street-facing arm outside the ACTUAL fitted facade.
        HangingShopSigns.place(house, title, collision_size)
    # Use the imported stone/plaster footprint, NOT roof or covered-porch
    # extents. This leaves sheltered walks beneath the wooden overhangs while
    # the ground-floor stone walls and closed doors remain solid.
    var wall_footprint: Rect2 = house.get_meta(
        "scenery_wall_footprint",
        Rect2(Vector2(-collision_size.x * 0.37, -collision_size.z * 0.37),
            Vector2(collision_size.x * 0.74, collision_size.z * 0.74))
    )
    var core_center := Vector2(position.x, position.z) + wall_footprint.position + wall_footprint.size * 0.5
    var core_half := wall_footprint.size * 0.5
    _house_blockers.append({
        "center": core_center,
        "half": core_half + Vector2.ONE * (PLAYER_WORLD_RADIUS + 0.04),
        "asset": imported,
        "door_stop_z": door_face + PLAYER_WORLD_RADIUS + 0.035,
        "door_half_width": 0.64
    })
    house.set_meta("collision_half", core_half)
    house.set_meta("collision_center", core_center)
    house.set_meta("covered_walkway_clearance", true)
    # Preserve the covered passage, but give its upright timber supports their
    # own compact blockers instead of restoring solid collision to the roof.
    _register_house_awning_supports(house, wall_footprint)
    # Build the pedestrian path from the imported ground-floor masonry edge.
    # The route ends at the door, not meters short of its porch or steps.
    var door_anchor := Vector2(position.x, core_center.y + core_half.y + PLAYER_WORLD_RADIUS + 0.13)
    house.set_meta("road_door_anchor", door_anchor)
    _road_door_anchors.append(door_anchor)
    # Match orbit-camera collision to the masonry too, so the camera may
    # travel beneath an awning instead of reacting to empty porch air.
    _add_camera_obstacle(
        Vector3(core_center.x, collision_size.y * 0.45, core_center.y),
        Vector3(wall_footprint.size.x, collision_size.y * 0.90, wall_footprint.size.y)
    )
    return house

# Awnings extend past the stone/plaster wall, so their individual uprights
# must be solid without treating the entire sheltered space as a wall.
# Prefer actual slender imported mesh pieces; older combined-mesh houses
# receive just two compact blockers near the FRONT edge of the overhang.
func _register_house_awning_supports(house: Node3D, wall_footprint: Rect2) -> void:
    var posts: Array[Vector2] = []
    var imported := house.find_child("Quaternius_*", true, false) as Node3D
    if imported != null:
        for node in imported.find_children("*", "MeshInstance3D", true, false):
            var visual := node as MeshInstance3D
            if visual == null or visual.mesh == null:
                continue
            var bounds := visual.get_aabb()
            var local_min := Vector3(INF, INF, INF)
            var local_max := Vector3(-INF, -INF, -INF)
            for cx in [0.0, 1.0]:
                for cy in [0.0, 1.0]:
                    for cz in [0.0, 1.0]:
                        var corner := bounds.position + bounds.size * Vector3(cx, cy, cz)
                        var local_point := house.to_local(visual.to_global(corner))
                        local_min = local_min.min(local_point)
                        local_max = local_max.max(local_point)
            var size := local_max - local_min
            var footprint := Vector2((local_min.x + local_max.x) * 0.5,
                (local_min.z + local_max.z) * 0.5)
            # Ignore wide facades, canopy surfaces, elevated decoration and
            # timber that is already inside the registered masonry blocker.
            if local_min.y > 0.30 or size.y < 1.25 or size.x > 0.56 or size.z > 0.56:
                continue
            if wall_footprint.grow(0.04).has_point(footprint):
                continue
            var unique := true
            for existing in posts:
                if existing.distance_to(footprint) < 0.28:
                    unique = false
                    break
            if unique:
                posts.append(footprint)
    # Some Quaternius houses merge the porch frame into one wide mesh. In
    # that case estimate only the two edge uprights from the fitted front
    # overhang; NEVER block the open middle or the full roof footprint.
    if posts.is_empty() and imported != null:
        var model_size: Vector3 = house.get_meta("scenery_model_size", Vector3.ZERO)
        var front_overhang := model_size.z * 0.5 - wall_footprint.end.y
        if front_overhang >= 0.35:
            for fraction in [0.14, 0.86]:
                posts.append(Vector2(
                    wall_footprint.position.x + wall_footprint.size.x * float(fraction),
                    wall_footprint.end.y + minf(0.40, front_overhang * 0.72)
                ))
    var world_posts: Array[Vector2] = []
    for local_post in posts:
        var wp := house.to_global(Vector3(local_post.x, 0.0, local_post.y))
        var center := Vector2(wp.x, wp.z)
        _add_circle_blocker(center, 0.11, PLAYER_WORLD_RADIUS + 0.015)
        world_posts.append(center)
    house.set_meta("awning_support_positions", world_posts)

func _add_pine_tree(tree: Node3D, scale_factor: float, variant: int) -> void:
    tree.name = "PineTree_%02d" % variant
    _tapered_cylinder(tree, "PineTrunk", 0.22 * scale_factor, 0.14 * scale_factor,
        5.30 * scale_factor, Vector3(0.0, 2.67 * scale_factor, 0.0), Color("#534d41"))
    # Five overlapping conifer crowns, not a flat leafy billboard. Each has
    # a distinct, dark evergreen green for visible definition and depth.
    var greens := [
        Color("#294333"), Color("#34523b"), Color("#405e43"),
        Color("#304d3a"), Color("#3a5944")
    ]
    for i in range(5):
        var rad := (1.43 - float(i) * 0.20) * scale_factor
        var height := (2.30 - float(i) * 0.125) * scale_factor
        var center_y := (2.64 + float(i) * 0.83) * scale_factor
        _tapered_cylinder(tree, "PineEvergreenLayer_%d" % i,
            rad, 0.11 * scale_factor, height,
            Vector3(0.0, center_y, 0.0), greens[(i + variant) % greens.size()])
    _tapered_cylinder(tree, "PineCrownTip", 0.43 * scale_factor, 0.0,
        0.94 * scale_factor, Vector3(0.0, 6.32 * scale_factor, 0.0), Color("#2b4939"))
    tree.set_meta("foliage_style", "solid_dark_evergreen_pine")
    tree.set_meta("tree_height_m", 6.79 * scale_factor)


func _add_tree(position: Vector3, scale_factor: float = 1.0, variant: int = 0) -> void:
    var tree := Node3D.new()
    tree.position = position
    add_child(tree)
    _cylinder(tree, "TreeDirt", 0.62 * scale_factor, 0.018,
        Vector3(0, 0.009, 0), Color("#5b4937"), 1.0)
    var is_pine := variant % 3 == 1 or variant == 8
    if is_pine:
        var pine_types := ["Pine_1", "Pine_2", "Pine_4", "Pine_5"]
        var pine_name: String = pine_types[variant % pine_types.size()]
        var pine_height := (8.35 if pine_name == "Pine_4" else 7.35) * scale_factor
        if NatureReplacement.place(tree, pine_name,
            Vector3(4.30, pine_height / scale_factor, 4.15) * scale_factor, 0.07):
            tree.name = "PineTree_%02d" % variant
            tree.set_meta("foliage_style", "textured_nature_pine")
            tree.set_meta("tree_height_m", pine_height)
        else:
            _add_pine_tree(tree, scale_factor, variant)
        _add_circle_blocker(Vector2(position.x, position.z), 0.23 * scale_factor,
            PLAYER_WORLD_RADIUS + 0.035)
        return

    tree.name = "BroadleafTree_%02d" % variant
    # Proven Quaternius birch and maple imports now receive darkened, solid
    # cutout leaves. Trunks remain bark-coloured and tree collision unchanged.
    var native_trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3"]
    var tree_asset: String = native_trees[variant % native_trees.size()]
    var installed := NatureReplacement.place(tree, tree_asset,
        Vector3(3.9, 6.5, 3.9) * scale_factor, 0.075)
    if not installed:
        # Existing imported Quaternius birch/maple stays as the safe fallback.
        tree_asset = "BirchTree_1" if variant % 4 == 0 else "MapleTree_1"
        installed = SceneryReplacement.place(tree, tree_asset,
            Vector3(3.3, 5.6, 3.3) * scale_factor, PackedStringArray(), 0.0, 0.035)
    if not installed:
        # Asset import unavailable: keep a small solid-leaved fallback.
        _tapered_cylinder(tree, "Trunk", 0.25 * scale_factor, 0.17 * scale_factor,
            2.7 * scale_factor, Vector3(0, 1.37 * scale_factor, 0), Color("#4a382b"))
        for pos in [
            Vector3(-0.49, 2.85, 0.0), Vector3(0.42, 2.87, 0.12),
            Vector3(0.0, 3.38, -0.05)
        ]:
            _sphere(tree, "FallbackLeafCluster", 0.78 * scale_factor,
                pos * scale_factor, Color("#416047"))
    tree.set_meta("foliage_style", "dark_cutout_deciduous")
    _add_circle_blocker(Vector2(position.x, position.z), 0.30 * scale_factor,
        PLAYER_WORLD_RADIUS + 0.035)


# Hedges are a familiar detail beside medieval timber-and-stone houses. A
# few non-interactive flowering shrubs remain, but most are close-cut, boxy
# foliage in less saturated greens (instead of bright neon-green spheres).
func _add_trimmed_hedge(root: Node3D, scale_factor: float, variant: int) -> void:
    root.name = "TownHedge_%02d" % variant
    var length := 2.10 if variant % 3 == 0 else 1.92
    var depth := 0.82 if variant % 2 == 0 else 0.94
    # World target after 0.90 scenery scaling: 0.95-1.02 m, approximately
    # the character's hip rather than a low border planting.
    var height := 1.13 if variant % 3 == 1 else 1.06
    length *= scale_factor
    depth *= scale_factor
    height *= scale_factor
    var dark := Color("#394f3d")
    var middle := Color("#4c654a")
    var upper := Color("#596f53")
    var faded := Color("#6c7c60")
    # Layers overlap so the hedge looks maintained but not like one rigid cube.
    _box(root, "HedgeTwigShadow", Vector3(length * 0.82, 0.13 * scale_factor, depth * 0.78),
        Vector3(0.0, 0.075 * scale_factor, 0.0), Color("#344134"))
    _box(root, "HedgeBase", Vector3(length * 0.96, height * 0.78, depth * 0.94),
        Vector3(0.0, height * 0.49, 0.0), dark)
    _box(root, "HedgeLeafBody", Vector3(length, height * 0.70, depth),
        Vector3(0.0, height * 0.59, 0.0), middle)
    _box(root, "HedgeFlatTop", Vector3(length * 0.92, 0.14 * scale_factor, depth * 0.90),
        Vector3(0.0, height * 0.94, 0.0), upper)
    for i in range(4):
        # Small asymmetries and quiet colour variation keep the trimmed edges
        # looking leafy without adding transparent cards or extra textures.
        var fraction := (float(i) - 1.5) / 4.0
        var px := fraction * length * 0.87
        var shade := faded if (i + variant) % 3 == 0 else upper
        var patch_length := length * (0.18 if i % 2 == 0 else 0.21)
        var patch_depth := depth * 0.44
        _box(root, "HedgeTopLeaves_%d" % i,
            Vector3(patch_length, 0.075 * scale_factor, patch_depth),
            Vector3(px, height + 0.014 * scale_factor, depth * (0.16 if i % 2 == 0 else -0.16)), shade)
        var side_shade := middle if i % 2 == 0 else dark.lightened(0.08)
        _box(root, "HedgeSideLeaves_%d" % i,
            Vector3(patch_length, height * 0.17, depth * 0.065),
            Vector3(px, height * (0.47 if i % 2 == 0 else 0.69),
                depth * (0.498 if i % 2 == 0 else -0.498)), side_shade)
    # Keep the foliage flush with the turf. The plant is ornamental and
    # intentionally walk-through, but grass below it should not poke through.
    root.set_meta("foliage_style", "low_rectangular_hedge")
    root.set_meta("hedge_dimensions", Vector3(length, height, depth))
    # Two overlapping real textured bushes create an elongated hip-high
    # hedge, retaining the rectangular shape of the approved mockup.
    var foliage_loaded := 0
    for side in [-1.0, 1.0]:
        var segment := Node3D.new()
        segment.name = "HedgeFoliageSegment"
        segment.position.x = float(side) * length * 0.23
        root.add_child(segment)
        if NatureReplacement.place(segment, "Bush_Common",
            Vector3(length * 0.61, height, depth * 1.05), 0.08):
            foliage_loaded += 1
    if foliage_loaded == 2:
        for child in root.get_children():
            if child is MeshInstance3D:
                (child as MeshInstance3D).visible = false
        root.set_meta("foliage_style", "textured_hip_high_hedge")
        root.set_meta("nature_hedge_imported", true)
    _foliage_grass_masks.append(Rect2(
        Vector2(root.position.x - length * 0.46, root.position.z - depth * 0.47),
        Vector2(length * 0.92, depth * 0.94)))


func _mute_imported_shrub(node: Node) -> void:
    if node is MeshInstance3D:
        var part := node as MeshInstance3D
        if part.mesh != null:
            for surface in range(part.mesh.get_surface_count()):
                var current := part.get_active_material(surface)
                if current is StandardMaterial3D:
                    var mat := (current as StandardMaterial3D).duplicate() as StandardMaterial3D
                    var source: Color = mat.albedo_color
                    # Quaternius foliage has particularly vivid yellow-green
                    # texture cards; tone them toward quiet moss/olive green.
                    mat.albedo_color = Color(source.r * 0.64, source.g * 0.74,
                        source.b * 0.63, source.a)
                    part.set_surface_override_material(surface, mat)
    for child in node.get_children():
        _mute_imported_shrub(child)


func _shrub_fits_lawn(center: Vector3, scale_factor: float, flowering: bool) -> bool:
    # Check the real outer footprint, not only the centre. Checking a single
    # point let foliage hang out over the freshly restored cobblestones.
    var half_x := (0.87 if flowering else 1.10) * scale_factor
    var half_z := (0.87 if flowering else 0.55) * scale_factor
    for dx in [-1.0, 0.0, 1.0]:
        for dz in [-1.0, 0.0, 1.0]:
            var sample := Vector3(center.x + float(dx) * half_x, 0.0,
                center.z + float(dz) * half_z)
            if _ground_surface_y(sample) > 0.011:
                return false
            if _world_point_blocked(Vector2(sample.x, sample.z)):
                return false
    return true


func _add_shrub(position: Vector3, scale_factor: float = 1.0, variant: int = 0) -> void:
    var flowering := variant % 4 == 2
    # Green rounded shrub for some variants; rectangular green hedges for the rest.
    # Previously these variants were reddish 'Bush_Common_Flowers'.
    # Search expanding rings rather than defaulting to the original point:
    # even a narrow patch of cobble underneath is unacceptable. Prefer spots
    # close to the intended house, not distant random open lawn.
    var chosen := position
    var found := false
    for ring in range(14):
        var radius := 0.48 * float(ring)
        var slots := 1 if ring == 0 else 20
        for angle_index in range(slots):
            var angle := TAU * float(angle_index) / float(slots) + float(variant) * 0.21
            var candidate := position + Vector3(cos(angle) * radius, 0.0,
                sin(angle) * radius)
            if _shrub_fits_lawn(candidate, scale_factor, flowering):
                chosen = candidate
                found = true
                break
        if found:
            break
    if not found:
        push_warning("No safe grass bed for shrub %d; skipping pavement placement." % variant)
        return

    var shrub := Node3D.new()
    shrub.position = chosen
    add_child(shrub)
    shrub.set_meta("planted_in_lawn", true)
    shrub.set_meta("lawn_footprint_checked", true)
    shrub.set_meta("original_landscape_position", position)
    if not flowering:
        _add_trimmed_hedge(shrub, scale_factor, variant)
    else:
        shrub.name = "TownGreenBush_%02d" % variant
        var ground_sink := 0.20 * scale_factor
        if not NatureReplacement.place(shrub, "Bush_Common",
            Vector3(1.54, 1.13, 1.54) * scale_factor, ground_sink):
            _add_trimmed_hedge(shrub, scale_factor, variant)
        shrub.set_meta("green_bush_only", true)
        _foliage_grass_masks.append(Rect2(
            Vector2(chosen.x - 0.60 * scale_factor, chosen.z - 0.60 * scale_factor),
            Vector2.ONE * (1.20 * scale_factor)))
    shrub.set_meta("grounded", true)


func _grass_point_blocked(point: Vector2) -> bool:
    # Player collision deliberately has ~0.35m of padding around every
    # wall and post. Grass does NOT need that avatar radius: only a slim
    # ~8cm botanical clearance from the physical masonry foundations.
    # Avoid making _world_point_blocked less restrictive for actual actors!
    for blocker in _world_blockers:
        if blocker.has_point(point):
            return true
    for house in _house_blockers:
        var center: Vector2 = house["center"]
        var padded_half: Vector2 = house["half"]
        var masonry_half := padded_half - Vector2.ONE * (PLAYER_WORLD_RADIUS + 0.04 - 0.08)
        var delta := point - center
        if absf(delta.x) < masonry_half.x and absf(delta.y) < masonry_half.y:
            return true
    for circle in _circle_blockers:
        var object_center := Vector2(circle.x, circle.y)
        var plant_radius := maxf(0.07, circle.z - PLAYER_WORLD_RADIUS + 0.09)
        if point.distance_squared_to(object_center) < plant_radius * plant_radius:
            return true
    for obstacle in _oriented_blockers:
        var delta: Vector2 = point - (obstacle["center"] as Vector2)
        var theta: float = float(obstacle["yaw"])
        var local := Vector2(cos(theta) * delta.x - sin(theta) * delta.y,
            sin(theta) * delta.x + cos(theta) * delta.y)
        var half: Vector2 = obstacle["half"]
        var plant_half := Vector2(maxf(0.08, half.x - PLAYER_WORLD_RADIUS + 0.08),
            maxf(0.08, half.y - PLAYER_WORLD_RADIUS + 0.08))
        if absf(local.x) < plant_half.x and absf(local.y) < plant_half.y:
            return true
    for area in _foliage_grass_masks:
        if area.has_point(point):
            return true
    return false

func _add_grass_clump(position: Vector3, scale_factor: float = 1.0) -> void:
    var clump := Node3D.new()
    clump.position = position
    add_child(clump)
    var green_a := Color("#496841")
    var green_b := Color("#5c7848")
    _box(clump, "BladeA", Vector3(0.035, 0.42, 0.05) * scale_factor, Vector3(-0.12, 0.20, 0), green_a, Vector3(0, 0, -13))
    _box(clump, "BladeB", Vector3(0.035, 0.48, 0.05) * scale_factor, Vector3(0.00, 0.23, 0), green_b, Vector3(0, 0, 7))
    _box(clump, "BladeC", Vector3(0.035, 0.38, 0.05) * scale_factor, Vector3(0.12, 0.18, 0), green_a, Vector3(0, 0, 16))
    SceneryReplacement.place(clump, "Grass_Small", Vector3(0.55, 0.65, 0.55) * scale_factor)

func _flower_patch_fits_lawn(center: Vector3, radius: float) -> bool:
    # A full 3x3 patch footprint must be grass, NOT the centre alone.
    # Unlike the former decorative prototypes this never touches cobbles.
    for dx in [-1.0, 0.0, 1.0]:
        for dz in [-1.0, 0.0, 1.0]:
            var sample := center + Vector3(float(dx) * radius, 0.0, float(dz) * radius)
            if _ground_surface_y(sample) >= 0.011:
                return false
            if _world_point_blocked(Vector2(sample.x, sample.z)):
                return false
            for mask in _foliage_grass_masks:
                if mask.grow(0.05).has_point(Vector2(sample.x, sample.z)):
                    return false
    return true


func _add_flower_patch(position: Vector3, flower_color: Color) -> void:
    # Real Quaternius wildflower groups; none of the old box stems or ball
    # heads remain. Deterministic irregular clusters, not a regular row.
    var patch_id: int = int(get_meta("wildflower_patch_count", 0))
    var chosen := position
    var found := false
    for ring in range(13):
        var distance := float(ring) * 0.36
        var slots := 1 if ring == 0 else 20
        for n in range(slots):
            var angle := TAU * float(n) / float(slots) + float(patch_id) * 0.48
            var candidate := position + Vector3(cos(angle) * distance, 0.0,
                sin(angle) * distance)
            if _flower_patch_fits_lawn(candidate, 0.45):
                chosen = candidate
                found = true
                break
        if found:
            break
    if not found:
        push_warning("No real lawn bed available for flower patch %d; skipping." % patch_id)
        return

    var flower := Node3D.new()
    flower.name = "WildflowerPatch_%02d" % patch_id
    flower.position = chosen
    flower.rotation.y = float(patch_id) * 0.77
    add_child(flower)
    var asset_name := "Flower_3_Group" if patch_id % 2 == 0 else "Flower_4_Group"
    var flower_width := 0.72 + 0.16 * float(patch_id % 3)
    var flower_height := 0.40 + 0.06 * float(patch_id % 4)
    if not NatureReplacement.place(flower, asset_name,
        Vector3(flower_width, flower_height, flower_width * 0.88), 0.035):
        flower.queue_free()
        push_warning("Quaternius flower model missing: " + asset_name)
        return
    flower.set_meta("landscaping_style", "real_meadow_wildflowers")
    flower.set_meta("planted_in_lawn", true)
    flower.set_meta("flower_group_asset", asset_name)
    flower.set_meta("flower_tint_hint", flower_color)
    flower.set_meta("patch_search_radius_m", 0.45)
    set_meta("wildflower_patch_count", patch_id + 1)

func _add_rock(position: Vector3, scale_factor: float = 1.0) -> void:
    var rock := Node3D.new()
    rock.position = position
    add_child(rock)
    _sphere(rock, "Rock", 0.26 * scale_factor, Vector3(0, 0.18 * scale_factor, 0), Color("#686861"), 1.0)
    rock.scale = Vector3(1.25, 0.70, 0.95)

func _add_town_fountain() -> void:
    # Actual user-supplied Tripo medieval fountain, not procedural geometry.
    # The 11,226-triangle mesh and all three embedded PBR maps are preserved;
    # textures are optimized for mobile before they are committed to GitHub.
    if not FileAccess.file_exists(FOUNTAIN_RUNTIME_PATH):
        push_error("AETHERFALL_FOUNTAIN_MISSING: " + FOUNTAIN_RUNTIME_PATH)
        return
    var raw := FileAccess.get_file_as_bytes(FOUNTAIN_RUNTIME_PATH)
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var err := document.append_from_buffer(raw, "", state)
    if err != OK:
        push_error("AETHERFALL_FOUNTAIN_IMPORT_FAILED: %d" % err)
        return
    var fountain_mesh := document.generate_scene(state) as Node3D
    if fountain_mesh == null:
        push_error("AETHERFALL_FOUNTAIN_INVALID: Runtime GLB has no 3D scene root")
        return
    var fountain := Node3D.new()
    fountain.name = "TownFountain"
    fountain.position = Vector3(FOUNTAIN_CENTER.x, RoadNetwork.COBBLE_HEIGHT, FOUNTAIN_CENTER.y)
    add_child(fountain)
    fountain_mesh.name = "ImportedMedievalFountain"
    fountain_mesh.scale = Vector3.ONE * FOUNTAIN_SCALE
    fountain.add_child(fountain_mesh)
    # Water layers use the fountain's approved Pass 10 local dimensions.
    # Never disturb the real Tripo model, its scale or the market position.
    var fountain_water := FountainWater.new()
    fountain_water.name = "FountainWaterEffects"
    fountain.add_child(fountain_water)
    fountain.set_meta("fountain_water_effects_enabled", true)

    # User-approved fountain made about 11% larger and centered precisely
    # between the two rows of market stalls. Preserve circular collision
    # rather than extending a rectangular no-walk barrier through the plaza.
    _add_circle_blocker(FOUNTAIN_CENTER, FOUNTAIN_BASIN_RADIUS, PLAYER_WORLD_RADIUS + 0.04)
    _add_camera_cylinder(Vector3(FOUNTAIN_CENTER.x, 1.49, FOUNTAIN_CENTER.y),
        FOUNTAIN_BASIN_RADIUS, 2.84)
    fountain.set_meta("fountain_asset", FOUNTAIN_RUNTIME_PATH)
    fountain.set_meta("fountain_imported", true)
    fountain.set_meta("fountain_visual_scale", FOUNTAIN_SCALE)
    fountain.set_meta("fountain_source_triangles", 11226)
    fountain.set_meta("fountain_player_blocker_radius", FOUNTAIN_BASIN_RADIUS + PLAYER_WORLD_RADIUS + 0.04)
    fountain.set_meta("fountain_basin_width_m", 3.14 * FOUNTAIN_SCALE / 3.2)
    fountain.set_meta("fountain_centered_between_stalls", true)
    fountain.set_meta("fountain_midpoint_stalls_z", (-6.1 + 2.45) * 0.5)


func _add_market_stall(position: Vector3, awning: Color, yaw: float) -> void:
    var stall := Node3D.new()
    stall.position = position
    stall.rotation_degrees.y = yaw
    stall.name = "MarketStall_%d_%d" % [roundi(position.x * 100.0), roundi(position.z * 100.0)]
    add_child(stall)
    var wood := Color("#5b3c2a")
    var dark_wood := Color("#3e2b22")
    _box(stall, "Counter", Vector3(2.55, 0.20, 1.25), Vector3(0, 1.05, 0), wood)
    _box(stall, "Shelf", Vector3(2.35, 0.14, 0.75), Vector3(0, 0.54, 0.18), dark_wood)
    _box(stall, "CounterFront", Vector3(2.42, 0.24, 0.12), Vector3(0, 0.84, 0.60), dark_wood)
    _box(stall, "CounterEdge", Vector3(2.61, 0.055, 1.30), Vector3(0, 1.18, 0), wood.lightened(0.12))
    for x in [-1.08, 1.08]:
        for z in [-0.46, 0.46]:
            _box(stall, "StallPost", Vector3(0.12, 2.50, 0.12), Vector3(float(x), 1.28, float(z)), dark_wood)
    # Striped awning reads much better than a single floating slab.
    for stripe in range(5):
        var sx := -1.06 + float(stripe) * 0.53
        var stripe_color := awning if stripe % 2 == 0 else awning.lightened(0.28)
        _box(stall, "AwningStripe", Vector3(0.54, 0.12, 1.72), Vector3(sx, 2.52, -0.04), stripe_color, Vector3(-8, 0, 0), 0.84)
    _box(stall, "CrateA", Vector3(0.62, 0.55, 0.62), Vector3(-0.70, 0.30, -0.35), Color("#79543a"))
    _box(stall, "CrateB", Vector3(0.55, 0.40, 0.55), Vector3(0.62, 0.22, 0.30), Color("#875f40"))
    # Try the real modular market stand while retaining the proven collision.
    # The Quaternius asset has a narrow native X axis, hence the 90-degree turn.
    # All vendors share the fully backed, striped awning version. The left
    # market stand was the approved reference in the 0.2Z phone screenshots.
    var stall_asset := "MarketStand_1"
    SceneryReplacement.place(stall, stall_asset, Vector3(2.60, 2.65, 1.65), PackedStringArray(), 90.0)
    stall.set_meta("vendor_stall_style", "backed_awning")
    # The canopy is walk-under; solid collision belongs to the COUNTER and
    # four posts. Rotate the footprint with the model so visitors can loop
    # between diagonal stalls without hitting invisible rectangular corners.
    _add_oriented_blocker(Vector2(position.x, position.z), Vector2(2.43, 1.02), yaw, PLAYER_WORLD_RADIUS + 0.025)
    var rotation := Basis(Vector3.UP, deg_to_rad(yaw))
    var post_positions: Array[Vector2] = []
    for px in [-1.08, 1.08]:
        for pz in [-0.46, 0.46]:
            var wp := position + rotation * Vector3(float(px), 0.0, float(pz))
            var post_center := Vector2(wp.x, wp.z)
            _add_circle_blocker(post_center, 0.08, PLAYER_WORLD_RADIUS + 0.02)
            post_positions.append(post_center)
    stall.set_meta("support_post_positions", post_positions)
    stall.set_meta("facing_degrees", yaw)
    _add_camera_obstacle(position + Vector3(0, 1.0, 0), Vector3(2.75, 2.0, 2.75))
    # Pass 4.2d: the Quaternius MarketStand_1 has a low built-in shelf
    # (~0.45 m), but NO waist-height sales counter. Our previous floating
    # merchandising rack looked like an entirely separate table inside it.
    # Integrate ONE countertop directly between the existing timber posts,
    # flush with the plaza-facing edge of the original stall. No new table
    # root, legs, freestanding shelves or overlapping furniture.
    var timber := Color("#63452e")
    var timber_edge := Color("#47301f")
    # Native timber posts span approximately local x=+-1.03, z=+-0.79.
    # The new counter reaches the post line and ties to the native structure.
    _box(stall, "IntegratedMerchantCountertop",
        Vector3(2.06, 0.15, 0.99),
        Vector3(0.0, 0.945, 0.29), timber, Vector3.ZERO, 0.94)
    # Front fascia joins the post line; not a second inner table or rack.
    _box(stall, "IntegratedCounterFrontFascia",
        Vector3(2.06, 0.30, 0.085),
        Vector3(0.0, 0.725, 0.755), timber_edge)
    # Two compact ledger braces connect the tabletop to the existing posts.
    # No extra legs or floor-standing structure are created.
    for edge_x in [-0.96, 0.96]:
        _box(stall, "IntegratedPostLedger_Left" if edge_x < 0.0 else "IntegratedPostLedger_Right",
            Vector3(0.12, 0.17, 0.70),
            Vector3(float(edge_x), 0.825, 0.32), timber_edge)
    # Merchandise stands ON this real integral counter, never on the canopy.
    var produce_stall := position.x < 0.0
    var first_asset := "FarmCrate_Apple" if produce_stall else "Crate_Wooden"
    var second_asset := "Crate_Wooden" if produce_stall else "FarmCrate_Apple"
    _add_market_counter_goods(stall, "CounterStock_Primary", first_asset,
        Vector3(-0.65, 1.025, 0.23), Vector3(0.47, 0.35, 0.43))
    _add_market_counter_goods(stall, "CounterStock_Secondary", second_asset,
        Vector3(0.00, 1.025, 0.23), Vector3(0.47, 0.35, 0.43))
    _add_market_counter_goods(stall, "CounterStock_Third", first_asset,
        Vector3(0.65, 1.025, 0.23), Vector3(0.47, 0.35, 0.43))
    stall.set_meta("market_wares_style", "single_integrated_market_counter")
    stall.set_meta("market_wares_expected", 3)
    stall.set_meta("market_counter_top_m", 1.02)
    stall.set_meta("market_wares_shelf_height_m", 1.02)
    stall.set_meta("market_wares_front_z", 0.755)
    stall.set_meta("market_wares_canopy_clearance", true)
    stall.set_meta("native_stall_has_counter", false)
    stall.set_meta("market_counter_frame_integrated", true)


func _add_market_counter_goods(stall: Node3D, label: String,
        asset: String, location: Vector3, desired_size: Vector3) -> void:
    var goods := Node3D.new()
    goods.name = label
    goods.position = location
    stall.add_child(goods)
    if not SceneryReplacement.place(goods, asset, desired_size):
        push_error("AETHERFALL_MARKET_WARES_MISSING: " + asset)
        return
    goods.set_meta("model", asset)
    goods.set_meta("placement", "on_existing_solid_counter")
    goods.set_meta("no_extra_collision", true)


func _add_bench(position: Vector3, yaw: float = 0.0) -> void:
    var bench := Node3D.new()
    bench.name = "TownBench_%d_%d" % [roundi(position.x * 100.0), roundi(position.z * 100.0)]
    bench.position = position
    bench.rotation_degrees.y = yaw
    # Realistic knee-height seating: original seat top was 0.88m and looked
    # waist-height next to the player, so make the whole timber frame shorter.
    bench.scale = Vector3(0.90, 0.64, 0.90)
    add_child(bench)
    # Rustic medieval trestle bench. Broad oak planks, carved supports and
    # wrought-iron bolt heads replace the modern metal frame/slatted furniture.
    var oak := Color("#6b4125")
    var dark_oak := Color("#44291a")
    var edge := Color("#91653c")
    var iron := Color("#383c3c")
    for x in [-0.75, 0.75]:
        var px := float(x)
        _box(bench, "CarvedTrestleFoot", Vector3(0.31, 0.18, 0.75), Vector3(px, 0.10, 0.02), dark_oak)
        _box(bench, "TrestlePost", Vector3(0.22, 0.57, 0.22), Vector3(px, 0.40, 0.0), oak)
        _box(bench, "IronFootBand", Vector3(0.245, 0.065, 0.245), Vector3(px, 0.22, 0), iron)
        _box(bench, "DiagonalWoodBraceFront", Vector3(0.12, 0.51, 0.12),
            Vector3(px, 0.39, -0.21), dark_oak, Vector3(25.0, 0, 0))
        _box(bench, "DiagonalWoodBraceBack", Vector3(0.12, 0.51, 0.12),
            Vector3(px, 0.39, 0.21), dark_oak, Vector3(-25.0, 0, 0))
    _box(bench, "SolidOakSeat", Vector3(2.20, 0.17, 0.65), Vector3(0.0, 0.74, -0.06), oak)
    _box(bench, "RoundedSeatEdge", Vector3(2.25, 0.065, 0.70), Vector3(0, 0.842, -0.06), edge)
    _box(bench, "BackBeam", Vector3(2.10, 0.44, 0.13), Vector3(0, 1.15, 0.30),
        oak, Vector3(9, 0, 0))
    _box(bench, "CarvedBackCap", Vector3(2.22, 0.09, 0.16), Vector3(0, 1.42, 0.35), edge)
    for x in [-0.88, 0.88]:
        var px := float(x)
        _box(bench, "BackTrestle", Vector3(0.13, 0.88, 0.14),
            Vector3(px, 1.05, 0.31), dark_oak, Vector3(9, 0, 0))
        _sphere(bench, "IronSeatRivet", 0.044, Vector3(px, 0.865, -0.27), iron, 0.33)
        _sphere(bench, "IronBackRivet", 0.045, Vector3(px, 1.18, 0.22), iron, 0.33)
    bench.set_meta("bench_style", "medieval_trestle")
    bench.set_meta("seat_top_m", 0.875 * bench.scale.y)
    # Keep collision as small as the newly scaled bench, not the old shell.
    var sx := (absf(cos(deg_to_rad(yaw))) * 2.25 + absf(sin(deg_to_rad(yaw))) * 0.92) * bench.scale.x
    var sz := (absf(sin(deg_to_rad(yaw))) * 2.25 + absf(cos(deg_to_rad(yaw))) * 0.92) * bench.scale.z
    _add_blocker(Vector2(position.x, position.z), Vector2(sx, sz), 0.20)


func _add_barrel(position: Vector3) -> void:
    var barrel := Node3D.new()
    barrel.position = position
    add_child(barrel)
    _cylinder(barrel, "Barrel", 0.34, 0.82, Vector3(0, 0.41, 0), Color("#765039"))
    _cylinder(barrel, "BandLow", 0.355, 0.07, Vector3(0, 0.18, 0), Color("#333638"), 0.45)
    _cylinder(barrel, "BandHigh", 0.355, 0.07, Vector3(0, 0.64, 0), Color("#333638"), 0.45)
    SceneryReplacement.place(barrel, "Barrel", Vector3(0.71, 0.92, 0.71))
    # The barrel and its iron bands need a shared footprint. Leave just
    # a couple of centimeters beyond the visible rim plus player radius.
    _add_circle_blocker(Vector2(position.x, position.z), 0.355, PLAYER_WORLD_RADIUS + 0.025)
    _add_camera_obstacle(position + Vector3(0.0, 0.41, 0.0), Vector3(0.71, 0.82, 0.71))

func _add_lamp(position: Vector3) -> void:
    var lamp := Node3D.new()
    lamp.name = "MedievalStreetLamp_%d_%d" % [roundi(position.x * 100.0), roundi(position.z * 100.0)]
    lamp.position = position
    add_child(lamp)
    var timber := Color("#533721")
    var dark_iron := Color("#363434")
    var sandstone := Color("#817969")
    # A small foundation and a carved oak column replace the modern thin pole.
    _cylinder(lamp, "StonePlinth", 0.15, 0.23, Vector3(0, 0.12, 0), sandstone)
    _tapered_cylinder(lamp, "OakLampMast", 0.13, 0.085, 2.30,
        Vector3(0, 1.37, 0), timber)
    _cylinder(lamp, "ForgedIronCollar", 0.15, 0.13,
        Vector3(0, 2.41, 0), dark_iron, 0.42)
    _box(lamp, "LampCrossBeam", Vector3(0.19, 0.17, 0.90),
        Vector3(0, 2.55, 0.31), timber)
    _box(lamp, "LampDiagonalBrace", Vector3(0.11, 0.70, 0.11),
        Vector3(0, 2.29, 0.25), timber, Vector3(-35, 0, 0))
    _cylinder(lamp, "CanopyFinial", 0.13, 0.17, Vector3(0, 2.78, 0), dark_iron, 0.40)
    # The actual licensed fantasy lantern is in the existing 20-model pack.
    # No extra asset download or mobile APK size penalty is required.
    var hanging := Node3D.new()
    hanging.name = "QuaterniusLanternMount"
    hanging.position = Vector3(0, 1.82, 0.52)
    lamp.add_child(hanging)
    var imported := SceneryReplacement.place(
        hanging, "Lantern_Wall", Vector3(0.50, 0.96, 0.77)
    )
    if not imported:
        _box(hanging, "ForgedIronLanternCage", Vector3(0.35, 0.52, 0.35),
            Vector3(0, 0.42, 0), dark_iron)
        _sphere(hanging, "WarmGlassGlow", 0.13, Vector3(0, 0.45, 0),
            Color("#ffd385"), 0.25)
    var glow := OmniLight3D.new()
    glow.name = "WarmLanternLight"
    glow.position = Vector3(0, 2.38, 0.52)
    glow.light_color = Color("#ffd38a")
    glow.light_energy = 0.55
    glow.omni_range = 4.0
    glow.shadow_enabled = false
    lamp.add_child(glow)
    lamp.set_meta("lamp_style", "medieval_oak_and_lantern")
    lamp.set_meta("lantern_asset_loaded", imported)
    _add_circle_blocker(Vector2(position.x, position.z), 0.15, PLAYER_WORLD_RADIUS + 0.025)
    _add_camera_obstacle(position + Vector3(0, 1.37, 0),
        Vector3(0.28, 2.75, 0.28))

func _add_wall_segment(position: Vector3, size: Vector3) -> void:
    var stone := Color("#716f68")
    _box(self, "TownWall", size, position, stone)
    _box(self, "WallCap", Vector3(size.x + 0.14, 0.20, size.z + 0.14), position + Vector3(0, size.y * 0.5 + 0.10, 0), Color("#8b877d"))
    _add_camera_obstacle(position, Vector3(size.x, size.y + 0.2, size.z))

# Pass 2 replaces overlapping paving boxes and their seams with the
# merged, continuously UV-mapped medieval road network in road_network.gd.

func _configure_hdri_environment(env: Environment) -> bool:
    if not FileAccess.file_exists(HDRI_PATH):
        return false
    var hdri_image: Image = Image.load_from_file(HDRI_PATH)
    if hdri_image == null or hdri_image.is_empty():
        return false
    var sky_texture: ImageTexture = ImageTexture.create_from_image(hdri_image)
    if sky_texture == null:
        return false
    var panorama := PanoramaSkyMaterial.new()
    panorama.panorama = sky_texture
    panorama.energy_multiplier = 0.82
    panorama.filter = true
    var sky := Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    sky.sky_material = panorama
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.background_energy_multiplier = 0.90
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_sky_contribution = 0.90
    env.ambient_light_color = Color("#d7e0e5")
    env.ambient_light_energy = 0.70
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    return true

func _configure_fallback_environment(env: Environment) -> void:
    var fallback := ProceduralSkyMaterial.new()
    fallback.sky_top_color = Color("#557b9a")
    fallback.sky_horizon_color = Color("#a9bac6")
    fallback.ground_horizon_color = Color("#87937f")
    fallback.ground_bottom_color = Color("#404b3c")
    fallback.energy_multiplier = 0.86
    var sky := Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    sky.sky_material = fallback
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.background_energy_multiplier = 0.86
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_sky_contribution = 0.82
    env.ambient_light_color = Color("#d6e0e5")
    env.ambient_light_energy = 0.66
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG

func _build_stage() -> void:
    _world_blockers.clear()
    _circle_blockers.clear()
    _oriented_blockers.clear()
    _house_blockers.clear()
    _road_door_anchors.clear()
    _road_regions.clear()
    _foliage_grass_masks.clear()
    _camera_obstacles.clear()
    _camera_cylinders.clear()
    _door_step_surfaces.clear()

    # GraphicsQuality.apply() sets the correct shadow atlas AND sampling
    # quality for the restored mobile graphics preset after the HUD is built.
    # Do not force expensive SOFT_HIGH filtering on Performance mode here.

    var world := WorldEnvironment.new()
    var env := Environment.new()
    _diag_stage("AF-LIGHT-222", "Loading Poly Haven Kloppenheim 03 1K HDR atmosphere.")
    var hdri_ready := _configure_hdri_environment(env)
    if not hdri_ready:
        _configure_fallback_environment(env)
        _diag_stage("AF-LIGHT-223", "HDRI unavailable; using mobile procedural-sky fallback.")
    else:
        _diag_stage("AF-LIGHT-224", "Poly Haven HDRI loaded successfully.")

    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 0.88
    env.tonemap_white = 4.6
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.03
    env.adjustment_contrast = 1.01
    env.adjustment_saturation = 0.97

    # Lightweight depth fog adds distance separation without Forward+ volumetrics.
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_light_color = Color("#a8b8c3")
    env.fog_light_energy = 0.34
    env.fog_depth_begin = 38.0
    env.fog_depth_end = 92.0
    env.fog_depth_curve = 1.08
    env.fog_sky_affect = 0.09
    env.fog_sun_scatter = 0.03

    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    _sun_light = sun
    sun.rotation_degrees = Vector3(-39, -28, 0)
    sun.light_color = Color("#ffe0b9")
    sun.light_energy = 0.86
    sun.shadow_enabled = true
    # Tight blended cascades plus softer contrast reduce blocky road shadows.
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_max_distance = 38.0
    sun.directional_shadow_split_1 = 0.10
    sun.directional_shadow_split_2 = 0.26
    sun.directional_shadow_split_3 = 0.52
    sun.directional_shadow_blend_splits = true
    sun.directional_shadow_fade_start = 0.84
    sun.directional_shadow_pancake_size = 9.0
    sun.shadow_bias = 0.035
    sun.shadow_normal_bias = 0.55
    sun.shadow_blur = 2.0
    sun.shadow_opacity = 0.72
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-22, 148, 0)
    fill.light_color = Color("#c2d6e2")
    fill.light_energy = 0.24
    fill.shadow_enabled = false
    add_child(fill)

    # Actual instanced leaves now define the meadow, so the visible ground
    # underneath them is one seamless, finely tiled dark earthen soil surface.
    # No separate circular terrain patches or additional physics collision.
    _box(self, "TownGround", Vector3(58.0, 0.16, 55.0),
        Vector3(0, -0.08, 0), Color("#614831"), Vector3.ZERO, 1.0)
    set_meta("town_ground_material", "textured_warm_brown_soil")

    # Road, square and house-side branches are generated together after
    # scenery placement so imported building entrances drive their endpoints.
    # The old three overlapping BoxMesh road slabs are deliberately retired.

    # Mountain valley: rugged cliffs along north and both sides conceal the
    # unloaded world, backed by a fully opaque, overlapping timber palisade.
    # The wall collision is a compact solid strip, not hundreds of physics bodies.
    MountainValley.build(self,
        _town_textures.get("stone", null) as Texture2D,
        _town_textures.get("wood", null) as Texture2D)
    for side in [-1, 1]:
        _add_blocker(Vector2(float(side) * 26.67, 0.0),
            Vector2(0.64, 49.2), PLAYER_WORLD_RADIUS + 0.025)
        _add_camera_obstacle(Vector3(float(side) * 26.67, 2.05, 0.0),
            Vector3(0.64, 4.10, 49.2))
    _add_blocker(Vector2(0.0, -24.65), Vector2(53.4, 0.64),
        PLAYER_WORLD_RADIUS + 0.025)
    _add_camera_obstacle(Vector3(0.0, 2.05, -24.65),
        Vector3(53.4, 4.10, 0.64))
    for side in [-1, 1]:
        _add_blocker(Vector2(float(side) * 16.55, 24.64),
            Vector2(20.8, 0.64), PLAYER_WORLD_RADIUS + 0.025)
        _add_camera_obstacle(Vector3(float(side) * 16.55, 2.05, 24.64),
            Vector3(20.8, 4.10, 0.64))

    # Keep the exact same physical/camera tower cylinders and 2.30 m radii.
    # Only the finish changes: a single batched staggered ashlar mesh reads
    # as carved defensive stone, not the pebbly ground paving texture.
    for side in [-1, 1]:
        var tower_x := float(side) * 4.1
        var tower := _cylinder(self, "StoneGateTower_%s" % ("Left" if side < 0 else "Right"), 2.30, 5.85,
            Vector3(tower_x, 2.925, 24.6), Color("#424a45"))
        tower.material_override = _mat(Color("#424a45"), 1.0)
        for band_y in [0.46, 4.92, 5.62]:
            var course := _cylinder(self, "StoneGateCourse", 2.32, 0.14,
                Vector3(tower_x, float(band_y), 24.6), Color("#606963"))
            course.material_override = _mat(Color("#606963"), 0.98)
        var wood_texture := _town_textures.get("wood", null) as Texture2D
        var roof := _tapered_cylinder(self, "TimberGateRoof_%s" % ("Left" if side < 0 else "Right"), 2.65, 0.10, 2.05,
            Vector3(tower_x, 6.82, 24.6), Color("#92704e"))
        roof.material_override = MountainValley._log_material(wood_texture, Color("#92704e"))
        for edge in [-1, 1]:
            var pier := _box(self, "GatePierStone", Vector3(0.28, 5.25, 0.30),
                Vector3(tower_x + float(edge) * 1.63, 2.63, 22.99), Color("#696f69"))
            pier.material_override = _mat(Color("#696f69"), 0.98)
        _add_circle_blocker(Vector2(tower_x, 24.6), 2.30,
            PLAYER_WORLD_RADIUS + 0.035)
        _add_camera_cylinder(Vector3(tower_x, 2.925, 24.6), 2.30, 5.85)
    GateAshlar.build(self)
    set_meta("gate_roof_wood_matches_leaves", true)

    # Same textured timber and exact tint as the exterior palisade logs.
    # Cross-bracing uses the same darker palette as its support beams.
    var gate_wood_texture := _town_textures.get("wood", null) as Texture2D
    var palisade_wood := Color("#92704e")
    var palisade_beam := Color("#715238")
    for side in [-1, 1]:
        var half_x := float(side) * 1.125
        var leaf := _box(self, "ClosedWoodGateLeaf_%s" % ("Left" if side < 0 else "Right"), Vector3(2.28, 4.60, 0.42),
            Vector3(half_x, 2.30, 24.62), palisade_wood)
        leaf.material_override = MountainValley._log_material(gate_wood_texture, palisade_wood)
        for groove in range(5):
            var gx := half_x - 0.95 + float(groove) * 0.47
            var plank := _box(self, "ClosedWoodGatePlank", Vector3(0.045, 4.43, 0.055),
                Vector3(gx, 2.32, 24.37), palisade_beam)
            plank.material_override = MountainValley._log_material(gate_wood_texture, palisade_beam)
        for bar_y in [1.05, 3.35]:
            var strap := _box(self, "ClosedWoodGateIronStrap", Vector3(2.33, 0.16, 0.10),
                Vector3(half_x, float(bar_y), 24.34), Color("#363a3a"))
            strap.material_override = _mat(Color("#363a3a"), 0.68, 0.32)
        var brace := _box(self, "GateDiagonalBrace", Vector3(0.23, 3.55, 0.13),
            Vector3(half_x, 2.35, 24.30), palisade_beam,
            Vector3(0, 0, 24.0 * float(side)))
        brace.material_override = MountainValley._log_material(gate_wood_texture, palisade_beam)
        for hinge_y in [1.10, 3.36]:
            _cylinder(self, "GateIronHinge", 0.095, 0.12,
                Vector3(half_x + float(side) * 0.89, float(hinge_y), 24.26),
                Color("#313332"))
    var join := _box(self, "GateCentralJoin", Vector3(0.18, 4.76, 0.48),
        Vector3(0.0, 2.38, 24.59), palisade_beam)
    join.material_override = MountainValley._log_material(gate_wood_texture, palisade_beam)
    var lintel := _box(self, "GatehouseHeavyLintel", Vector3(10.9, 0.95, 1.65),
        Vector3(0.0, 5.20, 24.68), palisade_wood)
    lintel.material_override = MountainValley._log_material(gate_wood_texture, palisade_wood)
    var gate_sign := _box(self, "GatehouseSign", Vector3(4.20, 0.60, 0.16),
        Vector3(0.0, 5.40, 23.73), palisade_beam)
    gate_sign.material_override = MountainValley._log_material(gate_wood_texture, palisade_beam)
    _add_blocker(Vector2(0.0, 24.64), Vector2(4.55, 0.50),
        PLAYER_WORLD_RADIUS + 0.035)
    _add_camera_obstacle(Vector3(0.0, 2.30, 24.62), Vector3(4.55, 4.60, 0.50))
    set_meta("main_gate_permanently_closed", true)
    set_meta("gate_interaction", "approach_loading_zone")
    set_meta("gate_destination_scene", NEXT_ZONE_SCENE)
    set_meta("gate_destination_label", NEXT_ZONE_NAME)

    # Landmark buildings.
    _add_house(Vector3(-10.5, 0, -7.5), Vector3(7.7, 3.8, 6.3), Color("#d4c29e"), Color("#704039"), "ADVENTURERS GUILD")
    _add_house(Vector3(10.3, 0, -7.0), Vector3(7.0, 3.5, 6.0), Color("#d5b486"), Color("#60352f"), "THE INN")
    _add_house(Vector3(-11.0, 0, 7.8), Vector3(6.2, 3.2, 5.2), Color("#c6b38e"), Color("#494746"), "BLACKSMITH")
    _add_house(Vector3(10.6, 0, 7.8), Vector3(5.8, 3.1, 5.1), Color("#d2c092"), Color("#674638"), "GENERAL SHOP")

    # Residential ring.
    _add_house(Vector3(-20.0, 0, -15.7), Vector3(4.8, 2.9, 4.6), Color("#d7c7aa"), Color("#694a41"))
    _add_house(Vector3(19.8, 0, -15.0), Vector3(5.0, 3.0, 4.4), Color("#cbb99b"), Color("#624139"))
    _add_house(Vector3(-20.1, 0, 16.4), Vector3(4.7, 2.8, 4.2), Color("#d3c19e"), Color("#6b4a42"))
    _add_house(Vector3(19.8, 0, 16.2), Vector3(5.2, 3.0, 4.5), Color("#d1be9b"), Color("#603d36"))
    _add_house(Vector3(-10.0, 0, 17.0), Vector3(4.7, 2.8, 4.3), Color("#d8c6a4"), Color("#62443b"))
    _add_house(Vector3(10.0, 0, 17.2), Vector3(4.8, 2.9, 4.2), Color("#d2bc92"), Color("#684438"))

    # Unified medieval paving uses one continuous cobblestone material and a
    # shallow dirt verge. All ten doors receive a connected walking path.
    _road_regions = RoadNetwork.plan(_road_door_anchors)
    var cobble_material := _town_mat("EntryRoad", Color("#aaa397"), 0.99, Vector3.ONE)
    var verge_material := _town_mat("EntryShoulderL", Color("#75563b"), 1.0, Vector3.ONE)
    RoadNetwork.build(self, _road_regions, cobble_material, verge_material)

    # Restore an authentic fountain focal point while the ring around the
    # marketplace stays walkable; original model is supplied by the user.
    _add_town_fountain()

    # Market and props. Vendor fronts/backs are reserved: no benches, lamps, or
    # loose storage are placed inside the stall working/customer zones.
    # Four matching backed-awning stalls, rotated 180 degrees from v0.2Z
    # so the open service fronts face the market circuit's central clearing.
    _add_market_stall(Vector3(-5.4, 0, -6.1), Color("#9d4540"), 45.0)
    _add_market_stall(Vector3(5.4, 0, -6.1), Color("#416791"), -45.0)
    _add_market_stall(Vector3(-5.4, 0, 2.45), Color("#638457"), 135.0)
    _add_market_stall(Vector3(5.4, 0, 2.45), Color("#bf9654"), -135.0)

    # Storage props sit beside buildings with explicit clearance from foundations.
    # Blacksmith barrels are on the west service side; shop barrel is east of the shop.
    _add_barrel(Vector3(-15.75,0,7.35))
    _add_barrel(Vector3(-15.75,0,8.25))
    _add_barrel(Vector3(15.20,0,8.10))

    # Phone-test feedback: isolated new supply crates sat in thick grass.
    # Retire these loose props until Pass 4.3 provides proper loading docks
    # or wagon storage; existing barrels and house landscaping stay untouched.

    # Alternate broadleaf/mossy deciduous trees with taller, dark evergreens.
    # Extra pines along the wall bring scale variation and a valley silhouette.
    var tree_index := 0
    for tree_pos in [
        Vector3(-23,0,-6), Vector3(23,0,-5), Vector3(-22,0,5), Vector3(22,0,4),
        Vector3(-16,0,-21), Vector3(16,0,-21), Vector3(-5,0,-20), Vector3(6,0,-20),
        Vector3(-24,0,21), Vector3(24,0,21)
    ]:
        var canopy_scale := 1.08 if tree_index % 3 == 1 else (0.95 if tree_index % 3 == 0 else 0.86)
        _add_tree(tree_pos, canopy_scale, tree_index)
        tree_index += 1
    var shrub_index := 0
    for shrub_pos in [
        Vector3(-15,0,-11), Vector3(-6,0,-11), Vector3(6,0,-11), Vector3(15,0,-11),
        Vector3(-15,0,11), Vector3(-7,0,11), Vector3(7,0,11), Vector3(15,0,11),
        Vector3(-19,0,-17), Vector3(19,0,-17), Vector3(-18,0,16),
        Vector3(18,0,16), Vector3(-22,0,1), Vector3(22,0,-1)
    ]:
        _add_shrub(shrub_pos, 0.9, shrub_index)
        shrub_index += 1

    # Dense grass is placed after all solid scenery to avoid doorways and paths.

    # Broader but deliberately irregular wildflower pockets among the grass
    # near houses, tree edges and the palisade. Each checks its entire 0.9 m
    # footprint against road surface, walls and shrub beds before placement.
    for flower_info in [
        [Vector3(-14.3,0,-10.9), Color("#c996ac")],
        [Vector3(-7.0,0,-11.1), Color("#c6b68c")],
        [Vector3(7.3,0,-11.0), Color("#aaa8c3")],
        [Vector3(14.2,0,-10.8), Color("#c996ac")],
        [Vector3(-14.0,0,11.0), Color("#bbb0c3")],
        [Vector3(13.8,0,11.1), Color("#c6b68c")],
        [Vector3(-20.5,0,-12.5), Color("#bbb0c3")],
        [Vector3(20.5,0,-11.9), Color("#c6b68c")],
        [Vector3(-21.0,0,12.8), Color("#c996ac")],
        [Vector3(21.2,0,13.4), Color("#aaa8c3")],
        [Vector3(-17.8,0,2.9), Color("#c6b68c")],
        [Vector3(17.7,0,3.5), Color("#c996ac")],
        [Vector3(-12.4,0,-17.5), Color("#aaa8c3")],
        [Vector3(12.5,0,-17.3), Color("#c6b68c")],
        [Vector3(-20.8,0,18.8), Color("#c996ac")],
        [Vector3(20.0,0,19.1), Color("#bbb0c3")],
        [Vector3(-8.6,0,16.1), Color("#c6b68c")],
        [Vector3(9.2,0,16.3), Color("#aaa8c3")],
    ]:
        _add_flower_patch(flower_info[0] as Vector3, flower_info[1] as Color)

    for rock_pos in [
        Vector3(-24.0,0,-14.0), Vector3(24.1,0,-14.3),
        Vector3(-24.2,0,15.0), Vector3(24.0,0,15.2),
        Vector3(-18.5,0,-22.2), Vector3(18.7,0,-22.0)
    ]:
        _add_rock(rock_pos, 0.85)

    # Keep only the two plaza benches on paving. The two near the town
    # entrance sat on lawn/road edges and did not belong in this layout.
    _add_bench(Vector3(-3.9,0,-8.9), 0)
    _add_bench(Vector3(3.9,0,-8.9), 0)

    # Lamps sit on clear road/square edges, outside all building and stall footprints.
    _add_lamp(Vector3(-4.70,0,-10.25))
    _add_lamp(Vector3(4.70,0,-10.25))
    _add_lamp(Vector3(-8.1,0,2.1))
    _add_lamp(Vector3(8.1,0,2.1))

    # Coverage is split into small instanced chunks for mobile frustum culling.
    GrassField.populate(self, Callable(self, "_grass_point_blocked"), Callable(self, "_ground_surface_y"))
    _cache_graphics_lod_batches()
    set_meta("nature_pack_loaded", NatureReplacement.available("Pine_1") and
        NatureReplacement.available("Bush_Common") and NatureReplacement.available("Grass_Common_Short"))

func _round_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    var header := ColorRect.new()
    header.position = Vector2(14, 12)
    header.size = Vector2(1010, 124)
    header.color = Color(0.035, 0.055, 0.10, 0.88)
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(header)

    _status = Label.new()
    _status.position = Vector2(28, 20)
    _status.size = Vector2(970, 54)
    _status.add_theme_font_size_override("font_size", 24)
    _status.add_theme_color_override("font_color", Color("#f3f6fa"))
    ui.add_child(_status)

    _detail = Label.new()
    _detail.position = Vector2(28, 70)
    _detail.size = Vector2(970, 58)
    _detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detail.add_theme_font_size_override("font_size", 16)
    _detail.add_theme_color_override("font_color", Color("#b8cade"))
    ui.add_child(_detail)

    # Fixed left virtual stick. Touch anywhere in this zone and drag.
    _joystick_base = Panel.new()
    _joystick_base.name = "MoveStick"
    _joystick_base.anchor_left = 0.0
    _joystick_base.anchor_right = 0.0
    _joystick_base.anchor_top = 1.0
    _joystick_base.anchor_bottom = 1.0
    _joystick_base.offset_left = 38.0
    _joystick_base.offset_right = 206.0
    _joystick_base.offset_top = -210.0
    _joystick_base.offset_bottom = -42.0
    _joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _joystick_base.add_theme_stylebox_override("panel", _round_style(Color(0.12, 0.17, 0.24, 0.70), 84))
    ui.add_child(_joystick_base)

    _joystick_knob = Panel.new()
    _joystick_knob.size = Vector2(70, 70)
    _joystick_knob.position = (_joystick_base.size - _joystick_knob.size) * 0.5
    _joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _joystick_knob.add_theme_stylebox_override("panel", _round_style(Color(0.62, 0.73, 0.84, 0.88), 35))
    _joystick_base.add_child(_joystick_knob)

    _sprint_button = Button.new()
    _sprint_button.text = "SPRINT OFF"
    _sprint_button.anchor_left = 1.0
    _sprint_button.anchor_right = 1.0
    _sprint_button.anchor_top = 1.0
    _sprint_button.anchor_bottom = 1.0
    _sprint_button.offset_left = -202.0
    _sprint_button.offset_right = -34.0
    _sprint_button.offset_top = -142.0
    _sprint_button.offset_bottom = -48.0
    _sprint_button.add_theme_font_size_override("font_size", 21)
    # Handle taps ourselves so the second finger is recognized while the
    # first finger is holding the joystick. Regular Godot GUI buttons rely on
    # the single emulated mouse pointer on many Android devices.
    _sprint_button.toggle_mode = true
    _sprint_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sprint_button.focus_mode = Control.FOCUS_NONE
    ui.add_child(_sprint_button)

    # Compare all three authored idle clips without another rebuild.
    _pose_button = Button.new()
    _pose_button.text = "POSE: RELAX"
    _pose_button.anchor_left = 1.0
    _pose_button.anchor_right = 1.0
    _pose_button.anchor_top = 1.0
    _pose_button.anchor_bottom = 1.0
    _pose_button.offset_left = -226.0
    _pose_button.offset_right = -34.0
    _pose_button.offset_top = -215.0
    _pose_button.offset_bottom = -150.0
    _pose_button.add_theme_font_size_override("font_size", 17)
    _pose_button.pressed.connect(_cycle_idle_pose)
    ui.add_child(_pose_button)

    _character_button = Button.new()
    _character_button.text = "CHARACTER: MALE"
    _character_button.anchor_left = 1.0
    _character_button.anchor_right = 1.0
    _character_button.anchor_top = 1.0
    _character_button.anchor_bottom = 1.0
    _character_button.offset_left = -226.0
    _character_button.offset_right = -34.0
    _character_button.offset_top = -285.0
    _character_button.offset_bottom = -222.0
    _character_button.add_theme_font_size_override("font_size", 16)
    _character_button.pressed.connect(_switch_character)
    ui.add_child(_character_button)

    var pause_button := Button.new()
    pause_button.text = "PAUSE"
    pause_button.anchor_left = 1.0
    pause_button.anchor_right = 1.0
    pause_button.offset_left = -202.0
    pause_button.offset_right = -92.0
    pause_button.offset_top = 18.0
    pause_button.offset_bottom = 70.0
    pause_button.pressed.connect(_toggle_pause)
    ui.add_child(pause_button)

    var reset_button := Button.new()
    reset_button.text = "RESET CAM"
    reset_button.anchor_left = 1.0
    reset_button.anchor_right = 1.0
    reset_button.offset_left = -326.0
    reset_button.offset_right = -210.0
    reset_button.offset_top = 18.0
    reset_button.offset_bottom = 70.0
    reset_button.pressed.connect(_reset_camera)
    ui.add_child(reset_button)

    # Quick thumb-friendly graphics setting. The button is handled from
    # _input like sprint, so it works with a second finger on Android.
    _graphics_button = Button.new()
    _graphics_button.name = "GraphicsQualityButton"
    _graphics_button.text = "GRAPHICS: BALANCED"
    _graphics_button.anchor_left = 1.0
    _graphics_button.anchor_right = 1.0
    _graphics_button.offset_left = -554.0
    _graphics_button.offset_right = -337.0
    _graphics_button.offset_top = 18.0
    _graphics_button.offset_bottom = 70.0
    _graphics_button.add_theme_font_size_override("font_size", 16)
    _graphics_button.focus_mode = Control.FOCUS_NONE
    _graphics_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(_graphics_button)

    _graphics_fps = Label.new()
    _graphics_fps.name = "GraphicsFpsLabel"
    _graphics_fps.anchor_left = 1.0
    _graphics_fps.anchor_right = 1.0
    _graphics_fps.offset_left = -551.0
    _graphics_fps.offset_right = -337.0
    _graphics_fps.offset_top = 75.0
    _graphics_fps.offset_bottom = 99.0
    _graphics_fps.add_theme_font_size_override("font_size", 13)
    _graphics_fps.add_theme_color_override("font_color", Color("#dde7db"))
    _graphics_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _graphics_fps.tooltip_text = "Tap FPS readout to show/hide renderer diagnostics"
    ui.add_child(_graphics_fps)

    # Optional, read-only GPU/CPU diagnostics. Hidden by default so the
    # normal gameplay view and the existing one-handed UI stay unchanged.
    _performance_panel = Panel.new()
    _performance_panel.name = "PerformanceStatsPanel"
    _performance_panel.anchor_left = 1.0
    _performance_panel.anchor_right = 1.0
    _performance_panel.offset_left = -556.0
    _performance_panel.offset_right = -322.0
    _performance_panel.offset_top = 103.0
    _performance_panel.offset_bottom = 169.0
    _performance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.025, 0.040, 0.052, 0.80)
    background.set_corner_radius_all(4)
    _performance_panel.add_theme_stylebox_override("panel", background)
    ui.add_child(_performance_panel)
    _performance_details = Label.new()
    _performance_details.name = "PerformanceStatsText"
    _performance_details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _performance_details.offset_left = 9.0
    _performance_details.offset_right = -5.0
    _performance_details.offset_top = 3.0
    _performance_details.add_theme_font_size_override("font_size", 12)
    _performance_details.add_theme_color_override("font_color", Color("#cce4d8"))
    _performance_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _performance_panel.add_child(_performance_details)
    _performance_panel.visible = false
    set_meta("performance_monitor_enabled", false)


func _cache_graphics_lod_batches() -> void:
    _graphics_lod_batches.clear()
    for child in get_children():
        if not (child is MultiMeshInstance3D):
            continue
        var render := child as MultiMeshInstance3D
        if not (render.name.begins_with("GrassField_") or render.name.begins_with("MeadowAccent_")):
            continue
        if render.multimesh == null:
            continue
        _graphics_lod_batches.append({
            "node": render,
            "full_count": render.multimesh.instance_count,
            "center": render.get_meta("meadow_center", render.position + Vector3(4.0, 0.0, 4.0))
        })
    set_meta("graphics_cached_meadow_batches", _graphics_lod_batches.size())


func _set_graphics_preset(preset: String, persist: bool = true) -> void:
    if not GraphicsQuality.valid(preset):
        return
    _graphics_preset = preset
    GraphicsQuality.apply(preset, get_viewport(), _sun_light)
    if _graphics_button != null:
        _graphics_button.text = "GRAPHICS: " + preset
    set_meta("graphics_preset", preset)
    set_meta("graphics_3d_resolution_scale", GraphicsQuality.resolution_scale(preset))
    set_meta("graphics_shadow_atlas", GraphicsQuality.shadow_atlas_size(preset))
    set_meta("graphics_shadow_filter", int(GraphicsQuality.shadow_filter_quality(preset)))
    if persist:
        GraphicsQuality.save(preset)
    _update_graphics_lod()


func _cycle_graphics_preset() -> void:
    match _graphics_preset:
        "BALANCED":
            _set_graphics_preset("PERFORMANCE")
        "PERFORMANCE":
            _set_graphics_preset("QUALITY")
        _:
            _set_graphics_preset("BALANCED")


func _update_graphics_lod() -> void:
    if _actor == null:
        return
    _graphics_last_lod = GraphicsQuality.apply_meadow_lod(
        _graphics_lod_batches, _actor.global_position, _graphics_preset)
    set_meta("graphics_meadow_drawn", int(_graphics_last_lod.get("drawn", 0)))
    set_meta("graphics_meadow_total", int(_graphics_last_lod.get("total", 0)))
    if _graphics_fps != null:
        _graphics_fps.text = "FPS: %d  |  3D: %d%%" % [
            Engine.get_frames_per_second(),
            roundi(GraphicsQuality.resolution_scale(_graphics_preset) * 100.0)
        ]
    # Sample only at the existing 0.4-second graphics update interval,
    # and ONLY when the optional panel is open.
    if _performance_stats_visible and _performance_details != null:
        var draw_calls := roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        var objects := roundi(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
        var cpu_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
        var drawn: int = _graphics_last_lod.get("drawn", 0)
        var total: int = _graphics_last_lod.get("total", 0)
        var meadow_pct := roundi(100.0 * float(drawn) / maxf(1.0, float(total)))
        _performance_details.text = "DRAW: %d  |  OBJECTS: %d\nCPU PROCESS: %.1f ms\nMEADOW: %d%% drawn" % [
            draw_calls, objects, cpu_ms, meadow_pct
        ]
        set_meta("performance_draw_calls", draw_calls)
        set_meta("performance_objects", objects)


func _toggle_performance_stats() -> void:
    _performance_stats_visible = not _performance_stats_visible
    if _performance_panel != null:
        _performance_panel.visible = _performance_stats_visible
    set_meta("performance_monitor_enabled", _performance_stats_visible)
    if _performance_stats_visible:
        _update_graphics_lod()


func _set_status(title: String, detail: String) -> void:
    if _status != null:
        _status.text = "AETHERFALL  |  STARTER TOWN PASS 3  |  " + title
    if _detail != null:
        _detail.text = detail

func _fail(message: String) -> void:
    _loaded = false
    _diag_failure("AF-MODEL-399", message)
    push_error("TRIPO_RUNTIME_FAIL: " + message)
    _set_status("LOAD ERROR", message + "\nThe app stays open so the error can be photographed.")

func _active_model_path() -> String:
    return FEMALE_MODEL_PATH if _character_variant == "female" else MALE_MODEL_PATH


func _load_runtime_glb() -> void:
    var model_path := _active_model_path()
    _diag_stage("AF-MODEL-301", "Checking embedded " + _character_variant + " character model.")
    if not FileAccess.file_exists(model_path):
        _fail("Embedded model file is missing: " + model_path)
        return

    _diag_stage("AF-MODEL-302", "Reading bundled seven-clip character bytes.")
    var bytes := FileAccess.get_file_as_bytes(model_path)
    if bytes.is_empty():
        _fail("Embedded GLB could not be read.")
        return

    _diag_stage("AF-MODEL-303", "Parsing character GLB with Godot GLTFDocument.")
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var err := document.append_from_buffer(bytes, "", state)
    if err != OK:
        _fail("Godot GLTFDocument returned error %d while parsing the GLB." % err)
        return

    _diag_stage("AF-MODEL-304", "GLB parsed. Generating character scene.")
    var generated := document.generate_scene(state)
    if generated == null:
        _fail("Godot parsed the GLB but could not generate its scene.")
        return

    _model = generated as Node3D
    if _model == null:
        generated.queue_free()
        _fail("Generated GLB root was not a Node3D.")
        return

    _diag_stage("AF-MODEL-305", "Character scene generated. Attaching model.")
    _model.name = "TripoAdventurer_" + _character_variant
    _actor.add_child(_model)
    # Tripo visual forward is opposite the controller's actor forward.
    # Rotate only the generated model, not gameplay/world motion.
    _model.rotation.y = PI
    _polish_actor_materials(_model)
    _camera_fade_surfaces.clear()
    _camera_fade_alpha = 1.0
    _cache_camera_fade_surfaces(_model)
    _skeleton = _find_skeleton(_model)
    _animation = _find_animation_player(_model)

    _diag_stage("AF-RIG-306", "Searching generated character for skeleton and animations.")
    if _skeleton == null:
        _fail("No Skeleton3D was generated from the GLB.")
        return
    _diag_stage("AF-RIG-307", "Skeleton found. Verifying 65-joint Mixamo rig.")
    if _skeleton.get_bone_count() != 65:
        _fail("Expected 65 Mixamo joints, got %d." % _skeleton.get_bone_count())
        return
    _diag_stage("AF-ANIM-308", "Rig verified. Checking AnimationPlayer.")
    if _animation == null:
        _fail("No AnimationPlayer was generated from the embedded clips.")
        return

    _diag_stage("AF-ANIM-309", "AnimationPlayer found. Verifying Walk and Run clips.")
    var walk_clip := _clip_for("walk")
    var run_clip := _clip_for("run")
    if walk_clip.is_empty() or run_clip.is_empty():
        _fail("Walk/Run clips were not found. Imported: %s" % [str(_animation.get_animation_list())])
        return
    for idle_option in IDLE_OPTIONS:
        if _clip_for(idle_option).is_empty():
            _fail("Missing authored pose %s in: %s" % [idle_option, str(_animation.get_animation_list())])
            return

    _neutral_pose.clear()
    for i in range(_skeleton.get_bone_count()):
        _neutral_pose.append(_skeleton.get_bone_pose(i))

    _hips_index = _find_bone_suffix("hips")
    _spine_index = _find_bone_suffix("spine")
    _spine1_index = _find_bone_suffix("spine1")
    _head_index = _find_bone_suffix("head")
    _left_foot_index = _find_bone_suffix("leftfoot")
    _right_foot_index = _find_bone_suffix("rightfoot")
    _left_toe_index = _find_bone_suffix("lefttoebase")
    _right_toe_index = _find_bone_suffix("righttoebase")
    _left_arm_index = _find_bone_suffix("leftarm")
    _right_arm_index = _find_bone_suffix("rightarm")
    _left_forearm_index = _find_bone_suffix("leftforearm")
    _right_forearm_index = _find_bone_suffix("rightforearm")
    _left_hand_index = _find_bone_suffix("lefthand")
    _right_hand_index = _find_bone_suffix("righthand")
    _left_finger_bones = _collect_finger_bones("lefthand")
    _right_finger_bones = _collect_finger_bones("righthand")
    if _hips_index < 0 or _left_foot_index < 0 or _right_foot_index < 0 or _left_toe_index < 0 or _right_toe_index < 0:
        _fail("Required Mixamo Hips/Foot/ToeBase bones could not be located.")
        return

    _neutral_hips_origin = _skeleton.get_bone_pose(_hips_index).origin
    _neutral_model_position = _model.position
    _diag_stage("AF-PLAYER-320", "Rig ready. Applying " + _idle_label() + " pose and sole grounding.")
    # Advance to the real animation pose BEFORE measuring the shoe sole. Unlike
    # the previous hand-rotated bind pose, this is exactly what the user sees.
    var starting_idle := _selected_idle_clip()
    var initial_anim := _animation.get_animation(starting_idle)
    if initial_anim != null:
        initial_anim.loop_mode = Animation.LOOP_LINEAR
    _animation.play(starting_idle)
    _animation.advance(0.0)
    _align_neutral_feet_to_floor()

    _loaded = true
    _set_motion("IDLE")
    _refresh_character_buttons()
    _set_status("READY", "Male/Female adventurers • Tap CHARACTER to switch • Tap POSE to compare")
    _diag_stage("AF-READY-900", "Starter Town, selected character, rig, animations and controls initialized successfully.")

func _polish_actor_materials(node: Node) -> void:
    # Restrict changes to recognizable hair and garment materials; retain
    # imported textured skin and unknown materials unchanged.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var source := mesh_instance.get_active_material(surface_index)
                if not (source is StandardMaterial3D):
                    continue
                var surface_name := (String(source.resource_name) + " " + mesh_instance.name).to_lower()
                var roughness_target := -1.0
                if surface_name.contains("hair"):
                    roughness_target = 0.67
                elif surface_name.contains("leather") or surface_name.contains("coat") or surface_name.contains("jacket"):
                    roughness_target = 0.74
                elif surface_name.contains("boot"):
                    roughness_target = 0.79
                if roughness_target < 0.0:
                    continue
                var polished := source.duplicate() as StandardMaterial3D
                polished.roughness = lerpf(source.roughness, roughness_target, 0.45)
                mesh_instance.set_surface_override_material(surface_index, polished)
    for child in node.get_children():
        _polish_actor_materials(child)


func _cache_camera_fade_surfaces(node: Node) -> void:
    # The game uses GL Compatibility: GeometryInstance3D.transparency is not
    # supported there, so cache duplicate per-surface StandardMaterial3D
    # overrides and swap them only while the actor needs to fade.
    if node is MeshInstance3D:
        var visual := node as MeshInstance3D
        if visual.mesh != null:
            for surface in range(visual.mesh.get_surface_count()):
                var active := visual.get_active_material(surface)
                if not (active is StandardMaterial3D):
                    continue
                var fade_mat := (active as StandardMaterial3D).duplicate() as StandardMaterial3D
                fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                _camera_fade_surfaces.append({
                    "mesh": visual, "surface": surface,
                    "original_override": visual.get_surface_override_material(surface),
                    "fade_material": fade_mat, "base_color": fade_mat.albedo_color
                })
    for child in node.get_children():
        _cache_camera_fade_surfaces(child)


func _apply_camera_fade(alpha: float) -> void:
    alpha = clampf(alpha, 0.0, 1.0)
    if absf(alpha - _camera_fade_alpha) < 0.0001:
        return
    var was_opaque := _camera_fade_alpha >= 0.995
    var now_opaque := alpha >= 0.995
    for entry in _camera_fade_surfaces:
        var visual := entry["mesh"] as MeshInstance3D
        if not is_instance_valid(visual):
            continue
        var surface: int = entry["surface"]
        if now_opaque:
            if not was_opaque:
                visual.set_surface_override_material(surface, entry["original_override"] as Material)
        else:
            var material := entry["fade_material"] as StandardMaterial3D
            var color: Color = entry["base_color"]
            color.a *= alpha
            material.albedo_color = color
            if was_opaque:
                visual.set_surface_override_material(surface, material)
    _camera_fade_alpha = alpha


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _find_bone_suffix(suffix: String) -> int:
    if _skeleton == null:
        return -1
    var needle := suffix.to_lower()
    for i in range(_skeleton.get_bone_count()):
        if String(_skeleton.get_bone_name(i)).to_lower().ends_with(needle):
            return i
    return -1

func _collect_finger_bones(hand_prefix: String) -> Array[int]:
    var result: Array[int] = []
    if _skeleton == null:
        return result
    var prefix := hand_prefix.to_lower()
    for i in range(_skeleton.get_bone_count()):
        var name := String(_skeleton.get_bone_name(i)).to_lower()
        if not name.contains(prefix):
            continue
        if name.contains("thumb") or name.contains("index") or name.contains("middle") or name.contains("ring") or name.contains("pinky"):
            result.append(i)
    return result

func _clip_for(mode: String) -> String:
    if _animation == null:
        return ""
    var needle := mode.to_lower()
    for entry in _animation.get_animation_list():
        var raw := String(entry)
        var label := raw.to_lower()
        if label == needle or label.ends_with("/" + needle) or label.ends_with("|" + needle) or label.ends_with(":" + needle):
            return raw
    return ""

func _capture_transition_pose() -> void:
    _transition_from.clear()
    if _skeleton == null:
        return
    for i in range(_skeleton.get_bone_count()):
        _transition_from.append(_skeleton.get_bone_pose(i))
    _transition_elapsed = 0.0
    _transitioning = _transition_from.size() == _neutral_pose.size()

func _selected_idle_clip() -> String:
    return _clip_for(String(IDLE_OPTIONS[_idle_option_index]))


func _idle_label() -> String:
    match String(IDLE_OPTIONS[_idle_option_index]):
        "standing_relax":
            return "Standing Relax"
        "idle":
            return "Idle"
        "look_around":
            return "Look Around"
    return "Idle"


func _refresh_character_buttons() -> void:
    if _character_button != null:
        _character_button.text = "CHARACTER: " + _character_variant.to_upper()
    if _pose_button != null:
        _pose_button.text = "POSE: " + _idle_label().to_upper()


func _switch_character() -> void:
    if not _loaded or _paused or _actor == null:
        return
    # Preserve world position/heading but recalibrate Y from new boot soles.
    _loaded = false
    if _animation != null:
        _animation.stop()
    if _model != null:
        _actor.remove_child(_model)
        _model.queue_free()
        _model = null
    _camera_fade_surfaces.clear()
    _camera_fade_alpha = 1.0
    _skeleton = null
    _animation = null
    _neutral_pose.clear()
    _transition_from.clear()
    _transitioning = false
    _move_speed = 0.0
    _move_input = Vector2.ZERO
    _actor.position.y = 0.0

    _character_variant = "female" if _character_variant == "male" else "male"
    _idle_option_index = 1 if _character_variant == "female" else 0
    _refresh_character_buttons()
    _set_status("LOADING", "Loading " + _character_variant + " adventurer")
    _load_runtime_glb()


func _cycle_idle_pose() -> void:
    if not _loaded or _paused:
        return
    _idle_option_index = (_idle_option_index + 1) % IDLE_OPTIONS.size()
    _refresh_character_buttons()
    if _motion == "IDLE":
        # Smooth transition from the current frame into the selected full-body
        # authored pose, preserving the world actor's position and sole offset.
        _set_motion("IDLE")
    else:
        _set_status(_motion, _motion_detail())


func _set_motion(mode: String) -> void:
    if not _loaded or _animation == null:
        _motion = mode
        return

    var clip_name := _selected_idle_clip() if mode == "IDLE" else _clip_for(mode)
    if clip_name.is_empty():
        _fail("Missing animation clip for " + mode)
        return

    _capture_transition_pose()
    _paused = false
    _motion = mode
    var clip := _animation.get_animation(clip_name)
    if clip != null:
        clip.loop_mode = Animation.LOOP_LINEAR

    var speed := 1.0
    if mode == "WALK":
        speed = WALK_SPEED
    elif mode == "RUN":
        speed = RUN_SPEED
    _animation.speed_scale = 1.0
    # Never stop() into a hand-twisted bind pose. All three idle modes are
    # genuine animations driving every joint from the verified model.
    _animation.play(clip_name, 0.0, speed)
    _set_status(mode, _motion_detail())


func _motion_detail() -> String:
    var sprint_state := "SPRINT ON" if _sprint_held else "SPRINT OFF"
    if _boundary_flash > 0.0:
        return "COLLISION • %.2f m/s • %s • solid town geometry" % [_move_speed, sprint_state]
    var clip_label := _idle_label() if _motion == "IDLE" else _motion.capitalize()
    return "%s (authored) • %s • %.2f m/s • %s" % [clip_label, _motion, _move_speed, sprint_state]


func _on_sprint_toggled(enabled: bool) -> void:
    _sprint_held = enabled
    if _sprint_button != null:
        _sprint_button.set_pressed_no_signal(enabled)
        _sprint_button.text = "SPRINT ON" if enabled else "SPRINT OFF"
    if _loaded and not _paused:
        _set_status(_motion, _motion_detail())

func _toggle_pause() -> void:
    if not _loaded:
        return
    _paused = not _paused
    if _paused:
        if _animation != null and _animation.is_playing():
            _animation.pause()
        _set_status("PAUSED", "Movement frozen • Drag right side to inspect • Tap PAUSE to resume")
    else:
        if _motion in ["WALK", "RUN"] and _animation != null:
            _animation.play()
        _set_status(_motion, _motion_detail())

func _reset_camera() -> void:
    _camera_yaw = _actor.rotation.y if _actor != null else 0.0
    _camera_pitch = 0.18
    _camera_distance = 4.0

func _set_joystick_visual(offset: Vector2) -> void:
    if _joystick_base == null or _joystick_knob == null:
        return
    var center := _joystick_base.size * 0.5
    _joystick_knob.position = center + offset - _joystick_knob.size * 0.5

func _update_joystick(screen_position: Vector2) -> void:
    if _joystick_base == null:
        return
    var center := _joystick_base.global_position + _joystick_base.size * 0.5
    var offset := screen_position - center
    if offset.length() > STICK_RADIUS:
        offset = offset.normalized() * STICK_RADIUS
    var normalized := offset / STICK_RADIUS
    if normalized.length() < STICK_DEADZONE:
        normalized = Vector2.ZERO
        offset = Vector2.ZERO
    _move_input = normalized
    _set_joystick_visual(offset)

func _release_joystick() -> void:
    _move_input = Vector2.ZERO
    _move_touch = -1
    _set_joystick_visual(Vector2.ZERO)

func _apply_transition(delta: float) -> void:
    if not _transitioning or _skeleton == null:
        return
    _transition_elapsed += delta
    var t := clampf(_transition_elapsed / MOTION_BLEND_TIME, 0.0, 1.0)
    var smooth_t := t * t * (3.0 - 2.0 * t)
    for i in range(_transition_from.size()):
        var target_pose := _skeleton.get_bone_pose(i)
        _skeleton.set_bone_pose(i, _transition_from[i].interpolate_with(target_pose, smooth_t))
    if t >= 1.0:
        _transitioning = false
        _transition_from.clear()

func _lock_root_motion() -> void:
    if not _loaded or _skeleton == null or _hips_index < 0:
        return
    # Keep vertical bob from the native clip but remove horizontal travel.
    var hips_pose := _skeleton.get_bone_pose(_hips_index)
    hips_pose.origin.x = _neutral_hips_origin.x
    hips_pose.origin.z = _neutral_hips_origin.z
    _skeleton.set_bone_pose(_hips_index, hips_pose)
    if _model != null:
        var model_pos := _model.position
        model_pos.x = _neutral_model_position.x
        model_pos.z = _neutral_model_position.z
        _model.position = model_pos

func _bone_world_y(index: int) -> float:
    if _skeleton == null or index < 0:
        return 999.0
    return _skeleton.to_global(_skeleton.get_bone_global_pose(index).origin).y

func _sole_floor_y() -> float:
    if _skeleton == null:
        return 0.0
    var scale_y := absf(_actor.scale.y)
    var foot_offset := FOOT_TO_SOLE_SOURCE_Y * scale_y
    var toe_offset := TOE_TO_SOLE_SOURCE_Y * scale_y
    # Use both ankle/foot and toe origins. During a stride either the heel or
    # the toe may be the lowest planted part of the boot.
    var left_sole := minf(_bone_world_y(_left_foot_index) - foot_offset,
                          _bone_world_y(_left_toe_index) - toe_offset)
    var right_sole := minf(_bone_world_y(_right_foot_index) - foot_offset,
                           _bone_world_y(_right_toe_index) - toe_offset)
    return minf(left_sole, right_sole)

func _build_ground_contact_shadow() -> void:
    # Tiny procedurally generated alpha texture creates soft boot contact on
    # Android without screen-space effects or an extra shadow-casting light.
    var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var p := Vector2((float(x) + 0.5) / 32.0 - 1.0, (float(y) + 0.5) / 32.0 - 1.0)
            var falloff := pow(clampf(1.0 - p.length_squared(), 0.0, 1.0), 2.2)
            image.set_pixel(x, y, Color(0.035, 0.044, 0.054, falloff * 0.23))
    var shadow_material := StandardMaterial3D.new()
    shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    shadow_material.albedo_texture = ImageTexture.create_from_image(image)
    _ground_contact_shadow = MeshInstance3D.new()
    _ground_contact_shadow.name = "SoftBootContactShadow"
    var plane := PlaneMesh.new()
    plane.size = Vector2(1.24, 0.96)
    _ground_contact_shadow.mesh = plane
    _ground_contact_shadow.material_override = shadow_material
    _ground_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _ground_contact_shadow.visible = false
    add_child(_ground_contact_shadow)


func _update_ground_contact_shadow() -> void:
    if _ground_contact_shadow == null or _actor == null:
        return
    _ground_contact_shadow.visible = _loaded
    if not _loaded:
        return
    var surface_y := _ground_surface_y(_actor.global_position)
    _ground_contact_shadow.global_position = Vector3(_actor.global_position.x, surface_y + 0.018, _actor.global_position.z)
    _ground_contact_shadow.rotation.y = _actor.rotation.y


func _ground_surface_y(world_position: Vector3) -> float:
    # No height mismatch between the player's soles and the visible paving:
    # road regions, market square and door approaches all share one level.
    # Stairs are intentionally absent until separate building interiors exist.
    return RoadNetwork.surface_height(
        Vector2(world_position.x, world_position.z), _road_regions
    )

func _align_neutral_feet_to_floor() -> void:
    var surface_y := _ground_surface_y(_actor.global_position)
    var sole_y := _sole_floor_y()
    _actor.position.y += surface_y + SOLE_CLEARANCE_WORLD - sole_y
    # Store the rig's calibrated actor offset relative to a zero-height lawn,
    # then add the current surface height dynamically during movement.
    _base_actor_y = _actor.position.y - surface_y

func _correct_foot_ground(delta: float) -> void:
    if not _loaded or _paused:
        return
    var surface_y := _ground_surface_y(_actor.global_position)
    var target_sole_y := surface_y + SOLE_CLEARANCE_WORLD
    var base_on_surface := _base_actor_y + surface_y
    var sole_y := _sole_floor_y()
    var desired_y := _actor.position.y
    if sole_y < target_sole_y:
        # Only lift enough to solve penetration into the current walk surface.
        desired_y += target_sole_y - sole_y
    else:
        # Ease back toward the calibrated standing height for this surface.
        desired_y = lerpf(desired_y, base_on_surface, clampf(delta * 3.4, 0.0, 1.0))
    desired_y = clampf(desired_y, base_on_surface, base_on_surface + 0.16)
    _actor.position.y = lerpf(_actor.position.y, desired_y, clampf(delta * 16.0, 0.0, 1.0))

func _desired_input() -> Vector2:
    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        keyboard.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        keyboard.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        keyboard.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        keyboard.y += 1.0
    if keyboard.length() > 0.01:
        return keyboard.normalized()
    return _move_input

func _ensure_motion(mode: String) -> void:
    if mode != _motion:
        _set_motion(mode)

func _world_point_blocked(point: Vector2) -> bool:
    for blocker in _world_blockers:
        if blocker.has_point(point):
            return true
    for house in _house_blockers:
        var center: Vector2 = house["center"]
        var half: Vector2 = house["half"]
        var local := point - center
        if absf(local.x) <= half.x and absf(local.y) <= half.y:
            if not bool(house["asset"]):
                var door_stop: float = house["door_stop_z"]
                var door_half: float = house["door_half_width"]
                if absf(local.x) <= door_half and local.y > door_stop:
                    continue
            return true
    for circle in _circle_blockers:
        var center := Vector2(circle.x, circle.y)
        if point.distance_to(center) < circle.z:
            return true
    for obstacle in _oriented_blockers:
        var delta: Vector2 = point - (obstacle["center"] as Vector2)
        var theta: float = float(obstacle["yaw"])
        var local := Vector2(
            cos(theta) * delta.x - sin(theta) * delta.y,
            sin(theta) * delta.x + cos(theta) * delta.y
        )
        var half: Vector2 = obstacle["half"]
        if absf(local.x) <= half.x and absf(local.y) <= half.y:
            return true
    return false

func _resolve_world_position(previous: Vector3) -> void:
    if _actor == null:
        return
    var requested := _actor.position
    var clamped_x := clampf(requested.x, TOWN_MIN_X + PLAYER_WORLD_RADIUS, TOWN_MAX_X - PLAYER_WORLD_RADIUS)
    var clamped_z := clampf(requested.z, TOWN_MIN_Z + PLAYER_WORLD_RADIUS, TOWN_MAX_Z - PLAYER_WORLD_RADIUS)
    var resolved := previous

    # Resolve one axis at a time so the player slides naturally along walls/buildings
    # instead of sticking or teleporting backward when moving diagonally into them.
    var x_test := Vector2(clamped_x, previous.z)
    if not _world_point_blocked(x_test):
        resolved.x = clamped_x
    var z_test := Vector2(resolved.x, clamped_z)
    if not _world_point_blocked(z_test):
        resolved.z = clamped_z

    _actor.position.x = resolved.x
    _actor.position.z = resolved.z
    var hit := absf(requested.x - resolved.x) > 0.001 or absf(requested.z - resolved.z) > 0.001
    if hit:
        _boundary_flash = 0.26
        _move_speed = minf(_move_speed, WALK_WORLD_SPEED * 0.72)

func _update_gameplay_movement(delta: float) -> void:
    if _actor == null or not _loaded or _paused:
        return
    var input_vec := _desired_input()
    var strength := clampf(input_vec.length(), 0.0, 1.0)
    var moving := strength > STICK_DEADZONE
    var wants_run := _sprint_held or Input.is_key_pressed(KEY_SHIFT)
    var target_speed := 0.0
    if moving:
        target_speed = (RUN_WORLD_SPEED if wants_run else WALK_WORLD_SPEED) * strength
    var rate := MOVE_ACCEL if target_speed > _move_speed else MOVE_DECEL
    _move_speed = move_toward(_move_speed, target_speed, rate * delta)

    if moving:
        # Stick up is -Z. Rotate that vector by the camera heading so movement
        # always feels camera-relative, like the final third-person game.
        var local_dir := Vector3(input_vec.x, 0.0, input_vec.y).normalized()
        _travel_direction = (Basis(Vector3.UP, _camera_yaw) * local_dir).normalized()
        var target_yaw := atan2(-_travel_direction.x, -_travel_direction.z)
        _actor.rotation.y = lerp_angle(_actor.rotation.y, target_yaw, clampf(delta * TURN_RATE, 0.0, 1.0))

    if _move_speed > 0.04:
        var previous_position := _actor.position
        _actor.position += _travel_direction * _move_speed * delta
        _resolve_world_position(previous_position)

    var desired_motion := "IDLE"
    if _move_speed > 0.12:
        desired_motion = "RUN" if wants_run and _move_speed > WALK_WORLD_SPEED * 0.85 else "WALK"
    _ensure_motion(desired_motion)

    # Match cadence to actual travel during acceleration/deceleration to reduce
    # visible foot sliding before we introduce full AnimationTree locomotion.
    if _animation != null and _motion == "WALK":
        _animation.speed_scale = clampf(_move_speed / WALK_WORLD_SPEED, 0.72, 1.05)
    elif _animation != null and _motion == "RUN":
        _animation.speed_scale = clampf(_move_speed / RUN_WORLD_SPEED, 0.82, 1.08)
    elif _animation != null:
        _animation.speed_scale = 1.0

func _update_gate_zone() -> void:
    if _zone_transfer == null or _actor == null or not _loaded or _paused:
        return
    var near_gate := absf(_actor.position.x) <= 1.35 and _actor.position.z >= 22.45
    if near_gate and not _gate_zone_latched:
        _gate_zone_latched = true
        # The gate never opens. A completed destination is loaded as a separate
        # Godot scene; while missing it shows an honest availability message.
        var carried := {
            "character_variant": _character_variant,
            "inventory": {},
            "equipment": {},
            "quest_progress": {},
            "origin_zone": "starter_town"
        }
        _zone_transfer.call("attempt_transfer", NEXT_ZONE_SCENE,
            NEXT_ZONE_NAME, carried, "valley_entrance")
    elif not near_gate and _gate_zone_latched:
        _gate_zone_latched = false
        _zone_transfer.call("clear_hint")

func _process(delta: float) -> void:
    if not _startup_complete and not _startup_failed:
        _startup_elapsed += delta
        if _startup_elapsed >= STARTUP_WATCHDOG_SECONDS:
            _diag_failure("AF-WATCH-500", "Startup stopped before READY. Last stage: " + _diag_code + " - " + _diag_detail_text)
    _boundary_flash = maxf(0.0, _boundary_flash - delta)
    _update_gameplay_movement(delta)
    _update_gate_zone()
    if _loaded and not _paused:
        _apply_transition(delta)
        _lock_root_motion()
        _correct_foot_ground(delta)
    _update_ground_contact_shadow()
    _update_camera(delta)
    _graphics_lod_accum += delta
    if _graphics_lod_accum >= 0.40:
        _graphics_lod_accum = 0.0
        _update_graphics_lod()
    if _loaded and not _paused:
        _set_status(_motion, _motion_detail())

func _update_camera(delta: float) -> void:
    if _camera == null or _actor == null:
        return
    var horizontal := cos(_camera_pitch) * _camera_distance
    var vertical := sin(_camera_pitch) * _camera_distance
    var target := _actor.global_position + Vector3(0.0, 1.03, 0.0)
    # At yaw zero the camera is +Z, behind a model whose forward is -Z.
    var offset := Vector3(sin(_camera_yaw) * horizontal, 0.55 + vertical, cos(_camera_yaw) * horizontal)
    var goal := _camera_safe_goal(target, target + offset)
    if delta >= 1.0:
        _camera.global_position = goal
    else:
        # Pull inward promptly when blocked and glide back outward gradually.
        var closing := goal.distance_to(target) < _camera.global_position.distance_to(target)
        var follow_speed := 18.0 if closing else 6.0
        var smoothed := _camera.global_position.lerp(goal, clampf(delta * follow_speed, 0.0, 1.0))
        _camera.global_position = _camera_safe_goal(target, smoothed)
    _camera.look_at(target, Vector3.UP)
    # Never show the camera inside clothing. Fade immediately when obstructed,
    # then restore the normal opaque model smoothly once the view is clear.
    var visible_alpha := smoothstep(CAMERA_FADE_FULL, CAMERA_FADE_START, _camera.global_position.distance_to(target))
    if visible_alpha < _camera_fade_alpha:
        _apply_camera_fade(visible_alpha)
    else:
        _apply_camera_fade(move_toward(_camera_fade_alpha, visible_alpha, delta * CAMERA_FADE_RETURN_SPEED))

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        # Ignore synthetic touch events generated by desktop mouse input.
        # Native Android touch indexes remain distinct for each finger.
        if event.device == InputEvent.DEVICE_ID_EMULATION:
            return
        var view := get_viewport().get_visible_rect().size
        if event.pressed:
            # Sprint responds immediately on touch-down, including while
            # another touch owns the joystick or camera. It stays latched
            # after that finger lifts until the next separate tap.
            if _sprint_button != null and _sprint_button.get_global_rect().has_point(event.position):
                _on_sprint_toggled(not _sprint_held)
                return
            if _graphics_button != null and _graphics_button.get_global_rect().has_point(event.position):
                _cycle_graphics_preset()
                return
            if _graphics_fps != null and _graphics_fps.get_global_rect().has_point(event.position):
                _toggle_performance_stats()
                return
            if event.position.x < view.x * 0.43 and event.position.y > view.y * 0.42 and _move_touch < 0:
                _move_touch = event.index
                _update_joystick(event.position)
            elif event.position.x > view.x * 0.42 and _camera_touch < 0:
                _camera_touch = event.index
        else:
            if event.index == _move_touch:
                _release_joystick()
            if event.index == _camera_touch:
                _camera_touch = -1
    elif event is InputEventScreenDrag:
        if event.index == _move_touch:
            _update_joystick(event.position)
        elif event.index == _camera_touch:
            _camera_yaw -= event.relative.x * 0.0045
            _camera_pitch = clampf(_camera_pitch + event.relative.y * 0.0023, -0.08, 0.56)
    elif event is InputEventMouseButton:
        if event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            if _sprint_button != null and _sprint_button.get_global_rect().has_point(event.position):
                _on_sprint_toggled(not _sprint_held)
                return
            if _graphics_button != null and _graphics_button.get_global_rect().has_point(event.position):
                _cycle_graphics_preset()
                return
            if _graphics_fps != null and _graphics_fps.get_global_rect().has_point(event.position):
                _toggle_performance_stats()
                return
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _drag_mouse = event.pressed
    elif event is InputEventMouseMotion and _drag_mouse:
        _camera_yaw -= event.relative.x * 0.0045
        _camera_pitch = clampf(_camera_pitch + event.relative.y * 0.0023, -0.08, 0.56)
