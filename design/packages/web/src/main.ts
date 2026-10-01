import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { baseId, materials, type Blueprint } from "@tb/blueprint";

// Shape of the /api/blueprint response; the report is computed server-side by @tb/tester.
interface Report {
  planned: number; built: number; fuelUsed: number; moves: number; extra: number; complete: boolean;
  missing: Array<{ at: [number, number, number]; block: string }>;
  wrong: Array<{ at: [number, number, number]; expected: string; actual: string }>;
  failures: Record<string, number>;
}
interface Payload { blueprint: Blueprint; report: Report | null; version: string }

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
$("view").appendChild(renderer.domElement);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 1000);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
scene.add(new THREE.HemisphereLight(0xffffff, 0x666666, 1.6));
const sun = new THREE.DirectionalLight(0xffffff, 1.4);
sun.position.set(30, 60, 20);
scene.add(sun);
const grid = new THREE.GridHelper(64, 64, 0x888888, 0xbbbbbb);
(grid.material as THREE.Material).opacity = 0.35;
(grid.material as THREE.Material).transparent = true;
scene.add(grid);

function resize() {
  renderer.setSize(innerWidth, innerHeight);
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setClearColor(matchMedia("(prefers-color-scheme: dark)").matches ? 0x161715 : 0xf4f4f2);
}
addEventListener("resize", resize);
resize();

// Blocks with no texture in the loaded packs that should not get a random hash colour.
const COLOR_OVERRIDES: Record<string, number> = {
  "computercraft:monitor_normal": 0x2b2f36,
  "computercraft:monitor_advanced": 0x1b2a3d,
  "computercraft:computer_normal": 0x8a8a86,
  "computercraft:computer_advanced": 0xc9a227,
  "computercraft:turtle_normal": 0x8a8a86,
  "computercraft:turtle_advanced": 0xc9a227,
};

const colorOf = (block: string): THREE.Color => {
  const fixed = COLOR_OVERRIDES[baseId(block)];
  if (fixed !== undefined) return new THREE.Color(fixed);
  let h = 0;
  for (const c of baseId(block)) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return new THREE.Color().setHSL((h % 360) / 360, 0.45, 0.55);
};

const unit = new THREE.BoxGeometry(1, 1, 1);

// One material per block id: flat colour first, swapped for the resource-pack texture if the server has one.
const loader = new THREE.TextureLoader();
let available = new Set<string>();
const textureReady = fetch("/api/textures").then((r) => r.json() as Promise<string[]>).then((ids) => { available = new Set(ids); }).catch(() => {});
const materialCache = new Map<string, THREE.MeshLambertMaterial>();
const textureUrl = (id: string) => {
  const [ns, name] = id.split(":");
  return `/api/texture/${ns}/${name}`;
};
function materialFor(id: string): THREE.MeshLambertMaterial {
  let mat = materialCache.get(id);
  if (mat) return mat;
  mat = new THREE.MeshLambertMaterial({ color: colorOf(id) });
  materialCache.set(id, mat);
  const target = mat;
  if (!available.has(id)) return mat;
  loader.load(textureUrl(id), (tex) => {
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestMipmapLinearFilter;
    const img = tex.image as { width: number; height: number };
    if (img.height > img.width) {
      // Animated texture strip: show the first frame.
      tex.repeat.set(1, img.width / img.height);
      tex.offset.set(0, 1 - img.width / img.height);
    }
    target.map = tex;
    target.color.set(0xffffff);
    target.alphaTest = 0.1;
    target.transparent = true;
    target.needsUpdate = true;
  }, undefined, () => { /* no texture for this block: keep the colour */ });
  return mat;
}
const group = new THREE.Group();
scene.add(group);
let current: Payload | null = null;
let framed = "";

// Block height as a fraction of a cube: carpets and slabs are not full cubes.
const heightOf = (block: string): number => {
  const id = baseId(block);
  return id.endsWith("_carpet") ? 1 / 16 : id.endsWith("_slab") ? 0.5 : 1;
};
let occupied = new Map<string, number>();
let groundY = 0;

function render() {
  group.clear();
  if (!current) return;
  const { blueprint: bp, report } = current;
  const maxY = Number($<HTMLInputElement>("slice").value);
  const shown = bp.blocks.filter((b) => b[1] <= maxY);
  occupied = new Map(shown.map((b) => [`${b[0]},${b[1]},${b[2]}`, heightOf(b[3])]));
  groundY = bp.blocks.length ? Math.min(...bp.blocks.map((b) => b[1])) : 0;
  const byBlock = new Map<string, Array<[number, number, number]>>();
  for (const [x, y, z, b] of shown) {
    const id = baseId(b);
    (byBlock.get(id) ?? byBlock.set(id, []).get(id)!).push([x, y, z]);
  }
  const m = new THREE.Matrix4();
  for (const [id, cells] of byBlock) {
    const mesh = new THREE.InstancedMesh(unit, materialFor(id), cells.length);
    const h = heightOf(id);
    cells.forEach(([x, y, z], i) => mesh.setMatrixAt(i, m.makeTranslation(x, y - 0.5 + h / 2, z).multiply(new THREE.Matrix4().makeScale(1, h, 1))));
    group.add(mesh);
  }
  if (report && $<HTMLInputElement>("ghosts").checked) {
    const ghost = (cells: Array<[number, number, number]>, color: number) => {
      const cells2 = cells.filter((c) => c[1] <= maxY);
      if (!cells2.length) return;
      const mesh = new THREE.InstancedMesh(unit, new THREE.MeshBasicMaterial({ color, wireframe: true }), cells2.length);
      cells2.forEach(([x, y, z], i) => mesh.setMatrixAt(i, m.makeTranslation(x, y, z)));
      group.add(mesh);
    };
    ghost(report.missing.map((r) => r.at), 0xd23b2a);
    ghost(report.wrong.map((r) => r.at), 0xe08a00);
  }
}

function sidebar() {
  if (!current) return;
  const { blueprint: bp, report } = current;
  const ys = bp.blocks.map((b) => b[1]);
  const lo = Math.min(...ys), hi = Math.max(...ys);
  const slice = $<HTMLInputElement>("slice");
  const wasTop = Number(slice.value) >= Number(slice.max);
  slice.min = String(lo);
  slice.max = String(hi);
  if (wasTop || Number(slice.value) < lo || Number(slice.value) > hi) slice.value = String(hi);
  $("sliceLabel").textContent = bp.blocks.length ? `showing y ${lo} to ${slice.value} of ${hi}` : "empty blueprint";
  const ul = $("mats");
  ul.replaceChildren(...materials(bp).map((m) => {
    const li = document.createElement("li");
    const sw = document.createElement("span");
    sw.className = "sw";
    sw.style.background = "#" + colorOf(m.block).getHexString();
    if (available.has(m.block)) sw.style.backgroundImage = `url(${textureUrl(m.block)})`;
    sw.style.backgroundSize = "cover";
    sw.style.imageRendering = "pixelated";
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = m.block;
    const n = document.createElement("span");
    n.className = "n";
    n.textContent = String(m.count);
    li.append(sw, name, n);
    return li;
  }));
  const r = $("report");
  if (!report) {
    r.textContent = "No test run yet. Ask Claude to run test_run_build.";
    return;
  }
  const fails = Object.entries(report.failures).map(([k, n]) => `${k} x${n}`).join(", ");
  r.innerHTML = "";
  const head = document.createElement("div");
  head.className = report.complete ? "pass" : "fail";
  head.textContent = `${report.complete ? "PASS" : "FAIL"}: built ${report.built} of ${report.planned}`;
  const body = document.createElement("div");
  body.textContent = `fuel ${report.fuelUsed}, moves ${report.moves}; missing ${report.missing.length}, wrong ${report.wrong.length}, extra ${report.extra}` + (fails ? `; failures: ${fails}` : "");
  r.append(head, body);
}

