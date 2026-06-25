#!/bin/bash
# apply-patches.sh — Clones COSMIC (cosmic-epoch) at the pinned tag and applies
# the Synex patches onto each submodule.
#
# Result: a cosmic-epoch tree ready to build the Synex .deb packages.
# COSMIC's source does NOT live in this repo: it is downloaded here from Pop!_OS.
# This repo only contains the patches (patches/) and the scripts.
#
# Usage:
#   ./apply-patches.sh            # clones into ./cosmic-epoch and applies the patches
#   ./apply-patches.sh /path      # clones into /path/cosmic-epoch

set -eu

# --- Configuration ---
COSMIC_TAG="epoch-1.1.0"
COSMIC_REPO="https://github.com/pop-os/cosmic-epoch"
PATCHES_DIR="$(cd "$(dirname "$0")" && pwd)/patches"
WORK_DIR="${1:-$(pwd)}"
TARGET="$WORK_DIR/cosmic-epoch"

echo "=== Synex COSMIC — patch application ==="
echo "Tag:      $COSMIC_TAG"
echo "Target:   $TARGET"
echo "Patches:  $PATCHES_DIR"
echo

# --- Pre-flight checks ---
if [ ! -d "$PATCHES_DIR" ]; then
    echo "ERROR: patches directory not found: $PATCHES_DIR"
    exit 1
fi

if [ -e "$TARGET" ]; then
    echo "ERROR: $TARGET already exists. Remove it or choose another path."
    exit 1
fi

# --- Clone COSMIC at the pinned tag, with submodules ---
echo "--- Cloning cosmic-epoch ($COSMIC_TAG) ---"
git clone --branch "$COSMIC_TAG" --depth 1 "$COSMIC_REPO" "$TARGET"
cd "$TARGET"
git submodule update --init --recursive --depth 1

# --- Apply each patch onto its submodule ---
echo
echo "--- Applying Synex patches ---"
OK=0
FAIL=0
for patch in "$PATCHES_DIR"/*.patch; do
    comp="$(basename "$patch" .patch)"
    if [ ! -d "$comp" ]; then
        echo "  [SKIP] $comp — submodule not found"
        continue
    fi
    # git am re-applies the full commit (message, author, date).
    # If the patch does not apply cleanly (upstream changed the same lines),
    # git am stops for manual resolution.
    if git -C "$comp" am "$patch" >/dev/null 2>&1; then
        echo "  [OK]   $comp"
        OK=$((OK+1))
    else
        echo "  [FAIL] $comp — patch did not apply cleanly (check with: cd $comp && git am --show-current-patch)"
        git -C "$comp" am --abort 2>/dev/null || true
        FAIL=$((FAIL+1))
    fi
done

echo
echo "=== Summary ==="
echo "Applied OK: $OK"
echo "Failed:     $FAIL"
echo
if [ "$FAIL" -eq 0 ]; then
    echo "Done. Tree prepared at: $TARGET"
    echo "Next step: copy build-cosmic-debs.sh there and build the .deb packages."
else
    echo "Some patches did not apply (likely upstream changed those lines)."
    echo "Review manually, regenerate the patch and try again."
fi
