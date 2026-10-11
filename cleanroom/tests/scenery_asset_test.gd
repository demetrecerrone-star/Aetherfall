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
    # Regression: correct the real source mesh and verify the merchandise
    # platform has no vertices left at its original raised shelf height.
    var stand_scene := load("res://models/scenery/MarketStand_1.glb") as PackedScene
    var stand := stand_scene.instantiate() as Node3D
    var town_script := load("res://starter_town.gd") as GDScript
    var town := town_script.new() as Node3D
    var adjusted: bool = town._align_imported_stall_display_with_desk(stand)
    var wood := stand.find_child("Wood", true, false) as MeshInstance3D
    if not adjusted or wood == null:
        push_error("AETHERFALL_SCENERY_FAIL: Unable to lower market display platform.")
        stand.free()
        town.free()
        quit(1)
        return
    var vertices: PackedVector3Array = wood.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var raised := 0
    var desk_level := 0
    for point in vertices:
        if point.y > 0.42 and point.y < 0.54:
            raised += 1
        if point.y > 0.22 and point.y < 0.27:
            desk_level += 1
    stand.free()
    town.free()
    if raised != 0 or desk_level < 620:
        push_error("AETHERFALL_SCENERY_FAIL: Market platform floats above desk (raised=%d desk=%d)" % [raised, desk_level])
        quit(1)
        return
    print("AETHERFALL_MARKET_STALL_DESK_OK: elevated shelf lowered flush to desk")
    print("AETHERFALL_SCENERY_ASSETS_OK: 20 imported game-ready models")
    quit(0)
