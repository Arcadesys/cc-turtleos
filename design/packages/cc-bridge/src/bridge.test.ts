import { describe, expect, it } from "vitest";
import { applyOps, newBlueprint } from "@tb/blueprint";
import { ccToWorld, normalise, toBlocksJson, toLayeredText } from "./index";

// Same shape as the 5x5 spike run through turtlesim.
const spike = applyOps(newBlueprint("spike"), [
  { op: "fill", from: [10, 5, 20], to: [14, 5, 24], block: "minecraft:stone_bricks" },
  { op: "fill", from: [10, 6, 20], to: [14, 6, 24], block: "minecraft:stone_bricks", mode: "outline" },
  { op: "set", at: [12, 6, 22], block: "minecraft:glass" },
]);

describe("normalise", () => {
  it("moves the minimum corner to 0,0,0", () => {
    const n = normalise(spike);
    expect(Math.min(...n.blocks.map((b) => b[0]))).toBe(0);
    expect(Math.min(...n.blocks.map((b) => b[1]))).toBe(0);
    expect(Math.min(...n.blocks.map((b) => b[2]))).toBe(0);
  });
});

describe("toLayeredText", () => {
  it("emits a legend, layer:N headers and rectangular rows", () => {
    const out = toLayeredText(spike);
    expect(out.text).toContain("legend:");
    expect(out.text).toContain("layer:0");
    expect(out.text).toContain("layer:1");
    expect(Object.values(out.legend).sort()).toEqual(["minecraft:glass", "minecraft:stone_bricks"]);
    const sym = Object.entries(out.legend).find(([, v]) => v === "minecraft:stone_bricks")?.[0] as string;
    const layer0 = out.text.split("layer:0\n")[1]!.split("\n\n")[0]!.split("\n");
    expect(layer0).toEqual(Array(5).fill(sym.repeat(5)));
  });

  it("puts the glass at the centre of layer 1 and air inside the ring", () => {
    const out = toLayeredText(spike);
    const g = Object.entries(out.legend).find(([, v]) => v === "minecraft:glass")?.[0] as string;
    const s = Object.entries(out.legend).find(([, v]) => v === "minecraft:stone_bricks")?.[0] as string;
    const layer1 = out.text.split("layer:1\n")[1]!.trim().split("\n");
    expect(layer1).toEqual([s.repeat(5), `${s}...${s}`, `${s}.${g}.${s}`, `${s}...${s}`, s.repeat(5)]);
  });

  it("refuses more materials than symbols", () => {
    let bp = newBlueprint("big");
    const ops = Array.from({ length: 80 }, (_, i) => ({ op: "set" as const, at: [i, 0, 0] as [number, number, number], block: `mod:block_${i}` }));
    bp = applyOps(bp, ops);
    expect(() => toLayeredText(bp)).toThrow(/toBlocksJson/);
  });

  it("warns about blockstate", () => {
    const bp = applyOps(newBlueprint("s"), [{ op: "set", at: [0, 0, 0], block: "minecraft:oak_stairs[facing=north]" }]);
    expect(toLayeredText(bp).warnings).toHaveLength(1);
  });
});

describe("toBlocksJson", () => {
  it("strips blockstate into meta", () => {
    const bp = applyOps(newBlueprint("s"), [{ op: "set", at: [3, 2, 1], block: "minecraft:oak_stairs[facing=north,half=top]" }]);
    const parsed = JSON.parse(toBlocksJson(bp).text);
    expect(parsed.blocks).toEqual([
      { x: 0, y: 0, z: 0, material: "minecraft:oak_stairs", meta: { state: { facing: "north", half: "top" } } },
    ]);
  });
});

describe("ccToWorld", () => {
  it("matches the transform measured in turtlesim (glass 2,1,2 -> -3,1,3)", () => {
    expect(ccToWorld([2, 1, 2])).toEqual([-3, 1, 3]);
    expect(ccToWorld([0, 0, 0])).toEqual([-1, 0, 1]);
    expect(ccToWorld([4, 0, 4])).toEqual([-5, 0, 5]);
  });
});
