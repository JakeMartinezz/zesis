// Camera-facing billboard for the background star field
// (AssemblyGlobeView.qml's star Model). Same billboard math as
// DotMaterial.vert.

// hash13/logMix are duplicated from DotMaterial.frag's own copies.
vec3 hash13(float p)
{
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float logMix(float a, float b, float t)
{
    return a * pow(b / a, t);
}

VARYING vec2 vUV;
VARYING float vSeed;

void MAIN()
{
    vUV = UV0;
    vSeed = float(INSTANCE_INDEX);
    vec3 rand3 = hash13(vSeed);
    float sizeScale = logMix(0.4, 1.8, rand3.y);
    VERTEX = (camRight * VERTEX.x + camUp * VERTEX.y) * (dotSize * sizeScale / 100.0);
}
