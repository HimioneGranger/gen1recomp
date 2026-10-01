# Changelog

## [1.3.0] - 2026-10-01

### Added

- Complete playback for long idle animations from exporter 1.1 part tracks.
  Each multicell record keeps its own intro and loop on the shared 60 Hz
  tick; frames are composed on demand in the source compositor's OAM order.
- Bounded part-model cache (four models) and composed-frame reuse by state.

### Changed

- Capped entries with part tracks now play instead of keeping native art.
  Capped entries without them (1.0 packs) keep native art as before.

## [1.2.0] - 2026-09-30

### Added

- Native optional `gen5_bw/battle_sprites` pack consumer using the scoped mod API.
- API version 1 renderer contract, bounded graphics caches, and shared simulation clock.
- Integer tick timing with one-time animation intros and suffix loops.
- ROM-free loader and playback regression tests.
