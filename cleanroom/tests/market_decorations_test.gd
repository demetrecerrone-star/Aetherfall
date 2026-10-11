extends SceneTree
## Pass 4.2: only add missing wares around EXISTING market and retain the
## user's approved scenery, while keeping the marketplace and doors accessible.
const EXPECTED_STALLS := [
    "MarketStall_-540_-610", "MarketStall_540_-610",
    "MarketStall_-540_245", "MarketStall_540_245"
]

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Starter town could not be loaded")
        return
    var town := scene.instantiate() as Node3D
    root.add_child(town)
    for i in range(12):
        await process_frame
    var stalls := town.find_children("MarketStall_*", "Node3D", false, false)
    if stalls.size() != 4:
        _fail("Existing four market stalls changed count")
        return
    _print_native_stall_counter_probe(stalls[0] as Node3D)
    var good_count := 0
    for name in EXPECTED_STALLS:
        var stand := town.get_node_or_null(name) as Node3D
        if stand == null:
            _fail("Existing stall missing: " + name)
            return
        if stand.get_node_or_null("Quaternius_MarketStand_1") == null:
            _fail("Market stall replaced with a placeholder")
            return
        if String(stand.get_meta("market_wares_style", "")) != "plaza_facing_front_counter_display":
            _fail("Stall doesn't use current licensed crate assets: " + name)
            return
        var rack := stand.get_node_or_null("FrontCounterMerchandiseRack") as Node3D
        if rack == null or rack.get_node_or_null("OakDisplayShelf") == null:
            _fail("Visible oak display shelf missing on " + name)
            return
        if not rack.get_node_or_null("DisplayFrontLip") or not rack.get_node_or_null("ShelfSupport"):
            _fail("Merchandise rack is not supported or trimmed on " + name)
            return
        var shelf := rack.get_node_or_null("OakDisplayShelf") as MeshInstance3D
        if absf(float(stand.get_meta("market_wares_shelf_height_m", 0.0)) - 1.045) > 0.01:
            _fail("The shelf is still above the actual counter and near canopy")
            return
        if shelf == null or absf(shelf.position.z - 0.59) > 0.01 or shelf.position.y > 1.1:
            _fail("Display shelf must sit on the plaza-facing, LOW front counter")
            return
        if not bool(stand.get_meta("market_wares_canopy_clearance", false)):
            _fail("Market display does not guarantee clearance below its canopy")
            return
        var forward: Vector3 = stand.transform.basis * Vector3(0, 0, 1)
        var market_center := Vector2(0.0, -1.825)
        var toward_plaza := market_center - Vector2(stand.position.x, stand.position.z)
        if Vector2(forward.x, forward.z).dot(toward_plaza) <= 0.0:
            _fail("Stall front axis is not facing the market square: " + name)
            return
        for label in ["CounterStock_Primary", "CounterStock_Secondary", "CounterStock_Third"]:
            var stock := stand.get_node_or_null(label) as Node3D
            if stock == null or stock.get_child_count() < 1:
                _fail("Missing market goods: " + label + " in " + name)
                return
            if not bool(stock.get_meta("no_extra_collision", false)):
                _fail("Countertop merchandise changed solid stall footprint")
                return
            var expected_asset: String = str(stock.get_meta("model", ""))
            var imported := stock.get_node_or_null("Quaternius_" + expected_asset)
            if expected_asset not in ["Crate_Wooden", "FarmCrate_Apple"] or imported == null:
                _fail("Not using the genuine existing Quaternius goods: " + name)
                return
            if absf(stock.position.y - 1.075) > 0.015 or stock.position.z < 0.50:
                _fail("Crate is still too high / too far back, visually on the awning")
                return
            if stock.position.y + 0.40 >= 1.65:
                _fail("Merchandise silhouette is not well below the canopy")
                return
            good_count += 1
    if good_count != 12:
        _fail("Expected 12 low, plaza-facing goods across four stall shelves")
        return
    var additions := town.find_children("ShopStock_*", "Node3D", false, false)
    if not additions.is_empty():
        _fail("Phone-feedback: solitary crates must not be scattered through grass")
        return
    if town.find_children("TownBench_*", "Node3D", false, false).size() != 2:
        _fail("Existing two plaza benches changed")
        return
    if town.find_children("MedievalStreetLamp_*", "Node3D", false, false).size() != 4:
        _fail("Existing four lantern posts changed")
        return
    if town.find_children("Quaternius_Barrel", "Node3D", true, false).size() != 3:
        _fail("Existing three barrels changed, or new barrels were duplicated")
        return
    for path in ["ADVENTURERS GUILD", "BLACKSMITH", "THE INN", "GENERAL SHOP"]:
        var house := town.get_node_or_null(path) as Node3D
        if house == null or house.get_node_or_null("HangingShopSign") == null:
            _fail("Shop signage got lost during market decoration: " + path)
            return
        var door: Vector2 = house.get_meta("road_door_anchor", Vector2.ZERO)
        if bool(town.call("_world_point_blocked", door + Vector2(0, 0.65))):
            _fail("Supply stock obstructs an existing building entrance")
            return
    for access in [Vector2(0, -4.55), Vector2(0, 0.95),
        Vector2(-2.75, -1.825), Vector2(2.75, -1.825),
        Vector2(-3.4, -3.7), Vector2(3.4, -3.7)]:
        if bool(town.call("_world_point_blocked", access)):
            _fail("Market or fountain circulation has become blocked: " + str(access))
            return
    if int(town.get_meta("graphics_cached_meadow_batches", 0)) < 30:
        _fail("Existing MultiMesh grass optimization was lost")
        return
    if town.find_children("TownFountain", "Node3D", false, false).size() != 1:
        _fail("Original centered fountain missing")
        return
    print("AETHERFALL_MARKET_DECOR_OK: 12 original Quaternius crate wares below canopy on front-facing shelves, no grass crates, original decor and walks retained")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_MARKET_DECOR_FAIL: " + message)
    quit(1)

