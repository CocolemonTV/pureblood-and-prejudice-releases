# Release build setup

The workflow runs in this public downloads repository and checks out the private
source with a read-only deploy key. Only packaged game downloads and their
checksums are uploaded. Logs are public; private build output is redirected to
ephemeral runner files and is never uploaded or printed, including on failure.

## Required repository secrets

Set these three Actions secrets in this downloads repository:

| Name | Value |
| --- | --- |
| `SOURCE_DEPLOY_KEY` | Private half of an SSH deploy key whose public half is registered on `CocolemonTV/pureblood-and-prejudice`, with **Allow write access disabled**. |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the existing persistent Android release keystore containing alias `cocolemon`; do not generate a replacement identity. Wrapped base64 is accepted. |
| `ANDROID_KEYSTORE_PASSWORD` | Existing keystore/key password used by that alias. |

`GITHUB_TOKEN` is provided automatically; it is not a fourth configured secret.
Only the release job receives `contents: write`. Enable Actions and allow that
permission for this repository. Keep release immutability disabled if reruns
must replace already published release assets. The temporary keystore is created
with mode 0600 under `RUNNER_TEMP`, supplied using `PP_ANDROID_KEYSTORE`,
`PP_ANDROID_KEY_ALIAS=cocolemon`, and `PP_ANDROID_KEYSTORE_PASSWORD`, and deleted
by an `always()` cleanup step. No `.env` or local signing file is required.

## Run a build

After the workflow is committed to this repository's default branch, use its
Actions → Build release → Run workflow page, or run from this repository:

```sh
gh workflow run build-release.yml -f publish=false
```

From any other directory, use the explicit repository:

```sh
gh workflow run build-release.yml \
  --repo CocolemonTV/pureblood-and-prejudice-releases \
  -f source_ref=main -f version=0.3.1 -f publish=false
```

`source_ref` defaults to the private source's `main`. For repeatable builds, use
an immutable source commit SHA or tag. The release job refuses mixed source
commits if a branch moves between checkouts. An empty `version` reads
`native/desktop/package.json`; an explicit SemVer overrides package versions,
lockfile root versions and Android `versionName` in disposable CI checkouts only.
Android `versionCode` remains the source value; bump it in source for an update
that requires a higher Android build number. No source change is pushed back.

`publish=false` creates or updates a **draft** `v<version>` release. Drafts are
visible to repository collaborators, but public workflow artifacts remain
accessible during their one-day retention. Set `publish=true` explicitly to
publish after successful uploads. Rerunning a version replaces all release
assets, including stale ones; an existing public release temporarily becomes a
draft while replacements upload. A failed upload leaves the release as a draft.
All release runs are serialized, so automatic and explicit versions cannot race.
GitHub concurrency retains at most one pending run per group; avoid queuing many
releases at once. Published release files persist independently of Actions
artifact retention. Nothing uploads to itch.io automatically.

## Jobs and approximate cold-run durations

These are estimates, not measured GitHub runner results. Image conversion runs
from scratch and can dominate the time. Queue delays and dependency downloads
can extend them; the five build jobs run in parallel.

| Job | Expected downloads | Estimate |
| --- | --- | --- |
| `web` / Ubuntu | `pureblood-and-prejudice.zip`, fewer than 1,000 entries | 15–30 min |
| `linux` / Ubuntu | x64 (`linux-x86_64.AppImage`, `linux-x64.tar.gz`) and ARM64 (`linux-arm64.AppImage`, `linux-arm64.tar.gz`) | 20–45 min |
| `windows` / Windows | x64 NSIS `.exe` and portable `.zip` | 25–50 min |
| `mac` / Apple Silicon macOS | ARM64 and x64 `.dmg` and `.zip`, unsigned/unnotarized | 25–60 min |
| `android` / Ubuntu | Signed `Pureblood-and-Prejudice-<version>.apk` | 20–45 min |
| `release` / Ubuntu | The twelve downloads, `SHA256SUMS.txt`, file-list notes | 3–10 min |

Desktop filenames start with `Pureblood-and-Prejudice-<version>-`; the suffixes
match the current source download manifest. iOS is intentionally skipped because
the current simulator and unsigned device archives are not installable downloads.
Expect roughly 30–70 minutes total without queue delays. These are standard public
runners; no paid larger runners are requested. Actions intermediates use
`retention-days: 1` and no extra compression. npm caching stores dependencies,
not the private source or native payload. Build checks verify existing audio
packs without synthesizing audio; ffmpeg is unnecessary. Python 3.12, Node
22.21.1, WebP, and only each target's required tools/dependencies are installed.
Windows uses Google's libwebp 1.6.0 binary with a pinned SHA-256; Python UTF-8
mode is enabled on every runner for portable reading of game files.
Android uses Temurin 21, platform 36 and Build Tools 35.0.0, and verifies both the
APK signature and every bundled runtime byte; Windows ZIP payload bytes are
also verified. These build checks do not replace gameplay or device testing.

References: [GitHub standard runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[Android SDK package installation](https://developer.android.com/tools/sdkmanager),
[APK signature verification](https://developer.android.com/tools/apksigner),
[official WebP downloads](https://developers.google.com/speed/webp/download).
