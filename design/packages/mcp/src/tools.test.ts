import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { Store, applyTool, exportTool, getTool, newTool, testTool, validateTool } from "./tools";

const fresh = () => new Store(mkdtempSync(join(tmpdir(), "tb-")));

describe("mcp tools", () => {
  it("creates, edits and shows a blueprint", () => {
    const s = fresh();
    newTool(s, { name: "tower" });
    const out = applyTool(s, {
      name: "tower",
      ops: [
        { op: "fill", from: [0, 0, 0], to: [4, 0, 4], block: "minecraft:stone_bricks" },
        { op: "fill", from: [0, 1, 0], to: [4, 3, 4], block: "minecraft:stone_bricks", mode: "hollow" },
        { op: "set", at: [2, 2, 0], block: "minecraft:glass" },
      ],
    });
    expect(out).toContain("applied 3 op(s)");
    const shown = getTool(s, { name: "tower", layers: [2] });
    expect(shown).toContain("y=2");
    expect(shown).toContain("minecraft:glass");
    expect(s.list()).toEqual(["tower"]);
  });

  it("rejects duplicates and bad names", () => {
    const s = fresh();
    newTool(s, { name: "a" });
    expect(() => newTool(s, { name: "a" })).toThrow(/already exists/);
    expect(() => s.path("../x")).toThrow(/bad blueprint name/);
    expect(() => getTool(s, { name: "missing" })).toThrow(/no blueprint named/);
  });

  it("validates and exports", () => {
    const s = fresh();
    newTool(s, { name: "b" });
    applyTool(s, { name: "b", ops: [{ op: "set", at: [0, 0, 0], block: "minecraft:oak_door" }] });
    expect(validateTool(s, { name: "b" })).toContain("warning:");
    expect(exportTool(s, { name: "b" })).toContain("legend:");
  });
});

const cc = process.env.CC_BINARIES ?? "/Users/arcades/Documents/GitHub/cc-binaries";
describe.skipIf(!existsSync("/Applications/CraftOS-PC.app") || !existsSync(`${cc}/turtlesim/turtle`))("test_run_build", () => {
  it("builds a small tower in the simulator", async () => {
    const s = fresh();
    newTool(s, { name: "tower" });
    applyTool(s, {
      name: "tower",
      ops: [
        { op: "fill", from: [0, 0, 0], to: [4, 3, 4], block: "minecraft:stone_bricks", mode: "hollow" },
        { op: "set", at: [2, 2, 0], block: "minecraft:glass" },
      ],
    });
    const out = await testTool(s, { name: "tower", ccBinaries: cc, timeoutSec: 120 });
    expect(out).toMatch(/^PASS: built \d+ of \d+/);
  }, 150_000);
});
