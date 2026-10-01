import { existsSync } from "node:fs";
import { resolve, join } from "node:path";
import { baseId, bounds, materials, type Blueprint, type Vec3 } from "@tb/blueprint";

/**
 * Where a blueprint block ends up when cc-factory builds it with the default
 * origin (turtle at 0,0,0 facing north) and an export normalised to min=0.
 * Measured with turtlesim (a 5x5 spike): x is mirrored, z is behind the turtle,
 * y is the turtle's own level. See cc-binaries turtlesim/README.md.
 */
export function ccToWorld(rel: Vec3): Vec3 {
  return [-(rel[0] + 1), rel[1], rel[2] + 1];
}

/** Shift a blueprint so its minimum corner is 0,0,0 (cc-factory treats y as absolute). */
export function normalise(bp: Blueprint): Blueprint {
  const bb = bounds(bp);
  if (!bb) return bp;
  return {
    ...bp,
    blocks: bp.blocks.map(([x, y, z, b]) => [x - bb.min[0], y - bb.min[1], z - bb.min[2], b]),
  };
}

// '.', ':', '=' and whitespace are legend separators or air, so never symbols.
const SYMBOLS = "#GLTSWBCPFRIOMNKHDEAUXYZQVJ0123456789abcdefghijklmnopqrstuvwxyz@$%&*+";

export interface LayeredExport {
  format: "layered-text";
  text: string;
  /** symbol -> base block id */
  legend: Record<string, string>;
  warnings: string[];
}

export interface BlocksExport {
  format: "blocks-json";
  text: string;
  warnings: string[];
}

function stateWarnings(bp: Blueprint): string[] {
  return bp.blocks.some((b) => b[3].includes("["))
    ? ["blockstate is carried in meta but ignored by turtles today"]
    : [];
}

/** cc-factory text grid: `legend:` then `layer:N` blocks, x across, z down. */
export function toLayeredText(input: Blueprint): LayeredExport {
  const bp = normalise(input);
  const mats = materials(bp);
  if (mats.length > SYMBOLS.length) {
    throw new Error(`${mats.length} materials exceed the ${SYMBOLS.length} text-grid symbols; use toBlocksJson`);
  }
  const symbols = new Map<string, string>();
  const legend: Record<string, string> = {};
  mats.forEach((m, i) => {
    const s = SYMBOLS[i] as string;
    symbols.set(m.block, s);
    legend[s] = m.block;
  });
  const bb = bounds(bp);
  const lines: string[] = ["legend:"];
  for (const [s, block] of Object.entries(legend)) lines.push(`${s} = ${block}`);
  if (bb) {
    const cells = new Map(bp.blocks.map((b) => [`${b[0]},${b[1]},${b[2]}`, b[3]]));
    for (let y = 0; y <= bb.max[1]; y++) {
      lines.push("", `layer:${y}`);
      for (let z = 0; z <= bb.max[2]; z++) {
        let row = "";
        for (let x = 0; x <= bb.max[0]; x++) {
          const b = cells.get(`${x},${y},${z}`);
          row += b ? (symbols.get(baseId(b)) as string) : ".";
        }
        lines.push(row);
      }
    }
  }
  return { format: "layered-text", text: lines.join("\n") + "\n", legend, warnings: stateWarnings(bp) };
}

/** cc-factory `{blocks:[{x,y,z,material,meta}]}` JSON; no palette limit. */
export function toBlocksJson(input: Blueprint): BlocksExport {
  const bp = normalise(input);
  const blocks = bp.blocks.map(([x, y, z, b]) => {
    const entry: Record<string, unknown> = { x, y, z, material: baseId(b) };
    const m = /\[(.*)\]$/.exec(b);
    if (m?.[1]) entry.meta = { state: Object.fromEntries(m[1].split(",").map((p) => p.split("="))) };
    return entry;
  });
  return { format: "blocks-json", text: JSON.stringify({ blocks }, null, 1) + "\n", warnings: stateWarnings(bp) };
}

/** Pick layered text when the palette fits, else blocks JSON. */
export function exportSchema(bp: Blueprint): LayeredExport | BlocksExport {
  return materials(bp).length <= SYMBOLS.length ? toLayeredText(bp) : toBlocksJson(bp);
}

export interface CcBinaries {
  root: string;
  turtle: string;
  factory: string;
}

/** Locate a cc-binaries checkout (with turtlesim and cc-factory) or throw. */
export function findCcBinaries(root = process.env.CC_BINARIES ?? resolve(process.cwd(), "../cc-binaries")): CcBinaries {
  const turtle = join(root, "turtlesim", "turtle");
  const factory = join(root, "cc-factory", "factory.lua");
  if (!existsSync(turtle) || !existsSync(factory)) {
    throw new Error(
      `cc-binaries not found at ${root} (need turtlesim/turtle and cc-factory/factory.lua; ` +
        `set CC_BINARIES to a checkout that has the turtlesim and the schema-path fix)`,
    );
  }
  return { root, turtle, factory };
}
