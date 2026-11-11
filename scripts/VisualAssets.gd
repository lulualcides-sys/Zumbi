extends RefCounted
## Import and animate CC0 Quaternius GLTF models with a procedural fallback.
const MODEL_ROOT := "res://assets/cc0/"
const TACTICAL_SOLDIER := "res://assets/tactical/soldier.glb"
const INFECTED_SOLDIER := "res://assets/tactical/infected.glb"

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

static var _white_texture: Texture2D

static func _neutral_texture() -> Texture2D:
    if _white_texture == null:
        var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _white_texture = ImageTexture.create_from_image(img)
    return _white_texture

static func _surface_palette(material_name: String, infected: bool) -> Color:
    var key := material_name.to_lower()
    if infected:
        match key:
            "soldier_armor": return Color("#5b6662")
            "soldier_clothes": return Color("#434b49")
            "soldier_fabric": return Color("#353b3b")
            "soldier_iron", "soldier_metal": return Color("#333e41")
            "soldier_elements": return Color("#4c4d44")
            "soldier_flesh", "soldier_skin": return Color("#788376")
            "soldier_shoes", "soldier_boots": return Color("#292e2d")
            "soldier_glass": return Color("#151c1c")
            _: return Color("#4b5551")
    match key:
        "soldier_armor": return Color("#dee5e9")
        "soldier_clothes": return Color("#34373c")
        "soldier_fabric": return Color("#34383d")
        "soldier_iron": return Color("#454d55")
        "soldier_metal": return Color("#555e64")
        "soldier_elements": return Color("#252b30")
        "soldier_flesh", "soldier_skin": return Color("#867f76")
        "soldier_shoes", "soldier_boots": return Color("#22262b")
        "soldier_glass": return Color("#101820")
        _: return Color("#737b81")

static func _grade_character(root: Node3D, shader_path: String) -> void:
    # Earlier releases silently kept the imported materials unchanged because
    # the original meshes use untextured materials on several surfaces.
    # Every surface now gets a shader, with source albedo color as fallback.
    var shader := load(shader_path) as Shader
    if shader == null:
        push_error("VISUAL_MATERIAL_FAILED: shader missing: " + shader_path)
        return
    var count := 0
    for node in root.find_children("*", "MeshInstance3D", true, false):
        var visual := node as MeshInstance3D
        if visual.mesh == null:
            continue
        for surface in range(visual.mesh.get_surface_count()):
            var original := visual.get_active_material(surface)
            var tint := Color.WHITE
            var texture: Texture2D = _neutral_texture()
            if original is BaseMaterial3D:
                var imported := original as BaseMaterial3D
                tint = imported.albedo_color
                if imported.albedo_texture != null:
                    texture = imported.albedo_texture
            var graded := ShaderMaterial.new()
            graded.shader = shader
            graded.set_shader_parameter("base_texture", texture)
            graded.set_shader_parameter("material_tint", tint)
            graded.set_shader_parameter("palette_color", _surface_palette(original.resource_name if original != null else "", root.name == "InfectedSoldierAnimated"))
            visual.set_surface_override_material(surface, graded)
            count += 1
    root.set_meta("graded_surfaces", count)
    print("VISUAL_MATERIALS_APPLIED: ", root.name, " surfaces=", count)

static func attach_character(body: CharacterBody3D, existing_rig: Dictionary, kind: String, variation: int = 0) -> Dictionary:
    var path := _path(kind, variation)
    # Infected tactical humans match the detail and silhouette of the player.
    # Avoid mixing a realistic soldier with cartoon Quaternius zombie models.
    if kind == "survivor" and ResourceLoader.exists(TACTICAL_SOLDIER):
        path = TACTICAL_SOLDIER
    elif kind == "zombie":
        if ResourceLoader.exists(INFECTED_SOLDIER):
            path = INFECTED_SOLDIER
        elif ResourceLoader.exists(TACTICAL_SOLDIER):
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
    if path == TACTICAL_SOLDIER or path == INFECTED_SOLDIER:
        model.name = "TacticalSoldierAnimated" if kind == "survivor" else "InfectedSoldierAnimated"
        if kind == "zombie":
            var height_scale: float = float([0.92, 1.01, 1.09][posmod(variation, 3)])
            model.scale = Vector3(1.0, height_scale, 1.0)
    body.add_child(model)
    if kind == "zombie":
        _grade_character(model, "res://shaders/infected_soldier.gdshader")
    elif path == TACTICAL_SOLDIER:
        _grade_character(model, "res://shaders/tactical_armor.gdshader")
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
    return {"root": model, "player": animator, "animations": available, "active": "", "path": path,
            "tactical": path == TACTICAL_SOLDIER and kind == "survivor",
            "infected": (path == TACTICAL_SOLDIER or path == INFECTED_SOLDIER) and kind == "zombie"}

static func animate(rig: Dictionary, state: String, running: bool = false) -> void:
    if rig.is_empty():
        return
    var player: AnimationPlayer = rig.get("player")
    if player == null:
        return
    var available: Array = rig.get("animations", [])
    var tactical: bool = rig.get("tactical", false)
    var infected: bool = rig.get("infected", false)
    var preferred: Array = []
    match state:
        "walk":
            if infected:
                preferred = ["run", "mocap_walk_F", "walk"] if running else ["walk", "mocap_walk_F", "run"]
            elif tactical:
                preferred = ["ready_run", "aim_run", "run", "mocap_run_F"] if running else ["ready_walk", "aim_walk", "walk", "mocap_walk_F"]
            else:
                preferred = ["run_gun", "run", "walk_gun", "walk"] if running else ["walk_gun", "walk", "run"]
        "attack":
            preferred = ["melee", "hit", "walk"] if infected else ["shoot", "aim_idle", "ready_idle", "idle_gun", "idle"]
        "death":
            preferred = ["death", "die", "dead"]
        "reload":
            preferred = ["reload", "aim_idle", "idle_gun", "idle"]
        _:
            preferred = ["idle", "walk"] if infected else (["aim_idle", "ready_idle", "idle", "idle_gun"] if tactical else ["idle_gun", "idle", "stand"])

    # First select exact clip names; do not match "idle" inside "aim_crouch_idle".
    # A substring selector made the soldier crouch even while standing still.
    var chosen := ""
    for requested in preferred:
        for name in available:
            var clean := str(name).to_lower()
            clean = clean.substr(clean.rfind("/") + 1)
            if clean == str(requested).to_lower():
                chosen = str(name)
                break
        if chosen != "":
            break
    if chosen == "":
        for requested in preferred:
            for name in available:
                var clean := str(name).to_lower()
                if str(requested).to_lower() in clean and not ("crouch" in clean and state != "crouch"):
                    chosen = str(name)
                    break
            if chosen != "":
                break
    if chosen == "":
        return
    if rig.get("active", "") == chosen and player.is_playing():
        return
    rig["active"] = chosen
    player.play(chosen, 0.18, 1.13 if running else 1.0)

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
