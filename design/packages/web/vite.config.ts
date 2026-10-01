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
        const t = /^\/texture\/([a-z0-9_.-]+)\/([a-z0-9_./-]+)$/.exec(url.pathname);
        if (t) {
          for (const face of FACES) {
            const data = textures.get(`${t[1]}:${t[2]}${face}`);
            if (data) {
              res.setHeader("content-type", "image/png");
              res.setHeader("cache-control", "max-age=3600");
              return void res.end(Buffer.from(data));
            }
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