function frame(bp: Blueprint) {
  if (framed === bp.name || !bp.blocks.length) return;
  framed = bp.name;
  const xs = bp.blocks.map((b) => b[0]), ys = bp.blocks.map((b) => b[1]), zs = bp.blocks.map((b) => b[2]);
  const mid = new THREE.Vector3((Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2, (Math.min(...zs) + Math.max(...zs)) / 2);
  const span = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys), Math.max(...zs) - Math.min(...zs)) + 4;
  controls.target.copy(mid);
  camera.position.set(mid.x + span, mid.y + span * 0.8, mid.z + span * 1.3);
  grid.position.set(mid.x, Math.min(...ys) - 0.5, mid.z);
}

async function load(name: string, force = false) {
  const res = await fetch(`/api/blueprint/${encodeURIComponent(name)}`);
  if (!res.ok) return;
  const next = (await res.json()) as Payload;
  if (!force && current?.version === next.version && current.blueprint.name === next.blueprint.name) return;
  current = next;
  frame(next.blueprint);
  sidebar();
  render();
}

const pick = $<HTMLSelectElement>("pick");
async function refreshList() {
  const names = (await (await fetch("/api/list")).json()) as string[];
  if (names.join() !== Array.from(pick.options, (o) => o.value).join()) {
    const keep = pick.value;
    pick.replaceChildren(...names.map((n) => new Option(n, n)));
    if (names.includes(keep)) pick.value = keep;
    if (names.length) await load(pick.value, true);
  }
  if (!names.length) $("sliceLabel").textContent = "No blueprints yet. Ask Claude to run blueprint_new.";
}
pick.addEventListener("change", () => { framed = ""; void load(pick.value, true); });
$("slice").addEventListener("input", () => { sidebar(); render(); });
$("ghosts").addEventListener("change", render);

// Files on disk are the source of truth; poll for edits from Claude or a test run.
const poll = () => refreshList().then(async () => { if (pick.value) await load(pick.value); }).catch(() => { /* server restarting: try again next tick */ });
setInterval(() => { void poll(); }, 1500);
void textureReady.then(() => { materialCache.clear(); void poll(); });

renderer.setAnimationLoop(() => {
  stepWalk();
  if (!walking) controls.update();
  renderer.render(scene, camera);
});

// Walk mode: first-person with voxel collision. Cells span [c-0.5, c+0.5]; below the lowest layer is solid ground.
const RADIUS = 0.3, HEIGHT = 1.8, EYE = 1.62;
let walking = false;
let yaw = 0, pitch = 0;
let vy = 0, onGround = false;
const feet = new THREE.Vector3();
(window as unknown as { tbWalk: unknown }).tbWalk = { feet, get walking() { return walking; } }; // read-only debug hook
const held = new Set<string>();
let dragLook = false;
const look = $<HTMLInputElement>("look");
try { look.value = localStorage.getItem("tb-look") ?? look.value; } catch { /* storage blocked */ }
look.addEventListener("input", () => { try { localStorage.setItem("tb-look", look.value); } catch { /* storage blocked */ } });
// Radians per pixel; the slider runs 1..30 around a default of 10 (0.0011).
const lookSpeed = () => Number(look.value) * 0.00011;
const clampMove = (n: number) => Math.max(-60, Math.min(60, n));
let last = performance.now();

// Top of the solid part of a cell, or null if empty. Everything at or below the lowest layer is ground.
const topOf = (cx: number, cy: number, cz: number): number | null => {
  if (cy <= groundY) return cy + 0.5;
  const h = occupied.get(`${cx},${cy},${cz}`);
  return h === undefined ? null : cy - 0.5 + h;
};

function hits(x: number, y: number, z: number): boolean {
  for (let cx = Math.round(x - RADIUS); cx <= Math.round(x + RADIUS); cx++)
    for (let cy = Math.round(y - 0.5); cy <= Math.round(y + HEIGHT - 0.01); cy++)
      for (let cz = Math.round(z - RADIUS); cz <= Math.round(z + RADIUS); cz++) {
        const overlapX = x + RADIUS > cx - 0.5 && x - RADIUS < cx + 0.5;
        const overlapZ = z + RADIUS > cz - 0.5 && z - RADIUS < cz + 0.5;
        const top = overlapX && overlapZ ? topOf(cx, cy, cz) : null;
        if (top !== null && y + HEIGHT > cy - 0.5 && y < top - 1e-6) return true;
      }
  return false;
}

