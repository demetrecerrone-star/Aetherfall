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
        if counter_mesh == null or counter_mesh.size.x < 1.90 or counter_mesh.size.x > 2.00:
            _fail("The desk must span the frame without protruding past its side posts")
            return
        # User's one-foot lowering request: original desk top was Y=1.020.
        # Shift the whole selling assembly down 0.305 m to Y=0.715.
        var measured_desk_y := counter.position.y + counter_mesh.size.y * 0.5
        if absf(measured_desk_y - 0.715) > 0.008:
            _fail("The service desk has not been lowered by one foot: " + name)
            return
        if absf(fascia.position.y - 0.555) > 0.008:
            _fail("The selling counter's front apron was not lowered together: " + name)
            return
        # The desktop front must be visibly INSIDE the imported front posts
        # (native post line is approximately +0.79m), not sticking into plaza.
        var front_edge := counter.position.z + counter_mesh.size.z * 0.5
        if front_edge < 0.48 or front_edge > 0.55:
            _fail("Selling desk must be inset within the stall frame: " + name)
            return
        var fascia_mesh := fascia.mesh as BoxMesh
        if fascia_mesh == null or fascia_mesh.size.y > 0.15:
            _fail("Bulky freestanding-looking front fascia returned: " + name)
            return
        if absf(fascia.position.z - (front_edge - 0.025)) > 0.02:
            _fail("Front trim must remain attached to inset desktop: " + name)
            return
        for ledger_node in ledgers:
            var ledger := ledger_node as MeshInstance3D
            var ledger_mesh := ledger.mesh as BoxMesh
            if ledger_mesh == null or ledger_mesh.size.z < 1.45:
                _fail("Structural support no longer reaches native stall posts: " + name)
                return
            if absf(ledger.position.y - 0.530) > 0.008:
                _fail("The support braces must move down with the counter: " + name)
                return
        if absf(float(stand.get_meta("market_counter_top_m", -1.0)) - 0.715) > 0.008:
            _fail("Stall counter height metadata must follow the new lowered desk: " + name)
            return
        if absf(float(stand.get_meta("market_wares_shelf_height_m", -1.0)) - 0.715) > 0.008:
            _fail("Merchandise anchor metadata must match the actual desk: " + name)
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
            var desk_surface_y := counter.position.y + counter_mesh.size.y * 0.5
            # Use the actual fitted Quaternius mesh dimensions, not just the
            # requested box. A resting crate may never float above the desk.
            var stock_mesh_size: Vector3 = stock.get_meta("scenery_model_size", Vector3.ZERO)
            if absf(stock.position.y - desk_surface_y) > 0.008 or absf(stock.position.z - 0.04) > 0.015:
                _fail("Merchandise is not flush to the inset service desk: " + name)
                return
            # Every stock crate must be completely supported by the desktop.
            if absf(stock.position.x) + stock_mesh_size.x * 0.5 > counter_mesh.size.x * 0.5 + 0.005:
                _fail("Merchandise projects past the sides of the selling counter: " + name)
                return
            if absf(stock.position.z - counter.position.z) + stock_mesh_size.z * 0.5 > counter_mesh.size.z * 0.5 + 0.005:
                _fail("Merchandise overhangs the countertop: " + name)
                return
            if stock_mesh_size.y < 0.08 or stock_mesh_size.y > 0.218:
                _fail("Merchant stock too tall or too small for the existing desk: " + name)
                return
            # The imported stand's nearest canopy mesh starts around Y=1.284,
            # including its low eaves. Preserve at least 4 cm of free space.
            if stock.position.y + stock_mesh_size.y > 1.244:
                _fail("Merchandise protrudes into the Quaternius stall roof: " + name)
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
    print("AETHERFALL_MARKET_DECOR_OK: 4 in-frame merchant counters and all 12 goods lowered one foot to Y=0.715m; fountain, nature, paths intact")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_MARKET_DECOR_FAIL: " + message)
    quit(1)

