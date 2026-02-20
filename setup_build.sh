#!/bin/bash

# 1. Umgebung initialisieren
source poky/oe-init-build-env build

# 2. Sauberes Setup: Alten custom-layer löschen, um Parsing-Fehler zu vermeiden
cd ..
echo "Bereinige alten meta-custom Layer..."
rm -rf meta-custom

# 3. Layer Struktur neu erstellen
echo "Erstelle meta-custom Layer Struktur..."
mkdir -p meta-custom/conf
mkdir -p meta-custom/recipes-core/custom-scripts/files/scripts-dir

# Layer-Konfiguration
cat <<EOT > meta-custom/conf/layer.conf
BBPATH .= ":\${LAYERDIR}"
BBFILES += "\${LAYERDIR}/recipes-core/*/*.bb \${LAYERDIR}/recipes-core/*/*.bbappend"
BBFILE_COLLECTIONS += "custom"
BBFILE_PATTERN_custom = "^\${LAYERDIR}/"
BBFILE_PRIORITY_custom = "6"
LAYERSERIES_COMPAT_custom = "scarthgap kirkstone mickledore"
EOT

# Das Rezept (WICHTIG: Kein file://* mehr!)
cat <<EOT > meta-custom/recipes-core/custom-scripts/custom-scripts.bb
SUMMARY = "Installiert eigene Scripte aus dem Repository"
LICENSE = "CLOSED"

SRC_URI = "file://scripts-dir"

S = "\${WORKDIR}/scripts-dir"

do_install() {
    install -d \${D}\${bindir}
    if [ -n "\$(ls -A \${S} 2>/dev/null)" ]; then
        for f in \${S}/*; do
            if [ -f "\$f" ]; then
                install -m 0755 "\$f" \${D}\${bindir}/
            fi
        done
    fi
}

FILES:\${PN} += "\${bindir}/*"
EOT

# 4. Dateien aus deinem 'bin' Ordner kopieren
# Wir stellen sicher, dass der Ordner existiert, sonst schlägt cp fehl
if [ -d "bin" ]; then
    echo "Kopiere Dateien aus /bin in den Layer..."
    cp -r bin/* meta-custom/recipes-core/custom-scripts/files/scripts-dir/
else
    echo "WARNUNG: Ordner /bin nicht gefunden! Erstelle leere Dummy-Datei..."
    touch meta-custom/recipes-core/custom-scripts/files/scripts-dir/.keep
fi

cd build

# 5. Layer hinzufügen (falls noch nicht drin)
echo "Konfiguriere Layer..."
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia
bitbake-layers add-layer ../meta-custom

# 6. local.conf neu schreiben
LOCAL_CONF="conf/local.conf"
echo "Schreibe $LOCAL_CONF neu..."
rm -f $LOCAL_CONF

cat <<EOT >> $LOCAL_CONF
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

IMAGE_INSTALL:append = " \\
    python3-core \\
    python3-modules \\
    python3-paho-mqtt \\
    python3-requests \\
    mosquitto \\
    mosquitto-clients \\
    ca-certificates \\
    custom-scripts \\
"

BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
BB_STRICT_CHECKSUM = "0"
SSTATE_DIR = "\${TOPDIR}/sstate-cache"

DISTRO ?= "poky"
PACKAGE_CLASSES ?= "package_rpm"
USER_CLASSES ?= "buildstats"
PATCHRESOLVE = "noop"
EOT

echo "--- Setup fertig. Starte BitBake ---"
bitbake core-image-base
