extends SceneTree
## Regression test: v0.2 avatar collapsed because runtime bones were at origin.
## Run: godot --headless --path . --script res://tests/avatar_rig_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	if scene == null:
		push_error("Rig test: player scene could not load")
		quit(1)
		return
	var player: Node3D = scene.instantiate()
	root.add_child(player)
	await process_frame

	var avatar: Node3D = player.get_node("Avatar")
	var pass_initial := _verify_rig(avatar, "spawn")
	# Regenerating art after an appearance change must not reset the character
	# into the collapsed neutral pose seen in the original v0.2 screenshot.
	avatar.cycle_option("hair_style")
	await process_frame
	var pass_rebuild := _verify_rig(avatar, "appearance-change")
	if pass_initial and pass_rebuild:
		print("RIG_TEST_OK: humanoid skeleton and visible attachments stay properly spaced.")
		quit(0)
	else:
		push_error("RIG_TEST_FAILED: collapsed humanoid detected.")
		quit(1)

func _verify_rig(avatar: Node3D, moment: String) -> bool:
	var skeleton: Skeleton3D = avatar.get_node_or_null("HumanoidSkeleton")
	if skeleton == null:
		push_error("%s: missing humanoid skeleton" % moment)
		return false

	var hips_idx := skeleton.find_bone("Hips")
	var head_idx := skeleton.find_bone("Head")
	var shin_idx := skeleton.find_bone("LeftShin")
	if hips_idx < 0 or head_idx < 0 or shin_idx < 0:
		push_error("%s: missing critical humanoid bones" % moment)
		return false

	var hip_height: float = skeleton.get_bone_global_pose(hips_idx).origin.y
	var head_height: float = skeleton.get_bone_global_pose(head_idx).origin.y
	var shin_height: float = skeleton.get_bone_global_pose(shin_idx).origin.y
	var attached_head_height := -100.0
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.bone_name == "Head":
			attached_head_height = skeleton.to_local(child.global_position).y
			break

	print("%s rig: hips=%.3f head=%.3f shin=%.3f head_attachment=%.3f" % [moment, hip_height, head_height, shin_height, attached_head_height])

	var skeletal_ok := (hip_height > 0.65 and hip_height < 1.2) and (head_height > 1.62 and head_height < 2.25) and (shin_height > 0.17 and shin_height < 0.70) and (head_height - shin_height > 1.15)
	var attachment_ok := absf(attached_head_height - head_height) < 0.2
	if not skeletal_ok or not attachment_ok:
		push_error("%s: skeleton or attachment heights invalid - avatar will appear as a pile." % moment)
		return false
	return true
