# TurtleOS design tools

Part of [TurtleOS](../agents.md). Design a build with Claude, see it in 3D, then test it on a simulated ComputerCraft turtle. The on-turtle roles and strategies live in `../turtleos/`; the simulator and the schema builder (`turtlesim`, `cc-factory`) live in [cc-binaries](https://github.com/Arcadesys/cc-binaries).

```
Claude ──MCP──► blueprint files (.blueprint.json) ──► viewer (three.js, live reload)
                      │
                      └─► cc-factory schema ─► turtlesim ─► built vs planned ─► viewer overlay
```

Blueprint files on disk are the source of truth. The MCP server holds no state, so edits from Claude, the CLI and your editor all agree.

## Packages

| package | what it does |
| --- | --- |
| `packages/blueprint` | sparse voxel model, namespaced block ids (`mod:block[state]`), `set`/`fill`/`clear` ops, validation, material counts |
| `packages/cc-bridge` | exports cc-factory's layered text or blocks JSON, normalises to `layer:0`, finds a cc-binaries checkout, and `ccToWorld` (where cc-factory actually places a block) |
| `packages/tester` | builds a turtlesim world from a blueprint, runs `factory.lua`, diffs placed blocks against the blueprint |
| `packages/mcp` | stdio MCP server: `blueprint_new/apply/get/validate/export_cc/list`, `test_run_build` |
| `packages/web` | read-only viewer: layer slicer, materials, test report, missing/wrong overlay |

## Setup

```bash
cd design
npm install
npm test
```

Tests that run the real simulator need CraftOS-PC and a [cc-binaries](https://github.com/Arcadesys/cc-binaries) checkout that has `turtlesim/` with `--file`, `--results` and `--dump-blocks`, plus the `factory.lua` schema-path fix. Point `CC_BINARIES` at it (default: `cc-binaries` next to this repo). They skip when it is missing.

## Use with Claude Code

```json
{
  "mcpServers": {
    "turtle-blueprints": {
      "command": "npx",
      "args": ["tsx", "design/packages/mcp/src/server.ts"],
      "env": { "TB_BLUEPRINTS": "blueprints", "CC_BINARIES": "../../cc-binaries" }
    }
  }
}
```

View the blueprints (reloads as files change):

```bash
TB_BLUEPRINTS=blueprints npm run dev -w @tb/web
```

## Textures (optional)

Drop any Minecraft resource pack `.zip` into `design/textures/` (gitignored, never committed) and the viewer skins blocks with `assets/<namespace>/textures/block/<name>.png`. Mod packs work the same way, so ATM10 blocks can be skinned by adding the mods' pack zips. Blocks without a texture keep a flat colour. Logs, grass and furnaces use a single face for now. Packs carry their own licences (Faithful's is not open), so keep them out of the repo.

## Limits to know about

- A turtle test must fit in the turtle's 16 inventory slots (about 1000 blocks); cc-factory does not pull from chests when checking requirements.
- Turtles place a block as the item of the same name. Blockstate (stairs, log axis) is carried but ignored, and doors, beds, redstone dust and fluids will not place.
- cc-factory builds mirrored left to right and behind-left of the turtle. The diff accounts for it; the viewer shows the blueprint as designed.
- A turtlesim exit status only says it did not crash. Judge a build by the report.
