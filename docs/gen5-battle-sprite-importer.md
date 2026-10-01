# Black/White battle sprite importer

Open **IMPORTERS → Pokemon Black / White** and choose your own untrimmed 256 MiB
Black or White `.nds` cartridge dump. Unzip it first. The importer runs inside
the engine: no Windows decoder, download, or separate Python tool is required.
It reads the ROM locally and writes a shared pack in the save directory at
`asset_packs/gen5_bw/battle_sprites`. No ROM or extracted artwork ships with this
change or the provider example.

This beta accepts structurally valid original Black/White archives with game
codes beginning `IRA` or `IRB`, and records the source MD5. It does not use an
MD5 allowlist. Black (IRBO, USA/Europe) was tested; White and other regions have
not yet been verified. Black 2 / White 2 and trimmed dumps are unsupported.

The pack exports national dex 1–649 base forms, front/back, normal/shiny and
female variants. Missing female graphics use the source's male/unisex graphics.
Exporter 1.0.1 reuses the same atlas file for those identical gender variants,
keeping all entry IDs available. On tested Black this removes 2,212 duplicate
PNG encodes/writes out of 5,192 while preserving the artwork and timing.
Alternate forms, portraits, overworld sprites, audio and battle renderer changes
are outside this importer. NMAR selects the idle multicell map; the separate
wait/break sequences are not combined with that idle animation.

## Public pack contract

Declare an optional dependency to keep native graphics available when no pack
has been imported:

```json
"optional_assets": [
  { "importer": "gen5_bw", "pack": "battle_sprites", "version": ">=1.0.0" }
]
```

Use `mod.packs:info`, `mod.packs:entries`, `mod.packs:entry` and `mod.packs:read`.
Entry IDs are `normal/025/front`, `shiny/025/back` and their `/female` variants.
Each entry has `width`/`height` for the whole PNG atlas, `frames`, and a `sprite`
table containing frame `width`/`height`, `columns`, `frames`, `tickRate = 60`,
integer `durations` in ticks, zero-based `loopStartFrame`, `cycleTicks`,
`cycleCapped`, `anchorX` and `anchorY`. Cells are row-major with a common opaque
union and transparent background. Play the introduction once, then repeat the
suffix starting at `loopStartFrame`; seconds per frame are `duration / tickRate`.

Exports are bounded to 240 ticks. `cycleCapped = true` means the source's full
cycle exceeds that bound; consumers should keep native graphics rather than
looping a truncated animation. The provider example does this. Tested Black
has 180 such side/gender variants across 56 species. All 2,596 side/gender
variants parsed and composed successfully; this is separate from White or
physical Quest verification.

`mods/examples/gen5_battle_sprites` exposes the shared provider API for Gen 1,
Gen 2, Gen 3 and renderer adapters. It does not replace battle art by itself.
A voxel renderer opts in through its adapter, so importing a pack has no
gameplay or rendering effect with no consumer installed.

## Import lifecycle and distribution

Android transfers run on a background worker and publish the final picker filename
only after a complete copy. Assembly slices yield after at most eight ticks or
a soft 4 ms limit between compositions. The launcher batches these slices within
a soft 6 ms budget, with at most 24 resumes per update; a failure stops the job. Assets use source MD5
and exporter version paths, and `pack.lua` is written after all entries. A failed
first import has no published pack. A reimport of the same source/version uses
the same paths; this is not a transactional filesystem replacement.

Distribute importer/provider code only. Every player imports their own dump.
Keep the port's MIT attribution in `src/import/gen5/PROVENANCE.md` and
`ANIMAENGINE_LICENSE`. Source/pixel parity evidence and private imported packs
are local verification materials, not repository fixtures.
