extends SceneTree
## Opt-in Godot validation: requires BOTH Tripo .bin files installed locally.
## godot --headless --path cleanroom --script res://tests/tripo_peasant_preview_test.gd
const MALE := "res://models/tripo/male_peasant_runtime.bin"
const FEMALE := "res://models/tripo/female_peasant_runtime.bin"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not FileAccess.file_exists(MALE) or not FileAccess.file_exists(FEMALE):
        _fail("Add both fitted Tripo .bin models from the installation ZIP first.")
        return
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Cannot load Starter Town")
        return
    var town := scene.instantiate() as Node3D
    root.add_child(town)
    for frame in range(18):
        await process_frame
    for gender in ["male", "female"]:
        if String(town.get("_character_variant")) != gender or not bool(town.get("_tripo_active")):
            _fail("Tripo active selection is wrong: " + gender)
            return
        if not bool(town.get("_loaded")):
            _fail("Tripo player did not become playable: " + gender)
            return
        var model := town.get("_model") as Node3D
        var rig := town.get("_skeleton") as Skeleton3D
        var player := town.get("_animation") as AnimationPlayer
        if model == null or model.name != "Tripo_"+gender or rig == null or rig.get_bone_count() != 65:
            _fail("Incorrect model or skeleton: " + gender)
            return
        if player == null or player.get_animation_list().size() != 3:
            _fail("Expected exactly three original Tripo clips: " + gender)
            return
        var gear_meshes: Array[MeshInstance3D] = []
        var legacy_visible := 0
        var nodes: Array[Node] = [model]
        while not nodes.is_empty():
            var item: Node = nodes.pop_back()
            if item is MeshInstance3D:
                var mesh := item as MeshInstance3D
                if mesh.name.begins_with("AF_Gear_fitted_peasant_"):
                    gear_meshes.append(mesh)
                    if mesh.skin == null or not mesh.visible:
                        _fail("Generated garment lost skin or visibility: " + mesh.name)
                        return
                elif mesh.name.begins_with("AF_Gear_peasant_") and mesh.visible:
                    legacy_visible += 1
            for child in item.get_children():
                nodes.append(child)
        if gear_meshes.size() < 10:
            _fail("Missing body-derived fitted garment pieces for " + gender)
            return
        if legacy_visible != 0:
            _fail("Legacy loose Tripo garments are still visible for " + gender)
            return
        if not bool(model.get_meta("tripo_body_derived_clothes", false)):
            _fail("Tripo clothing path did not use body-derived skin weights: " + gender)
            return
        for mode in ["IDLE","WALK","RUN"]:
            town.call("_set_motion",mode)
            if String(player.current_animation).is_empty():
                _fail("No authored motion playing for " + mode + " " + gender)
                return
        town.call("_set_motion","IDLE")
        var initial_alpha: float = float(town.get("_camera_fade_alpha"))
        town.call("_apply_camera_fade", 0.33)
        var active_fade := float(town.get("_camera_fade_alpha")) < 0.4
        var material := gear_meshes[0].get_active_material(0) as StandardMaterial3D
        if not active_fade or material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
            _fail("Clothing did not join the camera fade: " + gender)
            return
        town.call("_apply_camera_fade", 1.0)
        print("AETHERFALL_TRIPO_MODEL_OK: %s, 65 bones, 3 clips, %d body-derived skinned garment meshes, legacy loose gear hidden, fade restored" % [gender,gear_meshes.size()])
        if gender == "male":
            town.call("_switch_character")
            for frame in range(18):
                await process_frame
    town.queue_free()
    print("AETHERFALL_TRIPO_PREVIEW_OK: both sexes, body-derived garment skin, legacy loose gear hidden, idle/walk/run, clothing camera fade")
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_TRIPO_PREVIEW_FAILED: " + message)
    quit(1)
