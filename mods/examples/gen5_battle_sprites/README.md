# Native Gen 5 battle sprite provider example

This artist/developer example exposes animated battle sprites from the player's own Black/White import to compatible renderer mods.

Try the source-only example from the engine checkout:

```sh
python3 tools/modkit.py validate mods/examples/gen5_battle_sprites --base fixture
python3 tools/modkit.py lint mods/examples/gen5_battle_sprites
luajit mods/examples/gen5_battle_sprites/tests/provider_test.lua
```

Import your own Pokémon Black/White cartridge dump with the launcher's `gen5_bw` importer. This code-only mod reads the resulting optional `battle_sprites` asset pack through `mod.packs`. Generated artwork stays in the player's cache. Do not distribute imported images, caches, packs, ROMs, or derived previews. This example needs no PC extraction tool or personal binary import manifest.

The mod supplies a renderer API; enabling it alone does not change an engine's battle drawing. A compatible renderer obtains `mod.find("GEN5_PRIVATE_SPRITES").exports`, checks `apiVersion == 1`, and calls `frame({dex,side,shiny,gender,form,battleId,battlerId,mon})`. Dex is national 1–649, side is front/back, and female/F/2 selects a female entry when present. Form nil/0/normal is supported. The caller excludes substitute, ghost, personality-dependent and unsupported special forms. Nil means draw the native sprite. Valid frames return `{image,width=64,height=64,groundOffset=32,frame,entryId}`. The capability descriptor retains the standalone provider's API version 1 contract; this native package is version 1.2.0.

The importer stores frame dimensions, columns, durations in integer ticks, `tickRate=60`, and a zero-based `loopStartFrame` in each entry's `sprite` metadata. The provider plays the prefix once, then repeats the suffix. An entry marked `cycleCapped` falls back to native art because its full animation cycle was not captured. Atlas dimensions are validated separately from frame dimensions, including the PNG header before image decoding.

One shared clock advances from the public `input.step` hook. Calling `frame` for the second eye does not advance animation. Consumers must not call exported `update(dt)` additionally. Stable battle/battler identifiers and mon identity preserve phase; switching mon or transformed dex restarts animation. Session ending releases cached graphics. The provider retains at most eight 64×64 GPU images and four decoded atlases, with each atlas limited to four million pixels and each PNG read limited to 8 MiB.

Run `luajit mods/examples/gen5_battle_sprites/tests/provider_test.lua` from the engine checkout for ROM-free loader, fallback and timing checks. These tests do not establish headset rendering or comfort.
