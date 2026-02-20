#!/bin/bash

# 1. Umgebung initialisieren
source poky/oe-init-build-env build

# 2. EIGENEN LAYER ERSTELLEN (Der Yocto-Weg)
# Wir erstellen einen Layer für deine Dateien, falls er noch nicht existiert
cd ..
if [ ! -d "meta-custom" ]; then
    echo "Erstelle meta-custom Layer..."
    mkdir -p meta-custom/conf
    mkdir -p meta-custom/recipes-core/custom-scripts/files
    
    # Layer-Konfiguration erstellen
    cat <<EOT > meta-custom/conf/layer.conf
BBPATH .= ":\${LAYERDIR}"
BBFILES += "\${LAYERDIR}/recipes-core/*/*.bb \${LAYERDIR}/recipes-core/*/*.bbappend"
BBFILE_COLLECTIONS += "custom"
BBFILE_PATTERN_custom = "^\${LAYERDIR}/"
BBFILE_PRIORITY_custom = "6"
LAYERSERIES_COMPAT_custom = "scarthgap kirkstone mickledore"
EOT

    # Das Rezept erstellen, das deine Dateien aus dem 'bin' Ordner installiert
    cat <<EOT > meta-custom/recipes-core/custom-scripts/custom-scripts.bb
SUMMARY = "Installiert eigene Scripte in /usr/bin"
LICENSE = "CLOSED"

# Hier sagen wir Yocto, welche Dateien er nehmen soll
# Er sucht im Unterordner 'files'
SRC_URI = "file://*"

S = "\${WORKDIR}"

do_install() {
    install -d \${D}\${bindir}
    # Kopiere alle Dateien aus dem 'files' Ordner nach /usr/bin im Image
    # Wir nutzen ein Loop, um flexibel zu bleiben
    if [ -n "\$(ls -A \${WORKDIR}/*.sh 2>/dev/null)" ]; then
        install -m 0755 \${WORKDIR}/*.sh \${D}\${bindir}/
    fi
    # Falls du Python-Dateien oder andere hast, füge sie hier hinzu:
    if [ -n "\$(ls -A \${WORKDIR}/*.py 2>/dev/null)" ]; then
        install -m 0755 \${WORKDIR}/*.py \${D}\${bindir}/
    fi
}

FILES:\${PN} = "\${bindir}/*"
EOT
fi

# DATEIEN KOPIEREN: Hier schiebst du deine Dateien aus deinem GitHub 'bin' Ordner in den Layer
# Angenommen dein GitHub Repo hat einen Ordner 'scripts_folder'
cp -r ../scripts_folder/* meta-custom/recipes-core/custom-scripts/files/ 2>/dev/null || true

cd build

# 3. Layer hinzufügen
echo "Konfiguriere Layer..."
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-custom  # DEIN NEUER LAYER

# 4. local.conf zurücksetzen und neu schreiben
LOCAL_CONF="conf/local.conf"
rm -f $LOCAL_CONF

cat <<EOT >> $LOCAL_CONF
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

# SOFTWARE + DEIN CUSTOM REZEPT
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
SSTATE_DIR = "\${TOPDIR}/sstate-cache"
EOT

# 5. Build starten
bitbake core-image-base
