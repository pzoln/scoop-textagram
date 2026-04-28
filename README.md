# scoop-textagram

Scoop bucket for [`tg`](https://github.com/pzoln/tg).

## Install

```powershell
scoop bucket add textagram https://github.com/4erica/scoop-textagram
scoop install textagram/tg
```

## Maintain

Update the manifest for a specific release:

```bash
just update-manifest 0.1.0-beta.3
```

If you omit the version, the updater prompts for it:

```bash
just update-manifest
```

The updater reads the upstream `SHA256SUMS` file and rewrites `bucket/tg.json` with the new version, Windows download URL, hash, and `extract_dir`. The manifest also includes Scoop `checkver` and `autoupdate` metadata for future releases.

Pushes and pull requests that touch the manifest or updater also run a Windows GitHub Actions check that installs `tg` through Scoop from the checked-out manifest.
