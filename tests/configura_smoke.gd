extends SceneTree
## Data-model compatibility check ONLY; this does not prove outfit fit or Tripo import.

func _initialize() -> void:
	call_deferred("_run_test")

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("CONFIGURA_TEST_FAILED: " + message)
	quit(1)
	return false

func _run_test() -> void:
	var config := CharacterConfig.new()
	var hairstyle := MeshSwapOption.new()
	hairstyle.resource_name = "hairstyle"
	hairstyle.display_name = "Hairstyle"
	hairstyle.group = "Appearance"

	var short_hair := MeshSwapChoice.new()
	short_hair.label = "Short"
	var long_hair := MeshSwapChoice.new()
	long_hair.label = "Long"
	hairstyle.choices.append(short_hair)
	hairstyle.choices.append(long_hair)

	var eyes := ColorOption.new()
	eyes.resource_name = "eye_color"
	eyes.display_name = "Eye Color"
	eyes.group = "Appearance"
	eyes.default_color = Color(0.2, 0.5, 0.8)

	config.options.append(hairstyle)
	config.options.append(eyes)

	var state := CharacterState.from_config(config)
	if not _require(state.values.has("hairstyle"), "Missing hairstyle choice"):
		return
	if not _require(state.values.has("eye_color"), "Missing eye color"):
		return
	if not _require(state.values["hairstyle"] == 0, "Wrong default hairstyle"):
		return

	state.record("hairstyle", 1)
	state.record("eye_color", Color(0.4, 0.7, 0.2))
	state.metadata["character_model"] = "female"

	var save_path := "user://aetherfall_configura_feasibility.tres"
	var saved := ResourceSaver.save(state, save_path)
	if not _require(saved == OK, "Configura state resource failed to save"):
		return

	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterState
	if not _require(loaded != null, "Configura state resource failed to load"):
		return
	if not _require(loaded.values["hairstyle"] == 1, "Hairstyle did not persist"):
		return
	if not _require(loaded.values["eye_color"] == Color(0.4, 0.7, 0.2), "Eye color did not persist"):
		return
	if not _require(loaded.metadata["character_model"] == "female", "Gender selection metadata did not persist"):
		return

	print("AETHERFALL_CONFIGURA_DATA_MODEL_OK: hairstyle, eyes, gender metadata, resource save/load")
	quit(0)
