extends Node3D
## Aetherfall Avatar Studio: one 65-bone skeleton, interchangeable skinned equipment.
## Gameplay-adapted from the recovered v0.6.5 source: retains meshes, weights,
## apparel toggles, appearance colors and profile serialization.

const MODELS := {
    "male": "res://assets/male_modular.bin",
    "female": "res://assets/female_modular.bin"
}
const HAIR := {
    "male": ["Hair_Buzzed", "Hair_SimpleParted", "Hair_Long", "Hair_Buns"],
    "female": ["Hair_Buns", "Hair_Long", "Hair_BuzzedFemale", "Hair_Buzzed", "Hair_SimpleParted"]
}
const SLOTS := ["arms", "body", "legs", "feet"]
const HAIR_DISPLAY := {"Hair_Buzzed": "Buzz Cut", "Hair_SimpleParted": "Side Part", "Hair_Long": "Long", "Hair_Buns": "Twin Buns", "Hair_BuzzedFemale": "Short Crop"}
# These are safe, reversible character-studio appearance adjustments.
# The original Quaternius mesh has no facial morph targets.
const SKIN_NAMES := ["Porcelain", "Fair", "Warm", "Olive", "Tan", "Deep", "Umber"]
const SKIN_TINTS := [
    Color(1.29, 1.22, 1.19), Color(1.19, 1.13, 1.08),
    Color(1.08, 1.04, 0.96), Color(0.94, 0.99, 0.79),
    Color(0.92, 0.80, 0.68), Color(0.70, 0.55, 0.46),
    Color(0.51, 0.39, 0.33)
]
const HAIR_NAMES := ["Ash", "Chestnut", "Raven", "Honey", "Copper", "Silver", "Blue", "Rose"]
const HAIR_TINTS := [
    Color(0.92, 0.86, 0.78), Color(0.56, 0.33, 0.19),
    Color(0.20, 0.19, 0.24), Color(1.16, 0.92, 0.43),
    Color(1.04, 0.43, 0.24), Color(1.17, 1.16, 1.26),
    Color(0.36, 0.55, 1.12), Color(1.12, 0.49, 0.70)
]
const EYE_NAMES := ["Brown", "Blue", "Green", "Hazel", "Gray", "Violet"]
const EYE_STYLES := ["Natural", "Soft", "Defined"]
const HEIGHT_MIN := 0.85
const HEIGHT_MAX := 1.15


var gender: String = "male"
var neck_fit: String = "refined"
var outfit: String = "Ranger"
var hair_index: int = 1
var beard_enabled: bool = false
var hood_enabled: bool = false
var shoulders_enabled: bool = true
var slot_styles := {"arms": "Ranger", "body": "Ranger", "legs": "Ranger", "feet": "Ranger"}
var last_error: String = ""
var error_code: String = ""
var is_ready: bool = false
var skin_index: int = 2
var hair_color_index: int = 1
var eye_color_index: int = 0
var eye_style_index: int = 0
var height_multiplier: float = 1.0
var appearance_surfaces: Array[Dictionary] = []
var eye_texture_cache: Dictionary = {}

var loaded_root: Node3D
var active_skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []

func load_selected_gender() -> bool:
    is_ready = false
    last_error = ""
    error_code = ""
    if loaded_root != null:
        remove_child(loaded_root)
        loaded_root.queue_free()
        loaded_root = null
    active_skeleton = null
    meshes.clear()
    appearance_surfaces.clear()

    var path: String = "res://assets/male_refined.bin" if gender == "male" and neck_fit == "refined" else str(MODELS.get(gender, ""))
    if path.is_empty() or not FileAccess.file_exists(path):
        return _fail("AF-STUDIO-101", "Character model was not included in APK: " + path)
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return _fail("AF-STUDIO-102", "Unable to read character model bytes")
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var result := document.append_from_buffer(bytes, "", state)
    if result != OK:
        return _fail("AF-STUDIO-103", "Godot failed to parse character GLB, code " + str(result))
    var generated := document.generate_scene(state) as Node3D
    if generated == null:
        return _fail("AF-STUDIO-104", "Character scene generation failed")
    loaded_root = generated
    loaded_root.name = "Avatar_" + gender
    # Quaternius faces +Z in bind pose, directly toward the studio camera.
    loaded_root.rotation.y = 0.0
    add_child(loaded_root)
    _collect(loaded_root)
    if active_skeleton == null:
        return _fail("AF-STUDIO-105", "No Skeleton3D generated from character pack")
    if active_skeleton.get_bone_count() != 65:
        return _fail("AF-STUDIO-106", "Expected 65 bones; got " + str(active_skeleton.get_bone_count()))
    if meshes.size() < 10:
        return _fail("AF-STUDIO-107", "Equipment meshes missing; got " + str(meshes.size()))
    _pose_for_studio()
    _refresh_equipment()
    _prepare_appearance_materials()
    _apply_appearance()
    is_ready = true
    return true

