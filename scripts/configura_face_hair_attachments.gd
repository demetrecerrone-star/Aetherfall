extends RefCounted
## Temporary anime hairstyle and iris prototypes for the *new* Tripo bald bases.
## NON-DESTRUCTIVE: no GLB modification, no renaming bones, no edits to the
## skinned mesh, joint weights, rest transforms, or eye/face geometry.
## Coordinates were measured from the 14 Oct 2026 user-supplied source GLBs.
## These shapes are placeholders for artist-authored hair and iris meshes.
const HEAD_BONE := "mixamorig:Head"
const HAIR_COLOR_DEFAULT := Color("#343047")
const IRIS_COLOR_DEFAULT := Color("#478bd1")


static func mount(model: Node3D, variant: String) -> Dictionary:
    if variant not in ["male", "female"]:
        return {}
    var skeletons := model.find_children("*", "Skeleton3D", true, false)
    if skeletons.size() != 1:
        return {}
    var rig := skeletons[0] as Skeleton3D
    # Godot sanitizes glTF bone names because ':' is forbidden in Skeleton3D.
    # Recognize the actual imported bone name. Never rename the source GLB.
    var head_index := rig.find_bone("Head")
    if head_index < 0:
        for i in range(rig.get_bone_count()):
            var label := str(rig.get_bone_name(i)).to_lower().replace("_", "").replace(":", "")
            if label in ["head", "mixamorighead"]:
                head_index = i
                break
    if head_index < 0:
        return {}
    # BoneAttachment follows actual animated head pose; frame below uses a
    # fixed inverse of the initial head transform. Source model is untouched.
    var attachment := BoneAttachment3D.new()
    attachment.name = "AetherfallHeadOptions"
    attachment.bone_name = rig.get_bone_name(head_index)
    rig.add_child(attachment)
    var frame := Node3D.new()
    frame.name = "OriginalModelCoordinateFrame"
    attachment.add_child(frame)
    frame.transform = rig.get_bone_global_pose(head_index).affine_inverse() * (
        rig.global_transform.affine_inverse() * model.global_transform)

    var styles: Array[Node3D] = []
    for style in range(2):
        var hair := _make_hairstyle(variant, style)
        frame.add_child(hair)
        hair.visible = style == 0
        styles.append(hair)

    var eyes := Node3D.new()
    eyes.name = "SeparateEyeAttachments"
    frame.add_child(eyes)
    var irises: Array[MeshInstance3D] = []
    var eye_y := 0.895 if variant == "male" else 0.902
    var front_z := 0.054 if variant == "male" else 0.046
    for side in [-1.0, 1.0]:
        var eye_x: float = side * (0.025 if variant == "male" else 0.024)
        _ellipsoid(eyes, "Sclera" + str(side),
            Vector3(eye_x, eye_y, front_z), Vector3(0.010, 0.006, 0.0010),
            Color("#f5eff0"))
        var iris := _ellipsoid(eyes, "Iris" + str(side),
            Vector3(eye_x, eye_y, front_z + 0.0029),
            Vector3(0.0046, 0.0056, 0.0008), IRIS_COLOR_DEFAULT)
        irises.append(iris)
        _ellipsoid(eyes, "Pupil" + str(side),
            Vector3(eye_x, eye_y, front_z + 0.0046),
            Vector3(0.0020, 0.0028, 0.0006), Color("#161c30"))
        _ellipsoid(eyes, "Catchlight" + str(side),
            Vector3(eye_x - 0.0016, eye_y + 0.0024, front_z + 0.0059),
            Vector3(0.0006, 0.0007, 0.0004), Color("#ffffff"))

    return {
        "attachment": attachment,
        "frame": frame,
        "hairstyles": styles,
        "irises": irises,
        "hair_color": HAIR_COLOR_DEFAULT,
        "iris_color": IRIS_COLOR_DEFAULT,
        "head_bone": rig.get_bone_name(head_index),
    }


static func select_hairstyle(options: Dictionary, index: int) -> void:
    var hairstyles: Array = options.get("hairstyles", [])
    for n in range(hairstyles.size()):
        (hairstyles[n] as Node3D).visible = n == index


