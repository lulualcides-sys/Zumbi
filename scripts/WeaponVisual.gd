extends RefCounted
## Quaternius CC0 rifle follows the imported soldier's animated hand bones.
const RIFLE_PATH := "res://assets/cc0/rifle.gltf"
const ArmsIK = preload("res://scripts/ArmsIK.gd")
const RIFLE_OFFSET := Vector3(0.06, 0.65, 0.27)
const RIFLE_SCALE := 0.57

static func _metal(tint: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.58
    mat.roughness = 0.51
    if glow:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 2.8
    return mat

static func _box(parent: Node3D, at: Vector3, extents: Vector3, tint: Color) -> void:
    var instance := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = extents
    instance.mesh = shape
    instance.material_override = _metal(tint)
    instance.position = at
    parent.add_child(instance)

static func _fallback_rifle(root: Node3D) -> void:
    _box(root, Vector3(0, 0, 0.0), Vector3(0.14, 0.13, 0.48), Color("#232a2c"))
    _box(root, Vector3(0, 0, -0.28), Vector3(0.15, 0.19, 0.31), Color("#32393c"))
    _box(root, Vector3(0, 0.09, -0.05), Vector3(0.08, 0.12, 0.25), Color("#0a1215"))
    _box(root, Vector3(0, -0.15, 0.01), Vector3(0.09, 0.27, 0.12), Color("#343b40"))
    _box(root, Vector3(0, 0.0, 0.39), Vector3(0.07, 0.07, 0.43), Color("#1b2125"))

static func _grade_rifle(root: Node3D) -> void:
    var shader := load("res://shaders/rifle_gunmetal.gdshader") as Shader
    if shader == null:
        return
    var neutral := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
    neutral.fill(Color.WHITE)
    var white_tex: Texture2D = ImageTexture.create_from_image(neutral)
    for child in root.find_children("*", "MeshInstance3D", true, false):
        var visual := child as MeshInstance3D
        if visual.mesh == null:
            continue
        for surface in range(visual.mesh.get_surface_count()):
            var imported := visual.get_active_material(surface)
            var texture: Texture2D = white_tex
            if imported is BaseMaterial3D and imported.albedo_texture != null:
                texture = imported.albedo_texture
            var grade := ShaderMaterial.new()
            grade.shader = shader
            grade.set_shader_parameter("base_texture", texture)
            visual.set_surface_override_material(surface, grade)

static func _find_skeleton(root: Node) -> Skeleton3D:
    if root == null:
        return null
    if root is Skeleton3D:
        return root as Skeleton3D
    for child in root.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

static func _hand_index(skeleton: Skeleton3D, side: String) -> int:
    if skeleton == null:
        return -1
    for index in range(skeleton.get_bone_count()):
        var name := skeleton.get_bone_name(index).to_lower()
        var cleaned := name.replace("_", "").replace(":", "").replace(".", "").replace(" ", "")
        if side == "right":
            if "righthand" in cleaned or cleaned.ends_with("handr") or cleaned.ends_with("rhand"):
                return index
        else:
            if "lefthand" in cleaned or cleaned.ends_with("handl") or cleaned.ends_with("lhand"):
                return index
    return -1

static func attach(body: CharacterBody3D, character_art: Dictionary = {}) -> Dictionary:
    var holder := Node3D.new()
    holder.name = "BoneTrackedRifleMount"
    holder.position = RIFLE_OFFSET
    holder.rotation.x = -0.13
    body.add_child(holder)

    var weapon_visual := Node3D.new()
    weapon_visual.name = "GunVisualWithRecoil"
    holder.add_child(weapon_visual)

    var source_ok := false
    if ResourceLoader.exists(RIFLE_PATH):
        var packed := load(RIFLE_PATH) as PackedScene
        if packed != null:
            var model := packed.instantiate() as Node3D
            if model != null:
                model.name = "VisibleCC0Rifle"
                model.scale = Vector3.ONE * RIFLE_SCALE
                weapon_visual.add_child(model)
                _grade_rifle(model)
                source_ok = true
    if not source_ok:
        _fallback_rifle(weapon_visual)

    var muzzle := Marker3D.new()
    muzzle.name = "RealBarrelMuzzle"
    # GLTF barrel extends to +1.019 source units. Scale = 0.57.
    muzzle.position = Vector3(0.0, 0.03, 0.58)
    weapon_visual.add_child(muzzle)

    var muzzle_flash := MeshInstance3D.new()
    muzzle_flash.name = "MuzzleFlash"
    var shape := SphereMesh.new()
    shape.radius = 0.09
    shape.height = 0.17
    muzzle_flash.mesh = shape
    muzzle_flash.material_override = _metal(Color("#ffd08c"), true)
    muzzle_flash.visible = false
    muzzle.add_child(muzzle_flash)

    var skeleton := _find_skeleton(character_art.get("root"))
    var right_idx := _hand_index(skeleton, "right")
    var left_idx := _hand_index(skeleton, "left")
    if character_art.get("tactical", false):
        print("TACTICAL_HAND_BONES: right=", right_idx, " left=", left_idx,
              " skeleton=", skeleton.name if skeleton != null else "NONE")
        if skeleton != null and (right_idx < 0 or left_idx < 0):
            var names: Array[String] = []
            for i in range(skeleton.get_bone_count()):
                names.append(skeleton.get_bone_name(i))
            print("TACTICAL_BONE_LIST: ", names)
    var arm_ik := ArmsIK.attach(body, skeleton, holder)
    return {
        "arm_ik": arm_ik,
        "mount": holder,
        "visual": weapon_visual,
        "muzzle": muzzle,
        "flash": muzzle_flash,
        "source_ok": source_ok,
        "skeleton": skeleton,
        "right_hand": right_idx,
        "left_hand": left_idx,
        "base_offset": RIFLE_OFFSET
    }

static func align_to_hands(rig: Dictionary, body: CharacterBody3D, delta: float) -> void:
    if rig.get("arm_ik", {}).get("active", false):
        # Rifle remains shoulder-locked; IK moves both arms to the two grips.
        return
    var skeleton: Skeleton3D = rig.get("skeleton")
    var right_idx: int = rig.get("right_hand", -1)
    var left_idx: int = rig.get("left_hand", -1)
    var mount: Node3D = rig.get("mount")
    if skeleton == null or mount == null or right_idx < 0 or left_idx < 0:
        return
    var right_global: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(right_idx)).origin
    var left_global: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(left_idx)).origin
    var hands_mid: Vector3 = (right_global + left_global) * 0.5
    var target: Vector3 = body.to_local(hands_mid) + Vector3(0.0, -0.03, 0.18)
    target.x = clampf(target.x, -0.37, 0.37)
    target.y = clampf(maxf(target.y + 0.17, 0.57), 0.57, 1.03)
    target.z = clampf(target.z, -0.12, 0.65)
    mount.position = mount.position.lerp(target, minf(1.0, delta * 22.0))
    if not rig.get("first_alignment_logged", false):
        print("RIFLE_HAND_ALIGNMENT_LOCAL: ", target)
        rig["first_alignment_logged"] = true

static func animate_fire(rig: Dictionary) -> void:
    if rig.is_empty():
        return
    var visual: Node3D = rig.get("visual")
    var flash: MeshInstance3D = rig.get("flash")
    if visual == null or flash == null:
        return
    # Recoil only the gun mesh, never a fixed mount position: the mount follows
    # two moving hands through idle, walk and run animations.
    visual.position.z = -0.045
    flash.visible = true
    flash.scale = Vector3.ONE
    var recoil_tween := visual.create_tween()
    recoil_tween.tween_property(visual, "position:z", 0.0, 0.10)
    var fade := flash.create_tween()
    fade.tween_property(flash, "scale", Vector3.ZERO, 0.075)
    fade.tween_callback(func() -> void: flash.visible = false)
