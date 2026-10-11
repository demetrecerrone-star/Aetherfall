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
        if String(stand.get_meta("market_wares_style", "")) != "curated_existing_quaternius_crates":
            _fail("Stall doesn't use current licensed crate assets: " + name)
            return
        for label in ["CounterStock_Primary", "CounterStock_Secondary"]:
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
            if absf(stock.position.y - 1.18) > 0.01:
                _fail("Merchandise isn't placed on the existing stall counter")
                return
            good_count += 1
    if good_count != 8:
        _fail("Expected exactly eight curated wares across four market stalls")
        return
    var additions := town.find_children("ShopStock_*", "Node3D", false, false)
    if additions.size() != 2:
        _fail("Expected two restrained shop-side stock piles, not new clutter")
        return
    for stock in additions:
        var node := stock as Node3D
        var asset: String = str(node.get_meta("model", ""))
        if node.get_node_or_null("Quaternius_" + asset) == null:
            _fail("Loose shop stock must use the existing CC0 scenery pack")
            return
        if not bool(town.call("_world_point_blocked",
                Vector2(node.position.x, node.position.z))):
            _fail("New grounded crate can be walked through")
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
    print("AETHERFALL_MARKET_DECOR_OK: 8 authentic stall wares, 2 shop crates, old barrels/benches/lamps retained, plaza clear")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_MARKET_DECOR_FAIL: " + message)
    quit(1)
