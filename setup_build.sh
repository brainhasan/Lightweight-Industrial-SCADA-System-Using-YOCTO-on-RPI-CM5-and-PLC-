#!/bin/bash

# 1. Umgebung initialisieren
source poky/oe-init-build-env build

# 2. Sauberes Setup
cd ..
echo "Bereinige alten meta-custom Layer..."
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

# 5. Das Master-Rezept mit AKTUALISIERTEN Checksummen
cat <<EOT > meta-custom/recipes-core/custom-scripts/custom-scripts.bb
SUMMARY = "Custom RootFS Overlay & WiFi Firmware für CM5"
LICENSE = "CLOSED"

SRC_URI = " \\
    file://rootfs_overlay \\
    https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.bin;name=wifi_bin \\
    https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.clm_blob;name=wifi_blob \\
    https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.txt;name=wifi_txt \\
    https://raw.githubusercontent.com/RPi-Distro/bluez-firmware/master/broadcom/BCM4345C0.hcd;name=bt_hcd \\
"

# Aktualisierte Checksummen (Stand Heute)
SRC_URI[wifi_bin.sha256sum] = "cf79e8e8727d103a94cd243f1d98770fa29f5da25df251d0d31b3696f3b4ac6a"
SRC_URI[wifi_blob.sha256sum] = "741d7e822002167d643884f3df9116e053f3e6e87a2d1e28935c1507f439c894"
SRC_URI[wifi_txt.sha256sum] = "4f28588f0e53a29821815805eb2c923366c8105f992383507d7301c3422204c4"
SRC_URI[bt_hcd.sha256sum] = "40203a3b50c9509b533a1e58284698539207a9b09a738a0889139f4034870c52"

S = "\${WORKDIR}"

do_install() {
    install -d \${D}\${bindir}
    install -d \${D}\${sysconfdir}/network
    install -d \${D}\${sysconfdir}/mosquitto
    install -d \${D}\${sysconfdir}/init.d
    install -d \${D}/lib/firmware/brcm

    # Firmware Installation
    install -m 0644 \${WORKDIR}/brcmfmac43455-sdio.bin \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin
    install -m 0644 \${WORKDIR}/brcmfmac43455-sdio.clm_blob \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob
    install -m 0644 \${WORKDIR}/brcmfmac43455-sdio.txt \${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt
    install -m 0644 \${WORKDIR}/BCM4345C0.hcd \${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd

    # rootfs_overlay
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

# 6. Dateien kopieren
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

BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
BB_STRICT_CHECKSUM = "0"
SSTATE_DIR = "\${TOPDIR}/sstate-cache"
EOT

bitbake core-image-base
