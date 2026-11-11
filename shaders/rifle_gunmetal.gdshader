shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
void fragment() {
    vec4 albedo = texture(base_texture, UV);
    float detail = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
    ALBEDO = vec3(0.11, 0.135, 0.15) + vec3(0.20, 0.215, 0.23) * clamp(detail, 0.0, 1.0);
    ROUGHNESS = 0.55;
    METALLIC = 0.50;
    ALPHA = albedo.a;
}
