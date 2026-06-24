shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 1.0) = 0.0;
uniform float smooth_size : hint_range(0.0, 1.0) = 0.15;

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
    // Streaky horizontal noise to look like bristles
    vec2 n_uv = UV * vec2(3.0, 25.0);
    float n = fbm(n_uv);
    
    // Wipe progresses from left to right (UV.x)
    // Add noise offset to create jagged brush edges
    float value = UV.x + (n - 0.5) * 0.5;
    
    // Map cutoff (0 to 1) to cover the entire noisy range (-0.3 to 1.3 roughly)
    float mapped_cutoff = cutoff * 1.6 - 0.3;
    
    // Smooth transition at the edge
    float alpha = smoothstep(value - smooth_size, value + smooth_size, mapped_cutoff);
    
    COLOR.a *= alpha;
}
