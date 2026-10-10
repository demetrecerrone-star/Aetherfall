extends SceneTree
## Fail the Android build if the actual EXPORTED resource pack lacks the model.
## Run from a temporary empty Godot project so local source files cannot
## accidentally make a missing PCK entry appear present.

const MODEL_FILE := "res://models/adventurer_runtime.bin"
const REQUIRED := ["standing_relax", "idle", "look_around", "walk", "run", "jump", "sit"]


func _initialize() -> void:
    var pack_file := OS.get_environment("AETHERFALL_PACK_FILE")
    if pack_file.is_empty() or not FileAccess.file_exists(pack_file):
        _fail("Exported Android PCK is absent: " + pack_file)
        return

    if not ProjectSettings.load_resource_pack(pack_file):
        _fail("Godot cannot mount the exported PCK: " + pack_file)
        return

    if not FileAccess.file_exists(MODEL_FILE):
        _fail("Exported PCK does NOT contain raw model: " + MODEL_FILE)
        return

    var bytes := FileAccess.get_file_as_bytes(MODEL_FILE)
    if bytes.size() < 3000000 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
        _fail("Embedded model is missing or invalid, bytes=%d" % bytes.size())
        return

    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_buffer(bytes, "", state)
    if err != OK:
        _fail("Embedded character GLB does not parse; error=%d" % err)
        return

    var scene := doc.generate_scene(state)
    if scene == null:
        _fail("Exported GLB parsed but did not generate an instantiable scene")
        return
    var player := _find_animation_player(scene)
    var skeleton := _find_skeleton(scene)
    if skeleton == null or skeleton.get_bone_count() != 65:
        _fail("Exported model is missing its original 65-joint rig")
        scene.free()
        return
    if player == null:
        _fail("Exported model is missing AnimationPlayer")
        scene.free()
        return
    var animations: Array[String] = []
    for animation_name in player.get_animation_list():
        animations.append(String(animation_name).to_lower())
    for name in REQUIRED:
        var exists := false
        for imported in animations:
            if imported == name or imported.ends_with("/" + name) or imported.ends_with(":" + name) or imported.ends_with("|" + name):
                exists = true
                break
        if not exists:
            _fail("Exported character lacks %s; found %s" % [name, str(animations)])
            scene.free()
            return

    print("AETHERFALL_PACK_OK: %d raw model bytes, %d bones, clips=%s" % [bytes.size(), skeleton.get_bone_count(), str(animations)])
    scene.free()
    quit(0)


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var result := _find_animation_player(child)
        if result != null:
            return result
    return null


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var result := _find_skeleton(child)
        if result != null:
            return result
    return null


func _fail(message: String) -> void:
    push_error("AETHERFALL_PACK_FAIL: " + message)
    quit(1)
