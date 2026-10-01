import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { unzipSync } from "fflate";
import type { Plugin } from "vite";
import { defineConfig } from "vite";
import { diffBuild, type TurtleSummary } from "@tb/tester";

const dir = resolve(process.env.TB_BLUEPRINTS ?? "../../blueprints");
const textureDir = resolve(process.env.TB_TEXTURES ?? "../../textures");

/** Block textures from every resource pack zip in textureDir, keyed "namespace:name"; later zips win. Packs are never committed. */
function loadTextures(): Map<string, Uint8Array> {
  const out = new Map<string, Uint8Array>();
  if (!existsSync(textureDir)) return out;
  for (const f of readdirSync(textureDir).filter((n) => n.endsWith(".zip")).sort()) {
    const files = unzipSync(new Uint8Array(readFileSync(join(textureDir, f))), {
      filter: (e) => /^assets\/[^/]+\/textures\/block\/[^/]+\.png$/.test(e.name),
    });
    for (const [path, data] of Object.entries(files)) {
      const m = /^assets\/([^/]+)\/textures\/block\/([^/]+)\.png$/.exec(path);
      if (m) out.set(`${m[1]}:${m[2]}`, data);
    }
  }
  return out;
}

// Faces tried in order when a block has no single-image texture (logs, grass, furnaces...).
const FACES = ["", "_side", "_top", "_front", "_end"];

// Shaped variants reuse another block's image: oak_slab -> oak_planks, red_carpet -> red_wool, stone_brick_stairs -> stone_bricks.
const SHAPES = ["_slab", "_stairs", "_wall", "_fence_gate", "_fence", "_button", "_pressure_plate", "_carpet"];
const BASES = ["", "_planks", "_block", "_wool", "_bricks", "s"];

function lookup(textures: Map<string, Uint8Array>, id: string): Uint8Array | undefined {
  const colon = id.indexOf(":");
  const ns = id.slice(0, colon);
  const name = id.slice(colon + 1);
  const tries = [name];
  for (const shape of SHAPES) if (name.endsWith(shape)) tries.push(...BASES.map((b) => name.slice(0, -shape.length) + b));
  for (const t of tries) for (const face of FACES) {
    const data = textures.get(`${ns}:${t}${face}`);
    if (data) return data;
  }
  return undefined;
}

/** Every id lookup() can answer, so the page never asks for a missing texture. */
function availableIds(textures: Map<string, Uint8Array>): string[] {
  const ids = new Set<string>();
  for (const key of textures.keys()) {
    const colon = key.indexOf(":");
    const ns = key.slice(0, colon);
    const name = key.slice(colon + 1);
    const names = new Set([name]);
    for (const face of FACES) if (face && name.endsWith(face)) names.add(name.slice(0, -face.length));
    for (const n of [...names]) {
      for (const suffix of ["_planks", "_wool", "_block", "_bricks"]) {
        if (n.endsWith(suffix)) for (const shape of SHAPES) names.add(n.slice(0, -suffix.length) + shape);
      }
      for (const shape of SHAPES) names.add(n + shape);
      if (n.endsWith("_bricks")) for (const shape of SHAPES) names.add(n.slice(0, -1) + shape);
    }
    for (const n of names) if (lookup(textures, `${ns}:${n}`)) ids.add(`${ns}:${n}`);
  }
  return [...ids];
}

/** Serves blueprint files (the source of truth) and the latest test diff; the page polls `version`. */
function blueprintApi(): Plugin {
  return {
    name: "blueprint-api",
    configureServer(server) {
      const textures = loadTextures();
      console.log(`textures: ${textures.size} block images from ${textureDir}`);
      server.middlewares.use("/api", (req, res, next) => {
        const url = new URL(req.url ?? "/", "http://x");
        const json = (v: unknown, code = 200) => {
          res.statusCode = code;
          res.setHeader("content-type", "application/json");
          res.end(JSON.stringify(v));
        };
        if (url.pathname === "/list") {
          const names = existsSync(dir)
            ? readdirSync(dir).filter((f) => f.endsWith(".blueprint.json")).map((f) => f.replace(/\.blueprint\.json$/, "")).sort()
            : [];
          return json(names);
        }
        if (url.pathname === "/textures") return json(availableIds(textures));
        const t = /^\/texture\/([a-z0-9_.-]+)\/([a-z0-9_./-]+)$/.exec(url.pathname);
        if (t) {
          const data = lookup(textures, `${t[1]}:${t[2]}`);
          if (data) {
            res.setHeader("content-type", "image/png");
            res.setHeader("cache-control", "max-age=3600");
            return void res.end(Buffer.from(data));
          }
          res.statusCode = 404;
          return void res.end();
        }
        const m = /^\/blueprint\/([A-Za-z0-9_-]+)$/.exec(url.pathname);
        if (!m) return next();
        const file = join(dir, `${m[1]}.blueprint.json`);
        if (!existsSync(file)) return json({ error: "not found" }, 404);
        const blueprint = JSON.parse(readFileSync(file, "utf8"));
        const summaryFile = join(dir, ".test", m[1] as string, "results", "summary.json");
        let report = null;
        let version = String(statSync(file).mtimeMs);
        if (existsSync(summaryFile)) {
          report = diffBuild(blueprint, JSON.parse(readFileSync(summaryFile, "utf8")) as TurtleSummary);
          version += ":" + statSync(summaryFile).mtimeMs;
        }
        json({ blueprint, report, version });
      });
    },
  };
}

export default defineConfig({ plugins: [blueprintApi()], server: { port: 5173 } });
