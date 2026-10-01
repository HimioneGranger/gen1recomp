# RFC 0022: engine-owned Black/White battle sprite pack

## Motivation and existing decision

Mods and voxel renderers need a reusable local sprite pack from a player's own
Black/White dump. An external Windows decoder cannot serve the Quest launcher.
This extends the existing asset-transform/pack direction referenced as D11 in
`docs/rfcs/0008-streamed-mod-imports-and-install-cache.md`, using the established
`src/import/Importers.lua` and public `mod.packs` contract.

## Exact delta

Register beta importer `gen5_bw`, internal module
`src.import.gen5.BwImport`, source `.nds`, pack `battle_sprites`, version 1.0.1.
The launcher dispatches the registered trusted module instead of a hardcoded
two-importer map. Existing `pmd_red` and `lttp` descriptors name their existing
modules. Gen 5 work batches up to 24 resumes within a soft 6 ms launcher budget.
PMD's single resume and Zelda's existing 24-resume pacing remain unchanged.
Android `picked_importer_<id>.bin` sources use the existing background streaming
copy helper and become visible to Lua after `.part` publication. Their completion
signal remains the final basename; required-mod markers retain their separate
path. Assembly slices yield after at most eight ticks or a soft 4 ms limit
between compositions.
Empty female graphics variants alias the already assembled male atlas while
retaining their logical entry IDs; genuine female artwork remains distinct.
No public manifest field, registry, hook, event, schema or permission is added.
The complete pack IDs and timing contract are documented in
`docs/gen5-battle-sprite-importer.md`.

## Migration and compatibility

Existing mods need no changes. All v1 registration/event/hook/read/log and
`pokemon.before_give` behavior stays in its existing code. Existing importer
modules and file-picker sequences remain the same. A renderer can optionally
consume the new pack through its existing public `mod.packs` APIs; absence of a
consumer or pack preserves native rendering. Nothing is deprecated or removed.

## Validation and limits

ROM-free tests cover bounded containers, Nitro graphics/OAM, animation transforms,
composition and importer timing. Existing asset-pack tests cover public access
and missing-pack behavior. The example provider's real-SDK tests exercise
optional assets, introductory/suffix timing, native fallback, stereo clock and
cache release. Registry docs are regenerated with no schema delta expected.
The Android copy fixture executes the production Java helper with procedural
streams, checking exact bytes/MD5, final-file visibility and failure cleanup.
The unchanged v1 Mew starter loads against a procedural base record and retains
its content override and `pokemon.before_give` effect; an empty mod set preserves
the native sprite record.

Private Black source validation covers all 649 base species and both genders/
sides; sampled PNG export and source pixel parity are separate checks. White,
other regions, alternate forms and physical Quest acceptance remain unverified.
Long cycles are explicitly capped and rejected by the example consumer.
