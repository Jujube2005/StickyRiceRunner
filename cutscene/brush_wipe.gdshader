shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 1.0) = 0.0;
uniform float smooth_size : hint_range(0.0, 1.0) = 0.12;

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
    for(int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // Diagonal wipe axis: top-left → bottom-right
    // Mixing UV.x and UV.y gives a 45-degree diagonal
    float diag = (UV.x + UV.y) * 0.5;

    // Streaky noise along the diagonal to mimic bristles
    // Rotate UV 45° for bristle direction perpendicular to wipe
    vec2 bristle_uv = vec2(UV.x - UV.y, UV.x + UV.y) * vec2(20.0, 3.0);
    float n = fbm(bristle_uv);

    // Add noise offset to create jagged brush edges
    float value = diag + (n - 0.5) * 0.4;

    // Map cutoff (0 to 1) to cover the full noisy range
    float mapped_cutoff = cutoff * 1.6 - 0.3;

    // Smooth transition at the edge
    float alpha = smoothstep(value - smooth_size, value + smooth_size, mapped_cutoff);

    COLOR.a *= alpha;
}
