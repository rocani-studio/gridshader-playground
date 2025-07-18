#include ../includes/simplexNoise4d.glsl

precision highp float;
uniform float uTime;
uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uMouse;
varying vec2 vUv;
uniform vec3 uColor1;
uniform vec3 uColor2;
uniform float uGridSize;
uniform float uRefractionStrength;
uniform bool uHexagon;

// hexagon helper from Inigo Quilez
vec4 hexagon(vec2 p) {
      // skew to hex lattice
  vec2 q = vec2(p.x * 2.0 * 0.5773503, p.y + p.x * 0.5773503);
  vec2 pi = floor(q);
  vec2 pf = fract(q);
  float v = mod(pi.x + pi.y, 3.0);
  float ca = step(1.0, v);
  float cb = step(2.0, v);
  vec2 ma = step(pf.xy, pf.yx);
      // edge distance
  vec2 k = 1.0 - pf.yx + ca * (pf.x + pf.y - 1.0) + cb * (pf.yx - 2.0 * pf.xy);
  float edgeDist = dot(ma, k);
      // center‐offset vector
  vec2 centerOffset = (fract(vec2(q.x + floor(0.5 + p.y / 1.5), 4.0 * p.y / 3.0) * 0.5 + 0.5) - 0.5) * vec2(1.0, 0.85);
  return vec4(centerOffset, edgeDist, length(centerOffset));
}

vec4 circle(vec2 p) {
    // tile into 1×1 cells
  vec2 cell = floor(p);
    // compute offset to cell center
  vec2 offset = p - (cell + 0.5);
    // radial distance from center
  float dist = length(offset);
    // how far inside the circle we are (radius = 0.5)
  float R = 0.45;
  float edgeDist = R - dist;

  return vec4(offset, edgeDist, dist);
}

void main() {
  vec2 newUV = vUv;

  vec2 screenScale = uResolution / max(uResolution.x, uResolution.y);

    // map uv to -1 → +1, then scale
  vec2 p = (vUv * 2.0 - 1.0) * uGridSize * screenScale;
  vec3 rd = vec3(0.0, 0.0, -1.0);

      // get per‐cell data: .xy = center‐offset, .z = edgeDist, .w = centerDist
  vec4 hx = uHexagon ? hexagon(p) : circle(p);
  // hx = circle(p);

    // simple checker by which 3‐cell variant this is
  float cellID = mod(floor(p.x) + floor(p.y), 2.0);

  float di = (hx.w);

  float rod_x = hx.x;
  float rod_y = hx.y;
  vec3 n = vec3(0.0, 0.0, 1.0);
  if(di < 0.5) {
    float z = sqrt(1.0 - di * di);
    n = normalize(vec3(rod_x, rod_y, -z));
    n = mix(vec3(0.0, 0.0, -1.0), n, smoothstep(0.0, 0.3, hx.z));
  }

  float refrac = 0.2;
  vec3 refracted_ray = mix(n, rd, refrac);
  float z_dist = 0.8 / (refracted_ray.z + 0.00001);
  vec3 pos = vec3(p, 0.0) + z_dist * refracted_ray;

  float g = 1.0 - abs(n.z);
  g = g * 0.5 / (g * 0.5 - g + 1.0);
  float glass = (1.0 - 1.2 * g);

  vec2 scale = uResolution / min(uResolution.x, uResolution.y);
  vec2 texUV = vUv * scale - (scale - 1.0) * 0.5;

  vec4 texColor = texture2D(uTexture, texUV);

  float refStrength = uRefractionStrength;  // tweak fthis for more/less distortion
  vec2 refractUV = texUV + refracted_ray.xy * refStrength;

  vec3 refractedCol = texture2D(uTexture, refractUV).rgb;

  float wave = 0.5 + 0.5 * sin(vUv.x * 5.0 + uTime);
  vec3 color = vec3(wave);

  float dist = smoothstep(0.2, 0.201, distance(uMouse, newUV));
  color = vec3(dist);

  color = texColor.rgb;
  color = refractedCol;
  color = mix(refractedCol, vec3(glass), 0.2);

  float noise = simplexNoise4d(vec4(newUV, 1.0, uTime * 0.4));
  float signedNoise = noise * 2.0 - 1.0;
  vec2 uvOffset = vec2(noise) * 0.5;
  vec2 displacedUV = texUV + uvOffset + refracted_ray.xy * refStrength;

  float circ = 1.0 - smoothstep(0.3, 0.31, distance(vUv, vec2(0.5)));
  vec3 displacedColor = texture2D(uTexture, displacedUV).rgb;

    // color = vec3(displacedUV, 0.0);

    // color = vec3(noise);
  color = displacedColor;
  float gray = dot(color, vec3(0.299, 0.587, 0.114));

  if(!uHexagon) {
    color *= vec3(step(0.05, hx.b)) * 1.0;
  }

  gl_FragColor = vec4(color, color.r);
}