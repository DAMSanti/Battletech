shader_type canvas_item;

// Depth map passed as texture uniform (red channel == normalized depth value)
uniform sampler2D depth_tex : hint_albedo;
// uv scale transforms SCREEN_UV into the depth texture UVs (depth_tex may be lower
// resolution than the main screen — we must map UVs accordingly).
uniform vec2 depth_uv_scale : hint_range(0.0, 4.0) = vec2(1.0, 1.0);
// Offset in normalized depth-tex UV space (dt_uv = SCREEN_UV*scale - offset)
uniform vec2 depth_uv_offset : hint_range(-1.0, 1.0) = vec2(0.0, 0.0);
uniform vec4 albedo : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float eps : hint_range(0.0, 0.1) = 0.001;  // Reduced epsilon for sharper occlusion
uniform float occlusion_hardness : hint_range(1.0, 5.0) = 2.0;  // Controls occlusion falloff
uniform float max_depth : hint_range(0.0, 10000.0) = 1000.0;  // Max depth for normalization
// Debug helper
uniform bool debug_visualize : hint_range(0,1) = false;

void fragment() {
    // Sample the offscreen depth texture using screen UV so we compare by screen pixel
    // Map SCREEN_UV into depth_tex coordinates
    vec2 dt_uv = SCREEN_UV * depth_uv_scale - depth_uv_offset;
    // Clamp so sampling doesn't sample outside
    dt_uv = clamp(dt_uv, vec2(0.0), vec2(1.0));
    float depth_val = texture(depth_tex, dt_uv).r;
    
    // ✅ Read DEPTH (not elevation) from UV.y (interpolated per-vertex)
    // UV.y now contains normalized depth = (y + height) / max_depth
    float surface_depth = UV.y;
    
    // If debug visualization is enabled, show sampled depth and surface depth
    // so we can visually compare them in the main view.
    if (debug_visualize) {
        COLOR = vec4(depth_val, surface_depth, 0.0, 1.0);
        return;
    }

    // ✅ Improved occlusion logic using real depth (y + height)
    // If depth buffer shows a higher depth value than surface, this pixel is occluded
    float depth_diff = depth_val - surface_depth;
    
    // Smooth transition for better edge handling
    if (depth_diff > eps) {
        // Apply hardness factor for steeper falloff
        float occlusion_factor = smoothstep(0.0, eps * occlusion_hardness, depth_diff);
        
        if (occlusion_factor > 0.5) {
            discard;  // Fully occluded
        }
        
        // Optional: could apply partial transparency for soft edges
        // COLOR = vec4(albedo.rgb, albedo.a * (1.0 - occlusion_factor));
        // but we use hard cutoff for now:
        if (occlusion_factor > 0.1) {
            discard;
        }
    }

    COLOR = albedo;
}
