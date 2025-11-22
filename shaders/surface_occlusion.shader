shader_type canvas_item;

// Depth map for occlusion
uniform sampler2D depth_tex : filter_linear_mipmap, repeat_disable;
uniform vec2 depth_uv_scale = vec2(1.0, 1.0);
uniform vec2 depth_uv_offset = vec2(0.0, 0.0);

// Albedo texture
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_disable;
uniform int use_albedo_texture = 0;

// Occlusion parameters
uniform float eps = 0.001;
uniform float occlusion_hardness = 2.0;

void fragment() {
    // Sample the depth texture using screen UV
    vec2 dt_uv = SCREEN_UV * depth_uv_scale - depth_uv_offset;
    dt_uv = clamp(dt_uv, vec2(0.0), vec2(1.0));
    float depth_val = texture(depth_tex, dt_uv).r;
    
    // Read depth from UV.y (interpolated per-vertex)
    float surface_depth = UV.y;
    
    // Occlusion check
    float depth_diff = depth_val - surface_depth;
    if (depth_diff > eps) {
        float occlusion_factor = smoothstep(0.0, eps * occlusion_hardness, depth_diff);
        if (occlusion_factor > 0.1) {
            discard;
        }
    }

    // Use texture if available, otherwise use polygon color
    vec4 final_color = COLOR;
    if (use_albedo_texture > 0) {
        final_color = texture(albedo_tex, UV);
    }
    
    COLOR = final_color;
}
