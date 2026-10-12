extends RefCounted
## Lightweight skinned starting clothes for the 65-bone Universal Base bodies.
## They are made from the player's OWN skinning surface, so idle, walk, sprint
## and later combat animations deform the garments with the existing rig.
## No armor is granted at character creation: tutorial rewards come later.
const PARTS := ["Tunic", "Trousers", "Boots", "Belt"]
const STARTER_ITEMS := {
    "chest": "worn_linen_tunic",
    "legs": "patched_wool_trousers",
    "feet": "scuffed_leather_boots",
    "waist": "plain_leather_belt"
}
const EQUIPMENT_SLOTS := ["head", "chest", "hands", "legs", "feet", "waist", "weapon", "offhand"]

static func equip_default(character: Node3D, rig: Skeleton3D, variant: String) -> Dictionary:
    if character == null or rig == null:
        return {"ok": false, "reason": "Missing character or animation skeleton"}
    var body := _find_body(character)
    if body == null or body.mesh == null or body.skin == null:
        return {"ok": false, "reason": "Universal body must have a skinned surface"}
    var bind_names: Array[String] = []
    for i in range(body.skin.get_bind_count()):
        var bone_index := body.skin.get_bind_bone(i)
        bind_names.append(String(rig.get_bone_name(bone_index)).to_lower() if bone_index >= 0 and bone_index < rig.get_bone_count() else "")
    if bind_names.is_empty():
        return {"ok": false, "reason": "Universal body has no skin binds"}

    var generated := 0
    for part in PARTS:
        var garment_mesh := _make_garment(body.mesh, part, bind_names)
        if garment_mesh == null or garment_mesh.get_surface_count() == 0:
            return {"ok": false, "reason": "Missing skinned triangles for " + part}
        var cloth := MeshInstance3D.new()
        cloth.name = "Peasant_" + part
        # Same parent, local transform, skin and skeleton path as the original
        # body. Never attach unskinned costume props to animated limbs.
        body.get_parent().add_child(cloth)
        cloth.transform = body.transform
        cloth.skin = body.skin
        cloth.skeleton = body.skeleton
        cloth.mesh = garment_mesh
        cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        cloth.material_override = _fabric_material(part, variant)
        generated += 1
    character.set_meta("equipped_outfit", "peasant_clothes")
    character.set_meta("starting_equipment", STARTER_ITEMS.duplicate(true))
    character.set_meta("equipment_slots", EQUIPMENT_SLOTS.duplicate())
    character.set_meta("tutorial_armor_unlocked", false)
    character.set_meta("peasant_skinned_parts", generated)
    return {"ok": true, "parts": generated, "starter_items": STARTER_ITEMS.duplicate(true)}

static func _find_body(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D and node.name.to_lower().contains("superhero"):
        return node as MeshInstance3D
    for child in node.get_children():
        var result := _find_body(child)
        if result != null:
            return result
    return null

static func _fabric_material(part: String, variant: String) -> StandardMaterial3D:
    var cloth := StandardMaterial3D.new()
    cloth.resource_name = "Aetherfall Peasant " + part
    cloth.roughness = 0.94
    cloth.metallic = 0.0
    match part:
        "Tunic":
            cloth.albedo_color = Color("#927e64") if variant == "male" else Color("#807966")
        "Trousers":
            cloth.albedo_color = Color("#51483e") if variant == "male" else Color("#574d43")
        "Boots":
            cloth.albedo_color = Color("#3d3025")
        "Belt":
            cloth.albedo_color = Color("#422d21")
    return cloth

static func _vertex_region(name: String, y: float) -> String:
    if name in ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r"] and y >= 0.86:
        return "Tunic"
    if name in ["thigh_l", "thigh_r", "calf_l", "calf_r"] and y > 0.18:
        return "Trousers"
    if name in ["foot_l", "foot_r", "ball_l", "ball_r"] or (name in ["calf_l", "calf_r"] and y <= 0.25):
        return "Boots"
    return ""

static func _make_garment(body_mesh: Mesh, part: String, bind_names: Array[String]) -> ArrayMesh:
    var result := ArrayMesh.new()
    for surface in range(body_mesh.get_surface_count()):
        var a := body_mesh.surface_get_arrays(surface)
        var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
        var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
        var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
        var original_indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
        if verts.is_empty() or normals.size() != verts.size() or original_indices.is_empty() or bones.is_empty() or weights.is_empty():
            continue
        var stride := int(bones.size() / verts.size())
        if stride != 4 and stride != 8:
            continue
        var zones := PackedStringArray()
        var bone_names := PackedStringArray()
        for v in range(verts.size()):
            var winner := 0
            var highest := -1.0
            for j in range(stride):
                var score := float(weights[v * stride + j])
                if score > highest:
                    highest = score
                    winner = int(bones[v * stride + j])
            var name := bind_names[winner] if winner >= 0 and winner < bind_names.size() else ""
            bone_names.append(name)
            zones.append(_vertex_region(name, verts[v].y))

        var garment_indices := PackedInt32Array()
        for i in range(0, original_indices.size() - 2, 3):
            var a0 := int(original_indices[i])
            var a1 := int(original_indices[i + 1])
            var a2 := int(original_indices[i + 2])
            if part == "Belt":
                # Dark leather waist band follows the same animated pelvis and
                # lower-spine weights, sitting just above the tunic surface.
                var avg_y := (verts[a0].y + verts[a1].y + verts[a2].y) / 3.0
                if avg_y < 0.95 or avg_y > 1.04:
                    continue
                var waist_count := int(bone_names[a0] in ["pelvis", "spine_01"]) + int(bone_names[a1] in ["pelvis", "spine_01"]) + int(bone_names[a2] in ["pelvis", "spine_01"])
                if waist_count < 2:
                    continue
            else:
                var same := int(zones[a0] == part) + int(zones[a1] == part) + int(zones[a2] == part)
                if same < 2:
                    continue
            garment_indices.append_array(PackedInt32Array([a0, a1, a2]))
        if garment_indices.size() < 24:
            continue

        # Push the layered clothing outside the original textured body, rather
        # than replacing any underlying skin, head, hands or rigging.
        var offset := 0.030 if part == "Belt" else (0.022 if part == "Tunic" else 0.018)
        var expanded: PackedVector3Array = verts.duplicate()
        for k in range(expanded.size()):
            expanded[k] = expanded[k] + normals[k] * offset
        var output := a.duplicate(true)
        output[Mesh.ARRAY_VERTEX] = expanded
        output[Mesh.ARRAY_INDEX] = garment_indices
        var flags := body_mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
        result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output, [], {}, flags)
    return result
