extends RefCounted
## Geometria 3D original, sem assets externos. O eixo +Z e a frente do personagem.

static func material(color: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.83
    mat.metallic = metallic
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.3
    return mat

static func box(parent: Node3D, at: Vector3, size: Vector3, tint: Color, metallic: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var geom := BoxMesh.new()
    geom.size = size
    node.mesh = geom
    node.material_override = material(tint, metallic)
    node.position = at
    parent.add_child(node)
    return node

static func sphere(parent: Node3D, at: Vector3, radius: float, tint: Color, glow: bool = false) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var geom := SphereMesh.new()
    geom.radius = radius
    geom.height = radius * 2.0
    geom.radial_segments = 12
    geom.rings = 6
    node.mesh = geom
    node.material_override = material(tint, 0.0, glow)
    node.position = at
    parent.add_child(node)
    return node

static func joint(parent: Node3D, at: Vector3) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = at
    parent.add_child(pivot)
    return pivot

static func collision(body: CharacterBody3D, radius: float = 0.35) -> void:
    var hitbox := CollisionShape3D.new()
    var geom := CapsuleShape3D.new()
    geom.radius = radius
    geom.height = 1.65
    hitbox.shape = geom
    body.add_child(hitbox)

static func survivor(body: CharacterBody3D) -> Dictionary:
    collision(body)
    var root := Node3D.new()
    root.name = "SurvivorVisual"
    body.add_child(root)
    # Colete tatico, calcas, botas, capacete e mochila low-poly.
    box(root, Vector3(0, 0.05, 0), Vector3(0.67, 0.70, 0.43), Color("#59655f"))
    box(root, Vector3(0, 0.01, 0.27), Vector3(0.55, 0.53, 0.14), Color("#303f3a"))
    box(root, Vector3(-0.22, 0.21, 0.36), Vector3(0.17, 0.20, 0.13), Color("#a1a18a"))
    box(root, Vector3(0.22, 0.21, 0.36), Vector3(0.17, 0.20, 0.13), Color("#a1a18a"))
    box(root, Vector3(0, 0.05, -0.34), Vector3(0.60, 0.75, 0.27), Color("#394842"))
    box(root, Vector3(0, -0.35, 0), Vector3(0.57, 0.22, 0.39), Color("#3b4748"))
    sphere(root, Vector3(0, 0.55, 0), 0.245, Color("#c5c7b7"))
    box(root, Vector3(0, 0.56, 0.23), Vector3(0.40, 0.14, 0.06), Color("#111b1d"))
    box(root, Vector3(0, 0.76, 0.06), Vector3(0.48, 0.13, 0.48), Color("#dadbc9"))
    box(root, Vector3(-0.21, 0.52, 0), Vector3(0.07, 0.24, 0.25), Color("#c1c9be"))
    box(root, Vector3(0.21, 0.52, 0), Vector3(0.07, 0.24, 0.25), Color("#c1c9be"))
    var left_leg := joint(root, Vector3(-0.19, -0.39, 0))
    var right_leg := joint(root, Vector3(0.19, -0.39, 0))
    box(left_leg, Vector3(0, -0.24, 0), Vector3(0.25, 0.51, 0.27), Color("#445151"))
    box(right_leg, Vector3(0, -0.24, 0), Vector3(0.25, 0.51, 0.27), Color("#445151"))
    box(left_leg, Vector3(0, -0.49, 0.09), Vector3(0.29, 0.17, 0.40), Color("#24292b"))
    box(right_leg, Vector3(0, -0.49, 0.09), Vector3(0.29, 0.17, 0.40), Color("#24292b"))
    var left_arm := joint(root, Vector3(-0.42, 0.25, 0))
    var right_arm := joint(root, Vector3(0.42, 0.25, 0))
    box(left_arm, Vector3(0.03, -0.22, 0.14), Vector3(0.23, 0.51, 0.25), Color("#77857d"))
    box(right_arm, Vector3(-0.03, -0.22, 0.14), Vector3(0.23, 0.51, 0.25), Color("#77857d"))
    box(left_arm, Vector3(0.04, -0.40, 0.30), Vector3(0.20, 0.13, 0.28), Color("#b2ac95"))
    box(right_arm, Vector3(-0.04, -0.40, 0.30), Vector3(0.20, 0.13, 0.28), Color("#b2ac95"))
    # Arma de ficcao, nao a reproducao de um modelo real.
    box(root, Vector3(0.06, -0.02, 0.50), Vector3(0.20, 0.18, 0.77), Color("#1b2427"), 0.55)
    box(root, Vector3(0.06, -0.02, 0.92), Vector3(0.09, 0.09, 0.49), Color("#0c1215"), 0.7)
    box(root, Vector3(0.05, 0.11, 0.40), Vector3(0.13, 0.11, 0.34), Color("#242b2d"), 0.6)
    box(root, Vector3(0.06, -0.23, 0.38), Vector3(0.10, 0.38, 0.17), Color("#212829"), 0.4)
    var muzzle := Marker3D.new()
    muzzle.position = Vector3(0.06, -0.02, 1.16)
    root.add_child(muzzle)
    return {"visual":root, "left_leg":left_leg, "right_leg":right_leg, "left_arm":left_arm, "right_arm":right_arm, "muzzle":muzzle}

static func zombie(body: CharacterBody3D, variant: int = 0) -> Dictionary:
    collision(body, 0.36)
    var root := Node3D.new()
    root.name = "ZombieVisual"
    body.add_child(root)
    var coat := Color("#52624e")
    var skin := Color("#83947b")
    if variant == 1:
        coat = Color("#67635d")
        skin = Color("#849580")
    elif variant == 2:
        coat = Color("#455b67")
        skin = Color("#a2a38b")
    box(root, Vector3(0, 0.01, 0), Vector3(0.62, 0.68, 0.41), coat)
    box(root, Vector3(0, -0.32, 0), Vector3(0.53, 0.16, 0.35), Color("#383b39"))
    sphere(root, Vector3(0, 0.55, 0.08), 0.25, skin)
    box(root, Vector3(0, 0.47, 0.31), Vector3(0.36, 0.12, 0.05), Color("#404442"))
    sphere(root, Vector3(-0.105, 0.60, 0.307), 0.043, Color("#d3644e"), true)
    sphere(root, Vector3(0.105, 0.60, 0.307), 0.043, Color("#d3644e"), true)
    var left_leg := joint(root, Vector3(-0.17, -0.36, 0))
    var right_leg := joint(root, Vector3(0.17, -0.36, 0))
    box(left_leg, Vector3(0, -0.24, 0), Vector3(0.24, 0.53, 0.27), Color("#3d4845"))
    box(right_leg, Vector3(0, -0.24, 0), Vector3(0.24, 0.53, 0.27), Color("#3d4845"))
    var left_arm := joint(root, Vector3(-0.43, 0.25, 0))
    var right_arm := joint(root, Vector3(0.43, 0.25, 0))
    box(left_arm, Vector3(0, -0.17, 0.26), Vector3(0.22, 0.53, 0.24), coat)
    box(right_arm, Vector3(0, -0.17, 0.26), Vector3(0.22, 0.53, 0.24), coat)
    sphere(left_arm, Vector3(0, -0.44, 0.36), 0.12, skin)
    sphere(right_arm, Vector3(0, -0.44, 0.36), 0.12, skin)
    return {"visual":root, "left_leg":left_leg, "right_leg":right_leg, "left_arm":left_arm, "right_arm":right_arm}
