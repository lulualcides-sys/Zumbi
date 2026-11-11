extends RefCounted
## Rifle 3D real Quaternius CC0, sempre visivel no peito/maos do soldado.
## O glTF Rifle tem cano ao longo do eixo +Z (bounding box verificado).
## Sem dependencias de redes em tempo de execucao.
const RIFLE_PATH := "res://assets/cc0/rifle.gltf"
# Raise receiver to the animated tactical rifle-ready pose; previous mount was hip-high.
const RIFLE_OFFSET := Vector3(0.09, 0.56, 0.43)
const RIFLE_SCALE := 0.82

static func _metal(tint: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.65
    mat.roughness = 0.48
    if glow:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 3.5
    return mat

static func _box(parent: Node3D, at: Vector3, extents: Vector3, tint: Color) -> void:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = extents
    mesh.mesh = shape
    mesh.material_override = _metal(tint)
    mesh.position = at
    parent.add_child(mesh)

static func _fallback_rifle(root: Node3D) -> void:
    # Only visible when the CC0 glTF has not been installed in a local clone.
    # Made of multiple parts to read as a weapon rather than a rectangle.
    _box(root, Vector3(0, 0, 0.13), Vector3(0.17, 0.17, 0.86), Color("#23292d"))
    _box(root, Vector3(0, 0.01, -0.30), Vector3(0.19, 0.20, 0.43), Color("#323a3b"))
    _box(root, Vector3(0, 0.13, 0.03), Vector3(0.11, 0.14, 0.33), Color("#0a1215"))
    _box(root, Vector3(0, -0.19, 0.05), Vector3(0.11, 0.38, 0.16), Color("#343b40"))
    _box(root, Vector3(0, -0.02, 0.70), Vector3(0.08, 0.08, 0.82), Color("#1b2125"))
    _box(root, Vector3(0, 0.08, 0.33), Vector3(0.16, 0.06, 0.35), Color("#5a6267"))

static func _grade_rifle(model: Node3D) -> void:
    var shader := load("res://shaders/rifle_gunmetal.gdshader") as Shader
    if shader == null:
        return
    for node in model.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null:
            continue
        for surface in range(mesh.mesh.get_surface_count()):
            var material := mesh.get_active_material(surface)
            var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
            image.fill(Color.WHITE)
            var source_tex: Texture2D = ImageTexture.create_from_image(image)
            if material is BaseMaterial3D and material.albedo_texture != null:
                source_tex = material.albedo_texture
            var grade := ShaderMaterial.new()
            grade.shader = shader
            grade.set_shader_parameter("base_texture", source_tex)
            mesh.set_surface_override_material(surface, grade)

static func attach(body: CharacterBody3D) -> Dictionary:
    var holder := Node3D.new()
    holder.name = "VisibleRifleMount"
    holder.position = RIFLE_OFFSET
    # Tilt barrel into the imported rifle-ready hand pose; previous weapon
    # pointed toward the ground despite the arms being raised.
    holder.rotation.x = -0.28
    body.add_child(holder)

    var source_ok := false
    if ResourceLoader.exists(RIFLE_PATH):
        var packed := load(RIFLE_PATH) as PackedScene
        if packed != null:
            var model := packed.instantiate() as Node3D
            if model != null:
                model.name = "VisibleCC0Rifle"
                model.scale = Vector3.ONE * RIFLE_SCALE
                holder.add_child(model)
                _grade_rifle(model)
                source_ok = true
    if not source_ok:
        _fallback_rifle(holder)

    # Rifle.gltf barrel extends to +1.019 (asset-space units).
    # Offset and scale use the same coordinate system as the gameplay trace.
    var muzzle := Marker3D.new()
    muzzle.name = "RealBarrelMuzzle"
    muzzle.position = Vector3(0.0, 0.05, 0.92)
    holder.add_child(muzzle)

    var muzzle_flash := MeshInstance3D.new()
    muzzle_flash.name = "MuzzleFlash"
    var flash_shape := SphereMesh.new()
    flash_shape.radius = 0.13
    flash_shape.height = 0.23
    muzzle_flash.mesh = flash_shape
    muzzle_flash.material_override = _metal(Color("#ffd388"), true)
    muzzle_flash.position = Vector3.ZERO
    muzzle_flash.visible = false
    muzzle.add_child(muzzle_flash)
    return {
        "mount": holder,
        "muzzle": muzzle,
        "flash": muzzle_flash,
        "source_ok": source_ok,
        "base_offset": RIFLE_OFFSET
    }

static func animate_fire(rig: Dictionary) -> void:
    if rig.is_empty():
        return
    var mount: Node3D = rig.get("mount")
    var flash: MeshInstance3D = rig.get("flash")
    if mount == null or flash == null:
        return
    mount.position.z = RIFLE_OFFSET.z - 0.12
    flash.visible = true
    flash.scale = Vector3.ONE
    # Any previous flash tween may still be running; new muzzle flashes
    # remain subtle and each new shot resets the size immediately.
    var tween := mount.create_tween()
    tween.tween_property(mount, "position:z", RIFLE_OFFSET.z, 0.10)
    var fade := flash.create_tween()
    fade.tween_property(flash, "scale", Vector3.ZERO, 0.065)
    fade.tween_callback(func() -> void: flash.visible = false)
