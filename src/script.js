import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { RGBELoader } from "three/addons/loaders/RGBELoader.js";
import { TextureLoader } from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { DRACOLoader } from "three/addons/loaders/DRACOLoader.js";
import GUI from "lil-gui";

import gridVertex from "./shaders/grid/vertex.glsl";
import gridFragment from "./shaders/grid/fragment.glsl";

/**
 * Base
 */
// Debug
const gui = new GUI({ width: 325 });
// gui.hide();
const debugObject = {};

// Canvas
const canvas = document.querySelector("canvas.webgl");

// Scene
const scene = new THREE.Scene();

// Loaders
const rgbeLoader = new RGBELoader();
const dracoLoader = new DRACOLoader();
dracoLoader.setDecoderPath("./draco/");
const gltfLoader = new GLTFLoader();
gltfLoader.setDRACOLoader(dracoLoader);
const loader = new TextureLoader();

/**
 * Wobble
 */
// Material
const material = new THREE.MeshPhysicalMaterial({
  metalness: 0,
  roughness: 0.5,
  color: "#ffffff",
  transmission: 0,
  ior: 1.5,
  thickness: 1.5,
  transparent: true,
  wireframe: false,
});

// Geometry
const geometry = new THREE.IcosahedronGeometry(2.5, 50);

// Mesh
const wobble = new THREE.Mesh(geometry, material);
wobble.receiveShadow = true;
wobble.castShadow = true;
// scene.add(wobble);

/**
 * Plane
 */
const plane = new THREE.Mesh(
  new THREE.PlaneGeometry(15, 15, 15),
  new THREE.MeshStandardMaterial()
);
plane.receiveShadow = true;
plane.rotation.y = Math.PI;
plane.position.y = -5;
plane.position.z = 5;
// scene.add(plane);

/**
 * Lights
 */
const directionalLight = new THREE.DirectionalLight("#ffffff", 3);
directionalLight.castShadow = true;
directionalLight.shadow.mapSize.set(1024, 1024);
directionalLight.shadow.camera.far = 15;
directionalLight.shadow.normalBias = 0.05;
directionalLight.position.set(0.25, 2, -2.25);
// scene.add(directionalLight);

/**
 * Sizes
 */
const sizes = {
  width: window.innerWidth,
  height: window.innerHeight,
  pixelRatio: Math.min(window.devicePixelRatio, 2),
};

// ─── SHADER PLANE SETUP ─────────────────────────────────────────────────────────

/**
 * Camera
 */
// Base camera
const camera = new THREE.PerspectiveCamera(
  75,
  sizes.width / sizes.height,
  0.1,
  100
);
camera.position.set(0, 0, 10);
scene.add(camera);

// 1) create a fullscreen orthographic camera
const orthoCam = new THREE.OrthographicCamera(
  -sizes.width / 2,
  sizes.width / 2,
  sizes.height / 2,
  -sizes.height / 2,
  -1,
  1
);

// 2) simple ShaderMaterial
const shaderMat = new THREE.ShaderMaterial({
  uniforms: {
    uTime: { value: 0 },
    uMouse: { value: new THREE.Vector2(0, 0) },
    uResolution: { value: new THREE.Vector2(sizes.width, sizes.height) },
    uTexture: { value: null },
    uColor1: { value: new THREE.Color(0xffffff) },
    uColor2: { value: new THREE.Color(0xffeeee) },
    uGridSize: { value: 68 },
    uRefractionStrength: { value: 0.2 },
    uHexagon: { value: false },
    uBlurRadius: { value: 1.0 },
    uDisplace: { value: false },
  },
  vertexShader: gridVertex,
  fragmentShader: gridFragment,
  depthWrite: false,
  side: THREE.DoubleSide,
  transparent: true,
  // wireframe: true,
});

// Tweaks
if (gui) {
  gui
    .add(shaderMat.uniforms.uGridSize, "value", 10, 100, 1.0)
    .name("Grid Size");
  gui
    .add(shaderMat.uniforms.uRefractionStrength, "value", 0, 2.2, 0.001)
    .name("Refraction Strength");
  gui.add(shaderMat.uniforms.uHexagon, "value").name("Hexagons");
  gui
    .add(shaderMat.uniforms.uDisplace, "value")
    .name("Displace Geometry")
    .onChange((enabled) => {
      // `enabled` is true/false
      if (enabled) {
        // e.g. re-compute any buffers or flags you need
        controls.enabled = true;
        // maybe rebuild your quad’s geometry normals, or reset a timer:
        // rebuildDisplacement();
      } else {
        controls.enabled = false;
      }
    });
}

const z = 10;

// 2) compute the frustum size at z
const fovInRad = THREE.MathUtils.degToRad(camera.fov);
const heightAtZ = 2 * z * Math.tan(fovInRad / 2);
const widthAtZ = heightAtZ * camera.aspect;

// 3) fullscreen quad
const quadGeo = new THREE.PlaneGeometry(1, 1, 90, 90);
const testMat = new THREE.MeshBasicMaterial();
const quadMesh = new THREE.Mesh(quadGeo, shaderMat);
quadMesh.scale.set(widthAtZ, heightAtZ, 1);

