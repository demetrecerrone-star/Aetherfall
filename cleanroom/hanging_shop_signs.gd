extends RefCounted
## Pass 4.1: bespoke, symbol-first, suspended medieval signs.
## Art is four small authored vector textures imported by Godot. Signs are
## ornamental overhead meshes; player/camera blockers stay unmodified.
const ICONS := {
    "ADVENTURERS GUILD": "res://signs/guild.svg",
    "BLACKSMITH": "res://signs/blacksmith.svg",
    "THE INN": "res://signs/inn.svg",
    "GENERAL SHOP": "res://signs/supplies.svg",
}
const SYMBOLS := {
    "ADVENTURERS GUILD": "shield_crossed_swords",
    "BLACKSMITH": "hammer_anvil",
    "THE INN": "foaming_tankard",
    "GENERAL SHOP": "crate_supply_sack",
}
const DARK_IRON := Color("#373b38")
const WARM_IRON := Color("#a58556")
const WOOD_DARK := Color("#4b3023")

static func place(house: Node3D, title: String, fitted_size: Vector3) -> Node3D:
    if not ICONS.has(title):
        return null
    var texture_path: String = ICONS[title]
    var texture := load(texture_path) as Texture2D
    if texture == null:
        push_error("AETHERFALL_HANGING_SIGN_TEXTURE_MISSING: " + texture_path)
        return null

    var sign := Node3D.new()
    sign.name = "HangingShopSign"
    # The left landmark buildings hang on their market-facing right corner;
    # right-side shops hang on their market-facing left corner.
    var side := 1.0 if house.position.x < 0.0 else -1.0
    sign.position = Vector3(side * fitted_size.x * 0.275, 0.0,
        fitted_size.z * 0.5 + 0.03)
    house.add_child(sign)

    var guild := title == "ADVENTURERS GUILD"
    var smith := title == "BLACKSMITH"
    var inn := title == "THE INN"
    var board_height := 1.01 if guild else (0.93 if inn else 0.88)
    var board_width := 1.47 if guild else (1.29 if smith else 1.22)
    var board_y := 3.02 if guild else 2.95
    var board_z := 0.82
    var bracket_y := board_y + board_height * 0.5 + 0.71

    var wood := Color("#46382f") if guild else (
        Color("#4a332a") if smith else (
        Color("#886041") if inn else Color("#735339")))
    var trim_color := Color("#c29e62") if guild or inn else Color("#85796c")
    var plank_mat := _material(wood)
    var plank_light := _material(wood.lightened(0.09))
    var iron_mat := _material(DARK_IRON, 0.66)
    var trim_mat := _material(trim_color, 0.45)

    # A real wall plate and a projecting forged arm, not a flat facade label.
    _block(sign, "WallMount", Vector3(0.23, 0.39, 0.075),
        Vector3(0, bracket_y - 0.11, 0.03), iron_mat)
    _block(sign, "ProjectingIronArm", Vector3(0.084, 0.092, board_z + 0.43),
        Vector3(0, bracket_y, (board_z + 0.43) * 0.5), iron_mat)
    _block(sign, "BracketCurl", Vector3(0.13, 0.09, 0.23),
        Vector3(0, bracket_y + 0.08, board_z + 0.20), trim_mat)
    # Diagonal wall brace beneath the arm for a convincing working bracket.
    _block(sign, "IronDiagonalBrace", Vector3(0.067, 0.76, 0.073),
        Vector3(0, bracket_y - 0.28, 0.30), iron_mat, Vector3(-30, 0, 0))

    var chain_x := 0.0
    var top_y := board_y + board_height * 0.5
    for i in [-1, 1]:
        var chain_z := board_z + float(i) * board_width * 0.33
        var chain_length := bracket_y - top_y + 0.05
        _block(sign, "IronHangingLink_%s" % str(i), Vector3(0.044, chain_length, 0.044),
            Vector3(chain_x, (bracket_y + top_y) * 0.5, chain_z), iron_mat)
        _block(sign, "ForgedHangingEye_%s" % str(i), Vector3(0.09, 0.10, 0.09),
            Vector3(0, top_y + 0.02, chain_z), trim_mat)

    # Vertical two-sided board perpendicular to the facade, facing the plaza
    # from either approach direction; slight arch/taper on the inn's lower rim.
    var board := _block(sign, "CarvedWoodBoard",
        Vector3(0.16, board_height, board_width),
        Vector3(0, board_y, board_z), plank_mat)
    board.set_meta("sign_is_projecting", true)
    _block(sign, "CarvedBorderTop", Vector3(0.19, 0.065, board_width + 0.018),
        Vector3(0, board_y + board_height * 0.5 - 0.027, board_z), trim_mat)
    _block(sign, "CarvedBorderBottom", Vector3(0.19, 0.065, board_width + 0.018),
        Vector3(0, board_y - board_height * 0.5 + 0.027, board_z), trim_mat)
    for end_sign in [-1.0, 1.0]:
        _block(sign, "CarvedEndTrim", Vector3(0.20, board_height - 0.11, 0.055),
            Vector3(0, board_y, board_z + end_sign * board_width * 0.5), plank_light)
    # Separate mounting studs make the wooden plaque look attached to its frame.
    for face in [-1.0, 1.0]:
        for end_sign in [-1.0, 1.0]:
            _block(sign, "IronSignStud", Vector3(0.035, 0.052, 0.052),
                Vector3(face * 0.102, board_y,
                    board_z + end_sign * (board_width * 0.5 - 0.08)), trim_mat)

    if inn:
        _block(sign, "InnRoundedLowerEdge", Vector3(0.17, 0.075, board_width * 0.68),
            Vector3(0, board_y - board_height * 0.5 - 0.03, board_z), plank_light)
    if guild:
        _block(sign, "GuildFormalLowerTrim", Vector3(0.18, 0.09, board_width * 0.59),
            Vector3(0, board_y - board_height * 0.5 - 0.075, board_z), trim_mat)

    # Two icon faces so the emblem reads from either side of the hanging board.
    # We deliberately omit large lettering; symbols are legible at mobile zoom.
    for face in [-1, 1]:
        var art := Sprite3D.new()
        art.name = "PaintedEmblem_Front" if face == 1 else "PaintedEmblem_Back"
        art.texture = texture
        art.pixel_size = board_height * 0.80 / 512.0
        art.position = Vector3(float(face) * 0.100, board_y, board_z)
        art.rotation_degrees.y = 90.0 * float(face)
        art.shaded = true
        art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        sign.add_child(art)

    sign.set_meta("shop_category", title)
    sign.set_meta("symbol", SYMBOLS[title])
    sign.set_meta("icon_path", texture_path)
    sign.set_meta("facing_plaza", true)
    sign.set_meta("doorway_clearance_y", board_y - board_height * 0.5 - (0.075 if guild else 0.0))
    sign.set_meta("projecting_bracket", true)
    sign.set_meta("pass4_1_hanging_sign", true)
    house.set_meta("shop_sign_replaced", true)
    return sign


static func _material(colour: Color, metal: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = colour
    mat.metallic = metal
    mat.roughness = 0.85 if metal < 0.1 else 0.48
    return mat


static func _block(parent: Node3D, label: String, dimensions: Vector3,
        location: Vector3, material: Material,
        orientation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = material
    instance.position = location
    instance.rotation_degrees = orientation
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance
