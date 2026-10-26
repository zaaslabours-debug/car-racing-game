import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { MeshBVH, acceleratedRaycast } from 'three-mesh-bvh';

/* ============================================================
   SILVER LAKE GP — Prototype 0.1
   One hero car (Saba V12 '95) + Silver Lake track
   Arcade physics · drift · nitro · chase camera · HUD · audio
   ============================================================ */

const CAR_URL = '/models/cars/saba-v12.glb';
const TRACK_URL = '/models/track/silver-lake.glb';
const CAR_LENGTH_M = 4.55;        // normalize car to real-world size
const TARGET_ROAD_WIDTH_M = 13;   // scale track so road ≈ 13 m wide

const $ = (id) => document.getElementById(id);
const ui = {
  app: $('app'), hud: $('hud'), overlay: $('overlay'), err: $('err'),
  loadFill: $('load-fill'), loadText: $('load-text'), startBtn: $('start-btn'),
  speedVal: $('speed-val'), rpmFill: $('rpm-fill'),
  nitroFill: $('nitro-fill'), nitroPct: $('nitro-pct'),
  msg: $('msg'), offtrack: $('offtrack'), speedlines: $('speedlines'),
  touch: $('touch'),
};
function showError(e) {
  console.error(e);
  if (ui.err) ui.err.textContent = '⚠️ ' + (e?.message || e);
}
window.addEventListener('error', (e) => showError(e.message));
const nextFrame = () => new Promise((r) => requestAnimationFrame(r));
const clamp = THREE.MathUtils.clamp;
const lerp = THREE.MathUtils.lerp;

/* ---------------- renderer / scene ---------------- */
let renderer;
try {
  renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
} catch (e) { showError('WebGL not available: ' + e.message); throw e; }
renderer.setSize(innerWidth, innerHeight);
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.06;
ui.app.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0xe9a96f, 260, 4200);
const camera = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.1, 12000);
camera.position.set(0, 30, 70);

const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

