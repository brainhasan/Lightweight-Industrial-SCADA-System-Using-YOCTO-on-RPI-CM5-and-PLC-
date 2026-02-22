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

# 5. Das Rezept - Deine Buildroot Logik übertragen auf Yocto
cat <<EOT > meta-custom/recipes-core/custom-scripts/custom-scripts.bb
SUMMARY = "Custom RootFS Overlay & WiFi/BT Firmware via wget"
LICENSE = "CLOSED"

SRC_URI = "file://rootfs_overlay"

# Netzwerkzugriff für wget innerhalb von do_install erlauben
do_install[network] = "1"

S = "\${WORKDIR}"

do_install() {
    # Verzeichnisse erstellen (entspricht TARGET_DIR Pfaden)
    install -d \${D}\${bindir}
    install -d \${D}\${sysconfdir}/network
    install -d \${D}\${sysconfdir}/mosquitto
    install -d \${D}\${sysconfdir}/init.d
    install -d \${D}/lib/firmware/brcm
    install -d \${D}\${sysconfdir}/ssl/certs

    # ========================================================================
    # TEIL 2: Firmware Download (WiFi/BT für CM5) - DEINE LOGIK
    # ========================================================================
    RPI_WIFI_URL="https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm"
    RPI_BT_URL="https://raw.githubusercontent.com/RPi-Distro/bluez-firmware/master/broadcom"
    REG_DB_URL="https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain"

    # WiFi
    wget -O "\${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin" "\${RPI_WIFI_URL}/brcmfmac43455-sdio.bin"
    wget -O "\${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob" "\${RPI_WIFI_URL}/brcmfmac43455-sdio.clm_blob"
    wget -O "\${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt" "\${RPI_WIFI_URL}/brcmfmac43455-sdio.txt"

    # Bluetooth
    wget -O "\${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd" "\${RPI_BT_URL}/BCM4345C0.hcd"

    # Regulatory DB
    wget -O "\${D}/lib/firmware/regulatory.db" "\${REG_DB_URL}/regulatory.db"
    wget -O "\${D}/lib/firmware/regulatory.db.p7s" "\${REG_DB_URL}/regulatory.db.p7s"

    # ========================================================================
    # TEIL 3: TLS/SSL Zertifikate für HiveMQ Cloud - DEINE LOGIK
    # ========================================================================
    HIVEMQ_CA_URL="https://letsencrypt.org/certs/isrgrootx1.pem.txt"
    wget -O "\${D}\${sysconfdir}/ssl/certs/isrgrootx1.pem" "\$HIVEMQ_CA_URL"
    ln -sf isrgrootx1.pem "\${D}\${sysconfdir}/ssl/certs/ca-certificates.crt"

    # ========================================================================
    # rootfs_overlay (Skripte, Netzwerk, Mosquitto)
    # ========================================================================
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

FILES:\${PN} += "/lib/firmware/brcm/* /lib/firmware/regulatory.* \${bindir}/* \${sysconfdir}/*"
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

# Basispakete
IMAGE_INSTALL:append = " wpa-supplicant iw wget ca-certificates"
IMAGE_INSTALL:append = " \\
    python3-core \\
    python3-modules \\
    python3-paho-mqtt \\
    python3-requests \\
    mosquitto \\
    mosquitto-clients \\
    custom-scripts \\
"

# Netzwerk für den Build erlauben
BB_NO_NETWORK = "0"
EOT

bitbake core-image-base
