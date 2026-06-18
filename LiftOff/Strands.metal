#include <metal_stdlib>
using namespace metal;

// Must match StrandsUniforms in StrandsView.swift exactly
struct StrandsUniforms {
    float time;
    float _pad;
    float2 resolution;
    float4 colors[8];   // w component unused
    int colorCount;
    int strandCount;
    float speed;
    float amplitude;
    float waviness;
    float thickness;
    float glow;
    float taper;
    float spread;
    float hueShift;
    float intensity;
    float opacity;
    float scale;
    float saturation;
};

struct VertexOut {
    float4 position [[position]];
};

// Fullscreen triangle — no vertex buffer needed
vertex VertexOut strands_vertex(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
    VertexOut out;
    out.position = float4(pos[vid], 0, 1);
    return out;
}

float3 samplePalette(float t, constant float4* colors, int count) {
    t = fract(t);
    float scaled = t * float(count);
    int idx  = int(floor(scaled)) % count;
    int next = (idx + 1) % count;
    return mix(colors[idx].rgb, colors[next].rgb, fract(scaled));
}

fragment half4 strands_fragment(VertexOut in [[stage_in]],
                                constant StrandsUniforms& u [[buffer(0)]]) {
    const float PI = 3.14159265;

    float2 uv = (in.position.xy - 0.5 * u.resolution) / u.resolution.y;
    uv /= max(u.scale, 0.0001);

    float e   = 0.06 + u.intensity * 0.94;
    float env = pow(max(cos(uv.x * PI * 1.3), 0.0), u.taper);

    float3 col = float3(0);

    for (int i = 0; i < 12; i++) {
        if (i >= u.strandCount) break;

        float fi  = float(i);
        float ph  = fi * 1.7 * u.spread;
        float freq = (2.0 + fi * 0.35) * u.waviness;
        float spd  = 1.4 + fi * 1.2;
        float tt   = u.time * u.speed;

        float w = sin(uv.x * freq + tt * spd + ph) * 0.60
                + sin(uv.x * freq * 1.1 - tt * spd * 0.7 + ph * 1.7) * 0.40;

        float amp   = (0.1 + 0.02 * e) * env * u.amplitude;
        float y     = w * amp;
        float d     = abs(uv.y - y);
        float thick = (0.001 + 0.05 * e) * (0.35 + env) * u.thickness;
        float g     = thick / (d + thick * 0.45);
        g *= g;

        float h = fi / float(u.strandCount) + uv.x * 0.30 + u.time * 0.04 + u.hueShift;
        float3 c = u.colorCount > 0
            ? samplePalette(h, u.colors, u.colorCount)
            : 0.5 + 0.5 * cos(2.0 * PI * (h + float3(0.0, 0.33, 0.67)));

        col += c * g * env;
    }

    col  = 1.0 - exp(-col * u.glow);
    float gray = dot(col, float3(0.2126, 0.7152, 0.0722));
    col  = max(mix(float3(gray), col, u.saturation), 0.0);

    float lum   = max(max(col.r, col.g), col.b);
    float alpha = clamp(lum, 0.0, 1.0) * u.opacity;

    return half4(half3(col * u.opacity), half(alpha));
}
