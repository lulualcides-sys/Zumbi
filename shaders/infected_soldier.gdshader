shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 material_tint : source_color = vec4(1.0);
uniform vec4 palette_color : source_color = vec4(0.4, 0.45, 0.4, 1.0);

float dirt(vec2 uv) {
    return fract(sin(dot(floor(uv * 33.0), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 source = texture(base_texture, UV) * material_tint;
    float detail = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 dull_cloth = palette_color.rgb * (0.75 + 0.25 * clamp(detail, 0.0, 1.0));
    float stain = smoothstep(0.82, 0.94, dirt(UV)) * 0.35;
    ALBEDO = mix(dull_cloth, vec3(0.26, 0.10, 0.11), stain);
    ROUGHNESS = 0.94;
    METALLIC = 0.02;
    ALPHA = source.a;
}
