#!/bin/sh
# Install/update Pureblood & Prejudice. No administrator access is needed.
# Test only: PP_APP_DIR redirects macOS installs and bypasses Homebrew.
# Keep execution inside a function so curl | sh reads the script before working.
pp_main() {
    set -eu
    repo=https://github.com/CocolemonTV/pureblood-and-prejudice-releases
    cask=cocolemontv/tap/pureblood-and-prejudice
    app_name='Pureblood & Prejudice.app'
    bundle_id=dev.ruizukun.purebloodandprejudice
    tmp=
    mounted=
    stage=

    fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
    cleanup() {
        if [ -n "$mounted" ]; then
            if ! hdiutil detach "$mounted" -quiet 2>/dev/null && mount | grep -Fq " on $mounted ("; then
                printf 'Could not detach %s; temporary files kept at %s.\n' "$mounted" "$tmp" >&2
                return
            fi
        fi
        [ -z "$stage" ] || rm -rf "$stage"
        [ -z "$tmp" ] || rm -rf "$tmp"
    }
    trap cleanup 0
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    action=install
    case $# in
        0) ;;
        1) [ "$1" = --uninstall ] || fail 'Usage: sh install.sh [--uninstall]'; action=uninstall ;;
        *) fail 'Usage: sh install.sh [--uninstall]' ;;
    esac
    os=$(uname -s)
    case "$os" in
        Darwin) ;;
        Linux) ;;
        *) fail "Unsupported OS: $os. This installer supports macOS and Linux." ;;
    esac
    machine=$(uname -m)
    case "$machine" in
        arm64|aarch64) arch=arm64 ;;
        x86_64|amd64) arch=x64 ;;
        *) fail "Unsupported architecture: $machine. Use an ARM64 or x86-64 computer." ;;
    esac

    if [ "$os" = Darwin ]; then
        saves="$HOME/Library/Application Support/Pureblood-and-Prejudice"
        if [ "$action" = install ]; then
            mac_version=$(sw_vers -productVersion)
            [ "${mac_version%%.*}" -ge 13 ] || fail 'macOS 13 or later is required.'
        fi
        # A scratch install must never upgrade/uninstall the real Homebrew app.
        if [ -z "${PP_APP_DIR:-}" ] && command -v brew >/dev/null 2>&1 &&
            brew list --cask --versions "$cask" >/dev/null 2>&1; then
            if [ "$action" = uninstall ]; then
                brew uninstall --cask "$cask"
                printf 'Uninstalled. Saves kept at %s\n' "$saves"
            else
                brew upgrade --cask "$cask"
            fi
            return
        fi
        mac_bundle_value() {
            /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true
        }
        remove_app() {
            [ -e "$1" ] || [ -L "$1" ] || return 0
            [ "$(mac_bundle_value "$1" CFBundleIdentifier)" = "$bundle_id" ] ||
                fail "Refusing to replace an unrecognized app: $1"
            rm -rf "$1"
        }
        if [ "$action" = uninstall ]; then
            if [ -n "${PP_APP_DIR:-}" ]; then
                remove_app "$PP_APP_DIR/$app_name"
                remove_app "$PP_APP_DIR/pureblood-and-prejudice.app"
            else
                for app_dir in /Applications "$HOME/Applications"; do
                    remove_app "$app_dir/$app_name"
                    remove_app "$app_dir/pureblood-and-prejudice.app"
                done
            fi
            printf 'Uninstalled. Saves kept at %s\n' "$saves"
            return
        fi
        if [ -n "${PP_APP_DIR:-}" ]; then
            app_dir=$PP_APP_DIR
        elif [ -d "$HOME/Applications/$app_name" ] || [ -d "$HOME/Applications/pureblood-and-prejudice.app" ]; then
            app_dir="$HOME/Applications"
        elif [ -w /Applications ]; then
            app_dir=/Applications
        else
            app_dir="$HOME/Applications"
        fi
        app="$app_dir/$app_name"
        installed=$(mac_bundle_value "$app" CFBundleShortVersionString)
        if [ -z "$installed" ]; then
            installed=$(mac_bundle_value "$app_dir/pureblood-and-prejudice.app" CFBundleShortVersionString)
        fi
    else
        saves="${XDG_CONFIG_HOME:-$HOME/.config}/Pureblood-and-Prejudice"
        install_dir="$HOME/.local/share/pureblood-and-prejudice"
        image="$install_dir/Pureblood-and-Prejudice.AppImage"
        launcher="$HOME/.local/bin/pureblood-and-prejudice"
        desktop="$HOME/.local/share/applications/pureblood-and-prejudice.desktop"
        if [ "$action" = uninstall ]; then
            rm -f "$image" "$install_dir/VERSION" "$launcher" "$desktop"
            for icon in "$HOME"/.local/share/icons/hicolor/*/apps/pureblood-and-prejudice.png; do
                rm -f "$icon"
            done
            rmdir "$install_dir" 2>/dev/null || true
            printf 'Uninstalled. Saves kept at %s\n' "$saves"
            return
        fi
        installed=
        if [ -f "$image" ] && [ -f "$install_dir/VERSION" ]; then
            installed=$(cat "$install_dir/VERSION")
        fi
    fi

    command -v curl >/dev/null 2>&1 || fail 'Please install curl and run this command again.'
    version=${PP_VERSION:-}
    if [ -z "$version" ]; then
        latest=$(curl -fsSLI --retry 2 -o /dev/null -w '%{url_effective}' "$repo/releases/latest") ||
            fail 'Could not find the latest release. Please try again.'
        case "$latest" in
            "$repo/releases/tag/v"*) version=${latest##*/v} ;;
            *) fail 'GitHub did not redirect to a release. Please try again.' ;;
        esac
    fi
    printf '%s\n' "$version" | LC_ALL=C grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
        fail 'PP_VERSION must look like 0.3.1 (without v).'
    if [ "$installed" = "$version" ]; then
        printf 'Pureblood & Prejudice %s is already up to date.\n' "$version"
        return
    fi

    if [ "$os" = Darwin ]; then
        asset="Pureblood-and-Prejudice-$version-mac-$arch.dmg"
    else
        [ "$arch" != x64 ] || arch=x86_64
        asset="Pureblood-and-Prejudice-$version-linux-$arch.AppImage"
        command -v sha256sum >/dev/null 2>&1 || fail 'Please install sha256sum (coreutils).'
    fi
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/pp-install.XXXXXXXX")
    printf 'Downloading Pureblood & Prejudice %s...\n' "$version"
    base="$repo/releases/download/v$version"
    curl -fsSL --retry 2 "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt"
    expected=$(awk -v name="$asset" '$2 == name || $2 == "*" name {count++; hash=$1} END {if (count != 1) exit 1; print hash}' "$tmp/SHA256SUMS.txt") ||
        fail "No unique SHA-256 checksum found for $asset."
    printf '%s\n' "$expected" | LC_ALL=C grep -Eq '^[0-9a-fA-F]{64}$' ||
        fail "No unique SHA-256 checksum found for $asset."
    curl -fsSL --retry 2 "$base/$asset" -o "$tmp/$asset"
    if [ "$os" = Darwin ]; then
        actual=$(shasum -a 256 "$tmp/$asset")
    else
        actual=$(sha256sum "$tmp/$asset")
    fi
    actual=${actual%% *}
    [ "$(printf '%s' "$actual" | tr 'A-F' 'a-f')" = "$(printf '%s' "$expected" | tr 'A-F' 'a-f')" ] ||
        fail 'SHA-256 mismatch. Nothing was installed. Please try again.'

    if [ "$os" = Darwin ]; then
        mkdir -p "$tmp/mount" "$app_dir"
        # Set before attaching so an interrupted attach is also cleaned up.
        mounted="$tmp/mount"
        hdiutil attach "$tmp/$asset" -nobrowse -readonly -mountpoint "$mounted" -quiet
        source_app="$mounted/pureblood-and-prejudice.app"
        [ "$(mac_bundle_value "$source_app" CFBundleIdentifier)" = "$bundle_id" ] || fail 'Unexpected app in the disk image.'
        [ "$(mac_bundle_value "$source_app" CFBundleShortVersionString)" = "$version" ] || fail 'Unexpected app version in the disk image.'
        stage=$(mktemp -d "$app_dir/.pp-install.XXXXXXXX")
        ditto "$source_app" "$stage/$app_name"
        remove_app "$app"
        remove_app "$app_dir/pureblood-and-prejudice.app"
        mv "$stage/$app_name" "$app"
        hdiutil detach "$mounted" -quiet
        mounted=
        printf 'Installed %s at %s\n' "$(mac_bundle_value "$app" CFBundleShortVersionString)" "$app"
        printf 'The app is unsigned. In Finder, right-click the app and choose Open.\n'
    else
        chmod +x "$tmp/$asset"
        # Extraction needs neither FUSE nor an app launch.
        (cd "$tmp" && "./$asset" --appimage-extract >/dev/null)
        icon_source=
        icon_size=512
        for size in 512 1024 256 128 64 48 32 16; do
            candidate="$tmp/squashfs-root/usr/share/icons/hicolor/${size}x${size}/apps/pureblood-and-prejudice.png"
            if [ -f "$candidate" ]; then
                icon_source=$candidate
                icon_size=$size
                break
            fi
        done
        if [ -z "$icon_source" ] && [ -f "$tmp/squashfs-root/pureblood-and-prejudice.png" ]; then
            icon_source="$tmp/squashfs-root/pureblood-and-prejudice.png"
        fi
        [ -n "$icon_source" ] || fail 'Could not extract the app icon. Nothing was installed.'
        icon_dir="$HOME/.local/share/icons/hicolor/${icon_size}x${icon_size}/apps"
        mkdir -p "$install_dir" "$HOME/.local/bin" "$HOME/.local/share/applications" "$icon_dir"
        # Stage on the destination filesystem, then replace the AppImage atomically.
        stage=$(mktemp -d "$install_dir/.pp-install.XXXXXXXX")
        cp "$tmp/$asset" "$stage/game.AppImage"
        chmod +x "$stage/game.AppImage"
        mv -f "$stage/game.AppImage" "$image"
        cp "$icon_source" "$icon_dir/pureblood-and-prejudice.png"
        cat > "$launcher" <<'LAUNCHER'
