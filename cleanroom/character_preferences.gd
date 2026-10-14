extends RefCounted
## Durable character-preview choices shared by Starter Town and future Configura studio.
## Does not store meshes, skin weights, secrets, or depend on either GLB.
const SAVE_PATH := "user://aetherfall_character_profile.cfg"
const VALID_VARIANTS := ["male", "female"]
const VALID_IDLE_POSES := ["standing_relax", "idle", "look_around"]
const SCHEMA_VERSION := 1


static func load_profile(path: String = SAVE_PATH) -> Dictionary:
    var data := {"variant": "male", "idle_pose": "standing_relax"}
    var config := ConfigFile.new()
    if config.load(path) != OK:
        return data
    var variant: String = str(config.get_value("character", "variant", data["variant"]))
    var idle_pose: String = str(config.get_value("character", "idle_pose", data["idle_pose"]))
    # Recover individual fields independently if the save is old or edited.
    if variant in VALID_VARIANTS:
        data["variant"] = variant
    if idle_pose in VALID_IDLE_POSES:
        data["idle_pose"] = idle_pose
    return data


static func save_profile(variant: String, idle_pose: String,
        path: String = SAVE_PATH) -> bool:
    if not variant in VALID_VARIANTS or not idle_pose in VALID_IDLE_POSES:
        push_warning("Aetherfall character save rejected invalid values.")
        return false
    var config := ConfigFile.new()
    config.set_value("profile", "schema_version", SCHEMA_VERSION)
    config.set_value("character", "variant", variant)
    config.set_value("character", "idle_pose", idle_pose)
    var err := config.save(path)
    if err != OK:
        push_warning("Aetherfall character profile not saved: %d" % err)
    return err == OK
