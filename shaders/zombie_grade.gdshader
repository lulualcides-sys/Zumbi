shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec3 grade_tint : source_color = vec3(0.62, 0.74, 0.66);
uniform float desaturation : hint_range(0.0, 1.0) = 0.74;

void fragment() {
    vec4 original = texture(base_texture, UV);
    float luminance = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 muted = mix(original.rgb, vec3(luminance), desaturation);
    ALBEDO = clamp(muted * grade_tint, 0.0, 1.0);
    ROUGHNESS = 0.86;
    METALLIC = 0.0;
    ALPHA = original.a;
}