function setWalking(on: boolean) {
  if (!current || !current.blueprint.blocks.length) return;
  walking = on;
  document.body.classList.toggle("walking", on);
  controls.enabled = !on;
  $("walk").textContent = on ? "Stop walking (Esc)" : "Walk around (F)";
  if (on) {
    const xs = current.blueprint.blocks.map((b) => b[0]), zs = current.blueprint.blocks.map((b) => b[2]);
    // Start outside the +z (front) side, facing the building.
    feet.set((Math.min(...xs) + Math.max(...xs)) / 2, groundY + 0.5, Math.max(...zs) + 4);
    yaw = 0; pitch = 0; vy = 0; onGround = true;
    void Promise.resolve(renderer.domElement.requestPointerLock?.()).catch(() => { dragLook = false; });
  } else {
    held.clear();
    if (document.pointerLockElement) document.exitPointerLock();
    controls.target.set(feet.x, feet.y + EYE, feet.z - 6);
  }
}

function stepWalk() {
  const now = performance.now();
  let left = Math.min((now - last) / 1000, 0.5);
  last = now;
  if (!walking) return;
  // Sub-step so a slow frame moves the right distance without tunnelling through walls.
  while (left > 1e-4) {
    const dt = Math.min(left, 0.025);
    physics(dt);
    left -= dt;
  }
  camera.position.set(feet.x, feet.y + EYE, feet.z);
  camera.rotation.set(pitch, yaw, 0, "YXZ");
}

function physics(dt: number) {
  const speed = (held.has("ShiftLeft") || held.has("ShiftRight") ? 7 : 4.3) * dt;
  const f = (held.has("KeyW") ? 1 : 0) - (held.has("KeyS") ? 1 : 0);
  const r = (held.has("KeyD") ? 1 : 0) - (held.has("KeyA") ? 1 : 0);
  const len = Math.hypot(f, r) || 1;
  const dx = ((-Math.sin(yaw) * f + Math.cos(yaw) * r) / len) * speed;
  const dz = ((-Math.cos(yaw) * f - Math.sin(yaw) * r) / len) * speed;
  // Walk into a carpet, slab or other low edge: step up onto it (up to 0.6) like the game does.
  const slide = (mx: number, mz: number) => {
    if (!hits(feet.x + mx, feet.y, feet.z + mz)) { feet.x += mx; feet.z += mz; }
    else if (onGround && !hits(feet.x + mx, feet.y + 0.6, feet.z + mz)) { feet.x += mx; feet.z += mz; feet.y += 0.6; onGround = false; }
  };
  slide(dx, 0);
  slide(0, dz);
  if (onGround && held.has("Space")) { vy = 8; onGround = false; }
  vy -= 25 * dt;
  const ny = feet.y + vy * dt;
  if (!hits(feet.x, ny, feet.z)) {
    feet.y = ny;
    onGround = false;
  } else {
    if (vy < 0) onGround = true;
    vy = 0;
  }
}

addEventListener("keydown", (e) => {
  if (e.code === "KeyF" && !(e.target instanceof HTMLSelectElement)) { setWalking(!walking); return; }
  if (walking) { held.add(e.code); if (e.code === "Space") e.preventDefault(); if (e.code === "Escape") setWalking(false); }
});
addEventListener("keyup", (e) => held.delete(e.code));
addEventListener("blur", () => held.clear());
$("walk").addEventListener("click", () => setWalking(!walking));
document.addEventListener("pointerlockchange", () => {
  if (walking && !document.pointerLockElement) dragLook = false; // fall back to drag-to-look until the next click
});
renderer.domElement.addEventListener("mousedown", () => {
  if (!walking) return;
  if (!document.pointerLockElement) { void Promise.resolve(renderer.domElement.requestPointerLock?.()).catch(() => {}); dragLook = true; }
});
addEventListener("mouseup", () => { dragLook = false; });
addEventListener("mousemove", (e) => {
  if (!walking || !(document.pointerLockElement || dragLook)) return;
  yaw -= clampMove(e.movementX) * lookSpeed();
  pitch = Math.max(-1.55, Math.min(1.55, pitch - clampMove(e.movementY) * lookSpeed()));
});
