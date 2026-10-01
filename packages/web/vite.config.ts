import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import type { Plugin } from "vite";
import { defineConfig } from "vite";
import { diffBuild, type TurtleSummary } from "@tb/tester";

const dir = resolve(process.env.TB_BLUEPRINTS ?? "../../blueprints");

/** Serves blueprint files (the source of truth) and the latest test diff; the page polls `version`. */
function blueprintApi(): Plugin {
  return {
    name: "blueprint-api",
    configureServer(server) {
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
