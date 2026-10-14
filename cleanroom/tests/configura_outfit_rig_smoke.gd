extends SceneTree
## Isolated universal-body + peasant-gear rig compatibility. NOT a visual clipping test.
const PeasantGear = preload("res://peasant_gear.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for gender in ["male", "female"]:
		var ok := await _check_gender(gender)
		if not ok:
			quit(1)
			return
	print("AETHERFALL_CONFIGURA_EXISTING_GEAR_COMPATIBLE: both 65-bone universal bodies")
	quit(0)

func _check_gender(gender: String) -> bool:
	var filepath := "res://models/universal/%s_runtime.bin" % gender
	if not FileAccess.file_exists(filepath):
		push_error("RIG_PROBE_FAILED: missing " + filepath)
		return false
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_buffer(FileAccess.get_file_as_bytes(filepath), "", state)
	if err != OK:
		push_error("RIG_PROBE_FAILED: Godot import %s: %d" % [gender, err])
		return false
	var result := doc.generate_scene(state)
	if not result is Node3D:
		push_error("RIG_PROBE_FAILED: 3D scene not generated for " + gender)
		return false
	var avatar := result as Node3D
	root.add_child(avatar)
	var rigs := avatar.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_error("RIG_PROBE_FAILED: Missing 3D skeleton for " + gender)
		avatar.queue_free()
		return false
	var rig := rigs[0] as Skeleton3D
	if rig.get_bone_count() != 65:
		push_error("RIG_PROBE_FAILED: expected 65 joints for %s, got %d" % [gender, rig.get_bone_count()])
		avatar.queue_free()
		return false
	var result_gear: Dictionary = PeasantGear.equip_default(avatar, rig, gender)
	if not result_gear.get("ok", false):
		push_error("RIG_PROBE_FAILED: peasant gear %s: %s" % [gender, result_gear.get("reason", "unknown")])
		avatar.queue_free()
		return false
	var parts := avatar.find_children("Peasant_*", "MeshInstance3D", true, false)
	if parts.size() != 4:
		push_error("RIG_PROBE_FAILED: %s has %d/4 garment parts" % [gender, parts.size()])
		avatar.queue_free()
		return false
	for node in parts:
		var cloth := node as MeshInstance3D
		if cloth.mesh == null or cloth.skin == null or cloth.skin.get_bind_count() != 65:
			push_error("RIG_PROBE_FAILED: skinned garment missing binds: " + cloth.name)
			avatar.queue_free()
			return false
		if cloth.mesh.get_surface_count() < 1:
			push_error("RIG_PROBE_FAILED: empty garment geometry: " + cloth.name)
			avatar.queue_free()
			return false
		var arrays := cloth.mesh.surface_get_arrays(0)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if weights.is_empty():
			push_error("RIG_PROBE_FAILED: missing garment skin weights: " + cloth.name)
			avatar.queue_free()
			return false
	print("AETHERFALL_UNIVERSAL_PEASANT_RIG_OK %s: joints=65, skinned_parts=%d" % [gender, parts.size()])
	avatar.queue_free()
	await process_frame
	return true
