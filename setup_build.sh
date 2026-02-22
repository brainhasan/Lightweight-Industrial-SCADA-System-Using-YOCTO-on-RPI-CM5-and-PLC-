#!/bin/bash

# 1. Umgebung initialisieren
source poky/oe-init-build-env build

# 2. RADIKALE REINIGUNG (Um "Out of Resource" zu vermeiden)
# Wir gehen in den Build-Ordner und löschen die Altlasten
echo "Lösche alte Build-Daten (tmp und sstate)..."
rm -rf tmp
# Optional: sstate-cache löschen, wenn der Fehler hartnäckig bleibt
# rm -rf sstate-cache 

# 3. Layer Setup (Zurück zum Root)
cd ..
rm -rf meta-custom
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

# 5. Das Rezept mit sauberem Packaging
cat <<EOT > meta-custom/recipes-core/custom-scripts/custom-scripts.bb
SUMMARY = "Custom RootFS Overlay & WiFi/BT Firmware"
LICENSE = "CLOSED"

SRC_URI = "file://rootfs_overlay"
do_install[network] = "1"

S = "\${WORKDIR}"

do_install() {
    install -d \${D}\${bindir}
    install -d \${D}\${sysconfdir}/network
    install -d \${D}\${sysconfdir}/mosquitto
    install -d \${D}\${sysconfdir}/init.d
    install -d \${D}/lib/firmware/brcm
    install -d \${D}\${sysconfdir}/ssl/certs

    # Firmware & SSL Downloads
    RPI_WIFI_URL="https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm"
    RPI_BT_URL="https://raw.githubusercontent.com/RPi-Distro/bluez-firmware/master/broadcom"
    REG_DB_URL="https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain"
    HIVEMQ_CA_URL="https://letsencrypt.org/certs/isrgrootx1.pem.txt"

    wget -q -O "\${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin" "\${RPI_WIFI_URL}/brcmfmac43455-sdio.bin"
    wget -q -O "\${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob" "\${RPI_WIFI_URL}/brcmfmac43455-sdio.clm_blob"
    wget -q -O "\${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt" "\${RPI_WIFI_URL}/brcmfmac43455-sdio.txt"
    wget -q -O "\${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd" "\${RPI_BT_URL}/BCM4345C0.hcd"
    wget -q -O "\${D}/lib/firmware/regulatory.db" "\${REG_DB_URL}/regulatory.db"
    wget -q -O "\${D}/lib/firmware/regulatory.db.p7s" "\${REG_DB_URL}/regulatory.db.p7s"
    wget -q -O "\${D}\${sysconfdir}/ssl/certs/isrgrootx1.pem" "\$HIVEMQ_CA_URL"
    ln -sf isrgrootx1.pem "\${D}\${sysconfdir}/ssl/certs/ca-certificates.crt"

    # Overlay
    if [ -d \${S}/rootfs_overlay/bin ]; then
        cp -rp \${S}/rootfs_overlay/bin/. \${D}\${bindir}/
        chmod 0755 \${D}\${bindir}/*.py 2>/dev/null || true
    fi
    [ -f \${S}/rootfs_overlay/etc/network/interfaces ] && install -m 0644 \${S}/rootfs_overlay/etc/network/interfaces \${D}\${sysconfdir}/network/
    [ -f \${S}/rootfs_overlay/etc/wpa_supplicant.conf ] && install -m 0600 \${S}/rootfs_overlay/etc/wpa_supplicant.conf \${D}\${sysconfdir}/
    [ -f \${S}/etc/mosquitto/mosquitto.conf ] && install -m 0644 \${S}/etc/mosquitto/mosquitto.conf \${D}\${sysconfdir}/mosquitto/
    [ -f \${S}/rootfs_overlay/etc/init.d/S99wifi ] && install -m 0755 \${S}/rootfs_overlay/etc/init.d/S99wifi \${D}\${sysconfdir}/init.d/
}

FILES:\${PN} = "\${bindir}/* \${sysconfdir}/* /lib/firmware/*"
INSANE_SKIP:\${PN} = "installed-vs-shipped"
EOT

# 6. Overlay kopieren
OVERLAY_SRC="../external/board/cm5io/rootfs_overlay"
[ -d "$OVERLAY_SRC" ] && cp -r $OVERLAY_SRC/* meta-custom/recipes-core/custom-scripts/files/rootfs_overlay/

cd build

# 7. Layer hinzufügen & local.conf schreiben
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia
bitbake-layers add-layer ../meta-custom

LOCAL_CONF="conf/local.conf"
rm -f $LOCAL_CONF
cat <<EOT >> $LOCAL_CONF
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"
IMAGE_INSTALL:append = " wpa-supplicant iw wget ca-certificates python3-core python3-modules python3-paho-mqtt python3-requests mosquitto mosquitto-clients custom-scripts"

# RESSOURCEN-SCHUTZ
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
BB_NO_NETWORK = "0"
INHERIT += "rm_work"
EOT

# 8. Neustart des gesamten Builds
echo "Starte frischen Build..."
bitbake core-image-base
