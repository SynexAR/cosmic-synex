# cosmic-synex

*English: [README.md](README.md)*

Parches y herramientas de empaquetado del escritorio **COSMIC** para **Synex GNU/Linux** (base Debian 13 «Trixie»).

Este repositorio **no contiene el código de COSMIC**. Contiene únicamente los parches que adaptan COSMIC para Debian/Synex y los scripts que automatizan su descarga, parcheo y construcción. El código de COSMIC se descarga desde el repositorio oficial de [System76](https://github.com/pop-os/cosmic-epoch) al momento de construir.

## Qué resuelve

COSMIC se empaqueta oficialmente para Pop!_OS (base Ubuntu). Estos parches adaptan ese empaquetado a Debian 13, reemplazando dependencias del ecosistema Pop que no existen en Debian, y aplican la identidad visual de Synex:

- `pop-fonts` -> `fonts-inter`
- `pop-sound-theme` -> `sound-theme-freedesktop`
- `appstream-data-pop` -> `appstream`
- `network-manager-gnome` -> `nm-connection-editor` (evita un applet de red duplicado)
- Identidad Synex: acento naranja, tipografías Inter/Hack, fondo y barra por defecto.

## Estructura

```
cosmic-synex/
├── README.md
├── apply-patches.sh        # clona COSMIC en el tag fijado y aplica los parches
├── build-cosmic-debs.sh    # construye los paquetes .deb
└── patches/                # un parche por componente modificado
    ├── cosmic-applets.patch
    ├── cosmic-bg.patch
    ├── cosmic-initial-setup.patch
    ├── cosmic-panel.patch
    ├── cosmic-session.patch
    ├── cosmic-settings.patch
    ├── cosmic-settings-daemon.patch
    └── cosmic-store.patch
```

## Uso

Requisitos: `git` (con `user.name` y `user.email` configurados — `apply-patches.sh` usa `git am`, que crea commits), las herramientas de construcción de paquetes Debian (`devscripts`, `equivs`, `dpkg-dev`) y el toolchain de Rust (vía `rustup`).

```bash
# 1. Clonar este repositorio
git clone https://github.com/SynexAR/cosmic-synex.git
cd cosmic-synex

# 2. Descargar COSMIC y aplicar los parches
./apply-patches.sh

# 3. Construir los .deb
cp build-cosmic-debs.sh cosmic-epoch/
cd cosmic-epoch
./build-cosmic-debs.sh
```

Los paquetes resultantes quedan en `cosmic-epoch/synex-debs/`.

## Versión

Los parches están generados sobre el tag **`epoch-1.1.0`** de cosmic-epoch. La versión objetivo se define en la variable `COSMIC_TAG` de `apply-patches.sh`.

Todos los paquetes se versionan según el tag del superproyecto (`X.Y.Z+synexN`), no según el changelog interno de cada componente. La versión se aplica en el momento de la construcción mediante `dch`, definida en la variable `SYNEX_VERSION` de `build-cosmic-debs.sh`. Para usar tu propio versionado, editá esa variable.

## Mantenimiento

Al publicarse una nueva versión de COSMIC:

1. Actualizar `COSMIC_TAG` en `apply-patches.sh` al nuevo tag.
2. Ejecutar `apply-patches.sh`. Si algún parche no aplica limpio (porque upstream modificó las mismas líneas), `git am` lo indica para resolución manual.
3. Resolver, regenerar el parche afectado con `git format-patch`, y reconstruir.

## Paquetes adicionales

COSMIC depende de dos paquetes del ecosistema Pop!_OS que no están disponibles en Debian. Se construyen sin modificar desde sus fuentes originales y no forman parte de este conjunto de parches:

- **pop-icon-theme** — se construye desde https://github.com/pop-os/icon-theme
- **adw-gtk3** — se construye desde https://github.com/pop-os/adw-gtk3

Construilos por separado e incluilos en tu repositorio de paquetes junto con los componentes de COSMIC parcheados.

## Licencia

Los parches se publican bajo la misma licencia que los componentes de COSMIC que modifican (GPL-3.0). El código de COSMIC pertenece a System76 y mantiene sus respectivas licencias.

---

Mantenido por el equipo de [Synex](https://synex.ar).
