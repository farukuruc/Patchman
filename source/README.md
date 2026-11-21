# Patchman v1.5 source snapshot

Source code and source-level UI edits for **Patchman v1.5-stable on Sony NW-A55**.
This folder is for review and development. To install Patchman, use the firmware
ZIP from Releases and the main repository README. Do not copy this source folder
to the Walkman.

## Changes from the v1.1 source snapshot

- Sorting Options and the native newest/oldest/A–Z/Z–A album-order code.
- The shared top bar, battery percentage, charging/Full display and speaker icon.
- Now Playing and mini-player spacing, title size and transport image changes.
- Continuous long-title scrolling, including display/visibility lifecycle.
- Flat shuffle/repeat controls and the new Go to icon.
- Current Install, Remove and ReturnToV1.1 scripts and release component hashes.
- Source patches that reproduce the exact released v1.5 player from the supported
  original Walkman One player supplied by the user.

The v1.1 PEQ source remains unchanged. Reverse Stereo, the abandoned security
experiment and the abandoned Artist-mode navigation extension are not included.

## Included

- Rust PEQ profile reader and file-based UI helper.
- Cinder-derived C audio shim, DSP headers and service wrapper.
- Exact released external QML/JavaScript components in `src/ui/` and runtime
  scripts in `src/runtime/`.
- Embedded custom controls in `src/ui/controls/`. These are already applied by
  the player patch tool; they are also exposed separately for review.
- The Go to PNG as a text/base64 asset in `src/ui/icons/GoToIcon.json`.
- Native album sorting and read-only metadata/photo cache-builder sources.
- Source-level Sony QML patches and external-layout patches in `patches/`.
- Portable validation tools, tests, release hashes, credits and source provenance.
- Original workspace maintenance scripts in `maintenance/` and fixture-dependent
  tests in `tests/reference/`, clearly separated from the portable tools.

## Check the snapshot

From the repository root:

```sh
python3 source/tools/check-source.py
```

With Linux/Ubuntu/WSL, a C compiler, SQLite development headers and Rust:

```sh
bash source/tools/check-host.sh
```

These checks do not access a device. They do not perform a firmware update.

## Reconstruct the player and check UI

Supply your own compatible original Walkman One player:

```sh
python3 source/tools/apply-player-patches.py /path/to/original/HgrmMediaPlayerApp /path/to/local-build
```

The tool checks the input, every source edit and the complete output hash before
writing. It never flashes a device. The result must match the player hash in
`release-manifest.json` exactly; it includes the v1.5 Unit Information label.

Optional host Qt checks, using Qt 5 Quick/QML/Gui/Core development packages:

```sh
bash source/tools/check-ui.sh /path/to/original/HgrmMediaPlayerApp
```

The fixture uses the reconstructed player. Unchanged native firmware widgets are
stubbed where necessary. Host tests do not prove that a different device works.

## Build limit

**This is a source snapshot, not yet a complete one-command firmware build.**
The exact historical C source for the released B6 `goto-target` metadata helper
was not retained separately. The later abandoned Artist-mode source is excluded.
The released helper's hash is recorded. Other firmware libraries, the original
Sony executables, artwork and toolchains must be supplied separately.

The `outputs/Patchman-v1.5-Final/build.sh` command in the main release README
belongs to the original workspace. It is not a build command supplied by this
source checkout. See [build notes](docs/BUILD.md) and [provenance](SOURCE-MAP.json).
Do not claim every compiled binary can be rebuilt from this snapshot alone.

## Excluded files

No Sony/MrWalkman firmware executable, Windows installer executable, Sony library,
Wampy artwork, toolchain, personal EQ profile, device log or music database is
included. Sony UI changes are distributed as edits against a user-supplied image.

## License and attribution

This snapshot has mixed ownership. It is not a blanket MIT or GPL relicensing.
Cinder-derived files keep the **PolyForm Noncommercial License 1.0.0** and required
notice. See [third-party notices](THIRD_PARTY_NOTICES.md) and `LICENSES/`.
This source export does not grant rights to Sony firmware or Wampy artwork.
