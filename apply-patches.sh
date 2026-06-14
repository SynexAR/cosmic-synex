#!/bin/bash
# apply-patches.sh — Clona COSMIC (cosmic-epoch) en el tag fijado y aplica
# los parches Synex sobre cada submódulo.
#
# Resultado: un árbol cosmic-epoch listo para construir los .deb de Synex.
# El código de COSMIC NO vive en este repo: se descarga acá desde Pop!_OS.
# Este repo solo contiene los parches (patches/) y los scripts.
#
# Uso:
#   ./apply-patches.sh            # clona en ./cosmic-epoch y aplica los parches
#   ./apply-patches.sh /ruta      # clona en /ruta/cosmic-epoch

set -eu

# --- Configuración ---
COSMIC_TAG="epoch-1.0.16"
COSMIC_REPO="https://github.com/pop-os/cosmic-epoch"
PATCHES_DIR="$(cd "$(dirname "$0")" && pwd)/patches"
WORK_DIR="${1:-$(pwd)}"
TARGET="$WORK_DIR/cosmic-epoch"

echo "=== Synex COSMIC — aplicación de parches ==="
echo "Tag:      $COSMIC_TAG"
echo "Destino:  $TARGET"
echo "Parches:  $PATCHES_DIR"
echo

# --- Verificaciones previas ---
if [ ! -d "$PATCHES_DIR" ]; then
    echo "ERROR: no se encuentra el directorio de parches: $PATCHES_DIR"
    exit 1
fi

if [ -e "$TARGET" ]; then
    echo "ERROR: $TARGET ya existe. Borralo o elegí otra ruta."
    exit 1
fi

# --- Clonar COSMIC en el tag fijado, con submódulos ---
echo "--- Clonando cosmic-epoch ($COSMIC_TAG) ---"
git clone --branch "$COSMIC_TAG" --depth 1 "$COSMIC_REPO" "$TARGET"
cd "$TARGET"
git submodule update --init --recursive --depth 1

# --- Aplicar cada parche en su submódulo ---
echo
echo "--- Aplicando parches Synex ---"
OK=0
FAIL=0
for patch in "$PATCHES_DIR"/*.patch; do
    comp="$(basename "$patch" .patch)"
    if [ ! -d "$comp" ]; then
        echo "  [SKIP] $comp — submódulo no encontrado"
        continue
    fi
    # git am reaplica el commit completo (mensaje, autor, fecha).
    # Si el parche no aplica limpio (upstream cambió las mismas líneas),
    # git am se detiene para resolución manual.
    if git -C "$comp" am "$patch" >/dev/null 2>&1; then
        echo "  [OK]   $comp"
        OK=$((OK+1))
    else
        echo "  [FALLO] $comp — el parche no aplica limpio (revisar con: cd $comp && git am --show-current-patch)"
        git -C "$comp" am --abort 2>/dev/null || true
        FAIL=$((FAIL+1))
    fi
done

echo
echo "=== Resumen ==="
echo "Aplicados OK: $OK"
echo "Fallaron:     $FAIL"
echo
if [ "$FAIL" -eq 0 ]; then
    echo "Listo. Árbol preparado en: $TARGET"
    echo "Siguiente paso: copiar build-cosmic-debs.sh ahí y construir los .deb."
else
    echo "Algunos parches no aplicaron (probablemente upstream cambió esas líneas)."
    echo "Revisá manualmente, regenerá el parche y volvé a intentar."
fi
