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
uniform float uBlurRadius; 

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

vec3 hsb2rgb(in vec3 c) {
  vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
  rgb = rgb * rgb * (3.0 - 2.0 * rgb);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

// —————————————————————————————————————————————————————————————————————————————
    // Classic simplex noise (Inigo Quilez)
vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
      // First corner
  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);
      // Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);
      //  x0 = x0 - 0.0 + 0.0 * C 
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;
      // Permutations
  i = mod289(i);
  vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));
      // Gradients
  float n_ = 1.0 / 7.0; // N=7
  vec3 ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);
  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);
  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);
      // Normalise gradients
  vec4 norm = inversesqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;
      // Mix contributions
  vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

    // Domain‐warped FBM (“storm”)
float storm(vec3 p) {
  mat3 m = mat3(0.00, 0.80, 0.60, -0.80, 0.36, -0.48, -0.60, -0.48, 0.64);
  float amp = 0.6;
  float v = 0.0;
  for(int i = 0; i < 5; i++) {
    v += amp * snoise(p);
    p = m * p * 1.4 + vec3(1.7);
    amp *= 0.5;
  }
  return v;
}

    // Cosine‐palette
vec3 palette(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) {
  const float PI = 3.141592653589793;
  return a + b * cos(2.0 * PI * (c * t + d));
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

  // SCALE TEXTURE
  float currentAspect = uResolution.x / uResolution.y;
  float targetAspect = 16.0 / 9.0;

  // adjust UVs to preserve 16:9, adding black bars automatically
  vec2 texUV;
  if(currentAspect > targetAspect) {
    // viewport is wider than 16:9 → pillarbox (vertical bars)
    float scale = targetAspect / currentAspect * 1.0;
    texUV = vec2((vUv.x - 0.5) * scale + 0.5,  // scale X around center
    vUv.y                         // Y unchanged
    );
  } else {
    // viewport is taller than 16:9 → letterbox (horizontal bars)
    float scale = currentAspect / targetAspect;
    texUV = vec2(vUv.x,                        // X unchanged
    (vUv.y - 0.5) * scale + 0.5   // scale Y around center
    );
  }

  // vec2 scale = uResolution / min(uResolution.x, uResolution.y);
  // vec2 texUV = vUv * scale - (scale - 1.0) * 0.5;

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

    // SAMPLE CENTER
  vec2 cell = floor(p);

  // 2) the “p-space” center of that cell is at +0.5 in both x and y
  vec2 centerP = cell + 0.5;

  // 3) convert back to [0,1] UVs
  vec2 centerUv = (centerP / (uGridSize * screenScale) + 1.0) * 0.5;

  float noise = simplexNoise4d(vec4(newUV, 1.0, uTime * 0.1));
  float signedNoise = noise * 2.0 - 1.0;
  vec2 uvOffset = vec2(noise) * 0.4;
  vec2 displacedUV = centerUv + uvOffset + refracted_ray.xy * refStrength;
  vec2 refractedUV = (texUV + vec2(0.25) * 0.0) + refracted_ray.xy * refStrength;

  float circ = 1.0 - smoothstep(0.3, 0.31, distance(vUv, vec2(0.5)));
  vec3 displacedColor = texture2D(uTexture, refractedUV).rgb;

    // color = vec3(displacedUV, 0.0);

    // color = vec3(noise);
  color = displacedColor;
  float gray = dot(color, vec3(0.299, 0.587, 0.114));

  // color = col;

  // color = vec3(clamp(color.r, 0.2, 1.0));
  // color = vec3(color.r);
  // color = texture2D(uTexture, texUV).rgb;

  // color = vec3(centerUv, 0.0);
  // color = texture2D(uTexture, refractedUV).rgb;

  float alpha = 1.0;

  if(distance(color, vec3(1.0)) <= 0.2) {
    alpha = 0.0;
  }

  if(!uHexagon) {
    color *= vec3(step(0.05, hx.b)) * 1.0;
  }

  gl_FragColor = vec4(color, alpha * color.r * 1.0);

  // #include <tonemapping_fragment>
  // #include <colorspace_fragment>
}