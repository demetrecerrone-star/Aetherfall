extends SceneTree
## v0.3 original skinned GLTF asset gate.
## Blocks APK builds if the imported model has no skeleton, animation or hair.
func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	if scene == null:
		push_error("MODEL_TEST: missing player scene")
		quit(1)
		return
	var player := scene.instantiate()
	root.add_child(player)
	await process_frame
	var avatar: Node3D = player.get_node("Avatar")
	var statistics: Dictionary = avatar.get_model_stats()
	var skeleton: Skeleton3D = avatar.get_skeleton()
	var anim: AnimationPlayer = avatar.find_child("AnimationPlayer", true, false)
	var model_ok := int(statistics["model_meshes"]) >= 55 and int(statistics["bones"]) >= 16
	var clip_ok := anim != null and int(statistics["animation_clips"]) >= 5
	var rig_ok := false
	if skeleton != null:
		var hips := skeleton.find_bone("Hips")
		var head := skeleton.find_bone("Head")
		var right_hand := skeleton.find_bone("RightHand")
		if hips >= 0 and head >= 0 and right_hand >= 0:
			var height := skeleton.get_bone_global_pose(head).origin.y
			var hand := skeleton.get_bone_global_pose(right_hand).origin.y
			var hip := skeleton.get_bone_global_pose(hips).origin.y
			print("MODEL_TEST: bone heights: head %.2f  hand %.2f  hips %.2f" % [height, hand, hip])
			rig_ok = height > 1.6 and height < 2.3 and hand > .63 and hand < 1.3 and hip > .65
	var mesh_count := int(statistics["model_meshes"])
	var count_visible_hair := 0
	var count_hidden_hair := 0
	var imported_root: Node = avatar.get_node_or_null("AdventurerModel")
	var nodes: Array[Node] = []
	if imported_root != null:
		nodes.append(imported_root)
	while not nodes.is_empty():
		var n: Node = nodes.pop_back()
		if n is MeshInstance3D and str(n.name).begins_with("Hair_"):
			if n.visible:
				count_visible_hair += 1
			else:
				count_hidden_hair += 1
		for child in n.get_children():
			nodes.append(child)
	var hair_ok := count_visible_hair >= 5 and count_hidden_hair >= 12
	print("MODEL_TEST: mesh=%d bones=%d animations=%d hair_visible=%d hair_hidden=%d" % [
		mesh_count, int(statistics["bones"]), int(statistics["animation_clips"]),
		count_visible_hair, count_hidden_hair
	])
	avatar.cycle_option("hair_style", 1)
	avatar.cycle_option("skin", 1)
	await process_frame
	var save_ok := FileAccess.file_exists("user://aetherfall_appearance_v02.json")
	if model_ok and clip_ok and rig_ok and hair_ok and save_ok:
		print("MODEL_TEST_OK: original skinned GLTF avatar, clips and customization imported.")
		quit(0)
	else:
		push_error("MODEL_TEST_FAILED: missing rig, import, animations, hairstyles or save")
		quit(1)
