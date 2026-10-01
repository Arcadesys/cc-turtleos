import { describe, expect, it } from "vitest";
import { applyOps, bounds, materials, newBlueprint, validate } from "./index";

describe("applyOps", () => {
  it("fills a solid box", () => {
    const bp = applyOps(newBlueprint("t"), [{ op: "fill", from: [0, 0, 0], to: [2, 1, 2], block: "stone" }]);
    expect(bp.blocks).toHaveLength(18);
    expect(bp.blocks[0]).toEqual([0, 0, 0, "minecraft:stone"]);
  });

  it("hollow box leaves the interior empty", () => {
    const bp = applyOps(newBlueprint("t"), [{ op: "fill", from: [0, 0, 0], to: [4, 4, 4], block: "stone", mode: "hollow" }]);
    expect(bp.blocks).toHaveLength(125 - 27);
    expect(bp.blocks.some((b) => b[0] === 2 && b[1] === 2 && b[2] === 2)).toBe(false);
  });

  it("outline keeps only the edges", () => {
    const bp = applyOps(newBlueprint("t"), [{ op: "fill", from: [0, 0, 0], to: [2, 2, 2], block: "stone", mode: "outline" }]);
    expect(bp.blocks).toHaveLength(20);
  });

  it("air removes blocks and clear empties regions", () => {
    let bp = applyOps(newBlueprint("t"), [{ op: "fill", from: [0, 0, 0], to: [3, 0, 3], block: "stone" }]);
    bp = applyOps(bp, [{ op: "set", at: [1, 0, 1], block: "air" }]);
    expect(bp.blocks).toHaveLength(15);
    bp = applyOps(bp, [{ op: "clear", from: [0, 0, 0], to: [1, 0, 3] }]);
    expect(bp.blocks).toHaveLength(8);
    expect(applyOps(bp, [{ op: "clear" }]).blocks).toHaveLength(0);
  });

  it("does not mutate its input", () => {
    const base = newBlueprint("t");
    applyOps(base, [{ op: "set", at: [0, 0, 0], block: "stone" }]);
    expect(base.blocks).toHaveLength(0);
  });

  it("rejects non-integer coordinates", () => {
    expect(() => applyOps(newBlueprint("t"), [{ op: "set", at: [0.5, 0, 0], block: "stone" }])).toThrow(/integers/);
  });
});

describe("analysis", () => {
  const bp = applyOps(newBlueprint("t"), [
    { op: "fill", from: [2, 3, 4], to: [4, 3, 4], block: "stone" },
    { op: "set", at: [3, 4, 4], block: "mekanism:steel_casing" },
  ]);

  it("computes bounds", () => {
    expect(bounds(bp)).toEqual({ min: [2, 3, 4], max: [4, 4, 4], size: [3, 2, 1] });
  });

  it("counts materials by base id", () => {
    expect(materials(bp)).toEqual([
      { block: "minecraft:stone", count: 3 },
      { block: "mekanism:steel_casing", count: 1 },
    ]);
  });
});

describe("validate", () => {
  it("accepts a clean blueprint", () => {
    const bp = applyOps(newBlueprint("t"), [{ op: "set", at: [0, 0, 0], block: "minecraft:stone" }]);
    expect(validate(bp)).toEqual([]);
  });

  it("flags bad ids, duplicates and unplaceable blocks", () => {
    const bp = newBlueprint("t");
    bp.blocks.push([0, 0, 0, "Stone!"], [1, 0, 0, "minecraft:stone"], [1, 0, 0, "minecraft:stone"], [2, 0, 0, "minecraft:oak_door"]);
    const msgs = validate(bp).map((i) => `${i.level}: ${i.message}`);
    expect(msgs.some((m) => m.startsWith("error: invalid block id"))).toBe(true);
    expect(msgs.some((m) => m.includes("duplicate block"))).toBe(true);
    expect(msgs.some((m) => m.startsWith("warning:") && m.includes("oak_door"))).toBe(true);
  });

  it("warns that blockstate is ignored by turtles", () => {
    const bp = applyOps(newBlueprint("t"), [{ op: "set", at: [0, 0, 0], block: "minecraft:oak_stairs[facing=north]" }]);
    const issues = validate(bp);
    expect(issues).toHaveLength(1);
    expect(issues[0]?.level).toBe("warning");
  });
});
