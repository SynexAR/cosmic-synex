# cosmic-synex

*Español: [README.es.md](README.es.md)*

Patches and packaging tooling for the **COSMIC** desktop on **Synex GNU/Linux** (Debian 13 "Trixie" base).

This repository **does not contain COSMIC's source code**. It only holds the patches that adapt COSMIC for Debian/Synex and the scripts that automate downloading, patching and building it. COSMIC's source is fetched from [System76's official repository](https://github.com/pop-os/cosmic-epoch) at build time.

## What it solves

COSMIC is officially packaged for Pop!_OS (Ubuntu base). These patches adapt that packaging to Debian 13, replacing Pop ecosystem dependencies that don't exist in Debian, and apply Synex's visual identity:

- `pop-fonts` -> `fonts-inter`
- `pop-sound-theme` -> `sound-theme-freedesktop`
- `appstream-data-pop` -> `appstream`
- `network-manager-gnome` -> `nm-connection-editor` (avoids a duplicate network applet)
- Synex identity: orange accent, Inter/Hack typefaces, default wallpaper and dock.

## Structure

```
cosmic-synex/
├── README.md
├── apply-patches.sh        # clones COSMIC at the pinned tag and applies the patches
├── build-cosmic-debs.sh    # builds the .deb packages
└── patches/                # one patch per modified component
    ├── cosmic-applets.patch
    ├── cosmic-bg.patch
    ├── cosmic-initial-setup.patch
    ├── cosmic-panel.patch
    ├── cosmic-session.patch
    ├── cosmic-settings.patch
    ├── cosmic-settings-daemon.patch
    └── cosmic-store.patch
```

## Usage

Requirements: `git`, the Debian packaging tools (`devscripts`, `equivs`, `dpkg-dev`) and the Rust toolchain (via `rustup`).

```bash
# 1. Clone this repository
git clone git@github.com:SynexAR/cosmic-synex.git
cd cosmic-synex

# 2. Download COSMIC and apply the patches
./apply-patches.sh

# 3. Build the .deb packages
cp build-cosmic-debs.sh cosmic-epoch/
cd cosmic-epoch
./build-cosmic-debs.sh
```

The resulting packages are placed in `cosmic-epoch/synex-debs/`.

## Version

The patches are generated against the **`epoch-1.0.16`** tag of cosmic-epoch. The target version is defined by the `COSMIC_TAG` variable in `apply-patches.sh`.

## Maintenance

When a new COSMIC version is released:

1. Update `COSMIC_TAG` in `apply-patches.sh` to the new tag.
2. Run `apply-patches.sh`. If a patch doesn't apply cleanly (because upstream changed the same lines), `git am` will report it for manual resolution.
3. Resolve, regenerate the affected patch with `git format-patch`, and rebuild.

## Additional packages

COSMIC depends on two packages from the Pop!_OS ecosystem that are not available in Debian. They are built unmodified from their upstream sources and are not part of this patch set:

- **pop-icon-theme** — built from https://github.com/pop-os/icon-theme
- **adw-gtk3** — built from https://github.com/pop-os/adw-gtk3

Build these separately and include them in your package repository alongside the patched COSMIC components.

## License

The patches are released under the same license as the COSMIC components they modify (GPL-3.0). COSMIC's source code belongs to System76 and retains its respective licenses.

---

Maintained by the [Synex](https://synex.ar) team.
