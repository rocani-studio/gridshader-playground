uniform float uTime;
uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform bool uDisplace;

varying vec2 vUv;

// add this if you don’t already have it:
varying vec3 vNormal;

void main() {
    // 1) scale UV to 16:9 exactly as you already have
    float currentAspect = uResolution.x / uResolution.y;
    float targetAspect = 16.0 / 9.0;
    vec2 texUV;
    if(currentAspect > targetAspect) {
        float scale = targetAspect / currentAspect;
        texUV = vec2((uv.x - 0.5) * scale + 0.5, uv.y);
    } else {
        float scale = currentAspect / targetAspect;
        texUV = vec2(uv.x, (uv.y - 0.5) * scale + 0.5);
    }

    // 2) sample the texture
    vec4 texColor = texture2D(uTexture, texUV);

    // 3) compute brightness (luma)
    float brightness = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));

    // 4) displace along the normal
    //    tweak `4.0` to taste (strength of the displacement)
    vec3 displacedPosition = position + normal * brightness * 4.0;

    // 5) standard varyings & projection
    vUv = uv;
    vNormal = normalize(normalMatrix * normal);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(uDisplace ? displacedPosition : position, 1.0);
}