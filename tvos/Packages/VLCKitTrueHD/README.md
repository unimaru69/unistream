# VLC with TrueHD decoding for Apple TV

Run `./scripts/build-tvos-vlc-truehd.sh` from the repository root before
opening or building the tvOS project on a new checkout. The archive script
runs it automatically. Generated binaries stay in the ignored `Artifacts/`
directory. The initial build also builds VLC's required host tools.

The framework is dynamically linked and keeps the VLC 3.x API. Sources:

- VLCKit: https://github.com/videolan/vlckit, revision
  `a213fd113c5c014556b40765966e77d439f0ddf9` (official `3.0` branch).
- VLC: https://github.com/videolan/vlc, revision
  `6de05adcbaf2e8b85fe86aad4169393098628119`, plus the patches shipped by
  that VLCKit revision.

The build removes the three `--disable-*=mlp` options added by VLCKit's
`0003-Enable-System-DL.patch`. It also includes the ARM64 simulator in the
resulting XCFramework and targets tvOS 17 for its Xcode framework targets,
matching the app and the current SDK's requirements. All changes are in the build script; neither source
revision is silently upgraded. VLC's LGPL license is copied alongside the
package after building, and the complete source can be reconstructed with
the pinned revisions and script.

Tests require decoded audio and played PCM buffers for generated TrueHD,
AC3 and DTS tones. Fixtures are test resources, never app resources; regenerate
them with `./scripts/generate-tvos-audio-fixtures.sh` (requires FFmpeg).

TrueHD is decoded to PCM. This does not implement TrueHD/Atmos bitstream
passthrough or preservation of Atmos object metadata.

## CI

The binary is not committed, so a CI runner cannot use this package. The
`build-tvos` job runs `scripts/ci-tvos-upstream-vlc.sh`, which swaps the
dependency for the upstream prebuilt VLCKit (same API, no TrueHD), and sets
`TEST_RUNNER_UNISTREAM_UPSTREAM_VLC=1` so the three TrueHD-only tests skip.
CI therefore proves the app compiles and the other tests pass; the TrueHD
tests only run locally, against the framework that actually ships.
