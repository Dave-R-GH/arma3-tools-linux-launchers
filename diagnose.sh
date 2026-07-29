#!/usr/bin/env bash
set -Eeuo pipefail

STATE_FILE="$HOME/.config/arma3-tools-linux/state"
if [[ ! -f "$STATE_FILE" ]]; then
    printf 'No installation state was found. Run install.sh first.\n' >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$STATE_FILE"

printf 'Arma 3 Tools Linux diagnostics\n\n'
printf 'Tools:         %s\n' "$TOOLS_DIR"
printf 'Steam client:  %s\n' "$STEAM_CLIENT_ROOT"
printf 'Prefix:        %s\n' "$PREFIX"
printf 'Proton:        %s\n' "$PROTON"
printf 'Linux project: %s\n\n' "$PROJECT_LINK"

printf 'Wine drive mappings:\n'
for drive in s h l p z; do
    mapping="$(readlink "$PREFIX/dosdevices/$drive:" 2>/dev/null || true)"
    printf '  %s: -> %s\n' "${drive^^}" "${mapping:-MISSING}"
done

printf '\nInstalled launchers:\n'
for launcher in \
    "$HOME/.local/share/applications/arma3-object-builder.desktop" \
    "$HOME/.local/share/applications/arma3-addon-builder.desktop" \
    "$HOME/.local/share/applications/arma3-texview2.desktop"; do
    if [[ -f "$launcher" ]]; then
        printf '  OK      %s\n' "$launcher"
    else
        printf '  MISSING %s\n' "$launcher"
    fi
done

printf '\nRelevant registry values:\n'
if command -v rg >/dev/null; then
    rg -n -A5 \
        'BIStudio.*TextureConvert|AppDefaults.*ObjectBuilder|Bohemia Interactive.*AddonBuilder' \
        "$PREFIX/system.reg" "$PREFIX/user.reg" || true
else
    grep -n -A5 -E \
        'BIStudio.*TextureConvert|AppDefaults.*ObjectBuilder|Bohemia Interactive.*AddonBuilder' \
        "$PREFIX/system.reg" "$PREFIX/user.reg" || true
fi

