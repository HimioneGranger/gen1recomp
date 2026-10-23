# Steam Frame (experimental contributor proposal)

The proposed Linux ARM64/OpenXR host lives in
[`ports/steamframe`](../../ports/steamframe/README.md). It keeps the existing
launcher, game and editors and adds a virtual display plus controller/laser
input through the existing optional host seams. It does not change the desktop,
mobile or other platform defaults.

This is a draft for maintainer review, not a declaration of official platform
support. The reviewed publisher input is v0.3.95. Its bytes remain unmodified;
no ROMs, saves, installed mods, engine/assets copy or native binaries are in the
source proposal. See the port README for pinned explicit inputs, staging,
ARM64 runtime/bridge provenance, licenses and portable tests.

Desktop real-GPU/fake-XR tests exercise picker, editor, focus and presentation
boundaries. Physical Steam Frame startup, dashboard/focus, image quality,
performance, gameplay and audio acceptance remain pending. Do not replace a
working installation or user data before reviewing the candidate on hardware.
