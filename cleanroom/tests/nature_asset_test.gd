extends SceneTree
## Verify the actual CC0 glTF pack is imported and used in the starter town.
const NatureReplacement = preload("res://nature_replacements.gd")
const REQUIRED := [
    "Bush_Common", "Bush_Common_Flowers",
    "Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5",
    "CommonTree_1", "CommonTree_2", "CommonTree_3",
    "Grass_Common_Short", "Grass_Wispy_Short", "Fern_1", "Clover_1",
    "Flower_3_Group", "Flower_4_Group"
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

    # Bush_Common ships with red Leaves_TwistedTree in the Standard archive.
    # Verify the *embedded bitmap pixels*, not merely a green material tint:
    # a green multiply of the red source still produced red bushes in Pass 5.
    var shrub_scene := load("res://models/nature/Bush_Common.glb") as PackedScene
    if shrub_scene == null:
        _fail("Dark-green Bush_Common model failed to import")
        return
    var shrub := shrub_scene.instantiate() as Node3D
    root.add_child(shrub)
    var opaque_leaf_pixels := 0
    for visual in NatureReplacement._mesh_nodes(shrub):
        if visual.mesh == null:
            continue
        for surface in range(visual.mesh.get_surface_count()):
            var material := visual.get_active_material(surface) as StandardMaterial3D
            if material == null or material.albedo_texture == null:
                continue
            var leaf_image := material.albedo_texture.get_image()
            if leaf_image == null:
                _fail("Cannot read the imported shrub leaf bitmap")
                return
            for px in range(0, leaf_image.get_width(), 13):
                for py in range(0, leaf_image.get_height(), 13):
                    var leaf := leaf_image.get_pixel(px, py)
                    if leaf.a < 0.85:
                        continue
                    opaque_leaf_pixels += 1
                    if not (leaf.g > leaf.r * 1.14 and leaf.g > leaf.b * 1.06):
                        _fail("Bush_Common still embeds red instead of dark-green foliage pixels")
                        return
    shrub.free()
    if opaque_leaf_pixels < 25:
        _fail("No opaque foliage samples were found in the shrub texture")
        return

    for plant_model in ["Grass_Common_Short", "Grass_Wispy_Short", "Clover_1", "Fern_1"]:
        var native_grass := NatureReplacement.grass_mesh(plant_model)
        if native_grass == null or native_grass.get_surface_count() == 0:
            _fail("Real meadow groundcover mesh missing: " + plant_model)
            return
        var triangles := native_grass.get_faces().size() / 3
        if triangles < 20 or triangles > 600:
            _fail("Groundcover outside per-instance Android geometry budget: " + plant_model)
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
    if String(town.get_meta("grass_style", "")) != "quaternius_mixed_fantasy_meadow":
        _fail("The four-species fantasy meadow mix was not applied")
        return
    var species: Array = town.get_meta("grass_species_counts", [])
    if species.size() != 4 or int(species[1]) < 500 or int(species[2]) < 150 or int(species[3]) < 1:
        _fail("Actual wispy grass, clover and sparse ferns are not being instanced")
        return
    var flowers := town.find_children("WildflowerPatch_*", "Node3D", true, false)
    if flowers.size() < 12:
        _fail("The additional grass-bed flowers did not spawn")
        return
    for flower in flowers:
        var plant := flower as Node3D
        if not bool(town.call("_flower_patch_fits_lawn", plant.position, 0.45)):
            _fail("At least one genuine flower cluster is on a cobbled road")
            return
        if String(plant.get_meta("flower_group_asset", "")).is_empty():
            _fail("Flower is missing its Quaternius model reference")
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

    print("AETHERFALL_NATURE_ASSETS_OK: 16 CC0 plants, textured trees, green hedges, real flower groups and four-species meadow")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_NATURE_ASSETS_FAIL: " + message)
    quit(1)
