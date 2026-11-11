shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 material_tint : source_color = vec4(1.0);
uniform vec4 palette_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);

void fragment() {
    vec4 source = texture(base_texture, UV) * material_tint;
    float detail = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    // Separate light armor plates from charcoal cloth, gloves and visor.
    // The source GLB exposes named material groups for these physical parts.
    ALBEDO = palette_color.rgb * (0.77 + 0.23 * clamp(detail, 0.0, 1.0));
    ROUGHNESS = 0.84;
    METALLIC = 0.04;
    ALPHA = source.a;
}
