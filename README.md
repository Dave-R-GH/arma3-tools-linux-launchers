# Arma 3 Tools launchers for Linux

This package configures the Windows-only Arma 3 Tools suite for Linux through
Steam Proton and installs desktop/application-menu launchers for:

- Object Builder
- Addon Builder
- TexView2

It was developed and tested on Linux Mint with native Steam and Proton
Experimental.

## Prerequisites

1. Install **Arma 3 Tools** from the Steam Tools library.
2. Install **Proton Experimental**.
3. Open Arma 3 Tools' Steam properties.
4. Under **Compatibility**, force a Proton version.
5. Launch Arma 3 Tools once, then close it. This creates Steam app `233800`'s
   Proton prefix.

Do not run the installer with `sudo`. The installer refuses to run as root.

A separate Wine installation is not required. Steam Proton includes the Wine components used by these launchers.

## Installation

Extract the ZIP, open a terminal in the extracted directory, and run:

```bash
chmod +x install.sh uninstall.sh diagnose.sh
./install.sh
```

The installer automatically detects common native-Steam locations. For a
nonstandard Steam library, specify the Tools folder:

```bash
ARMA3_TOOLS_DIR="/path/to/steamapps/common/Arma 3 Tools" ./install.sh
```

If Proton cannot be detected:

```bash
PROTON_PATH="/path/to/Proton/proton" ./install.sh
```

## Installed layout

- `P:` is an internal Proton project drive. Object Builder should save here.
- `~/Arma3Work-Proton` links to the same project files from Linux.
- `L:` maps to the Linux desktop for TexView imports and exports.
- `H:` maps to the Linux home directory.
- `S:` maps to the Steam library's `steamapps` directory.

### Filesystem access

These mappings give Windows applications running in the Arma 3 Tools Proton
prefix access to the corresponding Linux folders:

- `H:` exposes your Linux home directory.
- `L:` exposes your Linux desktop.
- `S:` exposes your Steam library.

Only open trusted projects and files with the tools. The installer records
existing `H:`, `L:`, `P:`, and `S:` mappings so the uninstaller can restore
them later.

Object Builder receives a per-application Windows XP compatibility setting.
This forces its legacy Save dialog and avoids a Wine
`IFileSaveDialog::GetProperties` crash. It does not change the Windows version
seen by TexView or Addon Builder.

TexView's ImageToPAA configuration is copied into the prefix's `C:` drive so it
does not depend on external Wine drive traversal.

## Persistence

The configuration survives normal shutdowns and restarts. Steam and Proton
updates normally retain it as well.

Rerun `install.sh` if Steam's `compatdata/233800` prefix is deleted, reset, or
recreated. Project files stored under `P:` are inside that prefix, so back up
the Linux-visible `~/Arma3Work-Proton` folder before deliberately deleting the
prefix.

## Usage

- **Object Builder:** save models under `P:\`.
- **TexView2:** use `L:\` for the Linux desktop.
- **Addon Builder:** use `P:\` for source projects; `H:\` and `L:\` are also
  available.

The launchers appear on the desktop and in the application menu. On Cinnamon,
right-click a menu entry and choose **Add to panel** to pin it.

## Diagnostics

Run:

```bash
./diagnose.sh
```

It reports detected paths, Wine drive mappings, launcher presence, and relevant
registry values.

## Uninstallation

Run:

```bash
./uninstall.sh
```

The uninstaller removes the launchers and registry settings created by this
package and restores any drive mappings that existed before installation. It
deliberately preserves `~/Arma3Work-Proton`, the internal `P:` project folder,
and copied TexView support files to avoid deleting user data.

## Known scope

- Intended for desktop Linux with native Steam.
- Flatpak Steam may require additional filesystem permissions and is not
  automatically configured.
- Buldozer/game-preview setup is separate from these launcher and file-dialog
  repairs.

## Support and affiliation

This is an unofficial community project and is not affiliated with or endorsed
by Bohemia Interactive. Arma and Arma 3 are trademarks of Bohemia Interactive
a.s.

## License

MIT. See `LICENSE`.
