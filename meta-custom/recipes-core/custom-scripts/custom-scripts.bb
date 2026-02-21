SUMMARY = "Custom RootFS Overlay & WiFi Firmware für CM5"
LICENSE = "CLOSED"

# Wir fügen die Firmware-URLs direkt als Source hinzu
SRC_URI = " \
    file://rootfs_overlay \
    https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.bin;name=wifi_bin \
    https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.clm_blob;name=wifi_blob \
    https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/master/brcm/brcmfmac43455-sdio.txt;name=wifi_txt \
    https://raw.githubusercontent.com/RPi-Distro/bluez-firmware/master/broadcom/BCM4345C0.hcd;name=bt_hcd \
"

# Checksummen (notwendig für externe Downloads in Yocto)
SRC_URI[wifi_bin.sha256sum] = "76707835f992323c94060241065961d56350f96d91781216a30113c24cf1b988"
SRC_URI[wifi_blob.sha256sum] = "741d7e822002167d643884f3df9116e053f3e6e87a2d1e28935c1507f439c894"
SRC_URI[wifi_txt.sha256sum] = "4f28588f0e53a29821815805eb2c923366c8105f992383507d7301c3422204c4"
SRC_URI[bt_hcd.sha256sum] = "40203a3b50c9509b533a1e58284698539207a9b09a738a0889139f4034870c52"

S = "${WORKDIR}"

do_install() {
    # 1. Verzeichnisse erstellen
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/network
    install -d ${D}${sysconfdir}/mosquitto
    install -d ${D}${sysconfdir}/init.d
    install -d ${D}/lib/firmware/brcm

    # 2. Firmware installieren (Umbenennung für CM5 Support)
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.bin ${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.clm_blob ${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.txt ${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt
    install -m 0644 ${WORKDIR}/BCM4345C0.hcd ${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd

    # 3. rootfs_overlay Inhalte kopieren
    if [ -d ${WORKDIR}/rootfs_overlay/bin ]; then
        cp -rp ${WORKDIR}/rootfs_overlay/bin/. ${D}${bindir}/
        chmod 0755 ${D}${bindir}/*.py 2>/dev/null || true
    fi

    [ -f ${WORKDIR}/rootfs_overlay/etc/network/interfaces ] && install -m 0644 ${WORKDIR}/rootfs_overlay/etc/network/interfaces ${D}${sysconfdir}/network/
    [ -f ${WORKDIR}/rootfs_overlay/etc/wpa_supplicant.conf ] && install -m 0600 ${WORKDIR}/rootfs_overlay/etc/wpa_supplicant.conf ${D}${sysconfdir}/
    [ -f ${WORKDIR}/rootfs_overlay/etc/mosquitto/mosquitto.conf ] && install -m 0644 ${WORKDIR}/rootfs_overlay/etc/mosquitto/mosquitto.conf ${D}${sysconfdir}/mosquitto/
    
    if [ -f ${WORKDIR}/rootfs_overlay/etc/init.d/S99wifi ]; then
        install -m 0755 ${WORKDIR}/rootfs_overlay/etc/init.d/S99wifi ${D}${sysconfdir}/init.d/
    fi
}

FILES:${PN} += "/lib/firmware/brcm/* ${bindir}/* ${sysconfdir}/*"
