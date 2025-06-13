shader_type canvas_item;

uniform float press_amount : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float highlight_intensity : hint_range(0.0, 1.0) = 0.2;
uniform vec2 press_offset = vec2(0.02, 0.02);

void fragment() {
    vec2 uv = UV;
    
    // Apply press offset
    vec2 pressed_uv = uv - press_offset * press_amount;
    
    // Sample the texture with offset
    vec4 tex_color = texture(TEXTURE, pressed_uv);
    
    // Create shadow effect (darken bottom-right)
    float shadow_mask = smoothstep(0.3, 1.0, uv.x + uv.y);
    vec3 shadow_color = tex_color.rgb * (1.0 - shadow_intensity * press_amount * shadow_mask);
    
    // Create highlight effect (brighten top-left)
    float highlight_mask = smoothstep(0.3, 1.0, (1.0 - uv.x) + (1.0 - uv.y));
    vec3 highlight_color = shadow_color + highlight_intensity * press_amount * highlight_mask;
    
    // Apply overall darkening when pressed
    vec3 final_color = mix(tex_color.rgb, highlight_color * 0.8, press_amount);
    
    // Handle UV coordinates outside texture bounds
    if (pressed_uv.x < 0.0 || pressed_uv.x > 1.0 || pressed_uv.y < 0.0 || pressed_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        COLOR = vec4(final_color, tex_color.a);
    }
}