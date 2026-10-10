"""Non-destructive mobile skeleton and skin-weight reduction for MPFB/Rigify.

Keep the full Rigify control rig and original deformation on the editable .blend.
Duplicate only the GLB export objects, retaining an anatomically essential
subset of deform bones and remapping omitted weights to their closest retained
ancestor (or spatially closest retained rest bone).
"""
import bpy

MAX_RUNTIME_BONES = 96
ESSENTIAL = (
    "spine", "neck", "head", "shoulder", "upper_arm", "forearm",
    "hand", "thigh", "shin", "foot", "toe", "hips", "pelvis",
)


def build_runtime_rig(human, rig):
    bones = {bone.name: bone for bone in rig.data.bones if bone.use_deform}
    assert len(bones) > MAX_RUNTIME_BONES, "Rigify source rig unexpectedly small"
    importance = {name: 0.0 for name in bones}
    for vertex in human.data.vertices:
        for assignment in vertex.groups:
            name = human.vertex_groups[assignment.group].name
            if name in importance and assignment.weight > 0:
                importance[name] += assignment.weight

    # The knees, feet, arm hinges, neck and spine are never sacrificed just
    # because more facial/finger vertices happen to influence the score.
    retained = {name for name in bones
                if any(label in name.lower() for label in ESSENTIAL)}
    assert len(retained) <= MAX_RUNTIME_BONES, (
        "Essential humanoid joints exceed mobile skeleton budget", len(retained)
    )
    for name in sorted(bones, key=lambda n: (-importance[n], n)):
        if len(retained) >= MAX_RUNTIME_BONES:
            break
        retained.add(name)
    assert len(retained) == MAX_RUNTIME_BONES

    # Removed fingers/facial detail inherit deformation from the nearest
    # surviving ancestor in the same chain; disconnected branches fall back
    # to physically nearest same-side bone in rest pose.
    remap = {}
    for name, bone in bones.items():
        if name in retained:
            remap[name] = name
            continue
        parent = bone.parent
        while parent and parent.name not in retained:
            parent = parent.parent
        if parent:
            remap[name] = parent.name
            continue
        origin = bone.head_local
        def distance(candidate):
            pos = bones[candidate].head_local
            side_penalty = 1.0 if abs(origin.x) > .07 and origin.x * pos.x < -.002 else 0.0
            return (pos - origin).length_squared + side_penalty
        remap[name] = min(retained, key=distance)
    assert set(remap) == set(bones) and set(remap.values()) <= retained

    data = bpy.data.armatures.new("Aetherfall_Mobile_Deform_Armature")
    mobile = bpy.data.objects.new("Aetherfall_Mobile_Deform_Rig", data)
    bpy.context.collection.objects.link(mobile)
    mobile.matrix_world = rig.matrix_world.copy()
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    mobile.select_set(True)
    bpy.context.view_layer.objects.active = mobile
    bpy.ops.object.mode_set(mode="EDIT")
    for name in sorted(retained):
        original = bones[name]
        dest = data.edit_bones.new(name)
        dest.head = original.head_local
        dest.tail = original.tail_local
        dest.align_roll(original.z_axis)
        dest.use_deform = True
    for name in sorted(retained):
        ancestor = bones[name].parent
        while ancestor and ancestor.name not in retained:
            ancestor = ancestor.parent
        if ancestor:
            dest = data.edit_bones[name]
            dest.parent = data.edit_bones[ancestor.name]
            dest.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    assert len(mobile.data.bones) == MAX_RUNTIME_BONES
    return mobile, remap


def make_mobile_mesh(source, mobile, remap):
    """Clone (never mutate) one Blender body, hairstyle or costume mesh."""
    obj = source.copy()
    obj.data = source.data.copy()
    bpy.context.collection.objects.link(obj)
    world_transform = source.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world_transform
    for modifier in tuple(obj.modifiers):
        if modifier.type == "ARMATURE":
            obj.modifiers.remove(modifier)
    modifier = obj.modifiers.new("Mobile deformation", "ARMATURE")
    modifier.object = mobile

    source_groups = [group.name for group in source.vertex_groups]
    weights = []
    for vertex in source.data.vertices:
        reduced = {}
        for assignment in vertex.groups:
            if assignment.group >= len(source_groups) or assignment.weight <= 0:
                continue
            joint = remap.get(source_groups[assignment.group])
            if joint:
                reduced[joint] = reduced.get(joint, 0.0) + assignment.weight
        if not reduced:
            # MPFB includes decorative/mask helper verts without any original
            # deform groups. Give them a valid stationary rest-pose parent.
            pos = vertex.co
            joint = min(mobile.data.bones,
                        key=lambda bone: (bone.head_local - pos).length_squared).name
            reduced[joint] = 1.0
        strongest = sorted(reduced.items(), key=lambda pair: -pair[1])[:4]
        total = sum(weight for _, weight in strongest)
        assert total > 1e-8, "Runtime mesh has no deform weights"
        weights.append([(name, weight / total) for name, weight in strongest])

    for group in tuple(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    groups = {}
    for index, entries in enumerate(weights):
        for name, weight in entries:
            if name not in groups:
                groups[name] = obj.vertex_groups.new(name=name)
            groups[name].add([index], weight, "REPLACE")
    for vertex in obj.data.vertices:
        total = sum(group.weight for group in vertex.groups)
        assert abs(total - 1.0) < 1e-3, "Runtime skin weight loss: %s[%d]" % (source.name, vertex.index)
    return obj