# One-time native geometry audit used to eliminate the wrongly inserted
# second table. Print approximate level bands of upward-facing surfaces.
func _print_native_stall_counter_probe(stall: Node3D) -> void:
    var imported := stall.get_node_or_null("Quaternius_MarketStand_1") as Node3D
    if imported == null:
        return
    print("AF_STALL_PROBE start imported_scale=", imported.scale,
        " imported_rotation=", imported.rotation_degrees, " imported_pos=", imported.position)
    var mesh_parts := imported.find_children("*", "MeshInstance3D", true, false)
    var by_level: Dictionary = {}
    for part in mesh_parts:
        var mesh_part := part as MeshInstance3D
        if mesh_part.mesh == null:
            continue
        var bound := mesh_part.get_aabb()
        var l0: Vector3 = stall.to_local(mesh_part.to_global(bound.position))
        var l1: Vector3 = stall.to_local(mesh_part.to_global(bound.end))
        print("AF_STALL_MESH name=", mesh_part.name, " surfaces=", mesh_part.mesh.get_surface_count(),
            " approx_local_bound=", l0, " through ", l1)
        for surface in range(mesh_part.mesh.get_surface_count()):
            var arrays := mesh_part.mesh.surface_get_arrays(surface)
            if arrays.is_empty():
                continue
            var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
            var tri_count := ids.size() / 3 if not ids.is_empty() else verts.size() / 3
            for tri in range(tri_count):
                var ia: int = ids[tri * 3] if not ids.is_empty() else tri * 3
                var ib: int = ids[tri * 3 + 1] if not ids.is_empty() else tri * 3 + 1
                var ic: int = ids[tri * 3 + 2] if not ids.is_empty() else tri * 3 + 2
                var a: Vector3 = stall.to_local(mesh_part.to_global(verts[ia]))
                var b: Vector3 = stall.to_local(mesh_part.to_global(verts[ib]))
                var c: Vector3 = stall.to_local(mesh_part.to_global(verts[ic]))
                var normal := (b - a).cross(c - a)
                if normal.length_squared() < 0.000001 or absf(normal.normalized().y) < 0.94:
                    continue
                var mean := (a + b + c) / 3.0
                if mean.y < 0.45 or mean.y > 1.7:
                    continue
                var height := roundi(mean.y * 20.0)
                var front := roundi(mean.z * 5.0)
                var key := "%s_%s" % [height, front]
                var prev: Dictionary = by_level.get(key, {"area": 0.0, "xmin": 100.0,
                    "xmax": -100.0, "zmin": 100.0, "zmax": -100.0})
                prev["area"] = float(prev["area"]) + normal.length() * 0.5
                prev["xmin"] = minf(float(prev["xmin"]), minf(a.x, minf(b.x, c.x)))
                prev["xmax"] = maxf(float(prev["xmax"]), maxf(a.x, maxf(b.x, c.x)))
                prev["zmin"] = minf(float(prev["zmin"]), minf(a.z, minf(b.z, c.z)))
                prev["zmax"] = maxf(float(prev["zmax"]), maxf(a.z, maxf(b.z, c.z)))
                by_level[key] = prev
    var records: Array = []
    for key in by_level.keys():
        var parts := String(key).split("_")
        var level := float(parts[0]) / 20.0
        var front := float(parts[1]) / 5.0
        var stats: Dictionary = by_level[key]
        if float(stats["area"]) >= 0.06:
            records.append({"level": level, "front": front,
                "area": snappedf(float(stats["area"]), 0.001),
                "xmin": stats["xmin"], "xmax": stats["xmax"],
                "zmin": stats["zmin"], "zmax": stats["zmax"]})
    records.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
        return float(x["area"]) > float(y["area"]))
    print("AF_STALL_COUNTER_SURFACE_PROBE_TOP=", records.slice(0, 24))