#!/bin/sh
set -eu
image="$HOME/.local/share/pureblood-and-prejudice/Pureblood-and-Prejudice.AppImage"
has_fuse=false
if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
    has_fuse=true
else
    for library in /lib/libfuse.so.2 /usr/lib/libfuse.so.2 /lib/*/libfuse.so.2 /usr/lib/*/libfuse.so.2 /lib64/libfuse.so.2 /usr/lib64/libfuse.so.2; do
        if [ -f "$library" ]; then has_fuse=true; break; fi
    done
fi
if [ "$has_fuse" = false ]; then
    export APPIMAGE_EXTRACT_AND_RUN=1
fi
exec "$image" "$@"
LAUNCHER
        chmod +x "$launcher"
        # Desktop Entry escaping happens before Exec argument unquoting.
        # shellcheck disable=SC2016 # Dollar signs here are literal sed patterns.
        desktop_exec=$(printf '%s' "$launcher" | sed 's/\\/\\\\\\\\/g; s/"/\\\\"/g; s/`/\\\\`/g; s/\$/\\\\$/g; s/%/%%/g')
        cat > "$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Pureblood & Prejudice
Exec="$desktop_exec"
Icon=pureblood-and-prejudice
Terminal=false
Categories=Game;
DESKTOP
        printf '%s\n' "$version" > "$install_dir/VERSION"
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
        fi
        printf 'Installed %s. Open Pureblood & Prejudice from your applications menu.\n' "$version"
        case ":$PATH:" in
            *":$HOME/.local/bin:"*) ;;
            *) printf 'To use the terminal launcher, add %s/.local/bin to PATH.\n' "$HOME" ;;
        esac
    fi
    printf 'Run the same command again to update. Saves are kept.\n'
}

pp_main "$@" </dev/null
