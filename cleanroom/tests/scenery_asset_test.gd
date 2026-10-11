extends SceneTree
## Tests the real imported replacements before an Android APK is exported.
const MODELS := [
    "House_1", "House_2", "House_3", "House_4", "Inn", "Blacksmith",
    "MarketStand_1", "MarketStand_2", "Stall_Empty", "Barrel",
    "Crate_Wooden", "FarmCrate_Apple", "Anvil", "Lantern_Wall",
    "BirchTree_1", "MapleTree_1", "Bush", "Bush_Large", "Bush_Flowers",
    "Grass_Small"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for asset in MODELS:
        var path := "res://models/scenery/" + String(asset) + ".glb"
        if not ResourceLoader.exists(path):
            push_error("AETHERFALL_SCENERY_FAIL: Missing " + path)
            quit(1)
            return
        var imported := load(path) as PackedScene
        if imported == null:
            push_error("AETHERFALL_SCENERY_FAIL: Import failed for " + path)
            quit(1)
            return
        var model := imported.instantiate()
        if not (model is Node3D):
            push_error("AETHERFALL_SCENERY_FAIL: Not a 3D scene: " + path)
            quit(1)
            return
        model.free()
    print("AETHERFALL_SCENERY_ASSETS_OK: 20 imported game-ready models")
    quit(0)
