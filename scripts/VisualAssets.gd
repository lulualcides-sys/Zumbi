extends RefCounted
## Import and animate CC0 Quaternius GLTF models with a procedural fallback.
const MODEL_ROOT := "res://assets/cc0/"
const TACTICAL_SOLDIER := "res://assets/tactical/soldier.glb"

static func _path(kind: String, variation: int = 0) -> String:
    if kind == "survivor":
        return MODEL_ROOT + "survivor.gltf"
    var choices := ["zombie_basic.gltf", "zombie_chubby.gltf", "zombie_ribcage.gltf"]
    return MODEL_ROOT + choices[posmod(variation, choices.size())]

static func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

static func attach_character(body: CharacterBody3D, existing_rig: Dictionary, kind: String, variation: int = 0) -> Dictionary:
    var path := _path(kind, variation)
    if kind == "survivor" and ResourceLoader.exists(TACTICAL_SOLDIER):
        path = TACTICAL_SOLDIER
    if not ResourceLoader.exists(path):
        return {}
    var packed := load(path) as PackedScene
    if packed == null:
        push_warning("CC0 asset is not a PackedScene: " + path)
        return {}
    var model := packed.instantiate() as Node3D
    if model == null:
        push_warning("CC0 asset does not have a Node3D root: " + path)
        return {}
    model.name = "Art_CC0_" + kind
    model.position = Vector3(0.0, -0.87, 0.0)
    if path == TACTICAL_SOLDIER:
        model.name = "TacticalSoldierAnimated"
    body.add_child(model)
    var old_visual: Node3D = existing_rig.get("visual")
    if old_visual != null:
        old_visual.visible = false
    var animator := _find_animation_player(model)
    var available: Array[String] = []
    if animator != null:
        for name in animator.get_animation_list():
            available.append(str(name))
        if available.size() > 0:
            animator.play(available[0])
    return {"root": model, "player": animator, "animations": available, "active": "", "path": path, "tactical": path == TACTICAL_SOLDIER}

static func animate(rig: Dictionary, state: String, running: bool = false) -> void:
    if rig.is_empty():
        return
    var player: AnimationPlayer = rig.get("player")
    if player == null:
        return
    var names: Array = rig.get("animations", [])
    var preferred: Array = []
    match state:
        "walk":
            preferred = ["run_gun", "run", "sprint", "jog", "walk"] if running else ["walk_gun", "walk", "jog", "run"]
        "attack":
            preferred = ["shoot", "fire", "attack", "rifle"]
        "death":
            preferred = ["death", "die", "dead"]
        _:
            preferred = ["idle_gun", "idle", "breath", "stand"]
    var chosen := ""
    for prefix in preferred:
        for name in names:
            if prefix in str(name).to_lower():
                chosen = str(name)
                break
        if chosen != "":
            break
    if chosen == "":
        return
    if rig.get("active", "") == chosen and player.is_playing():
        return
    rig["active"] = chosen
    player.play(chosen, 0.16, 1.22 if running else 1.0)

static func add_prop(parent: Node3D, filename: String, where: Vector3, scale_factor: float = 1.0, y_rotation: float = 0.0) -> Node3D:
    var allowed := ["barrel.gltf", "pallet.gltf", "traffic_barrier.gltf", "container_green.gltf"]
    if not allowed.has(filename):
        return null
    var path := MODEL_ROOT + filename
    if not ResourceLoader.exists(path):
        return null
    var packed := load(path) as PackedScene
    if packed == null:
        return null
    var prop := packed.instantiate() as Node3D
    if prop == null:
        return null
    prop.name = "CC0_" + filename.trim_suffix(".gltf")
    parent.add_child(prop)
    prop.position = where
    prop.rotation.y = y_rotation
    prop.scale = Vector3.ONE * scale_factor
    return prop
