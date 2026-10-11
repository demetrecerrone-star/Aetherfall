extends SceneTree
## Verify the actual CC0 glTF pack is imported and used in the starter town.
const NatureReplacement = preload("res://nature_replacements.gd")
const REQUIRED := [
    "Bush_Common", "Bush_Common_Flowers",
    "Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5",
    "CommonTree_1", "CommonTree_2", "CommonTree_3",
    "Grass_Common_Short", "Grass_Wispy_Short", "Fern_1", "Clover_1"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for name in REQUIRED:
        if not NatureReplacement.available(name):
            _fail("Optimized model missing: " + name)
            return
        var scene := load("res://models/nature/" + name + ".glb") as PackedScene
        if scene == null:
            _fail("Unable to import model: " + name)
            return
        var obj := scene.instantiate() as Node3D
        if obj == null:
            _fail("Not a Node3D model: " + name)
            return
        root.add_child(obj)
        var bounds := NatureReplacement._bounds(obj)
        if bounds.size.length() < 0.1:
            _fail("Invalid glTF mesh bounds: " + name)
            return
        obj.free()

    var native_grass := NatureReplacement.grass_mesh()
    if native_grass == null or native_grass.get_surface_count() == 0:
        _fail("Real short-grass mesh failed to load")
        return
    var blades := native_grass.get_faces().size() / 3
    if blades < 20 or blades > 190:
        _fail("Native grass is outside mobile triangle budget")
        return

    var packed := load("res://starter_town.tscn") as PackedScene
    if packed == null:
        _fail("Starter town could not load")
        return
    var town := packed.instantiate()
    root.add_child(town)
    for i in range(10):
        await process_frame
    if not bool(town.get_meta("nature_pack_loaded", false)):
        _fail("Native models were available but not activated in town")
        return
    if not bool(town.get_meta("grass_nature_model_loaded", false)):
        _fail("Grass Field still uses procedural vegetation")
        return
    if String(town.get_meta("grass_style", "")) != "quaternius_textured_short_grass":
        _fail("The new grass style was not applied")
        return

    var planted_hedges := town.find_children("TownHedge_*", "Node3D", true, false)
    var actual_hedges := 0
    for hedge in planted_hedges:
        if bool((hedge as Node3D).get_meta("nature_hedge_imported", false)):
            actual_hedges += 1
    if actual_hedges < 5:
        _fail("Real hedge bushes were not substituted into the landscape")
        return

    var pines := town.find_children("PineTree_*", "Node3D", true, false)
    if pines.size() < 3:
        _fail("Not enough genuine pine trees")
        return
    for pine in pines:
        if String((pine as Node3D).get_meta("foliage_style", "")) != "textured_nature_pine":
            _fail("One pine is a procedural placeholder")
            return
        if (pine as Node3D).find_children("QuaterniusNature_Pine_*", "Node3D", true, false).is_empty():
            _fail("Pine textured geometry missing")
            return

    var broadleaf := town.find_children("BroadleafTree_*", "Node3D", true, false)
    if broadleaf.size() < 5:
        _fail("Lost broadleaf tree variety")
        return
    for tree in broadleaf:
        if String((tree as Node3D).get_meta("nature_asset", "")).begins_with("CommonTree_"):
            continue
        _fail("Broadleaf used old tree geometry instead of MegaKit")
        return

    print("AETHERFALL_NATURE_ASSETS_OK: 14 optimized models, textured trees, hip-high hedges, real lawn grass")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_NATURE_ASSETS_FAIL: " + message)
    quit(1)
