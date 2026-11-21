# Patchman v1.1 source snapshot

Source code and source-level UI edits for the NW-A55 Patchman v1.1 release.
This folder is for review and development. For installation, use the firmware ZIP
and the main repository README. Do not copy this folder onto the Walkman.

## Included

- Rust PEQ profile reader and file-based UI helper.
- The Cinder-derived C audio shim, DSP headers and service wrapper.
- Exact released QML/JavaScript overlay components: PEQ, queue cache, cassette,
  Audio Path, Go to and artist-photo view.
- Native album-year ordering and read-only year/photo cache-builder sources.
- Full-installer and runtime shell scripts from the confirmed clean installer.
- Fourteen source-level patches for Sony's embedded QML and two external layouts.
  A checked tool reconstructs the exact released player from your own compatible
  original Walkman One player. No original Sony executable is included.
- Tests, component hashes, credits and source provenance.

## Important source/build limit

**This snapshot is not yet a complete one-command reproducible firmware build.**
The exact historical C source used for the released B6 `goto-target` metadata
helper was not retained separately in the workspace. The surviving C file has
the later, abandoned Artist-mode extension and is deliberately not presented as
stable v1.1 source. The released helper's hash is recorded in the release manifest.
The QML/JavaScript navigation sources are included exactly as released.

Rebuilding that helper and proving its equivalence is outstanding. Do not claim
that every compiled binary can currently be rebuilt from this snapshot alone.
See [build notes](docs/BUILD.md) and [provenance](SOURCE-MAP.json).

## Check sources

```bash
python3 source/tools/check-source.py
```

With a Linux C compiler, SQLite development headers and a suitable Rust toolchain:

```bash
bash source/tools/check-host.sh
```

These checks do not access a device. They are distinct from the ten installer
tests performed in the original firmware-fixture environment.

## Reconstruct the player locally

From the repository root, using your own extracted compatible firmware file:

```bash
python3 source/tools/apply-player-patches.py /path/to/original/HgrmMediaPlayerApp /path/to/local-build
```

The tool refuses an unknown original file. It checks every source edit and the
complete final player hash before writing local output. It never flashes a
device. Original Sony QML is read from your supplied executable; the repository
stores the edits rather than complete original firmware resources.

## Not included

Sony/MrWalkman firmware images and executables, Sony libraries, Wampy artwork,
toolchains, personal EQ profiles, device logs and user music databases are not
included. The abandoned security experiment and Artist-mode implementation are
also excluded. The existing stable installer is unchanged by this source export.

## License and attribution

This is a source-available snapshot with mixed ownership, not a blanket MIT or
GPL relicensing of all projects. Cinder-derived files retain Cinder's
**PolyForm Noncommercial License 1.0.0** and required notice. See
[third-party notices](THIRD_PARTY_NOTICES.md) and the included license text.
The source export does not grant rights to Sony firmware or Wampy artwork.
