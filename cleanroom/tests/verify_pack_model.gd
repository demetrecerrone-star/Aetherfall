extends SceneTree
## Test only the EXPORTED Android resource pack, never the source tree.

const MODEL_FILES := ["res://models/adventurer_runtime.bin", "res://models/adventurer_female_runtime.bin"]
const REQUIRED := ["standing_relax", "idle", "look_around", "walk", "run", "jump", "sit"]


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
    print("AETHERFALL_DUAL_PACK_OK: Two rigs, all animations and seven materials validated")
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
    if skeleton == null or skeleton.get_bone_count() != 65 or player == null:
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
