extends SceneTree
## No GLB generation or APK export. Exercise Starter Town's reusable profile format.
const CharacterPreferences = preload("res://character_preferences.gd")
const TEST_PATH := "user://aetherfall-character-profile-smoke-test.cfg"

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var abs_path := ProjectSettings.globalize_path(TEST_PATH)
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(abs_path)

    var first: Dictionary = CharacterPreferences.load_profile(TEST_PATH)
    if first.get("variant") != "male" or first.get("idle_pose") != "standing_relax":
        _fail("Missing profile should safely start with male / standing relax")
        return

    if not CharacterPreferences.save_profile("female", "look_around", TEST_PATH):
        _fail("Could not store female model and look-around pose")
        return
    var restored: Dictionary = CharacterPreferences.load_profile(TEST_PATH)
    if restored.get("variant") != "female" or restored.get("idle_pose") != "look_around":
        _fail("Preferences did not survive save and load")
        return

    if CharacterPreferences.save_profile("unknown", "idle", TEST_PATH):
        _fail("Unrecognized model choice was accepted")
        return
    if CharacterPreferences.save_profile("male", "dance", TEST_PATH):
        _fail("Unsupported idle pose was accepted")
        return
    restored = CharacterPreferences.load_profile(TEST_PATH)
    if restored.get("variant") != "female" or restored.get("idle_pose") != "look_around":
        _fail("Invalid writes must not corrupt the existing profile")
        return

    # Malformed individual values should fall back without discarding good ones.
    var config := ConfigFile.new()
    config.set_value("character", "variant", "unrecognized")
    config.set_value("character", "idle_pose", "idle")
    if config.save(TEST_PATH) != OK:
        _fail("Could not create old/corrupt profile fixture")
        return
    restored = CharacterPreferences.load_profile(TEST_PATH)
    if restored.get("variant") != "male" or restored.get("idle_pose") != "idle":
        _fail("Independent fallback for corrupt variant failed")
        return

    var town: Script = load("res://starter_town.gd")
    if town == null or not town.can_instantiate():
        _fail("Starter Town no longer parses after saved-profile integration")
        return

    DirAccess.remove_absolute(abs_path)
    print("AETHERFALL_CHARACTER_PREFERENCES_OK: defaults, save/load, validation, recovery, town script parse")
    quit(0)


func _fail(reason: String) -> void:
    push_error("AETHERFALL_CHARACTER_PREFERENCES_FAIL: " + reason)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    quit(1)
