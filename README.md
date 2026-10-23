# Pureblood & Prejudice

Downloads for Pureblood & Prejudice, an unofficial, non-commercial Harry Potter fan visual novel. Not affiliated with or endorsed by Warner Bros., J.K. Rowling or any rights holder.

## Quick install

Paste one line. Run the same line again later to update.

| Platform | Command |
| --- | --- |
| macOS (Homebrew) | `brew install --cask cocolemontv/tap/pureblood-and-prejudice` |
| macOS or Linux | `curl -fsSL https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.sh \| sh` |
| Windows (PowerShell) | `irm https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.ps1 \| iex` |
| Android | Download the `.apk` from the [latest release](https://github.com/CocolemonTV/pureblood-and-prejudice-releases/releases/latest) on your phone. |

Details for each platform follow below.

## Install in detail

Close the game before installing or updating. Get manual downloads from the [latest release](https://github.com/CocolemonTV/pureblood-and-prejudice-releases/releases/latest).

### macOS

Requires macOS 13 or later. Apple Silicon and Intel Macs are supported.

If you have Homebrew, this is the recommended way. Paste into Terminal:

```sh
brew install --cask cocolemontv/tap/pureblood-and-prejudice
```

To update, run `brew update && brew upgrade --cask cocolemontv/tap/pureblood-and-prejudice`.

You can also install without Homebrew:

```sh
curl -fsSL https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.sh | sh
```

To update, run the same command again. It uses Homebrew if the game is already installed as a cask. Otherwise, it installs in `/Applications`, or `~/Applications` if needed, without asking for administrator access.

For a manual install, download the `mac-arm64.dmg` for Apple Silicon or `mac-x64.dmg` for Intel. Open it and drag the app to Applications. The app is unsigned. In Finder, right-click the app and choose **Open**, then confirm **Open** if prompted. If macOS still blocks it, try opening it once, then use **System Settings > Privacy & Security > Open Anyway**.

### Windows

Requires 64-bit Windows on an x86-64 computer. Paste into a normal PowerShell window:

```powershell
irm https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.ps1 | iex
```

To update, run the same command again. It installs for your user without asking for administrator access.

For a manual install, download and run the `win-x64.exe` installer. If SmartScreen flags this unsigned download, choose **More info > Run anyway** if you trust it. You can also download `win-x64.zip`, extract it, and run `pureblood-and-prejudice.exe`. To update a ZIP copy, extract the newer ZIP into a new folder and use that copy.

### Linux

ARM64 and x86-64 Linux are supported. Paste into a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.sh | sh
```

To update, run the same command again. It installs an AppImage in `~/.local/share/pureblood-and-prejudice`, adds an applications menu entry, and creates the `~/.local/bin/pureblood-and-prejudice` launcher. The launcher uses extraction mode if FUSE 2 is missing. If `~/.local/bin` is outside your PATH, use the applications menu or the full launcher path.

For a manual install, download the `linux-x86_64.AppImage` or `linux-arm64.AppImage` for your computer. In the download folder, make it executable and run it, replacing the filename below with yours:

```sh
chmod +x Pureblood-and-Prejudice-0.3.1-linux-x86_64.AppImage
./Pureblood-and-Prejudice-0.3.1-linux-x86_64.AppImage
```

If FUSE 2 is missing, run `APPIMAGE_EXTRACT_AND_RUN=1 ./Pureblood-and-Prejudice-0.3.1-linux-x86_64.AppImage`. You can also extract the matching `linux-x64.tar.gz` or `linux-arm64.tar.gz` and run `./pureblood-and-prejudice` inside it. These methods keep the normal sandbox enabled. Some Linux security policies may block it; the installer does not change those policies.

### Android

On your phone, open the [latest release](https://github.com/CocolemonTV/pureblood-and-prejudice-releases/releases/latest) and download `Pureblood-and-Prejudice-0.3.1.apk` (or the newer version shown there). Open the download and allow **Install unknown apps** for your browser or file manager when prompted. Then tap **Install**.

To update, install the newer APK over the existing app. Releases use the same signing key, so your saves stay in place. Do not uninstall first. Android requires matching signatures for updates; see [Android's update guide](https://developer.android.com/google/play/app-updates).

## Uninstall

On macOS with Homebrew:

```sh
brew uninstall --cask cocolemontv/tap/pureblood-and-prejudice
```

For a script install on macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.sh | sh -s -- --uninstall
```

On Windows, paste into PowerShell:

```powershell
try { $env:PP_UNINSTALL='1'; irm https://raw.githubusercontent.com/CocolemonTV/pureblood-and-prejudice-releases/main/install.ps1 | iex } finally { Remove-Item Env:\PP_UNINSTALL -ErrorAction SilentlyContinue }
```

You can also remove the Windows installer version through **Settings > Apps**. For a manual macOS, Linux, or Windows ZIP install, delete the app or extracted folder. Desktop uninstall commands keep your saves.

On Android, use the app's **Uninstall** option. **Android uninstalling or clearing app storage deletes local saves.** Export a backup from the game first.

## Saves

Updates keep your saves. Desktop saves live in these folders:

| Platform | Save folder |
| --- | --- |
| macOS | `~/Library/Application Support/Pureblood-and-Prejudice/` |
| Windows | `%APPDATA%\Pureblood-and-Prejudice\` |
| Linux | `~/.config/Pureblood-and-Prejudice/` (or `$XDG_CONFIG_HOME/Pureblood-and-Prejudice/` if set) |
| Android | The app's private storage for `dev.ruizukun.purebloodandprejudice`; use the game's backup export to copy saves out. |

## Verify downloads

Each release includes `SHA256SUMS.txt`. The scripts check SHA-256 before installing. For manual downloads, compare the file's hash with its entry in that release's checksum file using `shasum -a 256 FILE` on macOS, `sha256sum FILE` on Linux, or `Get-FileHash FILE -Algorithm SHA256` in PowerShell.
