import { existsSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { applyOps, newBlueprint } from "@tb/blueprint";
import { ccToWorld } from "@tb/cc-bridge";
import { diffBuild, formatReport, makeWorld, runBuildTest, type TurtleSummary } from "./index";

const spike = applyOps(newBlueprint("spike"), [
  { op: "fill", from: [0, 0, 0], to: [4, 0, 4], block: "minecraft:stone_bricks" },
  { op: "fill", from: [0, 1, 0], to: [4, 1, 4], block: "minecraft:stone_bricks", mode: "outline" },
  { op: "set", at: [2, 1, 2], block: "minecraft:glass" },
]);

function perfectSummary(): TurtleSummary {
  return {
    fuelUsed: 72, moves: 72, dug: 0, actions: 182, failures: {}, finalPos: [0, 0, 0],
    blocks: spike.blocks.map(([x, y, z, b]) => [...ccToWorld([x, y, z]), b] as [number, number, number, string]),
  };
}

describe("makeWorld", () => {
  it("stocks the turtle with exactly the needed stacks", () => {
    const { lua, slots } = makeWorld(spike);
    expect(slots).toBe(2);
    expect(lua).toContain('"minecraft:stone_bricks:41"');
    expect(lua).toContain('"minecraft:glass:1"');
    expect(lua).toContain('facing = "north"');
  });

  it("rejects builds that do not fit in 16 slots", () => {
    const big = applyOps(newBlueprint("big"), [{ op: "fill", from: [0, 0, 0], to: [31, 1, 31], block: "stone" }]);
    expect(() => makeWorld(big)).toThrow(/16/);
  });
});

describe("diffBuild", () => {
  it("passes a complete build", () => {
    const r = diffBuild(spike, perfectSummary());
    expect(r.complete).toBe(true);
    expect(r.built).toBe(42);
    expect(formatReport(r)).toMatch(/^PASS: built 42 of 42/);
  });

  it("reports missing, wrong and extra blocks", () => {
    const s = perfectSummary();
    const dropped = s.blocks!.pop()!;
    s.blocks![0]![3] = "minecraft:dirt";
    s.blocks!.push([50, 50, 50, "minecraft:stone"]);
    const r = diffBuild(spike, s);
    expect(r.complete).toBe(false);
    expect(r.missing).toHaveLength(1);
    expect(r.wrong).toHaveLength(1);
    expect(r.extra).toBe(1);
    expect(dropped).toBeDefined();
    expect(formatReport(r)).toMatch(/^FAIL/);
  });
});

const ccBinaries = process.env.CC_BINARIES ?? "/Users/arcades/Documents/GitHub/cc-binaries";
const haveSim = existsSync("/Applications/CraftOS-PC.app") && existsSync(`${ccBinaries}/turtlesim/turtle`);

describe.skipIf(!haveSim)("turtlesim integration", () => {
  it("builds the 5x5 spike end to end", async () => {
    const result = await runBuildTest(spike, { ccBinaries, timeoutSec: 120 });
    expect(formatReport(result.report)).toMatch(/^PASS: built 42 of 42/);
    expect(result.report.extra).toBe(0);
    expect(result.report.failures).toEqual({});
  }, 150_000);

  it("fails visibly when the turtle has no fuel", async () => {
    // fuel 0 means the turtle cannot move, so nothing gets built.
    const result = await runBuildTest(spike, { ccBinaries, timeoutSec: 60, fuel: 0, workDir: ".turtle-test/nofuel" });
    expect(result.report.complete).toBe(false);
    expect(result.report.missing.length).toBeGreaterThan(0);
  }, 90_000);
});
