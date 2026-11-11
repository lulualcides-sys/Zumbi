extends RefCounted
## Deterministic gritty street surface. Small baked CPU texture, not a paid asset.

static var _asphalt: Texture2D

static func asphalt_material(tint: Color, repeats: float = 8.0) -> StandardMaterial3D:
    if _asphalt == null:
        var grain := Image.create_empty(192, 192, false, Image.FORMAT_RGBA8)
        var noise := FastNoiseLite.new()
        noise.seed = 14597
        noise.frequency = 0.055
        noise.fractal_type = FastNoiseLite.FRACTAL_FBM
        noise.fractal_octaves = 3
        var cracks := FastNoiseLite.new()
        cracks.seed = 734
        cracks.frequency = 0.012
        for y in range(192):
            for x in range(192):
                var broad := noise.get_noise_2d(float(x), float(y))
                var fine := float((x * 37 + y * 67) % 31) / 31.0 - 0.5
                var fracture := absf(cracks.get_noise_2d(float(x), float(y)))
                var detail := clampf(0.91 + 0.035 * broad + 0.017 * fine - 0.020 * (1.0 - smoothstep(0.0, 0.13, fracture)), 0.82, 0.98)
                grain.set_pixel(x, y, Color(detail, detail * 0.99, detail * 0.98, 1.0))
        _asphalt = ImageTexture.create_from_image(grain)
    var material := StandardMaterial3D.new()
    material.albedo_texture = _asphalt
    material.albedo_color = tint
    material.roughness = 0.95
    material.uv1_scale = Vector3(repeats, repeats, 1.0)
    return material