func _fail(code: String, message: String) -> bool:
    error_code = code
    last_error = message
    push_error(code + " " + message)
    return false

func _collect(node: Node) -> void:
    if node is Skeleton3D and active_skeleton == null:
        active_skeleton = node as Skeleton3D
    if node is MeshInstance3D:
        meshes.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect(child)

func _pose_for_studio() -> void:
    # v0.6.1 display meshes carry the corrected, relaxed preview pose
    # precomputed across ALL skinned clothing/body meshes. Reapplying a
    # local upperarm rotation here would double-pose them, making arms wing.
    # For animation-enabled Aetherfall gameplay use unbaked source GLBs and
    # a matching real idle animation, not this static creator-only pose.
    return

func set_gender(value: String) -> void:
    if MODELS.has(value):
        gender = value
        hair_index = 1 if value == "male" else 0
        beard_enabled = false

func toggle_full_outfit() -> void:
    outfit = "Peasant" if outfit == "Ranger" else "Ranger"
    for slot in SLOTS:
        slot_styles[slot] = outfit
    _refresh_equipment()

func cycle_slot(slot: String) -> void:
    if not slot_styles.has(slot):
        return
    slot_styles[slot] = "Peasant" if slot_styles[slot] == "Ranger" else "Ranger"
    _refresh_equipment()

func cycle_hair(delta: int) -> void:
    hair_index = posmod(hair_index + delta, HAIR[gender].size())
    _refresh_equipment()

func toggle_hood() -> void:
    hood_enabled = not hood_enabled
    _refresh_equipment()

func toggle_shoulders() -> void:
    shoulders_enabled = not shoulders_enabled
    _refresh_equipment()

func toggle_beard() -> void:
    if gender == "male":
        beard_enabled = not beard_enabled
        _refresh_equipment()

func _refresh_equipment() -> void:
    if meshes.is_empty():
        return
    var hair_name: String = HAIR[gender][hair_index]
    var use_hood: bool = hood_enabled and slot_styles["body"] == "Ranger"
    for mesh in meshes:
        var name := String(mesh.name)
        if name.begins_with("Face_") or name == "HeadNeck_CollarSafe":
            mesh.visible = true
        elif name.begins_with("Style_"):
            mesh.visible = (name == "Style_" + hair_name and not use_hood) or (name == "Style_Hair_Beard" and beard_enabled and gender == "male")
        elif name.begins_with("Peasant_") or name.begins_with("Ranger_"):
            var style: String = name.split("_")[0]
            if name.contains("_Acc_"):
                mesh.visible = style == "Ranger" and shoulders_enabled and slot_styles["body"] == "Ranger"
            elif name.contains("_Head_Hood"):
                mesh.visible = style == "Ranger" and use_hood
            else:
                var slot := _slot_for(name)
                mesh.visible = style == slot_styles.get(slot, "")
        else:
            mesh.visible = true

func _slot_for(name: String) -> String:
    if name.contains("_Arms"):
        return "arms"
    if name.contains("_Body"):
        return "body"
    if name.contains("_Legs"):
        return "legs"
    if name.contains("_Feet"):
        return "feet"
    return "other"


func skin_label() -> String:
    return str(SKIN_NAMES[skin_index])

func hairstyle_label() -> String:
    var entries: Array = HAIR.get(gender, [])
    if entries.is_empty():
        return "NONE"
    return str(HAIR_DISPLAY.get(entries[hair_index], entries[hair_index]))

func hair_color_label() -> String:
    return str(HAIR_NAMES[hair_color_index])

