shader_type canvas_item;

// Depth texture for occlusion testing
uniform sampler2D depth_tex : filter_nearest, repeat_disable;

// Normal map texture (optional)
uniform sampler2D normal_map : filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = false;

// Fallback color when no texture is assigned
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Surface normal direction for lighting (flat surfaces)
uniform vec3 surface_normal = vec3(0.0, 0.0, 1.0);

// Current surface depth (0.0 to 1.0, normalized)
uniform float surface_depth = 0.0;

// Lighting parameters
uniform vec3 light_direction = vec3(-0.707, 0.0, 0.707);  // Light from west (normalized)
uniform vec3 light_color = vec3(1.0, 0.95, 0.9);  // Warm white light
uniform float ambient_intensity = 0.4;  // Ambient light strength
uniform float diffuse_intensity = 0.6;  // Directional light strength

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
    
    // If texture sampling returns near-transparent OR default white, use the fallback color
    // When Polygon2D.texture is null, Godot returns white (1,1,1,1)
    // When there's an actual texture but it's transparent, alpha will be low
    if (albedo.a < 0.01 || (albedo.rgb == vec3(1.0, 1.0, 1.0) && albedo.a == 1.0)) {
        albedo = albedo_color;
    }
    
    // Calculate depth UV (map from screen space to depth texture space)
    vec2 depth_uv = FRAGCOORD.xy / vec2(textureSize(depth_tex, 0));
    depth_uv = depth_uv * depth_uv_scale + depth_uv_offset;
    
    // Sample depth texture (red channel contains normalized depth)
    float stored_depth = texture(depth_tex, depth_uv).r;
    
    // Use the uniform surface_depth instead of reading from UV
    float current_depth = surface_depth;
    
    // TEMPORARILY DISABLE occlusion to debug textures
    // Occlusion test: discard if current fragment is behind stored depth
    // float depth_diff = current_depth - stored_depth;
    // if (depth_diff < -occlusion_eps) {
    //     discard;
    // }
    
    // Apply soft falloff at occlusion boundaries
    // float occlusion_factor = smoothstep(-occlusion_eps, occlusion_eps, depth_diff);
    // occlusion_factor = pow(occlusion_factor, occlusion_hardness);
    float occlusion_factor = 1.0;  // No occlusion for now
    
    // === NORMAL MAPPING AND LIGHTING ===
    vec3 normal = surface_normal;  // Use the uniform surface normal
    
    if (use_normal_map) {
        // Sample normal map and convert from [0,1] to [-1,1]
        vec3 normal_sample = texture(normal_map, UV).rgb;
        normal = normalize(normal_sample * 2.0 - 1.0);
    }
    
    // Calculate diffuse lighting (Lambertian)
    float diffuse = max(dot(normal, light_direction), 0.0);
    
    // Combine ambient + diffuse
    vec3 lighting = (ambient_intensity + diffuse * diffuse_intensity) * light_color;
    
    // Apply lighting to albedo
    vec3 lit_color = albedo.rgb * lighting;
    
    // Debug visualization: show depth as color
    if (debug_visualize) {
        COLOR = vec4(current_depth, stored_depth, 0.0, 1.0);
    } else {
        // Combine lit color with occlusion
        COLOR = vec4(lit_color, albedo.a) * occlusion_factor;
    }
}
