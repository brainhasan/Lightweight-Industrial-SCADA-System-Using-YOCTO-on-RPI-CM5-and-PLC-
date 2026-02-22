#!/bin/bash

# 1. Umgebung initialisieren
source poky/oe-init-build-env build

# 2. Sauberes Setup
cd ..
rm -rf meta-custom

# 3. Layer Struktur erstellen
mkdir -p meta-custom/conf
mkdir -p meta-custom/recipes-core/custom-scripts/files/rootfs_overlay

# 4. Layer-Konfiguration
cat <<EOT > meta-custom/conf/layer.conf
BBPATH .= ":\${LAYERDIR}"
BBFILES += "\${LAYERDIR}/recipes-core/*/*.bb \${LAYERDIR}/recipes-core/*/*.bbappend"
BBFILE_COLLECTIONS += "custom"
BBFILE_PATTERN_custom = "^\${LAYERDIR}/"
BBFILE_PRIORITY_custom = "6"
LAYERSERIES_COMPAT_custom = "scarthgap kirkstone mickledore"
EOT

# 5. Das Rezept - Nutzt GIT statt Einzel-Downloads (Keine Checksummen nötig!)
cat <<EOT > meta-custom/recipes-core/custom-scripts/custom-scripts.bb
SUMMARY = "Custom RootFS Overlay & WiFi Firmware via Git"
LICENSE = "CLOSED"

# Wir holen das gesamte Firmware-Repo vom Master/Main. 
# 'destsuffix' legt es in einen Unterordner, damit es sauber bleibt.
SRC_URI = " \\
    file://rootfs_overlay \\
    git://github.com/RPi-Distro/firmware-nonfree.git;protocol=https;branch=master;destsuffix=firmware-repo \\
    git://github.com/RPi-Distro/bluez-firmware.git;protocol=https;branch=master;destsuffix=bluez-repo \\
"

# SRCREV definiert die Version. \${AUTOREV} holt IMMER das Neueste vom Main/Master.
SRCREV = "\${AUTOREV}"

S = "\${WORKDIR}"

do_install() {
    install -d \${D}\${bindir}
    install -d \${D}\${sysconfdir}/network
    install -d \${D}\${sysconfdir}/mosquitto
    install -d \${D}\${sysconfdir}/init.d
    install -d \${D}/lib/firmware/brcm

    # 1. Firmware kopieren (Aus den Git-Ordnern)
    # Entspricht deinem wget-Ansatz, aber Yocto-konform via Git-Clone
    cp \${WORKDIR}/firmware-repo/brcm/brcmfmac43455-sdio.bin \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin
    cp \${WORKDIR}/firmware-repo/brcm/brcmfmac43455-sdio.clm_blob \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob
    cp \${WORKDIR}/firmware-repo/brcm/brcmfmac43455-sdio.txt \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt
    cp \${WORKDIR}/bluez-repo/broadcom/BCM4345C0.hcd \${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd

    # 2. rootfs_overlay
    if [ -d \${WORKDIR}/rootfs_overlay/bin ]; then
        cp -rp \${WORKDIR}/rootfs_overlay/bin/. \${D}\${bindir}/
        chmod 0755 \${D}\${bindir}/*.py 2>/dev/null || true
    fi

    [ -f \${WORKDIR}/rootfs_overlay/etc/network/interfaces ] && install -m 0644 \${WORKDIR}/rootfs_overlay/etc/network/interfaces \${D}\${sysconfdir}/network/
    [ -f \${WORKDIR}/rootfs_overlay/etc/wpa_supplicant.conf ] && install -m 0600 \${WORKDIR}/rootfs_overlay/etc/wpa_supplicant.conf \${D}\${sysconfdir}/
    [ -f \${WORKDIR}/rootfs_overlay/etc/mosquitto/mosquitto.conf ] && install -m 0644 \${WORKDIR}/rootfs_overlay/etc/mosquitto/mosquitto.conf \${D}\${sysconfdir}/mosquitto/
    
    if [ -f \${WORKDIR}/rootfs_overlay/etc/init.d/S99wifi ]; then
        install -m 0755 \${WORKDIR}/rootfs_overlay/etc/init.d/S99wifi \${D}\${sysconfdir}/init.d/
    fi
}

FILES:\${PN} += "/lib/firmware/brcm/* \${bindir}/* \${sysconfdir}/*"
EOT

# 6. Lokale Dateien kopieren
OVERLAY_SRC="../external/board/cm5io/rootfs_overlay"
if [ -d "$OVERLAY_SRC" ]; then
    cp -r $OVERLAY_SRC/* meta-custom/recipes-core/custom-scripts/files/rootfs_overlay/
fi

cd build

# 7. Layer hinzufügen
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia
bitbake-layers add-layer ../meta-custom

# 8. local.conf
LOCAL_CONF="conf/local.conf"
rm -f $LOCAL_CONF

cat <<EOT >> $LOCAL_CONF
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

IMAGE_INSTALL:append = " wpa-supplicant iw"
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

# Erlaubt Netzwerkzugriff während des Builds für den Git-Clone
BB_NO_NETWORK = "0"
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
EOT

bitbake core-image-base
