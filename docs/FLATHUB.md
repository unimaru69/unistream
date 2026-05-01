# Flathub submission guide

UniStream targets Flathub for Linux distribution. The Flatpak manifest
lives at `packaging/linux/fr.unimaru.unistream.yml` and pulls a pre-built
tarball from the GitHub Release matching the manifest's tag.

## One-time setup

1. Confirm the app ID is reverse-DNS for a domain you own:
   `fr.unimaru.unistream` ✓
2. Create (or sign in to) a GitHub account that will own the Flathub
   submission PR.
3. Fork <https://github.com/flathub/flathub>.

## Per-release submission

### 1. Cut a GitHub Release

Push a tag (e.g. `v1.0.0`). The `release.yml` workflow builds and
uploads `unistream-linux-x86_64.tar.gz` to the release assets.

```bash
git tag v1.0.0
git push origin v1.0.0
# CI takes ~10 min, then check:
# https://github.com/unimaru69/unistream/releases/tag/v1.0.0
```

### 2. Generate the submission files locally

```bash
bash packaging/linux/prepare-flathub-submission.sh v1.0.0
```

This writes three files to `build/flathub/v1.0.0/`:
- `fr.unimaru.unistream.yml` (manifest with the real sha256)
- `fr.unimaru.unistream.metainfo.xml`
- `fr.unimaru.unistream.desktop`

### 3. Validate locally before submitting

Optional but **strongly recommended** — Flathub bots run the same checks
and PR validation can take days. To validate locally:

```bash
# AppStream metadata (the metainfo XML)
appstreamcli validate build/flathub/v1.0.0/fr.unimaru.unistream.metainfo.xml

# Desktop file
desktop-file-validate build/flathub/v1.0.0/fr.unimaru.unistream.desktop

# Manifest (full build)
flatpak-builder --force-clean --user --install build/flatpak \
  build/flathub/v1.0.0/fr.unimaru.unistream.yml
flatpak run fr.unimaru.unistream
```

### 4. Open the Flathub PR

1. In your fork of `flathub/flathub`, create a branch
   `new-pr/fr.unimaru.unistream`.
2. Add the three files from `build/flathub/v1.0.0/` under a folder
   `fr.unimaru.unistream/` at the repo root.
3. Open a PR against `flathub:new-pr` titled
   `Add fr.unimaru.unistream`.
4. The Flathub Pipeline bot will validate the manifest. Address any
   findings (sandbox permissions, missing icon, AppStream errors).

### 5. Review and publication

- Median review time: 1–4 weeks.
- Once merged, Flathub creates a dedicated repo
  `flathub/fr.unimaru.unistream` where future releases are pushed.
- Subsequent updates: open PRs against that dedicated repo only,
  bumping the `url` + `sha256` in the manifest. The
  `prepare-flathub-submission.sh` script handles both cases.

## Common rejection reasons

| Issue | Fix |
|---|---|
| `metainfo.xml` validation errors | Run `appstreamcli validate` locally and fix every warning |
| Missing `oars-1.1` content rating | Already set in our manifest |
| Hardcoded `--filesystem=host` or unjustified `--share=network` | We only request `--share=network`, justified by IPTV |
| Screenshots from a non-stable URL | We use `raw.githubusercontent.com/.../main/screenshots/...` — fine for the initial PR, but consider pinning to a tag for stability |
| Bundling proprietary codecs | We rely on host `libmpv` + `ffmpeg` already shipped with the runtime — OK |

## Files referenced

- Manifest source: [packaging/linux/fr.unimaru.unistream.yml](../packaging/linux/fr.unimaru.unistream.yml)
- AppStream metadata: [packaging/linux/fr.unimaru.unistream.metainfo.xml](../packaging/linux/fr.unimaru.unistream.metainfo.xml)
- Desktop entry: [packaging/linux/unistream.desktop](../packaging/linux/unistream.desktop)
- Submission helper: [packaging/linux/prepare-flathub-submission.sh](../packaging/linux/prepare-flathub-submission.sh)
