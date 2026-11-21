# Build and provenance notes

## What is verified

The export is tied to the v1.1 clean-installer release identified in
`SOURCE-MAP.json`. The text overlays and installer/runtime scripts come from that
released payload. All 14 player resource edits reproduce the released player
byte-for-byte with the supported original player and the checked Python/zlib
environment. External artist and artist-album QML layouts are reconstructed too.

The original player SHA256 is
`f515f75e48e84460c18707e5408c6c09c26a77a13deccdee23e220dc81f49124`.
This identifies a binary, not every firmware that displays version 3.02.

The PEQ C source was taken from the pre-security prepared source tree. Its Sony
effect-chain hook passes the original chain through. No experimental runtime
permission changes or special-file hardening are included.

## Host prerequisites

Linux or Ubuntu/WSL, Python 3.10+, a C compiler, SQLite development headers and
Rust. The original project used Rust 1.95.0. To compile the host checks on Ubuntu,
the usual packages include `build-essential` and `libsqlite3-dev`.

`tools/check-host.sh` tests the profile parser/UI helper and the native metadata
and optional photo cache builder. It checks shell syntax. It does not test an
ARM audio service, device permissions or a firmware update.

## Device compilation

The audio shim and native ordering interposer require an ARM hard-float compiler
and a glibc sysroot compatible with Sony's glibc 2.23. The original build linked
against the device's own libc, libdl and libpthread. Do not link against the host
system's newer glibc and assume it will run on the player.

PEQ audio build definitions were:

```text
CINDER_MONO_DIR="/data/sony-peq/runtime"
CINDER_MONO_DATA="/data/sony-peq/state"
```

The wrapper used:

```text
HAGO_REAL="/system/vendor/sony/bin/hagodaemon.peq-original"
HAGO_SHIM="/system/vendor/sony-peq/libsony_peq.so"
HAGO_DIR="/system/vendor/sony-peq/preload"
HAGO_OFF="/data/sony-peq/off"
HAGO_OFF_MSC="/contents/peq_off"
```

Profile/UI helpers and the metadata cache builder were static ARM musl binaries.
Their external SQLite amalgamation and the compiler toolchains are dependencies,
not firmware files to upload to GitHub. Device ABI tests and a real playback test
are required before replacing an audio binary.

## Outstanding full-build work

- Recover or reconstruct the released B6 metadata helper, then test its output
  against the known release before calling the rebuild equivalent.
- Replace old private-fixture dependencies in `tests/reference/` and
  `maintenance/` with explicit local input arguments. Those files preserve the
  original maintenance workflow for review; they are not standalone build tools.
- Supply your own compatible Sony libraries, original boot/daemon files and
  Windows installer template locally; do not commit them.
- Obtain the selected cassette artwork from Wampy with its applicable notices.
- Assemble all components, regenerate every checksum and pack/round-trip the UPG
  with Rockbox nwztools. A changed binary must not be installed using stale
  checksums or an inherited playback confirmation.

`release-manifest.json` records the original component identities. Do not change
its expected hashes just to suppress a failed compatibility check.

## Tests from the private build environment

`tests/reference/test-full-installer.py` is the ten-case clean-installer suite
used before packaging. It depends on firmware fixtures and earlier helper tests
that are not part of this snapshot. Its presence is documentation of those
checks, not a claim that the test runs independently in this repository today.
