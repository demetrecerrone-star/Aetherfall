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
    # Regression for the screenshot report: the imported shelf is low
    # storage; a visible, supported waist-height service counter must remain.
    var stall_preview := Node3D.new()
    town = town_script.new() as Node3D
    town._add_vendor_service_counter(stall_preview)
    var countertop := stall_preview.get_node_or_null("VendorCountertop") as MeshInstance3D
    var goods := stall_preview.get_node_or_null("VendorGoodsTray") as MeshInstance3D
    var apron := stall_preview.get_node_or_null("VendorCounterFrontApron") as MeshInstance3D
    if countertop == null or goods == null or apron == null:
        push_error("AETHERFALL_SCENERY_FAIL: Service counter or goods missing")
        stall_preview.free()
        town.free()
        quit(1)
        return
    var counter_mesh := countertop.mesh as BoxMesh
    var counter_top_y := countertop.position.y + counter_mesh.size.y * 0.5
    var goods_mesh := goods.mesh as BoxMesh
    var goods_bottom_y := goods.position.y - goods_mesh.size.y * 0.5
    if counter_top_y < 0.98 or counter_top_y > 1.07 or absf(goods_bottom_y - counter_top_y) > 0.05:
        push_error("AETHERFALL_SCENERY_FAIL: Desk height or merchandise placement incorrect")
        stall_preview.free()
        town.free()
        quit(1)
        return
    stall_preview.free()
    town.free()
    print("AETHERFALL_VENDOR_COUNTER_OK: standing-height desk, supports, goods on top")
    print("AETHERFALL_MARKET_STALL_DESK_OK: elevated shelf lowered flush to desk")
    print("AETHERFALL_SCENERY_ASSETS_OK: 20 imported game-ready models")
    quit(0)
