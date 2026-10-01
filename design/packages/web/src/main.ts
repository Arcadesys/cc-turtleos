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

function render() {
  group.clear();
  if (!current) return;
  const { blueprint: bp, report } = current;
  const maxY = Number($<HTMLInputElement>("slice").value);
  const shown = bp.blocks.filter((b) => b[1] <= maxY);
  const byBlock = new Map<string, Array<[number, number, number]>>();
  for (const [x, y, z, b] of shown) {
    const id = baseId(b);
    (byBlock.get(id) ?? byBlock.set(id, []).get(id)!).push([x, y, z]);
  }
  const m = new THREE.Matrix4();
  for (const [id, cells] of byBlock) {
    const mesh = new THREE.InstancedMesh(unit, materialFor(id), cells.length);
    cells.forEach(([x, y, z], i) => mesh.setMatrixAt(i, m.makeTranslation(x, y, z)));
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
    sw.style.backgroundImage = `url(${textureUrl(m.block)})`;
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
void poll();

renderer.setAnimationLoop(() => {
  controls.update();
  renderer.render(scene, camera);
});
