shader_type canvas_item;

// Brush-wipe transition with built-in zoom support
// cutoff 0.0 = fully visible new image; 1.0 = fully replaced
uniform float cutoff      : hint_range(0.0, 1.0) = 0.0;
uniform float smooth_size : hint_range(0.0, 1.0) = 0.12;
// zoom for new image: 1.0 = no zoom, >1.0 = zoom in
uniform float zoom        : hint_range(1.0, 3.0)  = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // Apply zoom to UV (scale around center)
    vec2 zoomed_uv = (UV - 0.5) / zoom + 0.5;
    COLOR = texture(TEXTURE, zoomed_uv);

    // Diagonal wipe mask (top-left → bottom-right)
    float diag = (UV.x + UV.y) * 0.5;
    vec2 bristle_uv = vec2(UV.x - UV.y, UV.x + UV.y) * vec2(20.0, 3.0);
    float n = fbm(bristle_uv);
    float value = diag + (n - 0.5) * 0.4;
    float mapped_cutoff = cutoff * 1.6 - 0.3;
    float alpha = smoothstep(value - smooth_size, value + smooth_size, mapped_cutoff);
    COLOR.a *= alpha;
}
