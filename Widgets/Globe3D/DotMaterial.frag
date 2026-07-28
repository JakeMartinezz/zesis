// Soft emissive dot: tiny hot core + gaussian-ish halo, written to
// EMISSIVE_COLOR over a black BASE_COLOR so the scene light never
// touches it. Runs through the SHADED pipeline. Unshaded rendered
// nothing at all for some reason.
//
// The output is HDR (dotIntensity pushes past 1.0) and the material
// blends One/One (additive), so overlapping dots SUM: a dense cluster
// climbs past the glow pass's HDR threshold (glowHDRMinimumValue) where
// a lone dot barely grazes it, that's what makes bloom read as
// density.
VARYING vec2 vUV;

void MAIN()
{
    vec2 d = vUV * 2.0 - 1.0;
    float r2 = dot(d, d);
    float r = sqrt(r2);
    float halo = exp(-r2 * 5.0) * clamp(1.0 - r, 0.0, 1.0);
    float core = 1.0 - smoothstep(0.0, 0.35, r);
    float shape = halo * 0.6 + core;
    BASE_COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    EMISSIVE_COLOR = dotColor.rgb * (dotIntensity * shape * dotFade);
}
