shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = tex_color;
    COLOR.rgb = mix(COLOR.rgb, tint_color.rgb, tint_strength);
    COLOR.a *= tint_color.a;
}