#!/bin/bash

# 1. Projekt-Root Verzeichnis festlegen
PROJECT_ROOT=$(pwd)

# 2. Yocto Umgebung initialisieren
# Falls der Build-Ordner noch nicht existiert, wird er erstellt
source poky/oe-init-build-env build

# 3. Zurück zum Root, um die Layer-Struktur sauber aufzubauen
cd "$PROJECT_ROOT"

# 4. Verzeichnisse vorbereiten
RECIPE_DIR="meta-custom/recipes-core/custom-scripts"
DL_DIR="$RECIPE_DIR/files/downloads"
OVERLAY_DIR="$RECIPE_DIR/files/rootfs_overlay"

# Alten Layer löschen für einen sauberen Stand
rm -rf meta-custom
mkdir -p meta-custom/conf
mkdir -p "$DL_DIR"
mkdir -p "$OVERLAY_DIR"

# 5. Layer-Konfiguration (layer.conf)
cat <<EOT > meta-custom/conf/layer.conf
BBPATH .= ":\${LAYERDIR}"
BBFILES += "\${LAYERDIR}/recipes-core/*/*.bb \${LAYERDIR}/recipes-core/*/*.bbappend"
BBFILE_COLLECTIONS += "custom"
BBFILE_PATTERN_custom = "^\${LAYERDIR}/"
BBFILE_PRIORITY_custom = "6"
LAYERSERIES_COMPAT_custom = "scarthgap"
EOT

# 6. Das Rezept (custom-scripts.bb)
# WICHTIG: RREPLACES/RCONFLICTS löst den File-Clash Fehler
cat <<EOT > "$RECIPE_DIR/custom-scripts.bb"
SUMMARY = "Custom RootFS Overlay & WiFi/BT Firmware"
DESCRIPTION = "Replaces official firmware to avoid file clashes and adds custom scripts"
LICENSE = "CLOSED"

SRC_URI = " \\
    file://rootfs_overlay \\
    file://downloads/brcmfmac43455-sdio.bin \\
    file://downloads/brcmfmac43455-sdio.clm_blob \\
    file://downloads/brcmfmac43455-sdio.txt \\
    file://downloads/BCM4345C0.hcd \\
    file://downloads/isrgrootx1.pem \\
"

S = "\${WORKDIR}"

# Diese Zeilen verhindern den Fehler "But that file is already provided by package..."
RREPLACES:\${PN} = "linux-firmware-rpidistro-bcm43455"
RCONFLICTS:\${PN} = "linux-firmware-rpidistro-bcm43455"
RPROVIDES:\${PN} = "linux-firmware-rpidistro-bcm43455"

do_install() {
    # Zielverzeichnisse erstellen
    install -d \${D}\${bindir}
    install -d \${D}\${sysconfdir}/network
    install -d \${D}\${sysconfdir}/mosquitto
    install -d \${D}\${sysconfdir}/init.d
    install -d \${D}\${sysconfdir}/ssl/certs
    install -d \${D}/lib/firmware/brcm

    # Firmware installieren (mit den spezifischen RPi5 CM Namen)
    install -m 0644 \${WORKDIR}/downloads/brcmfmac43455-sdio.bin \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin
    install -m 0644 \${WORKDIR}/downloads/brcmfmac43455-sdio.clm_blob \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob
    install -m 0644 \${WORKDIR}/downloads/brcmfmac43455-sdio.txt \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt
    install -m 0644 \${WORKDIR}/downloads/BCM4345C0.hcd \${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd
    
    # SSL Zertifikat & Link
    install -m 0644 \${WORKDIR}/downloads/isrgrootx1.pem \${D}\${sysconfdir}/ssl/certs/isrgrootx1.pem
    ln -sf isrgrootx1.pem \${D}\${sysconfdir}/ssl/certs/ca-certificates.crt

    # Overlay Installation aus dem bin-Ordner
    if [ -d \${S}/rootfs_overlay/bin ]; then
        install -m 0755 \${S}/rootfs_overlay/bin/*.py \${D}\${bindir}/
    fi

    # Overlay Installation aus dem etc-Ordner (entsprechend deiner Baumstruktur)
    [ -f \${S}/rootfs_overlay/etc/network/interfaces ] && install -m 0644 \${S}/rootfs_overlay/etc/network/interfaces \${D}\${sysconfdir}/network/
    [ -f \${S}/rootfs_overlay/etc/network/wpa_supplicant.conf ] && install -m 0600 \${S}/rootfs_overlay/etc/network/wpa_supplicant.conf \${D}\${sysconfdir}/
    [ -f \${S}/rootfs_overlay/etc/mosquitto/mosquitto.conf ] && install -m 0644 \${S}/rootfs_overlay/etc/mosquitto/mosquitto.conf \${D}\${sysconfdir}/mosquitto/
    [ -f \${S}/rootfs_overlay/etc/init.d/S99wifi ] && install -m 0755 \${S}/rootfs_overlay/etc/init.d/S99wifi \${D}\${sysconfdir}/init.d/
}

FILES:\${PN} = "\${bindir}/* \${sysconfdir}/* /lib/firmware/*"
INSANE_SKIP:\${PN} = "installed-vs-shipped"
EOT

# 7. Firmware Downloads vorab ausführen (Host-Side)
RPI_WIFI="https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm"
RPI_BT="https://raw.githubusercontent.com/RPi-Distro/bluez-firmware/master/broadcom"

echo "Lade Firmware-Dateien herunter..."
wget -q -O "$DL_DIR/brcmfmac43455-sdio.bin" "$RPI_WIFI/brcmfmac43455-sdio.bin"
wget -q -O "$DL_DIR/brcmfmac43455-sdio.clm_blob" "$RPI_WIFI/brcmfmac43455-sdio.clm_blob"
wget -q -O "$DL_DIR/brcmfmac43455-sdio.txt" "$RPI_WIFI/brcmfmac43455-sdio.txt"
wget -q -O "$DL_DIR/BCM4345C0.hcd" "$RPI_BT/BCM4345C0.hcd"
wget -q -O "$DL_DIR/isrgrootx1.pem" "https://letsencrypt.org/certs/isrgrootx1.pem.txt"

# 8. Lokale Dateien (bin/ und etc/) in den Overlay-Ordner kopieren
echo "Kopiere lokale Scripte und Konfigurationen..."
[ -d "$PROJECT_ROOT/bin" ] && cp -r "$PROJECT_ROOT/bin" "$OVERLAY_DIR/"
[ -d "$PROJECT_ROOT/etc" ] && cp -r "$PROJECT_ROOT/etc" "$OVERLAY_DIR/"

# 9. Zurück in den Build-Ordner
cd "$PROJECT_ROOT/build"

# 10. Layer hinzufügen
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia
bitbake-layers add-layer ../meta-custom

# 11. local.conf schreiben
cat <<EOT > conf/local.conf
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

IMAGE_INSTALL:append = " \\
    wpa-supplicant \\
    iw \\
    wget \\
    ca-certificates \\
    python3-core \\
    python3-modules \\
    python3-paho-mqtt \\
    python3-requests \\
    mosquitto \\
    mosquitto-clients \\
    custom-scripts \\
"

# Ressourcen-Management (anpassen falls nötig)
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
INHERIT += "rm_work"
EOT

# 12. Build starten
# Wir clearen das Rezept einmal, um sicherzugehen, dass die neuen RREPLACES Regeln greifen
bitbake -c cleanall custom-scripts
echo "Starte core-image-base Build..."
bitbake core-image-base
