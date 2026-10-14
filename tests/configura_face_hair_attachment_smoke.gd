extends SceneTree
## Uses an artificial skeleton so CI can test head attachment without publishing
## the user's private GLBs to the public Aetherfall GitHub repository.
const FaceHairAttachments = preload("res://scripts/configura_face_hair_attachments.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for variant in ["male", "female"]:
        var model := Node3D.new()
        root.add_child(model)
        var rig := Skeleton3D.new()
        rig.name = "SyntheticRig"
        model.add_child(rig)
        rig.add_bone("Head")
        rig.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.86, -0.02)))
        var opts: Dictionary = FaceHairAttachments.mount(model, variant)
        if opts.is_empty():
            _fail("Could not attach head options: " + variant)
            return
        if rig.get_bone_count() != 1 or rig.get_bone_name(0) != "Head":
            _fail("Head attachment changed original rig")
            return
        var styles: Array = opts["hairstyles"]
        var irises: Array = opts["irises"]
        if styles.size() != 2 or irises.size() != 2:
            _fail("Missing two hairstyle meshes or separate irises")
            return
        FaceHairAttachments.select_hairstyle(opts, -1)
        if (styles[0] as Node3D).visible or (styles[1] as Node3D).visible:
            _fail("Bald option still shows hair")
            return
        FaceHairAttachments.select_hairstyle(opts, 1)
        if (styles[0] as Node3D).visible or not (styles[1] as Node3D).visible:
            _fail("Hair mesh option failed to swap")
            return

        var new_iris := Color("#21be70")
        var new_hair := Color("#8e61d1")
        FaceHairAttachments.color_iris(opts, new_iris)
        FaceHairAttachments.color_hair(opts, new_hair)
        for eye in irises:
            var mat := (eye as MeshInstance3D).material_override as StandardMaterial3D
            if mat == null or mat.albedo_color != new_iris:
                _fail("Iris color option failed")
                return
        for child in (styles[1] as Node3D).find_children("*", "MeshInstance3D", true, false):
            var material := (child as MeshInstance3D).material_override as StandardMaterial3D
            if material == null or material.albedo_color != new_hair:
                _fail("Hair color option failed")
                return
        var sclera_nodes := model.find_children("Sclera*", "MeshInstance3D", true, false)
        if sclera_nodes.size() != 2:
            _fail("Separate sclera components not found")
            return
        var sclera := sclera_nodes[0] as MeshInstance3D
        var sclera_mat := sclera.material_override as StandardMaterial3D
        if sclera_mat.albedo_color == new_iris:
            _fail("Iris recoloring accidentally changed sclera")
            return
        # Test that attachments follow head transforms while preserving bones.
        var attachment := opts["attachment"] as BoneAttachment3D
        await process_frame
        var before: Vector3 = attachment.global_position
        rig.set_bone_pose_position(0, Vector3(0, 0.05, 0))
        await process_frame
        var after: Vector3 = attachment.global_position
        if after.distance_to(before) < 0.02:
            _fail("Head-attached options failed to follow head movement")
            return
        model.queue_free()
        await process_frame
    print("AETHERFALL_FACE_HAIR_ATTACHMENT_OK: 2 models, bald + two hair choices, independent iris/hair colors, head follow, intact skeleton")
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_FACE_HAIR_ATTACHMENT_FAIL: " + message)
    quit(1)