static func color_hair(options: Dictionary, color: Color) -> void:
    for style in options.get("hairstyles", []):
        for child in (style as Node3D).find_children("*", "MeshInstance3D", true, false):
            var surface := (child as MeshInstance3D)
            surface.material_override = _material(color)


static func color_iris(options: Dictionary, color: Color) -> void:
    # ONLY target separate iris meshes; never tint the face or sclera.
    for iris in options.get("irises", []):
        (iris as MeshInstance3D).material_override = _material(color)


static func _make_hairstyle(variant: String, style: int) -> Node3D:
    var hair := Node3D.new()
    hair.name = "Hairstyle_" + str(style)
    var color := HAIR_COLOR_DEFAULT
    # Head geometry reaches ~0.98m; thin cap sits just outside the scalp.
    _ellipsoid(hair, "HairCap", Vector3(0.0, 0.950, -0.020),
        Vector3(0.056, 0.038, 0.056), color)
    if variant == "male":
        if style == 0:  # Short tousled / tapered
            for n in range(6):
                var x: float = -0.041 + float(n) * 0.016
                _strand(hair, "Fringe" + str(n),
                    Vector3(x, 0.946, 0.029), Vector3(x + 0.009, 0.913, 0.059),
                    0.010, color)
        else:  # Spiky swept
            for n in range(7):
                var x: float = -0.046 + float(n) * 0.015
                _strand(hair, "Spike" + str(n),
                    Vector3(x, 0.967, 0.002), Vector3(x + 0.018, 1.003 + 0.006 * (n % 2), 0.018),
                    0.011, color)
            for n in range(4):
                var x: float = -0.038 + float(n) * 0.026
                _strand(hair, "Fringe" + str(n),
                    Vector3(x, 0.947, 0.026), Vector3(x + 0.014, 0.919, 0.056),
                    0.012, color)
    elif style == 0:  # Short rounded bob
        for n in range(4):
            var x: float = -0.047 if n < 2 else 0.047
            var z: float = -0.032 if n % 2 == 0 else 0.005
            _strand(hair, "BobLock" + str(n),
                Vector3(x, 0.945, z), Vector3(x * 1.12, 0.849, z + 0.007),
                0.014, color)
        for n in range(5):
            var x: float = -0.04 + float(n) * 0.02
            _strand(hair, "Bangs" + str(n),
                Vector3(x, 0.956, 0.025), Vector3(x + 0.008, 0.928, 0.057),
                0.009, color)
    else:  # Long layered back + face framing locks
        for n in range(9):
            var theta: float = PI * (0.14 + float(n) * 0.09)
            var x: float = 0.054 * cos(theta)
            var z: float = -0.025 - 0.044 * sin(theta)
            _strand(hair, "LongLock" + str(n),
                Vector3(x, 0.940, z),
                Vector3(x * 1.22, 0.705 + 0.045 * (n % 3), z - 0.004),
                0.014, color)
        for side in [-1.0, 1.0]:
            _strand(hair, "FaceFramingLock" + str(side),
                Vector3(side * 0.050, 0.941, 0.012),
                Vector3(side * 0.064, 0.774, 0.022),
                0.013, color)
    return hair


static func _ellipsoid(parent: Node3D, label: String,
        at: Vector3, scale_xyz: Vector3, color: Color) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 12
    mesh.rings = 8
    mesh.radius = 1.0
    mesh.height = 2.0
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    # SphereMesh default height/radius is unit sphere in XYZ.
    node.position = at
    node.scale = scale_xyz
    node.material_override = _material(color)
    parent.add_child(node)
    return node


static func _strand(parent: Node3D, label: String,
        start: Vector3, finish: Vector3, radius: float, color: Color) -> void:
    var axis := finish - start
    var hair := CylinderMesh.new()
    hair.top_radius = 0.002
    hair.bottom_radius = radius
    hair.height = axis.length()
    hair.radial_segments = 7
    hair.rings = 1
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = hair
    node.position = (start + finish) * 0.5
    node.quaternion = Quaternion(Vector3.UP, axis.normalized())
    node.material_override = _material(color)
    parent.add_child(node)


static func _material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = 0.0
    result.roughness = 0.86
    return result
