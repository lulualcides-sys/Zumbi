shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Same high-detail humanoid skeleton as the survivor, with weathered,
// blood-stained tactical cloth instead of neon/cartoon colored zombies.
uniform sampler2D base_texture : source_color, filter_linear_mipmap;

float dirt(vec2 uv) {
    return fract(sin(dot(floor(uv * 27.0), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 cloth = texture(base_texture, UV);
    float value = dot(cloth.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 ash = vec3(0.29, 0.34, 0.34) + vec3(0.10, 0.11, 0.10) * value;
    vec3 base = mix(cloth.rgb * vec3(0.57, 0.62, 0.58), ash, 0.70);
    float stain = smoothstep(0.65, 0.86, dirt(UV)) * (0.25 + 0.35 * value);
    ALBEDO = mix(base, vec3(0.26, 0.10, 0.10), stain);
    ROUGHNESS = 0.96;
    METALLIC = 0.01;
    ALPHA = cloth.a;
}