// scene.add(quadMesh);
scene.add(quadMesh);
quadMesh.position.set(0, 0, -z + 10);

const tex = loader.load("/img/blommor5.png", () => {
  // optional: once loaded, you can set any wrap/filter modes:
  //   tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.minFilter = THREE.NearestFilter;

  console.log(tex.image);
});
// testMat.map = tex;
// testMat.needsUpdate = true;
shaderMat.uniforms.uTexture.value = tex;
shaderMat.needsUpdate = true;

const video = document.getElementById("video");

// 2. (Optional, but highly recommended) make it muted so browsers will autoplay it
//    — without a user gesture most browsers block un-muted video.play()
video.muted = true;
video.loop = true; // loop if you like
video.playsInline = true; // for mobile Safari

// 3. Tell the browser to play it
video
  .play()
  .then(() => {
    // video.pause();
    // once it’s playing, hook it into your Three.js texture
    const vidTex = new THREE.VideoTexture(video);
    shaderMat.uniforms.uTexture.value = vidTex;
    shaderMat.needsUpdate = true;
  })
  .catch((err) => {
    console.error("Video playback failed:", err);
    // you may need to wait for a user gesture (e.g. button click) to start playback
  });

// const vidTex = new THREE.VideoTexture(video);
// shaderMat.uniforms.uTexture.value = vidTex;
// shaderMat.needsUpdate = true;

window.addEventListener("resize", () => {
  // Update sizes
  sizes.width = window.innerWidth;
  sizes.height = window.innerHeight;
  sizes.pixelRatio = Math.min(window.devicePixelRatio, 2);

  // Update camera
  camera.aspect = sizes.width / sizes.height;
  camera.updateProjectionMatrix();

  // Update renderer
  renderer.setSize(sizes.width, sizes.height);
  renderer.setPixelRatio(sizes.pixelRatio);

  // 1) update ortho frustum
  orthoCam.left = -sizes.width / 2;
  orthoCam.right = sizes.width / 2;
  orthoCam.top = sizes.height / 2;
  orthoCam.bottom = -sizes.height / 2;
  orthoCam.updateProjectionMatrix();

  // 2) rebuild fullscreen quad
  quadMesh.geometry.dispose();
  quadMesh.geometry = new THREE.PlaneGeometry(sizes.width, sizes.height);

  shaderMat.uniforms.uResolution.value.x = sizes.width;
  shaderMat.uniforms.uResolution.value.y = sizes.height;
});

window.addEventListener("pointermove", (event) => {
  const x = event.clientX / window.innerWidth; // 0 (left) → 1 (right)
  const y = 1 - event.clientY / window.innerHeight; // 0 (bottom) → 1 (top)
  shaderMat.uniforms.uMouse.value.set(x, y);
});

// ─── INSTANCED GRID OF SPHERES ──────────────────────────────────────────────

// Parameters
const sphereRadius = 0.05; // adjust to taste
const diameter = sphereRadius * 2;
const sphereGeo = new THREE.SphereGeometry(sphereRadius, 16, 16);
const sphereMat = new THREE.MeshStandardMaterial({ color: 0xddddff });

// Helper: build grid once (and on resize)
let sphereMesh;
function buildSphereGrid() {
  // remove old
  if (sphereMesh) scene.remove(sphereMesh);

  // compute how many cols/rows fit in view
  const viewWidth = orthoCam.right - orthoCam.left;
  const viewHeight = orthoCam.top - orthoCam.bottom;
  const cols = Math.ceil(viewWidth / diameter);
  const rows = Math.ceil(viewHeight / diameter);
  const count = cols * rows;

  // create instanced mesh
  sphereMesh = new THREE.InstancedMesh(sphereGeo, sphereMat, count);
  let idx = 0;
  const tmpMat = new THREE.Matrix4();

  for (let i = 0; i < cols; i++) {
    for (let j = 0; j < rows; j++) {
      const x = orthoCam.left + diameter * (i + 0.5);
      const y = orthoCam.bottom + diameter * (j + 0.5);
      tmpMat.makeTranslation(x, y, 0);
      sphereMesh.setMatrixAt(idx++, tmpMat);
    }
  }

  sphereMesh.instanceMatrix.needsUpdate = true;
  scene.add(sphereMesh);
}

// initial build
// buildSphereGrid();

// Controls
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;

/**
 * Renderer
 */
const renderer = new THREE.WebGLRenderer({
  canvas: canvas,
  antialias: true,
  alpha: true,
});
renderer.setClearColor(0x000000, 0);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1;
renderer.setSize(sizes.width, sizes.height);
renderer.setPixelRatio(sizes.pixelRatio);

/**
 * Animate
 */
const clock = new THREE.Clock();

const tick = () => {
  const elapsedTime = clock.getElapsedTime();

  // Update controls
  if (shaderMat.uniforms.uDisplace.value) {
    controls.update();
  }

  // Render
  renderer.render(scene, camera);

  shaderMat.uniforms.uTime.value = clock.getElapsedTime();

  //   console.log(shaderMat.uniforms.uTime);

  // Call tick again on the next frame
  window.requestAnimationFrame(tick);
};

tick();