func eye_color_label() -> String:
    return str(EYE_NAMES[eye_color_index])

func eye_style_label() -> String:
    return str(EYE_STYLES[eye_style_index])

func height_label() -> String:
    return "%d%%" % int(round(height_multiplier * 100.0))

func cycle_skin() -> void:
    skin_index = (skin_index + 1) % SKIN_NAMES.size()
    _apply_appearance()

func cycle_hair_color() -> void:
    hair_color_index = (hair_color_index + 1) % HAIR_NAMES.size()
    _apply_appearance()

func cycle_eye_color() -> void:
    eye_color_index = (eye_color_index + 1) % EYE_NAMES.size()
    _apply_appearance()

func cycle_eye_style() -> void:
    eye_style_index = (eye_style_index + 1) % EYE_STYLES.size()
    _apply_appearance()

func change_height(delta: float) -> void:
    height_multiplier = clampf(snappedf(height_multiplier + delta, 0.05), HEIGHT_MIN, HEIGHT_MAX)
    _apply_appearance()

func reset_appearance() -> void:
    skin_index = 2
    hair_color_index = 1
    eye_color_index = 0
    eye_style_index = 0
    height_multiplier = 1.0
    _apply_appearance()

func _prepare_appearance_materials() -> void:
    appearance_surfaces.clear()
    for item in meshes:
        if item.mesh == null:
            continue
        var node_name := String(item.name)
        var category := ""
        if node_name == "HeadNeck_CollarSafe":
            category = "skin"
        elif node_name == "Face_Eyes":
            category = "eyes"
        elif node_name == "Face_Eyebrows" or node_name.begins_with("Style_"):
            category = "hair"
        for idx in range(item.mesh.get_surface_count()):
            var original := item.get_active_material(idx)
            if not (original is StandardMaterial3D):
                continue
            var named := String(original.resource_name).to_lower()
            var surface_category := category
            if surface_category == "" and named.contains("regular_"):
                # Exposed skin on arms must match the visible face.
                surface_category = "skin"
            if surface_category == "":
                continue
            var material := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
            material.resource_local_to_scene = true
            item.set_surface_override_material(idx, material)
            appearance_surfaces.append({
                "mesh": item,
                "surface": idx,
                "category": surface_category,
                "material": material,
                "original_color": material.albedo_color
            })

func _eye_atlas_texture() -> Texture2D:
    var key := str(EYE_NAMES[eye_color_index]).to_lower()
    if eye_texture_cache.has(key):
        return eye_texture_cache[key] as Texture2D
    var file_path := "res://assets/eye_" + key + ".bin"
    if not FileAccess.file_exists(file_path):
        # Source APK was truncated before its texture atlases; keep eyes visible.
        return null
    var bytes := FileAccess.get_file_as_bytes(file_path)
    var image := Image.new()
    if image.load_png_from_buffer(bytes) != OK:
        push_warning("AF-STUDIO-EYE-202: Eye atlas could not be decoded " + key)
        return null
    var texture := ImageTexture.create_from_image(image)
    eye_texture_cache[key] = texture
    return texture

func _apply_appearance() -> void:
    # Unlike v0.3, height changes the CHARACTER ONLY, not the preview camera.
    # Non-uniform Y scale preserves width/depth and leaves the boots at floor Y=0.
    # This is a stature preview, not facial/body morph targets.
    scale = Vector3.ONE
    if loaded_root != null:
        # Fit Quaternius 2m source actor to Starter Town gameplay world units.
        # The original creator source file remains unchanged next door.
        loaded_root.scale = Vector3(0.56, 0.56 * height_multiplier, 0.56)
    var eye_atlas := _eye_atlas_texture()
    for entry in appearance_surfaces:
        var material := entry["material"] as StandardMaterial3D
        if material == null:
            continue
        var tint: Color = entry["original_color"]
        match str(entry["category"]):
            "skin":
                material.albedo_color = tint * SKIN_TINTS[skin_index]
            "hair":
                material.albedo_color = tint * HAIR_TINTS[hair_color_index]
            "eyes":
                if eye_atlas != null:
                    material.albedo_texture = eye_atlas
    # Do not scale Face_Eyes! v0.3 vertically stretched the entire textured
    # eye mesh and created detached/warped eye geometry on Android.
    # Existing characters contain no lid/eye morphs; offer non-deforming
    # eye finishes instead (subtle texture/material changes only).
    for entry in appearance_surfaces:
        if str(entry["category"]) != "eyes":
            continue
        var eye_mat := entry["material"] as StandardMaterial3D
        if eye_mat == null:
            continue
        match eye_style_index:
            0: # NATURAL: original atlas contrast and matte eye finish.
                eye_mat.roughness = 0.72
                eye_mat.albedo_color = entry["original_color"]
            1: # SOFT: slightly diffuse, low-glare iris.
                eye_mat.roughness = 0.92
                eye_mat.albedo_color = entry["original_color"] * Color(0.99, 0.99, 0.99)
            2: # DEFINED: clearer iris highlights with no mesh deformation.
                eye_mat.roughness = 0.36
                eye_mat.albedo_color = entry["original_color"] * Color(1.05, 1.05, 1.05)
    # Reset any old experimental per-eye scaling on appearance edits.
    for item in meshes:
        if item.name == "Face_Eyes":
            item.scale = Vector3.ONE


