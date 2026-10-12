extends SceneTree
## Test only the EXPORTED Android resource pack, never the source tree.

const MODEL_FILES := ["res://models/universal/male_runtime.bin", "res://models/universal/female_runtime.bin"]
const REQUIRED := ["Idle_Loop", "Walk_Loop", "Sprint_Loop", "Sword_Attack", "Sword_Block", "Interact"]


func _initialize() -> void:
    var pack_file := OS.get_environment("AETHERFALL_PACK_FILE")
    if pack_file.is_empty() or not FileAccess.file_exists(pack_file):
        _fail("Exported Android pack is absent: " + pack_file)
        return
    if not ProjectSettings.load_resource_pack(pack_file):
        _fail("Godot cannot mount the exported pack")
        return
    for model_file in MODEL_FILES:
        if not _validate_model(String(model_file)):
            return
    # The old creator and imported Tripo players are deliberately absent.
    if FileAccess.file_exists("res://models/creator_v065/male_playable.bin"):
        _fail("Old v0.6.5 model was bundled in the new APK")
        return
    # This catches exactly the Android packaging mistake that broke 0.2P:
    # verifying the source file is not enough; both models AND each texture
    # must remain inside the exported Android PCK.
    for kind in ["cobble", "grass", "dirt", "plaster", "wood", "roof", "stone"]:
        var texture_path: String = "res://textures/" + String(kind) + ".bin"
        if not FileAccess.file_exists(texture_path):
            _fail("Android PCK does not include CC0 material: " + texture_path)
            return
        var img := Image.new()
        var image_err := img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(texture_path))
        if image_err != OK or img.get_width() < 512 or img.get_height() < 512:
            _fail("Bad texture in exported PCK: %s, error=%d" % [texture_path, image_err])
            return
        print("AETHERFALL_TEXTURE_PACK_OK: %s (%d x %d)" % [texture_path, img.get_width(), img.get_height()])
    # The fountain is loaded at runtime from genuine GLB bytes. Do not
    # substitute an editor-only import path that silently vanishes in Android.
    var fountain_path := "res://models/fountain/MedievalFountain.bin"
    if not FileAccess.file_exists(fountain_path):
        _fail("Optimized user fountain was omitted from the exported APK resource pack")
        return
    var fountain_bytes := FileAccess.get_file_as_bytes(fountain_path)
    if fountain_bytes.size() < 300000 or fountain_bytes.slice(0, 4).get_string_from_ascii() != "glTF":
        _fail("Fountain in exported Android pack is empty or corrupt")
        return
    var fountain_doc := GLTFDocument.new()
    var fountain_state := GLTFState.new()
    if fountain_doc.append_from_buffer(fountain_bytes, "", fountain_state) != OK:
        _fail("Bundled user fountain cannot be imported on Android")
        return
    var fountain_scene := fountain_doc.generate_scene(fountain_state)
    if fountain_scene == null:
        _fail("Bundled fountain has no renderable geometry")
        return
    fountain_scene.free()
    print("AETHERFALL_FOUNTAIN_PACK_OK: authentic optimized fountain included in Android")
    print("AETHERFALL_DUAL_PACK_OK: two new Universal characters, 25 clips, seven materials and fountain validated")
    quit(0)


func _validate_model(model_file: String) -> bool:
    if not FileAccess.file_exists(model_file):
        _fail("Android pack is missing " + model_file)
        return false
    var bytes := FileAccess.get_file_as_bytes(model_file)
    if bytes.size() < 3000000 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
        _fail("Bundled model is empty or invalid: " + model_file)
        return false
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_buffer(bytes, "", state)
    if err != OK:
        _fail("Cannot import bundled model %s, error %d" % [model_file, err])
        return false
    var scene := doc.generate_scene(state)
    if scene == null:
        _fail("GLB did not generate a scene: " + model_file)
        return false
    var player := _find_animation_player(scene)
    var skeleton := _find_skeleton(scene)
    if skeleton == null or skeleton.get_bone_count() != 65 or player == null or player.get_animation_list().size() < 25:
        _fail("Missing 65-joint rig or animation player in " + model_file)
        scene.free()
        return false
    var names: Array[String] = []
    for clip in player.get_animation_list():
        names.append(String(clip).to_lower())
    for required in REQUIRED:
        var found := false
        for clip in names:
            if clip == required or clip.ends_with("/" + required) or clip.ends_with(":" + required) or clip.ends_with("|" + required):
                found = true
                break
        if not found:
            _fail("Missing %s in %s; clips=%s" % [required, model_file, str(names)])
            scene.free()
            return false
    print("AETHERFALL_PACK_MODEL_OK: %s bytes=%d bones=65 clips=%s" % [model_file, bytes.size(), str(names)])
    scene.free()
    return true


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var match_node := _find_animation_player(child)
        if match_node != null:
            return match_node
    return null


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var match_node := _find_skeleton(child)
        if match_node != null:
            return match_node
    return null


func _fail(message: String) -> void:
    push_error("AETHERFALL_PACK_FAIL: " + message)
    quit(1)
