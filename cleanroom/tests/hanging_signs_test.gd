extends SceneTree
## Pass 4.1 regression: four ORIGINAL symbol-first overhead shop signs
## replace old facade labels and don't change doors, camera or collision.
const EXPECTED := {
    "ADVENTURERS GUILD": ["shield_crossed_swords", "res://signs/guild.svg"],
    "BLACKSMITH": ["hammer_anvil", "res://signs/blacksmith.svg"],
    "THE INN": ["foaming_tankard", "res://signs/inn.svg"],
    "GENERAL SHOP": ["crate_supply_sack", "res://signs/supplies.svg"],
}

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var packed := load("res://starter_town.tscn") as PackedScene
    if packed == null:
        _fail("Starter town scene not importable")
        return
    var town := packed.instantiate() as Node3D
    root.add_child(town)
    for i in range(12):
        await process_frame
    var icons := {}
    for title in EXPECTED:
        var building := town.get_node_or_null(title) as Node3D
        if building == null:
            _fail("Missing existing landmark building " + title)
            return
        if building.get_node_or_null("ShopSign") != null or building.get_node_or_null("Label3D") != null:
            _fail("Old flat/floating sign was not removed on " + title)
            return
        if not bool(building.get_meta("shop_sign_replaced", false)):
            _fail("Landmark does not report new signage: " + title)
            return
        var sign := building.get_node_or_null("HangingShopSign") as Node3D
        if sign == null:
            _fail("No physical hanging sign on " + title)
            return
        if not bool(sign.get_meta("pass4_1_hanging_sign", false)) or not bool(sign.get_meta("projecting_bracket", false)):
            _fail("Sign is missing its physical hanging mount: " + title)
            return
        if not bool(sign.get_meta("facing_plaza", false)):
            _fail("Hanging sign must be visible from the plaza: " + title)
            return
        if float(sign.get_meta("doorway_clearance_y", 0.0)) < 2.28:
            _fail("Sign hangs too low in adventurer walkway: " + title)
            return
        var size: Vector3 = building.get_meta("scenery_model_size", Vector3.ZERO)
        if size.z <= 0.0 or sign.position.z < size.z * 0.50:
            _fail("Shop bracket is hidden inside the building facade: " + title)
            return
        var side := 1.0 if building.position.x < 0.0 else -1.0
        if sign.position.x * side < 1.0:
            _fail("Sign is not offset toward market side of facade: " + title)
            return
        if sign.get_node_or_null("WallMount") == null or sign.get_node_or_null("ProjectingIronArm") == null:
            _fail("Hanging sign has no visible bracket: " + title)
            return
        if sign.get_node_or_null("CarvedWoodBoard") == null:
            _fail("Hanging sign is just a text label: " + title)
            return
        for name in ["PaintedEmblem_Front", "PaintedEmblem_Back"]:
            var icon := sign.get_node_or_null(name) as Sprite3D
            if icon == null or icon.texture == null:
                _fail("Missing real SVG emblem " + name + " at " + title)
                return
        var symbol: String = sign.get_meta("symbol", "")
        var file: String = sign.get_meta("icon_path", "")
        var spec: Array = EXPECTED[title]
        if symbol != spec[0] or file != spec[1]:
            _fail("Incorrect bespoke shop emblem on " + title)
            return
        if icons.has(file):
            _fail("Different shops should not repeat icon texture " + file)
            return
        icons[file] = true
        var anchor: Vector2 = building.get_meta("road_door_anchor", Vector2.ZERO)
        if bool(town.call("_world_point_blocked", anchor + Vector2(0, 0.6))):
            _fail("Shop's public doorway path is blocked " + title)
            return
    for residential in town.find_children("House_*", "Node3D", false, false):
        if residential.get_node_or_null("HangingShopSign") != null:
            _fail("Residential house unnecessarily received a commercial sign")
            return
    if town.get_node_or_null("GatehouseSign") == null:
        _fail("Town gate sign should not be removed with shop signs")
        return
    print("AETHERFALL_HANGING_SIGNS_OK: four unique readable guild/forge/inn/supply emblems, physical hanging brackets, no flat labels, safe footpaths")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_HANGING_SIGNS_FAIL: " + message)
    quit(1)