/* gradient sky dome (sunset) */
const sky = new THREE.Mesh(
  new THREE.SphereGeometry(6000, 24, 16),
  new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: {
      top: { value: new THREE.Color(0x3d6ea8) },
      mid: { value: new THREE.Color(0xf7b267) },
      bot: { value: new THREE.Color(0x4a4238) },
    },
    vertexShader: `varying vec3 vW; void main(){ vW=(modelMatrix*vec4(position,1.)).xyz; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
    fragmentShader: `varying vec3 vW; uniform vec3 top,mid,bot;
      void main(){ float h=normalize(vW-cameraPosition).y;
        vec3 c = h>0.12 ? mix(mid,top,smoothstep(0.12,0.65,h)) : mix(bot,mid,smoothstep(-0.25,0.12,h));
        gl_FragColor=vec4(c,1.); }`,
  })
);
sky.frustumCulled = false;
scene.add(sky);

const hemi = new THREE.HemisphereLight(0xcfe5ff, 0x54452e, 0.75);
scene.add(hemi);
const sunDir = new THREE.Vector3(-0.55, 0.42, -0.35).normalize();
const sun = new THREE.DirectionalLight(0xffb36b, 2.9);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -60; sun.shadow.camera.right = 60;
sun.shadow.camera.top = 60; sun.shadow.camera.bottom = -60;
sun.shadow.camera.near = 10; sun.shadow.camera.far = 320;
sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.6;
scene.add(sun); scene.add(sun.target);

/* ---------------- input ---------------- */
const input = { gas: 0, brake: 0, left: 0, right: 0, drift: false, nitro: false };
const KEYMAP = {
  KeyW: 'gas', ArrowUp: 'gas', KeyS: 'brake', ArrowDown: 'brake',
  KeyA: 'left', ArrowLeft: 'left', KeyD: 'right', ArrowRight: 'right',
};
addEventListener('keydown', (e) => {
  if (KEYMAP[e.code]) { input[KEYMAP[e.code]] = 1; e.preventDefault(); }
  if (e.code === 'Space') { input.drift = true; e.preventDefault(); }
  if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') input.nitro = true;
  if (e.code === 'KeyR') resetCar();
  if (e.code === 'KeyT') teleport();
  if (e.code === 'KeyC') cycleCam();
  if (e.code === 'KeyM') audio.toggleMute();
  if (e.code === 'Enter' && state === 'menu' && !ui.startBtn.disabled) startRace();
});
addEventListener('keyup', (e) => {
  if (KEYMAP[e.code]) input[KEYMAP[e.code]] = 0;
  if (e.code === 'Space') input.drift = false;
  if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') input.nitro = false;
});
document.querySelectorAll('.tbtn').forEach((b) => {
  const k = b.dataset.k;
  const on = (e) => { e.preventDefault(); if (k === 'nitro') input.nitro = true; else if (k === 'drift') input.drift = true; else input[k] = 1; };
  const off = (e) => { e.preventDefault(); if (k === 'nitro') input.nitro = false; else if (k === 'drift') input.drift = false; else input[k] = 0; };
  b.addEventListener('pointerdown', on);
  b.addEventListener('pointerup', off);
  b.addEventListener('pointerleave', off);
  b.addEventListener('pointercancel', off);
});
$('btn-cam').addEventListener('click', cycleCam);
$('btn-reset').addEventListener('click', resetCar);
$('btn-sound').addEventListener('click', () => audio.toggleMute());
ui.startBtn.addEventListener('click', startRace);

/* ---------------- audio ---------------- */
const audio = {
  ctx: null, muted: false, _impactCd: 0,
  async init() {
    if (this.ctx) { this.ctx.resume(); return; }
    try {
      const C = window.AudioContext || window.webkitAudioContext;
      this.ctx = new C();
      this.master = this.ctx.createGain(); this.master.gain.value = 0.9; this.master.connect(this.ctx.destination);
      const load = async (u) => this.ctx.decodeAudioData(await (await fetch(u)).arrayBuffer());
      const mkLoop = (buf) => { const s = this.ctx.createBufferSource(); s.buffer = buf; s.loop = true; const g = this.ctx.createGain(); g.gain.value = 0; s.connect(g); g.connect(this.master); s.start(); return { s, g }; };
      this.engine = mkLoop(await load('/audio/engine.ogg'));
      this.skid = mkLoop(await load('/audio/skid.ogg'));
      this.impactBuf = await load('/audio/impact.ogg');
      // nitro whoosh: filtered noise loop
      const nb = this.ctx.createBuffer(1, this.ctx.sampleRate, this.ctx.sampleRate);
      const d = nb.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      const ns = this.ctx.createBufferSource(); ns.buffer = nb; ns.loop = true;
      this.noiseFilter = this.ctx.createBiquadFilter(); this.noiseFilter.type = 'bandpass'; this.noiseFilter.frequency.value = 800; this.noiseFilter.Q.value = 0.8;
      this.noiseGain = this.ctx.createGain(); this.noiseGain.gain.value = 0;
      ns.connect(this.noiseFilter); this.noiseFilter.connect(this.noiseGain); this.noiseGain.connect(this.master); ns.start();
    } catch (e) { console.warn('audio unavailable', e); }
  },
  update(dt, speedRatio, throttle, sliding, boosting) {
    if (!this.ctx || !this.engine) return;
    const t = this.ctx.currentTime;
    this.engine.s.playbackRate.setTargetAtTime(0.55 + speedRatio * 1.75 + (throttle ? 0.1 : 0), t, 0.06);
    this.engine.g.gain.setTargetAtTime(state === 'menu' ? 0.05 : 0.16, t, 0.1);
    this.skid.g.gain.setTargetAtTime(sliding ? 0.34 : 0, t, 0.07);
    this.noiseGain.gain.setTargetAtTime(boosting ? 0.2 : 0, t, 0.09);
    this.noiseFilter.frequency.setTargetAtTime(650 + speedRatio * 1100, t, 0.1);
    this._impactCd = Math.max(0, this._impactCd - dt);
  },
  impact(v) {
    if (!this.ctx || !this.impactBuf || this._impactCd > 0) return;
    this._impactCd = 0.35;
    const s = this.ctx.createBufferSource(); s.buffer = this.impactBuf;
    const g = this.ctx.createGain(); g.gain.value = clamp(v, 0.08, 0.85);
    s.connect(g); g.connect(this.master); s.start();
  },
  beep(freq = 440, dur = 0.13) {
    if (!this.ctx) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.type = 'square'; o.frequency.value = freq;
    g.gain.setValueAtTime(0.16, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + dur);
    o.connect(g); g.connect(this.master); o.start(); o.stop(this.ctx.currentTime + dur);
  },
  toggleMute() {
    this.muted = !this.muted;
    if (this.master) this.master.gain.value = this.muted ? 0 : 0.9;
    $('btn-sound').textContent = this.muted ? '🔇 MUTED' : '🔊 SOUND';
  },
};

/* ---------------- track setup ---------------- */
const raycaster = new THREE.Raycaster();
const DOWN = new THREE.Vector3(0, -1, 0);
try { THREE.Mesh.prototype.raycast = acceleratedRaycast; } catch (e) { console.warn('BVH raycast unavailable', e); }

let trackGroup, trackMeshes = [], asphaltMeshes = [], trackSize = 1000;
let spawns = [], spawnIdx = 0;

function matNameOf(hit) {
  const m = hit.object.material;
  const mm = Array.isArray(m) ? m[hit.face?.materialIndex ?? 0] : m;
  return (mm?.name || '').toLowerCase();
}
function castDown(x, z, fromY, list = trackMeshes) {
  raycaster.set(new THREE.Vector3(x, fromY, z), DOWN);
  raycaster.far = 20000;
  const hits = raycaster.intersectObjects(list, false);
  return hits.length ? hits[0] : null;
}
function recenterTrack() {
  trackGroup.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(trackGroup);
  const c = box.getCenter(new THREE.Vector3());
  trackGroup.position.x -= c.x; trackGroup.position.z -= c.z; trackGroup.position.y -= box.min.y;
  trackGroup.updateMatrixWorld(true);
  return new THREE.Box3().setFromObject(trackGroup);
}
function measureRoadWidth() {
  const box = new THREE.Box3().setFromObject(trackGroup);
  const size = box.getSize(new THREE.Vector3());
  const topY = box.max.y + 30;
  let p = null;
  outer:
  for (let i = 0; i < 26; i++) for (let j = 0; j < 26; j++) {
    const h = castDown(box.min.x + size.x * (i + 0.5) / 26, box.min.z + size.z * (j + 0.5) / 26, topY, asphaltMeshes);
    if (h) { p = h.point; break outer; }
  }
  if (!p) return null;
  const step = Math.max(size.x, size.z) * 0.0016;
  const run = (dx, dz) => {
    let d = 0, gaps = 0;
    for (let k = 1; k <= 500; k++) {
      if (castDown(p.x + dx * step * k, p.z + dz * step * k, topY, asphaltMeshes)) { d = step * k; gaps = 0; }
      else if (++gaps > 2) break;
    }
    return d;
  };
  return Math.min(run(1, 0) + run(-1, 0), run(0, 1) + run(0, -1));
}
function findSpawns() {
  const box = new THREE.Box3().setFromObject(trackGroup);
  const size = box.getSize(new THREE.Vector3());
  const topY = box.max.y + 30;
  const N = 56, cells = [];
  for (let i = 0; i < N; i++) {
    cells.push([]);
    for (let j = 0; j < N; j++) {
      const x = box.min.x + size.x * (i + 0.5) / N, z = box.min.z + size.z * (j + 0.5) / N;
      const h = castDown(x, z, topY);
      let cell = { ok: false, asphalt: false, score: -1e9, point: null };
      if (h && h.face) {
        const n = h.face.normal.clone().transformDirection(h.object.matrixWorld);
        const mn = matNameOf(h);
        if (n.y > 0.72 && !/water|backdrop/.test(mn)) {
          cell = { ok: true, asphalt: /asphalt|road|tarmac/.test(mn), score: n.y * 10, point: h.point.clone() };
          if (cell.asphalt) cell.score += 100;
          else if (/concrete|paint/.test(mn)) cell.score += 35;
        }
      }
      cells[i].push(cell);
    }
  }
  const out = [];
  for (let i = 1; i < N - 1; i++) for (let j = 1; j < N - 1; j++) {
    const c = cells[i][j]; if (!c.ok) continue;
    let nb = 0;
    for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) if (cells[i + a][j + b].asphalt) nb++;
    c.score += nb * 5;
    if (c.asphalt) out.push({ i, j, ...c });
  }
  out.sort((a, b) => b.score - a.score);
  const picked = [];
  for (const c of out) {
    if (picked.some((p) => p.point.distanceTo(c.point) < trackSize * 0.055)) continue;
    // heading: longest asphalt run in 8 grid directions
    let best = { n: -1, dx: 1, dz: 0 };
    for (const [di, dj] of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]) {
      let n = 0;
      for (let k = 1; k <= 14; k++) {
        const ii = c.i + di * k, jj = c.j + dj * k;
        if (ii < 0 || jj < 0 || ii >= N || jj >= N || !cells[ii][jj].asphalt) break;
        n = k;
      }
      if (n > best.n) best = { n, dx: di, dz: dj };
    }
    picked.push({ point: c.point, heading: Math.atan2(best.dx, best.dz) });
    if (picked.length >= 6) break;
  }
  if (!picked.length) {
    const h = castDown(0, 0, topY);
    picked.push({ point: h ? h.point.clone() : new THREE.Vector3(0, 0, 0), heading: 0 });
  }
  return picked;
}
function setupTrack(gltf) {
  trackGroup = gltf.scene;
  scene.add(trackGroup);
  trackGroup.traverse((o) => {
    if (o.isMesh) {
      o.receiveShadow = true; o.castShadow = false;
      const mats = Array.isArray(o.material) ? o.material : [o.material];
      mats.forEach((m) => { if (m) m.envMapIntensity = 0.35; });
      if (mats.some((m) => /asphalt|road|tarmac/i.test(m?.name || ''))) asphaltMeshes.push(o);
      trackMeshes.push(o);
      try { if (!o.geometry.boundsTree) o.geometry.boundsTree = new MeshBVH(o.geometry); } catch (e) {}
    }
  });
  // provisional fit → measure road → final scale
  let box = recenterTrack();
  let size = box.getSize(new THREE.Vector3());
  trackGroup.scale.setScalar(2000 / Math.max(size.x, size.z));
  box = recenterTrack();
  const w = measureRoadWidth();
  console.log('[track] measured road width ≈', w?.toFixed(1), 'm at provisional scale');
  if (w && w > 0.8) {
    trackGroup.scale.multiplyScalar(clamp(TARGET_ROAD_WIDTH_M / w, 0.12, 6));
    box = recenterTrack();
  }
  size = box.getSize(new THREE.Vector3());
  trackSize = Math.max(size.x, size.z);
  scene.fog.far = clamp(trackSize * 1.9, 1400, 9000);
  scene.fog.near = clamp(trackSize * 0.12, 120, 600);
  console.log('[track] final size ≈', trackSize.toFixed(0), 'm across');
}

/* ---------------- car setup ---------------- */
let carGroup, wheelPivots = [], frontPivots = [], wheelRadius = 0.34, carHalfLen = 2.27;
let flames = [], brakeGlows = [], underglow;

function makeGlowTexture(inner = 'rgba(255,255,255,1)') {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d');
  const gr = g.createRadialGradient(64, 64, 2, 64, 64, 64);
  gr.addColorStop(0, inner); gr.addColorStop(0.35, 'rgba(255,255,255,.55)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
let smokeTex;

function setupCar(gltf) {
  const model = gltf.scene;
  const inner = new THREE.Group(); inner.add(model);
  const align = new THREE.Group(); align.add(inner);
  carGroup = new THREE.Group(); carGroup.add(align);
  scene.add(carGroup);
  carGroup.updateMatrixWorld(true);

  // find wheel groups (Saba: Saba95_WheelStock_FL etc.)
  const wheels = [];
  model.traverse((o) => {
    const nm = o.name || '';
    if (/wheelstock_(fl|fr|rl|rr)$/i.test(nm)) wheels.push({ obj: o, tag: nm.slice(-2).toUpperCase() });
  });
  if (!wheels.length) {
    model.traverse((o) => {
      if (/wheel/i.test(o.name) && !/steer/i.test(o.name)) {
        let has = false; o.traverse((d) => { if (d.isMesh) has = true; });
        if (has) wheels.push({ obj: o, tag: '' });
      }
    });
  }
  // orient: front axle vs rear axle → model forward
  const centers = wheels.map((w) => {
    const b = new THREE.Box3().setFromObject(w.obj);
    return { ...w, center: b.getCenter(new THREE.Vector3()), size: b.getSize(new THREE.Vector3()) };
  });
  const front = centers.filter((c) => c.tag.startsWith('F'));
  const rear = centers.filter((c) => c.tag.startsWith('R'));
  if (front.length && rear.length) {
    const fa = front.reduce((a, c) => a.add(c.center), new THREE.Vector3()).multiplyScalar(1 / front.length);
    const ra = rear.reduce((a, c) => a.add(c.center), new THREE.Vector3()).multiplyScalar(1 / rear.length);
    const f = fa.sub(ra); f.y = 0;
    if (f.lengthSq() > 1e-6) { f.normalize(); inner.rotation.y = -Math.atan2(f.x, f.z); }
  }
  // normalize scale + recenter (origin at ground center)
  carGroup.updateMatrixWorld(true);
  let b = new THREE.Box3().setFromObject(align);
  let s = b.getSize(new THREE.Vector3());
  const sc = CAR_LENGTH_M / Math.max(s.z, 0.001);
  align.scale.setScalar(sc);
  carGroup.updateMatrixWorld(true);
  b = new THREE.Box3().setFromObject(align);
  const c = b.getCenter(new THREE.Vector3());
  align.position.set(-c.x, -b.min.y, -c.z);
  carGroup.updateMatrixWorld(true);
  b = new THREE.Box3().setFromObject(align);
  s = b.getSize(new THREE.Vector3());
  carHalfLen = s.z / 2;

  // rig wheel pivots at wheel centers
  for (const w of centers) {
    const wb = new THREE.Box3().setFromObject(w.obj);
    const wc = wb.getCenter(new THREE.Vector3());
    const ws = wb.getSize(new THREE.Vector3());
    const pivot = new THREE.Group();
    pivot.rotation.order = 'YXZ';
    pivot.position.copy(carGroup.worldToLocal(wc.clone()));
    carGroup.add(pivot);
    carGroup.updateMatrixWorld(true);
    pivot.attach(w.obj);
    wheelPivots.push(pivot);
    if (w.tag.startsWith('F')) frontPivots.push(pivot);
    wheelRadius = Math.max(wheelRadius, ws.y / 2);
  }
  console.log('[car] wheels rigged:', wheelPivots.length, 'radius', wheelRadius.toFixed(2));

  model.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = true; o.receiveShadow = false;
      const mats = Array.isArray(o.material) ? o.material : [o.material];
      mats.forEach((m) => { if (m) m.envMapIntensity = /body|paint/i.test(m.name || '') ? 1.3 : 0.9; });
    }
  });

  // nitro exhaust flames (blue core + orange outer) at rear
  const flameOuter = new THREE.MeshBasicMaterial({ color: 0xff7a1f, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false });
  const flameCore = new THREE.MeshBasicMaterial({ color: 0x7fe3ff, transparent: true, opacity: 0.95, blending: THREE.AdditiveBlending, depthWrite: false });
  for (const sx of [-0.36, 0.36]) {
    const grp = new THREE.Group();
    const outer = new THREE.Mesh(new THREE.ConeGeometry(0.11, 1.05, 12, 1, true), flameOuter);
    const core = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.7, 10, 1, true), flameCore);
    outer.rotation.x = core.rotation.x = -Math.PI / 2;
    outer.position.z = -0.5; core.position.z = -0.33;
    grp.add(outer, core);
    grp.position.set(sx, 0.4, -carHalfLen - 0.05);
    grp.visible = false;
    carGroup.add(grp); flames.push(grp);
  }
  // brake light glows
  smokeTex = makeGlowTexture();
  for (const sx of [-0.6, 0.6]) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: smokeTex, color: 0xff2213, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false }));
    sp.scale.setScalar(0.55); sp.position.set(sx, 0.66, -carHalfLen - 0.04);
    carGroup.add(sp); brakeGlows.push(sp);
  }
  underglow = new THREE.PointLight(0x35c8ff, 0, 10, 2);
  underglow.position.set(0, 0.5, 0);
  carGroup.add(underglow);
}

/* ---------------- drift smoke ---------------- */
const smokePool = [];
function initSmoke() {
  for (let i = 0; i < 110; i++) {
    const m = new THREE.SpriteMaterial({ map: smokeTex, color: 0xd8dde2, transparent: true, opacity: 0, depthWrite: false });
    const sp = new THREE.Sprite(m);
    sp.visible = false; scene.add(sp);
    smokePool.push({ sp, life: 0, max: 1, vel: new THREE.Vector3() });
  }
}
let smokeIdx = 0, smokeAcc = 0;
function spawnSmoke(pos, baseVel) {
  const p = smokePool[smokeIdx++ % smokePool.length];
  p.life = 0; p.max = 0.7 + Math.random() * 0.6;
  p.sp.position.copy(pos).add(new THREE.Vector3((Math.random() - .5) * .3, 0.12, (Math.random() - .5) * .3));
  p.vel.copy(baseVel).multiplyScalar(0.25).add(new THREE.Vector3((Math.random() - .5) * 1.6, 0.7 + Math.random(), (Math.random() - .5) * 1.6));
  p.sp.visible = true;
}
function updateSmoke(dt) {
  for (const p of smokePool) {
    if (!p.sp.visible) continue;
    p.life += dt;
    const t = p.life / p.max;
    if (t >= 1) { p.sp.visible = false; p.sp.material.opacity = 0; continue; }
    p.sp.position.addScaledVector(p.vel, dt);
    p.sp.scale.setScalar(0.7 + t * 3.1);
    p.sp.material.opacity = 0.32 * (1 - t);
  }
}

/* ---------------- game state / physics ---------------- */
let state = 'menu'; // menu | countdown | drive
let stateT = 0, cdStage = -1;
const pos = new THREE.Vector3();
const vel = new THREE.Vector3();
let heading = 0, nitro = 60, boosting = false;
let steerSmooth = 0, spinAngle = 0, shakeAmp = 0;
let targetY = 0, surface = 'asphalt';
let camMode = 0;
const camPos = new THREE.Vector3(0, 26, 60);
let clockT = 0;

function placeAtSpawn(i) {
  if (!spawns.length) return;
  spawnIdx = ((i % spawns.length) + spawns.length) % spawns.length;
  const s = spawns[spawnIdx];
  pos.copy(s.point); targetY = s.point.y;
  heading = s.heading;
  vel.set(0, 0, 0); steerSmooth = 0;
  carGroup.position.copy(pos);
  carGroup.quaternion.setFromAxisAngle(new THREE.Vector3(0, 1, 0), heading);
  const f = new THREE.Vector3(Math.sin(heading), 0, Math.cos(heading));
  camPos.copy(pos).addScaledVector(f, -10).add(new THREE.Vector3(0, 3.4, 0));
}
function resetCar() { if (state === 'drive') placeAtSpawn(spawnIdx); }
function teleport() { if (state === 'drive') { placeAtSpawn(spawnIdx + 1); flashMsg('TELEPORT'); } }
function cycleCam() { camMode = (camMode + 1) % 3; }
let msgTimer = null;
function flashMsg(txt, hold = 900) {
  ui.msg.textContent = txt; ui.msg.style.opacity = 1;
  clearTimeout(msgTimer);
  msgTimer = setTimeout(() => { ui.msg.style.opacity = 0; }, hold);
}

const _f = new THREE.Vector3(), _r = new THREE.Vector3(), _n = new THREE.Vector3(), _v = new THREE.Vector3();
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion();
const DRIVABLE = /asphalt|concrete|road|paint|wood|tarmac/;

function stepPhysics(dt) {
  const steerInput = (input.left ? 1 : 0) - (input.right ? 1 : 0);
  const drift = input.drift;
  _f.set(Math.sin(heading), 0, Math.cos(heading));
  _r.set(_f.z === 0 && false ? 0 : Math.cos(heading), 0, -Math.sin(heading));
  let vF = vel.dot(_f), vR = vel.dot(_r);
  const spd = Math.abs(vF);

  const offroad = surface !== 'asphalt';
  boosting = input.nitro && nitro > 0.5 && vF > -1 && state === 'drive';
  let topSpeed = boosting ? 84 : 62;
  if (surface === 'water') topSpeed = 9; else if (offroad) topSpeed *= 0.45;

  const ratio = clamp(spd / 62, 0, 1);
  const maxSteer = lerp(0.55, 0.15, Math.pow(ratio, 0.7));
  steerSmooth += (steerInput - steerSmooth) * (1 - Math.exp(-dt * 9));
  const delta = steerSmooth * maxSteer;
  heading -= (vF / 2.7) * Math.tan(delta) * (drift ? 1.5 : 1) * dt;

  // recompute axes after turning
  _f.set(Math.sin(heading), 0, Math.cos(heading));
  _r.set(Math.cos(heading), 0, -Math.sin(heading));

  vR *= Math.exp(-(drift ? 1.7 : 9.0) * dt);
  if (input.gas) vF += (boosting ? 30 : 19) * Math.max(0, 1 - vF / topSpeed) * dt;
  if (input.brake) {
    if (vF > 0.4) vF -= 30 * dt;
    else vF -= 10 * Math.max(0, 1 - Math.abs(vF) / 13) * dt;
  }
  vF *= Math.exp(-(offroad ? 0.85 : 0.26) * dt);
  if (!input.gas && !input.brake) vF *= Math.exp(-0.45 * dt);
  if (drift) vF *= Math.exp(-0.32 * dt);
  if (Math.abs(vF) < 0.04 && !input.gas && !input.brake) vF = 0;

  vel.copy(_f).multiplyScalar(vF).addScaledVector(_r, vR);

  // nitro economy
  const sliding = Math.abs(vR) > 3.2 && spd > 7;
  if (boosting) nitro -= 34 * dt;
  else nitro += (sliding ? 17 : input.gas ? 2.2 : 1.2) * dt;
  nitro = clamp(nitro, 0, 100);

  // integrate XZ with wall-step check
  const nx = pos.x + vel.x * dt, nz = pos.z + vel.z * dt;
  const hit = castDown(nx, nz, pos.y + 2.0);
  if (hit) {
    if (hit.point.y - pos.y > 1.05 && spd > 2) {
      vel.multiplyScalar(0.3);
      shakeAmp = Math.min(0.6, shakeAmp + spd * 0.012);
      audio.impact(spd / 34);
    } else {
      pos.x = nx; pos.z = nz; targetY = hit.point.y;
      const mn = matNameOf(hit);
      surface = /water/.test(mn) ? 'water' : DRIVABLE.test(mn) ? 'asphalt' : 'offroad';
    }
  } else { pos.x = nx; pos.z = nz; surface = 'offroad'; }
  pos.y += (targetY - pos.y) * (1 - Math.exp(-dt * 13));

  // orientation: align to ground normal (sampled), keep heading
  _n.set(0, 0, 0);
  const samples = [[0, 0], [1.7, 0], [-1.7, 0], [0, 0.95], [0, -0.95]];
  let got = 0;
  for (const [df, dr] of samples) {
    const h = castDown(pos.x + _f.x * df + _r.x * dr, pos.z + _f.z * df + _r.z * dr, pos.y + 2.5);
    if (h && h.face) { _n.add(h.face.normal.clone().transformDirection(h.object.matrixWorld)); got++; }
  }
  if (!got || _n.lengthSq() < 1e-6) _n.set(0, 1, 0); else _n.normalize();
  if (_n.y < 0.35) _n.set(0, 1, 0);
  const zAxis = _f.clone().addScaledVector(_n, -_f.dot(_n)).normalize();
  const xAxis = new THREE.Vector3().crossVectors(_n, zAxis).normalize();
  const yAxis = new THREE.Vector3().crossVectors(zAxis, xAxis);
  _m.makeBasis(xAxis, yAxis, zAxis);
  _q.setFromRotationMatrix(_m);
  carGroup.quaternion.slerp(_q, 1 - Math.exp(-dt * 11));
  carGroup.position.copy(pos);

  // wheels
  spinAngle += (vF * dt) / Math.max(wheelRadius, 0.1);
  for (const p of wheelPivots) p.rotation.x = spinAngle;
  for (const p of frontPivots) p.rotation.y = -delta * 1.05;

  // flames / glows / smoke
  for (const f of flames) {
    f.visible = boosting;
    if (boosting) { const s = 0.85 + Math.random() * 0.55; f.scale.set(1, 1, s); }
  }
  underglow.intensity = boosting ? 26 : 0;
  for (const g of brakeGlows) g.material.opacity = input.brake && vF > 1 ? 0.95 : (spd > 1 ? 0.25 : 0.12);
  if (sliding || (drift && spd > 7)) {
    smokeAcc += dt * 46;
    while (smokeAcc > 1) {
      smokeAcc -= 1;
      const side = Math.random() < 0.5 ? -0.85 : 0.85;
      _v.copy(pos).addScaledVector(_f, -carHalfLen * 0.72).addScaledVector(_r, side);
      spawnSmoke(_v, vel);
    }
  }
  return { vF, vR, sliding, ratio };
}

/* ---------------- camera & HUD ---------------- */
function updateCamera(dt, vF) {
  const f = _f.set(Math.sin(heading), 0, Math.cos(heading));
  let look;
  if (state === 'menu') {
    const t = clockT * 0.22;
    camPos.set(pos.x + Math.sin(t) * 8.5, pos.y + 2.3, pos.z + Math.cos(t) * 8.5);
    look = _v.copy(pos).add(new THREE.Vector3(0, 0.8, 0));
  } else if (camMode === 2) {
    camPos.copy(carGroup.localToWorld(new THREE.Vector3(0, 1.08, 0.3)));
    look = carGroup.localToWorld(new THREE.Vector3(0, 0.92, 9));
    camera.position.copy(camPos);
  } else {
    const d = camMode === 0 ? 9.8 : 6.9, h = camMode === 0 ? 3.4 : 2.35;
    const desired = new THREE.Vector3().copy(pos).addScaledVector(f, -d).add(new THREE.Vector3(0, h, 0));
    camPos.lerp(desired, 1 - Math.exp(-dt * 5.2));
    const gh = castDown(camPos.x, camPos.z, camPos.y + 10);
    if (gh && camPos.y < gh.point.y + 0.55) camPos.y = gh.point.y + 0.55;
    look = _v.copy(pos).addScaledVector(f, 6.5).add(new THREE.Vector3(0, 1.15, 0));
  }
  if (camMode !== 2 || state === 'menu') camera.position.copy(camPos);
  if (shakeAmp > 0.003) {
    camera.position.x += (Math.random() - 0.5) * shakeAmp * 0.35;
    camera.position.y += (Math.random() - 0.5) * shakeAmp * 0.3;
  }
  camera.lookAt(look);
  const targetFov = 62 + clamp(Math.abs(vF) / 62, 0, 1) * 7 + (boosting ? 9 : 0);
  if (Math.abs(camera.fov - targetFov) > 0.05) {
    camera.fov += (targetFov - camera.fov) * (1 - Math.exp(-dt * 5));
    camera.updateProjectionMatrix();
  }
  sky.position.copy(camera.position);
  sun.position.copy(pos).addScaledVector(sunDir, 150);
  sun.target.position.copy(pos);
}
function updateHUD(vF) {
  const kmh = Math.round(Math.abs(vF) * 3.6);
  ui.speedVal.textContent = kmh;
  ui.rpmFill.style.width = clamp(Math.abs(vF) / 84, 0, 1) * 100 + '%';
  ui.nitroFill.style.width = nitro + '%';
  ui.nitroFill.classList.toggle('boosting', boosting);
  ui.nitroFill.classList.toggle('full', nitro > 97 && !boosting);
  ui.nitroPct.textContent = Math.round(nitro) + '%';
  ui.offtrack.classList.toggle('hidden', !(state === 'drive' && surface !== 'asphalt' && Math.abs(vF) > 3));
  ui.speedlines.style.opacity = clamp((kmh - 135) / 170, 0, 1) * (boosting ? 1 : 0.55);
}

/* ---------------- race flow ---------------- */
function startRace() {
  if (state !== 'menu') return;
  ui.overlay.classList.add('hidden');
  ui.hud.classList.remove('hidden');
  ui.touch.classList.add('on');
  audio.init();
  state = 'countdown'; stateT = 0; cdStage = -1;
}
function updateCountdown(dt) {
  stateT += dt;
  const seq = [[0.05, '3', 440], [0.75, '2', 440], [1.45, '1', 440], [2.15, 'GO!', 880]];
  for (let i = 0; i < seq.length; i++) {
    if (stateT >= seq[i][0] && cdStage < i) {
      cdStage = i;
      flashMsg(seq[i][1], i === 3 ? 850 : 640);
      audio.beep(seq[i][2], i === 3 ? 0.32 : 0.13);
      if (i === 3) state = 'drive';
    }
  }
}

/* ---------------- boot ---------------- */
const clock = new THREE.Clock();
let last = { vF: 0, vR: 0, sliding: false, ratio: 0 };

async function init() {
  const manager = new THREE.LoadingManager();
  manager.onProgress = (u, done, total) => {
    ui.loadFill.style.width = Math.round((done / Math.max(total, 1)) * 88) + '%';
  };
  const loader = new GLTFLoader(manager);
  ui.loadText.textContent = 'Loading Silver Lake track (23 MB)…';
  const trackG = await loader.loadAsync(TRACK_URL);
  ui.loadText.textContent = 'Loading Saba V12…';
  const carG = await loader.loadAsync(CAR_URL);
  ui.loadFill.style.width = '92%';
  ui.loadText.textContent = 'Building track physics…';
  await nextFrame();
  setupTrack(trackG);
  ui.loadText.textContent = 'Scouting spawn points on the asphalt…';
  await nextFrame();
  spawns = findSpawns();
  console.log('[spawn] candidates:', spawns.length);
  setupCar(carG);
  initSmoke();
  placeAtSpawn(0);
  ui.loadFill.style.width = '100%';
  ui.loadText.textContent = 'Ready — Saba V12 on the Silver Lake grid.';
  ui.startBtn.disabled = false;
}

renderer.setAnimationLoop(() => {
  const dt = Math.min(clock.getDelta(), 0.05);
  clockT += dt;
  shakeAmp *= Math.exp(-dt * 3.0);
  if (carGroup) {
    if (state === 'countdown') updateCountdown(dt);
    if (state === 'drive') {
      const sub = 2, sdt = dt / sub;
      for (let i = 0; i < sub; i++) last = stepPhysics(sdt);
    }
    updateSmoke(dt);
    updateCamera(dt, last.vF);
    updateHUD(last.vF);
    audio.update(dt, clamp(Math.abs(last.vF) / 62, 0, 1), !!input.gas, last.sliding && state === 'drive', boosting);
    if (boosting && Math.abs(last.vF) > 18) shakeAmp = Math.max(shakeAmp, 0.055);
  }
  renderer.render(scene, camera);
});

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

init().catch(showError);
