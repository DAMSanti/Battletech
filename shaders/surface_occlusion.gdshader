shader_type canvas_item;

// Depth texture for occlusion testing
uniform sampler2D depth_tex : filter_nearest, repeat_disable;

// Fallback color when no texture is assigned
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Current surface depth (0.0 to 1.0, normalized)
uniform float surface_depth = 0.0;

// Debug visualization
uniform bool debug_visualize = false;

// UV mapping parameters for depth texture
uniform vec2 depth_uv_scale = vec2(1.0, 1.0);
uniform vec2 depth_uv_offset = vec2(0.0, 0.0);

// Occlusion parameters
uniform float occlusion_eps = 0.001;
uniform float occlusion_hardness = 2.0;

void fragment() {
    // Sample the albedo texture using UV coordinates
    // TEXTURE is the built-in texture sampler for Polygon2D.texture
    vec4 albedo = texture(TEXTURE, UV);
    
    // If texture sampling returns near-transparent, use the fallback color
    if (albedo.a < 0.01) {
        albedo = albedo_color;
    }
    
    // Calculate depth UV (map from screen space to depth texture space)
    vec2 depth_uv = FRAGCOORD.xy / vec2(textureSize(depth_tex, 0));
    depth_uv = depth_uv * depth_uv_scale + depth_uv_offset;
    
    // Sample depth texture (red channel contains normalized depth)
    float stored_depth = texture(depth_tex, depth_uv).r;
    
    // Use the uniform surface_depth instead of reading from UV
    float current_depth = surface_depth;
    
    // Occlusion test: discard if current fragment is behind stored depth
    float depth_diff = current_depth - stored_depth;
    if (depth_diff < -occlusion_eps) {
        discard;
    }
    
    // Apply soft falloff at occlusion boundaries
    float occlusion_factor = smoothstep(-occlusion_eps, occlusion_eps, depth_diff);
    occlusion_factor = pow(occlusion_factor, occlusion_hardness);
    
    // Debug visualization: show depth as color
    if (debug_visualize) {
        COLOR = vec4(current_depth, stored_depth, 0.0, 1.0);
    } else {
        // Combine albedo with occlusion
        COLOR = albedo * occlusion_factor;
        COLOR.a = albedo.a * occlusion_factor;
    }
}
