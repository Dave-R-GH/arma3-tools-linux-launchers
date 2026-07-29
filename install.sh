#!/usr/bin/env bash
set -Eeuo pipefail

APP_ID="233800"
STATE_DIR="$HOME/.config/arma3-tools-linux"
MAPPINGS_FILE="$STATE_DIR/original-drive-mappings"
APP_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"
PROJECT_LINK="${ARMA3_PROJECT_LINK:-$HOME/Arma3Work-Proton}"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if (( EUID == 0 )); then
    die "Do not run this installer with sudo or as root."
fi

find_tools_dir() {
    local candidate

    if [[ -n "${ARMA3_TOOLS_DIR:-}" && -d "$ARMA3_TOOLS_DIR" ]]; then
        printf '%s\n' "$ARMA3_TOOLS_DIR"
        return 0
    fi

    for candidate in \
        "$HOME/.steam/debian-installation/steamapps/common/Arma 3 Tools" \
        "$HOME/.steam/root/steamapps/common/Arma 3 Tools" \
        "$HOME/.local/share/Steam/steamapps/common/Arma 3 Tools"; do
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_steam_client_root() {
    local candidate

    if [[ -n "${STEAM_CLIENT_ROOT:-}" && -d "$STEAM_CLIENT_ROOT" ]]; then
        printf '%s\n' "$STEAM_CLIENT_ROOT"
        return 0
    fi

    for candidate in \
        "$HOME/.steam/debian-installation" \
        "$HOME/.steam/root" \
        "$HOME/.local/share/Steam"; do
        if [[ -d "$candidate/steamapps" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_proton() {
    local candidate search_root

    if [[ -n "${PROTON_PATH:-}" && -x "$PROTON_PATH" ]]; then
        printf '%s\n' "$PROTON_PATH"
        return 0
    fi

    for candidate in \
        "$STEAMAPPS/common/Proton - Experimental/proton" \
        "$STEAM_CLIENT_ROOT/steamapps/common/Proton - Experimental/proton"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    for search_root in \
        "$STEAMAPPS/common" \
        "$STEAM_CLIENT_ROOT/steamapps/common" \
        "$STEAM_CLIENT_ROOT/compatibilitytools.d"; do
        [[ -d "$search_root" ]] || continue
        candidate="$(find "$search_root" -maxdepth 3 -type f -name proton \
            -path '*Proton*/*' -perm -u+x -print 2>/dev/null |
            sort -V | tail -n 1)"
        if [[ -n "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_executable() {
    local candidate result
    for candidate in "$@"; do
        if [[ -f "$TOOLS_DIR/$candidate" ]]; then
            printf '%s\n' "$TOOLS_DIR/$candidate"
            return 0
        fi
    done

    for candidate in "$@"; do
        result="$(find "$TOOLS_DIR" -type f -iname "${candidate##*/}" \
            -print -quit 2>/dev/null)"
        if [[ -n "$result" ]]; then
            printf '%s\n' "$result"
            return 0
        fi
    done
    return 1
}

TOOLS_DIR="$(find_tools_dir || true)"
[[ -n "$TOOLS_DIR" ]] ||
    die "Arma 3 Tools was not found. Set ARMA3_TOOLS_DIR and run again."

STEAMAPPS="$(dirname "$(dirname "$TOOLS_DIR")")"
[[ "$(basename "$STEAMAPPS")" == "steamapps" ]] ||
    die "Tools directory is not inside a Steam steamapps/common folder."

STEAM_CLIENT_ROOT="$(find_steam_client_root || true)"
[[ -n "$STEAM_CLIENT_ROOT" ]] ||
    die "Steam client root was not found. Set STEAM_CLIENT_ROOT and run again."

COMPAT_ROOT="$STEAMAPPS/compatdata/$APP_ID"
PREFIX="$COMPAT_ROOT/pfx"
[[ -f "$PREFIX/system.reg" ]] || die \
    "The Proton prefix is missing. Force Proton for Arma 3 Tools in Steam, launch it once, close it, then rerun this installer."

PROTON="$(find_proton || true)"
[[ -n "$PROTON" ]] ||
    die "Proton was not found. Install Proton Experimental or set PROTON_PATH."
PROTON_DIR="$(dirname "$PROTON")"
WINESERVER="$PROTON_DIR/files/bin/wineserver"
[[ -x "$WINESERVER" ]] || die "The selected Proton installation has no wineserver."

OBJECT_BUILDER="$(find_executable \
    "ObjectBuilder/ObjectBuilder.exe" \
    "Object Builder/ObjectBuilder.exe" \
    "ObjectBuilder.exe" || true)"
ADDON_BUILDER="$(find_executable \
    "AddonBuilder/AddonBuilder.exe" \
    "Addon Builder/AddonBuilder.exe" \
    "AddonBuilder.exe" || true)"
TEXVIEW="$(find_executable \
    "TexView2/TexView.exe" \
    "TexView2/TexView2.exe" \
    "TexView/TexView2.exe" \
    "TexView.exe" \
    "TexView2.exe" || true)"
TEXCONVERT_CFG="$(find "$TOOLS_DIR/ImageToPAA" "$TOOLS_DIR" -maxdepth 3 \
    -type f -iname 'TexConvert.cfg' -print -quit 2>/dev/null || true)"

[[ -n "$OBJECT_BUILDER" ]] || die "Object Builder executable was not found."
[[ -n "$ADDON_BUILDER" ]] || die "Addon Builder executable was not found."
[[ -n "$TEXVIEW" ]] || die "TexView executable was not found."
[[ -n "$TEXCONVERT_CFG" ]] || die "ImageToPAA/TexConvert.cfg was not found."

run_proton() {
    timeout 45s env \
        STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_CLIENT_ROOT" \
        STEAM_COMPAT_DATA_PATH="$COMPAT_ROOT" \
        STEAM_COMPAT_APP_ID="$APP_ID" \
        SteamAppId="$APP_ID" \
        SteamGameId="$APP_ID" \
        "$PROTON" run "$@"
}

printf 'Stopping the Arma 3 Tools Wine server...\n'
WINEPREFIX="$PREFIX" "$WINESERVER" -k 2>/dev/null || true

DOSDEVICES="$PREFIX/dosdevices"
INTERNAL_P="$PREFIX/drive_c/Arma3Work"
INTERNAL_TEX="$PREFIX/drive_c/Arma3Tools/ImageToPAA"
mkdir -p \
    "$DOSDEVICES" \
    "$INTERNAL_P" \
    "$INTERNAL_TEX" \
    "$STATE_DIR" \
    "$APP_DIR" \
    "$DESKTOP_DIR"

cp -a "$(dirname "$TEXCONVERT_CFG")/." "$INTERNAL_TEX/"

if [[ -f "$MAPPINGS_FILE" ]]; then
    # Preserve the mappings recorded by the first installation when rerunning.
    # shellcheck disable=SC1090
    source "$MAPPINGS_FILE"
else
    PREVIOUS_S="$(readlink "$DOSDEVICES/s:" 2>/dev/null || true)"
    PREVIOUS_H="$(readlink "$DOSDEVICES/h:" 2>/dev/null || true)"
    PREVIOUS_L="$(readlink "$DOSDEVICES/l:" 2>/dev/null || true)"
    PREVIOUS_P="$(readlink "$DOSDEVICES/p:" 2>/dev/null || true)"
    {
        printf 'PREVIOUS_S=%q\n' "$PREVIOUS_S"
        printf 'PREVIOUS_H=%q\n' "$PREVIOUS_H"
        printf 'PREVIOUS_L=%q\n' "$PREVIOUS_L"
        printf 'PREVIOUS_P=%q\n' "$PREVIOUS_P"
    } >"$MAPPINGS_FILE"
fi

ln -sfnT "$STEAMAPPS" "$DOSDEVICES/s:"
ln -sfnT "$HOME" "$DOSDEVICES/h:"
ln -sfnT "$DESKTOP_DIR" "$DOSDEVICES/l:"
ln -sfnT "$INTERNAL_P" "$DOSDEVICES/p:"

if [[ -e "$PROJECT_LINK" && ! -L "$PROJECT_LINK" ]]; then
    PROJECT_LINK="$HOME/Arma3Work-Proton-Prefix"
fi
ln -sfnT "$INTERNAL_P" "$PROJECT_LINK"

printf 'Configuring TexView...\n'
for registry_view in 32 64; do
    run_proton reg.exe add 'HKLM\Software\BIStudio\TextureConvert' \
        /v MAIN /t REG_SZ /d 'C:\Arma3Tools\ImageToPAA' \
        /f "/reg:$registry_view"
    run_proton reg.exe add 'HKLM\Software\BIStudio\TextureConvert' \
        /v configPath /t REG_SZ \
        /d 'C:\Arma3Tools\ImageToPAA\TexConvert.cfg' \
        /f "/reg:$registry_view"
done

printf 'Configuring Object Builder legacy save dialog...\n'
run_proton reg.exe add \
    'HKCU\Software\Wine\AppDefaults\ObjectBuilder.exe' \
    /v Version /t REG_SZ /d winxp /f

addon_dir="${ADDON_BUILDER%/*}"
addon_relative="${addon_dir#"$STEAMAPPS"/}"
addon_windows="S:\\${addon_relative//\//\\}"

printf 'Configuring Addon Builder...\n'
for registry_view in 32 64; do
    run_proton reg.exe add \
        'HKLM\Software\Bohemia Interactive\AddonBuilder' \
        /v path /t REG_SZ /d "$addon_windows" \
        /f "/reg:$registry_view"
    run_proton reg.exe add \
        'HKLM\Software\Bohemia Interactive\AddonBuilder' \
        /v exe /t REG_SZ /d "${ADDON_BUILDER##*/}" \
        /f "/reg:$registry_view"
done

desktop_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\`/\\\`}"
    value="${value//\$/\\\$}"
    printf '%s' "$value"
}

write_launcher() {
    local app_id="$1"
    local name="$2"
    local comment="$3"
    local icon="$4"
    local executable="$5"
    local launcher="$APP_DIR/$app_id.desktop"
    local desktop_copy="$DESKTOP_DIR/$app_id.desktop"
    local client_escaped compat_escaped proton_escaped exe_escaped path_escaped

    client_escaped="$(desktop_escape "$STEAM_CLIENT_ROOT")"
    compat_escaped="$(desktop_escape "$COMPAT_ROOT")"
    proton_escaped="$(desktop_escape "$PROTON")"
    exe_escaped="$(desktop_escape "$executable")"
    path_escaped="$(desktop_escape "$(dirname "$executable")")"

    {
        printf '[Desktop Entry]\n'
        printf 'Version=1.0\n'
        printf 'Type=Application\n'
        printf 'Name=%s\n' "$name"
        printf 'Comment=%s\n' "$comment"
        printf 'Exec=env WINEDEBUG=-all STEAM_COMPAT_CLIENT_INSTALL_PATH="%s" STEAM_COMPAT_DATA_PATH="%s" STEAM_COMPAT_APP_ID=%s SteamAppId=%s SteamGameId=%s "%s" run "%s"\n' \
            "$client_escaped" "$compat_escaped" "$APP_ID" "$APP_ID" "$APP_ID" \
            "$proton_escaped" "$exe_escaped"
        printf 'Path=%s\n' "$path_escaped"
        printf 'Icon=%s\n' "$icon"
        printf 'Terminal=false\n'
        printf 'StartupNotify=true\n'
        printf 'Categories=Development;Graphics;\n'
        printf 'Keywords=Arma;Bohemia;Modding;Wine;Proton;\n'
    } >"$launcher"

    chmod +x "$launcher"
    cp -f "$launcher" "$desktop_copy"
    chmod +x "$desktop_copy"
    gio set "$desktop_copy" metadata::trusted true >/dev/null 2>&1 || true
}

write_launcher \
    "arma3-object-builder" \
    "Arma 3 Object Builder" \
    "Create and edit Arma 3 P3D models" \
    "applications-graphics" \
    "$OBJECT_BUILDER"

write_launcher \
    "arma3-addon-builder" \
    "Arma 3 Addon Builder" \
    "Pack and binarize Arma 3 addons" \
    "applications-development" \
    "$ADDON_BUILDER"

write_launcher \
    "arma3-texview2" \
    "Arma 3 TexView2" \
    "View and convert Arma 3 textures" \
    "applications-graphics" \
    "$TEXVIEW"

if command -v update-desktop-database >/dev/null; then
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
fi

{
    printf 'TOOLS_DIR=%q\n' "$TOOLS_DIR"
    printf 'STEAMAPPS=%q\n' "$STEAMAPPS"
    printf 'STEAM_CLIENT_ROOT=%q\n' "$STEAM_CLIENT_ROOT"
    printf 'COMPAT_ROOT=%q\n' "$COMPAT_ROOT"
    printf 'PREFIX=%q\n' "$PREFIX"
    printf 'PROTON=%q\n' "$PROTON"
    printf 'PROJECT_LINK=%q\n' "$PROJECT_LINK"
    printf 'DESKTOP_DIR=%q\n' "$DESKTOP_DIR"
    printf 'PREVIOUS_S=%q\n' "$PREVIOUS_S"
    printf 'PREVIOUS_H=%q\n' "$PREVIOUS_H"
    printf 'PREVIOUS_L=%q\n' "$PREVIOUS_L"
    printf 'PREVIOUS_P=%q\n' "$PREVIOUS_P"
} >"$STATE_DIR/state"

WINEPREFIX="$PREFIX" "$WINESERVER" -k 2>/dev/null || true

printf '\nInstallation complete.\n\n'
printf 'Linux project folder: %s\n' "$PROJECT_LINK"
printf 'Object Builder: save models under P:\\\n'
printf 'TexView: use L:\\ to open/save files on the Linux desktop\n'
printf 'Addon Builder: P:\\, H:\\ and L:\\ are available\n\n'
printf 'Launchers were installed on the desktop and in the application menu.\n'
