# Build & release scripts

Shipping iOS / tvOS to TestFlight without burning ASC's daily upload quota.

## Daily iteration loop — no upload, no rate limit

For most code changes, **don't archive**. Run on a connected device from
Xcode and iterate freely:

* **tvOS** — open `tvos/UniStreamTV/UniStreamTV.xcodeproj`, select your
  Apple TV in the run target picker (network-paired), Cmd+R. Each Run is
  a fresh debug install on the device. No version bump, no upload, no
  rate limit.
* **Flutter iOS / iPadOS** — `flutter run -d <device-id>` or open
  `ios/Runner.xcworkspace` in Xcode and Cmd+R on a connected iPad/iPhone.
  Same story — no archive needed.

Every commit on this loop is **code only**: don't touch
`CURRENT_PROJECT_VERSION` or `pubspec.yaml`'s `+N` suffix. Build numbers
are reserved for actual TestFlight uploads.

## Shipping a build to TestFlight

When you're ready to push a build to TF (for non-local testers, for the
review pipeline, or just to validate cross-device behaviour from a real
distribution build):

```bash
# tvOS
./scripts/archive-tvos.sh

# Flutter iOS / iPadOS
./scripts/archive-flutter-ios.sh
```

Each script:
1. **Bumps** the build number (CURRENT_PROJECT_VERSION for tvOS, the `+N`
   suffix in pubspec.yaml for Flutter).
2. Runs `xcodegen` (tvOS) or `flutter pub get` + `pod install` (Flutter).
3. **Archives** + exports an `.ipa`.
4. **Uploads** to App Store Connect via `xcrun altool` using your ASC API
   key.
5. **Commits** the version bump (clear git history of what's on TF).

Flags:
* `--no-upload` — archive + export, skip the upload (useful when ASC is
  rate-limited and you want to keep the IPA for manual upload later).
* `--no-commit` — skip the auto-commit of the bump.

## Rate limits

Apple caps uploads at roughly **20 builds per app per day**. The scripts
won't help you upload more — but the "daily iteration" loop above means
you'll rarely *need* more than a handful of upload-worthy builds per day.

If you hit the cap (`90382 Upload limit reached`), wait until midnight
UTC, then re-run the script.

## Credentials

The scripts default to the existing project keys:
* `ASC_API_KEY_ID=N4K77SK2A9`
* `ASC_API_ISSUER_ID=025be2c7-6d3e-42a9-a892-8dfb6f3112fc`

The matching `.p8` file must live at
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` so `xcrun altool`
can find it. Override either by exporting the env vars before running.
