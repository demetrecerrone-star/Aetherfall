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
    var good_count := 0
    for name in EXPECTED_STALLS:
        var stand := town.get_node_or_null(name) as Node3D
        if stand == null:
            _fail("Existing stall missing: " + name)
            return
        if stand.get_node_or_null("Quaternius_MarketStand_1") == null:
            _fail("Market stall replaced with a placeholder")
            return
        if String(stand.get_meta("market_wares_style", "")) != "single_integrated_market_counter":
            _fail("Stall still has an inserted display table instead of an integral counter: " + name)
            return
        if stand.get_node_or_null("FrontCounterMerchandiseRack") != null or stand.get_node_or_null("RaisedMerchandiseRack") != null:
            _fail("Extra freestanding display table survived removal: " + name)
            return
        var counter := stand.get_node_or_null("IntegratedMerchantCountertop") as MeshInstance3D
        var fascia := stand.get_node_or_null("IntegratedCounterFrontFascia") as MeshInstance3D
        var ledgers := stand.find_children("IntegratedPostLedger_*", "MeshInstance3D", false, false)
        if counter == null or fascia == null or ledgers.size() != 2:
            _fail("One integrated merchant counter must be physically joined to the native stall posts: " + name)
            return
        var counter_mesh := counter.mesh as BoxMesh
        if counter_mesh == null or counter_mesh.size.x < 2.05:
            _fail("Built-in counter does not reach imported stall frame width")
            return
        if absf((counter.position.y + counter_mesh.size.y * 0.5) - 1.02) > 0.012:
            _fail("Merchandise surface is not one integrated waist-height counter")
            return
        if absf((counter.position.z + counter_mesh.size.z * 0.5) - 0.785) > 0.015:
            _fail("Integral counter front doesn't reach native stall post line")
            return
        if absf(fascia.position.z - 0.755) > 0.01:
            _fail("Integral counter fascia is not tied to the front stall pillars")
            return
        if not bool(stand.get_meta("market_counter_frame_integrated", false)):
            _fail("Counter is not marked structural; old second-table approach may return")
            return
        if bool(stand.get_meta("native_stall_has_counter", true)):
            _fail("Test incorrectly assumes imported market model already has a waist-height counter")
            return
        if not bool(stand.get_meta("market_wares_canopy_clearance", false)):
            _fail("Market goods clearance under canopy lost")
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
            if absf(stock.position.y - 1.025) > 0.01 or absf(stock.position.z - 0.23) > 0.015:
                _fail("Crate is not resting on the single integrated counter")
                return
            if stock.position.y + 0.35 >= 1.50:
                _fail("Crate intersects roof-edge clearance region")
                return
            good_count += 1
    if good_count != 12:
        _fail("Expected 12 items on built-in counters across four stalls")
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
    print("AETHERFALL_MARKET_DECOR_OK: 12 Quaternius crate wares directly on native-frame-integrated counters, zero extra tables/grass crates, original decor and paths retained")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_MARKET_DECOR_FAIL: " + message)
    quit(1)

