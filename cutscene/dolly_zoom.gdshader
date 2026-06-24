shader_type canvas_item;

// zoom > 1.0 = zoom in (dolly-in). Animate from 1.0 toward target.
uniform float zoom : hint_range(1.0, 3.0) = 1.0;

void fragment() {
    // Scale UV around center (0.5, 0.5)
    vec2 centered = UV - 0.5;
    vec2 zoomed   = centered / zoom + 0.5;

    // Sample the texture at zoomed UV
    COLOR = texture(TEXTURE, zoomed);
}
