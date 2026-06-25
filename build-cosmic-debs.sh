#!/bin/bash
# build-cosmic-debs.sh — Bulk build of COSMIC .deb packages for Synex
# Usage: ./build-cosmic-debs.sh [component ...]
#   No arguments: builds all components.
#   With arguments: builds only the listed ones (e.g.: ./build-cosmic-debs.sh cosmic-comp cosmic-panel)
#
# Prerequisites:
#   - sysext disabled (sudo systemd-sysext unmerge) — /usr must be writable
#   - devscripts, equivs, dpkg-dev installed
#   - Run from the root of ~/cosmic-epoch

set -u

EPOCH_DIR="$(pwd)"
OUT_DIR="$EPOCH_DIR/synex-debs"
LOG_DIR="$EPOCH_DIR/synex-debs/logs"
NC_FLAG="-nc"   # first pass: no clean, reuses cached target/. For clean final builds: NC_FLAG=""

# Synex package version: all packages are versioned by the superproject tag,
# not by each component's internal changelog. Bump this on every COSMIC release.
SYNEX_VERSION="1.1.0+synex1"
SYNEX_MESSAGE="Rebuild for COSMIC epoch-1.1.0"

# Components (matching the real cosmic-epoch tree)
ALL_COMPONENTS=(
  cosmic-icons
  cosmic-wallpapers
  pop-launcher
  cosmic-comp
  cosmic-session
  cosmic-greeter
  cosmic-settings-daemon
  cosmic-randr
  xdg-desktop-portal-cosmic
  cosmic-panel
  cosmic-applets
  cosmic-launcher
  cosmic-workspaces-epoch
  cosmic-bg
  cosmic-osd
  cosmic-notifications
  cosmic-applibrary
  cosmic-idle
  cosmic-screenshot
  cosmic-settings
  cosmic-files
  cosmic-term
  cosmic-edit
  cosmic-store
  cosmic-player
  cosmic-initial-setup
  cosmic-monitor
)

# If components were passed as arguments, use those
if [ $# -gt 0 ]; then
  COMPONENTS=("$@")
else
  COMPONENTS=("${ALL_COMPONENTS[@]}")
fi

mkdir -p "$OUT_DIR" "$LOG_DIR"

OK_LIST=()
FAIL_LIST=()
SKIP_LIST=()

echo "=== Build of COSMIC packages for Synex ==="
echo "Components: ${#COMPONENTS[@]}"
echo "Output: $OUT_DIR"
echo "Logs:   $LOG_DIR"
echo

for c in "${COMPONENTS[@]}"; do
  if [ ! -d "$EPOCH_DIR/$c" ]; then
    echo "[SKIP] $c — directory does not exist"
    SKIP_LIST+=("$c")
    continue
  fi
  if [ ! -f "$EPOCH_DIR/$c/debian/control" ]; then
    echo "[SKIP] $c — no debian/control (package manually)"
    SKIP_LIST+=("$c")
    continue
  fi

  echo "=== [$c] ==="
  LOG="$LOG_DIR/$c.log"
  cd "$EPOCH_DIR/$c" || { FAIL_LIST+=("$c (cd)"); continue; }

  # Build-deps: install the declared ones; if it fails (Ubuntu/Pop names), don't abort:
  # the build can still work because the real deps are already installed.
  echo "--- mk-build-deps ---" > "$LOG"
  if ! sudo mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control >> "$LOG" 2>&1; then
    echo "  (warning) mk-build-deps failed — check Build-Depends in the log; build is attempted anyway"
  fi

  # Vendoring: Pop's debian/rules expect a vendor.tar with the crates
  # pre-packaged (offline build). Generate it if it doesn't exist.
  if [ ! -f vendor.tar ]; then
    echo "--- vendor ---" >> "$LOG"
    if [ -f justfile ] && just --summary 2>/dev/null | tr ' ' '\n' | grep -qx vendor; then
      echo "  generating vendor.tar (just vendor)..."
      just vendor >> "$LOG" 2>&1 || echo "  (warning) just vendor failed — see log"
    elif [ -f Makefile ] && grep -qE '^vendor:' Makefile; then
      echo "  generating vendor.tar (make vendor)..."
      make vendor >> "$LOG" 2>&1 || echo "  (warning) make vendor failed — see log"
    fi
  fi

  # Synex versioning: force the package version to the superproject tag so apt
  # always serves the update and all packages stay consistent. Applied at build
  # time, not as a per-component patch.
  echo "--- dch (Synex version) ---" >> "$LOG"
  dch -b -v "$SYNEX_VERSION" --distribution stable "$SYNEX_MESSAGE" >> "$LOG" 2>&1

  # Build the binary package, unsigned, ignoring build-dep versions (-d),
  # without clean (-nc) to reuse cached target/.
  echo "--- dpkg-buildpackage ---" >> "$LOG"
  if dpkg-buildpackage -us -uc -b -d $NC_FLAG >> "$LOG" 2>&1; then
    echo "  OK"
    OK_LIST+=("$c")
    # move artifacts generated in the parent directory
    find "$EPOCH_DIR" -maxdepth 1 -name "*.deb"      -newer "$LOG" -exec mv {} "$OUT_DIR/" \; 2>/dev/null
    mv "$EPOCH_DIR"/*.deb "$OUT_DIR/" 2>/dev/null
    mv "$EPOCH_DIR"/*.buildinfo "$EPOCH_DIR"/*.changes "$OUT_DIR/" 2>/dev/null
  else
    echo "  FAIL — see $LOG (last lines:)"
    tail -n 8 "$LOG" | sed 's/^/    /'
    FAIL_LIST+=("$c")
  fi

  # Synex versioning: revert the changelog after building so the work tree stays
  # clean and the Synex entry is never accidentally pulled into a patch.
  git checkout debian/changelog 2>/dev/null || true

  echo
done

cd "$EPOCH_DIR"

echo "==================== SUMMARY ===================="
echo "OK    (${#OK_LIST[@]}): ${OK_LIST[*]:-—}"
echo "FAIL  (${#FAIL_LIST[@]}): ${FAIL_LIST[*]:-—}"
echo "SKIP  (${#SKIP_LIST[@]}): ${SKIP_LIST[*]:-—}"
echo
echo "Generated packages:"
ls -1 "$OUT_DIR"/*.deb 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo
echo "Per-component logs in: $LOG_DIR"
