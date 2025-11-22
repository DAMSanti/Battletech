shader_type canvas_item;

void fragment() {
    // Read elevation from the modulate color (R channel)
    // The renderer will set polygon.modulate = Color(elev_norm, elev_norm, elev_norm, 1.0)
    float v = MODULATE.r;
    COLOR = vec4(v, v, v, 1.0);
}

