shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
void fragment() {
    vec4 albedo = texture(base_texture, UV);
    float lum = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
    // Raise only cloth/armor medium values. Black visor, undersuit and
    // tactical pockets remain darker: desaturated white/gray near reference.
    float armor = smoothstep(0.09, 0.33, lum);
    vec3 white_fabric = vec3(0.85, 0.88, 0.90) * (0.83 + 0.17 * lum);
    ALBEDO = mix(albedo.rgb, white_fabric, armor * 0.90);
    ROUGHNESS = 0.89;
    METALLIC = 0.03;
    ALPHA = albedo.a;
}
