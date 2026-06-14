#!/bin/bash
# build-cosmic-debs.sh — Construcción masiva de paquetes .deb de COSMIC para Synex
# Uso: ./build-cosmic-debs.sh [componente ...]
#   Sin argumentos: construye todos los componentes.
#   Con argumentos: construye solo los indicados (ej.: ./build-cosmic-debs.sh cosmic-comp cosmic-panel)
#
# Requisitos previos:
#   - sysext desactivado (sudo systemd-sysext unmerge) — /usr debe ser escribible
#   - devscripts, equivs, dpkg-dev instalados
#   - Ejecutar desde la raíz de ~/cosmic-epoch

set -u

EPOCH_DIR="$(pwd)"
OUT_DIR="$EPOCH_DIR/synex-debs"
LOG_DIR="$EPOCH_DIR/synex-debs/logs"
NC_FLAG="-nc"   # primera pasada: sin clean, aprovecha target/ cacheado. Para builds limpios finales: NC_FLAG=""

# Componentes (según el árbol real de cosmic-epoch)
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
)

# Si se pasaron componentes por argumento, usar esos
if [ $# -gt 0 ]; then
  COMPONENTS=("$@")
else
  COMPONENTS=("${ALL_COMPONENTS[@]}")
fi

mkdir -p "$OUT_DIR" "$LOG_DIR"

OK_LIST=()
FAIL_LIST=()
SKIP_LIST=()

echo "=== Build de paquetes COSMIC para Synex ==="
echo "Componentes: ${#COMPONENTS[@]}"
echo "Salida: $OUT_DIR"
echo "Logs:   $LOG_DIR"
echo

for c in "${COMPONENTS[@]}"; do
  if [ ! -d "$EPOCH_DIR/$c" ]; then
    echo "[SKIP] $c — directorio no existe"
    SKIP_LIST+=("$c")
    continue
  fi
  if [ ! -f "$EPOCH_DIR/$c/debian/control" ]; then
    echo "[SKIP] $c — sin debian/control (empaquetar a mano)"
    SKIP_LIST+=("$c")
    continue
  fi

  echo "=== [$c] ==="
  LOG="$LOG_DIR/$c.log"
  cd "$EPOCH_DIR/$c" || { FAIL_LIST+=("$c (cd)"); continue; }

  # Build-deps: instalar las declaradas; si falla (nombres de Ubuntu/Pop), no abortar:
  # el build igual puede funcionar porque las deps reales ya están instaladas.
  echo "--- mk-build-deps ---" > "$LOG"
  if ! sudo mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control >> "$LOG" 2>&1; then
    echo "  (aviso) mk-build-deps falló — revisar Build-Depends en el log; se intenta el build igual"
  fi

  # Vendoring: los debian/rules de Pop esperan un vendor.tar con los crates
  # pre-empaquetados (build offline). Generarlo si no existe.
  if [ ! -f vendor.tar ]; then
    echo "--- vendor ---" >> "$LOG"
    if [ -f justfile ] && just --summary 2>/dev/null | tr ' ' '\n' | grep -qx vendor; then
      echo "  generando vendor.tar (just vendor)..."
      just vendor >> "$LOG" 2>&1 || echo "  (aviso) just vendor falló — ver log"
    elif [ -f Makefile ] && grep -qE '^vendor:' Makefile; then
      echo "  generando vendor.tar (make vendor)..."
      make vendor >> "$LOG" 2>&1 || echo "  (aviso) make vendor falló — ver log"
    fi
  fi

  # Build del paquete binario, sin firmar, ignorando versiones de build-deps (-d),
  # sin clean (-nc) para aprovechar target/ cacheado.
  echo "--- dpkg-buildpackage ---" >> "$LOG"
  if dpkg-buildpackage -us -uc -b -d $NC_FLAG >> "$LOG" 2>&1; then
    echo "  OK"
    OK_LIST+=("$c")
    # mover artefactos generados en el directorio padre
    find "$EPOCH_DIR" -maxdepth 1 -name "*.deb"      -newer "$LOG" -exec mv {} "$OUT_DIR/" \; 2>/dev/null
    mv "$EPOCH_DIR"/*.deb "$OUT_DIR/" 2>/dev/null
    mv "$EPOCH_DIR"/*.buildinfo "$EPOCH_DIR"/*.changes "$OUT_DIR/" 2>/dev/null
  else
    echo "  FALLO — ver $LOG (últimas líneas:)"
    tail -n 8 "$LOG" | sed 's/^/    /'
    FAIL_LIST+=("$c")
  fi
  echo
done

cd "$EPOCH_DIR"

echo "==================== RESUMEN ===================="
echo "OK    (${#OK_LIST[@]}): ${OK_LIST[*]:-—}"
echo "FALLO (${#FAIL_LIST[@]}): ${FAIL_LIST[*]:-—}"
echo "SKIP  (${#SKIP_LIST[@]}): ${SKIP_LIST[*]:-—}"
echo
echo "Paquetes generados:"
ls -1 "$OUT_DIR"/*.deb 2>/dev/null | sed 's/^/  /' || echo "  (ninguno)"
echo
echo "Logs por componente en: $LOG_DIR"