# Portable format for Aetherfall's future CharacterCreator and save-game system.
# Stores only selected indexes and garment slots, not imported mesh resources.
func export_profile() -> Dictionary:
    return {
        "schema": 1,
        "gender": gender,
        "skin_index": skin_index,
        "hair_index": hair_index,
        "hair_color_index": hair_color_index,
        "eye_color_index": eye_color_index,
        "eye_style_index": eye_style_index,
        "height_multiplier": height_multiplier,
        "beard_enabled": beard_enabled,
        "hood_enabled": hood_enabled,
        "shoulders_enabled": shoulders_enabled,
        "outfit": outfit,
        "slots": slot_styles.duplicate(true)
    }

func import_profile(profile: Dictionary) -> bool:
    if str(profile.get("gender", "")) != gender:
        return false
    skin_index = clampi(int(profile.get("skin_index", 2)), 0, SKIN_NAMES.size() - 1)
    hair_index = clampi(int(profile.get("hair_index", 0)), 0, HAIR[gender].size() - 1)
    hair_color_index = clampi(int(profile.get("hair_color_index", 1)), 0, HAIR_NAMES.size() - 1)
    eye_color_index = clampi(int(profile.get("eye_color_index", 0)), 0, EYE_NAMES.size() - 1)
    eye_style_index = clampi(int(profile.get("eye_style_index", 0)), 0, EYE_STYLES.size() - 1)
    height_multiplier = clampf(float(profile.get("height_multiplier", 1.0)), HEIGHT_MIN, HEIGHT_MAX)
    beard_enabled = bool(profile.get("beard_enabled", false)) if gender == "male" else false
    hood_enabled = bool(profile.get("hood_enabled", false))
    shoulders_enabled = bool(profile.get("shoulders_enabled", true))
    var style: String = str(profile.get("outfit", "Ranger"))
    outfit = style if style in ["Ranger", "Peasant"] else "Ranger"
    var parts: Dictionary = profile.get("slots", {})
    for slot in SLOTS:
        var choice: String = str(parts.get(slot, outfit))
        slot_styles[slot] = choice if choice in ["Ranger", "Peasant"] else outfit
    _refresh_equipment()
    _apply_appearance()
    return true

func randomize_look() -> void:
    skin_index = randi_range(0, SKIN_NAMES.size() - 1)
    hair_index = randi_range(0, HAIR[gender].size() - 1)
    hair_color_index = randi_range(0, HAIR_NAMES.size() - 1)
    eye_color_index = randi_range(0, EYE_NAMES.size() - 1)
    eye_style_index = randi_range(0, EYE_STYLES.size() - 1)
    height_multiplier = float(randi_range(17, 23)) / 20.0
    outfit = "Ranger" if randi_range(0, 1) == 0 else "Peasant"
    for slot in SLOTS:
        slot_styles[slot] = "Ranger" if randi_range(0, 1) == 0 else "Peasant"
    shoulders_enabled = bool(randi_range(0, 1))
    hood_enabled = bool(randi_range(0, 1))
    beard_enabled = gender == "male" and bool(randi_range(0, 1))
    _refresh_equipment()
    _apply_appearance()
