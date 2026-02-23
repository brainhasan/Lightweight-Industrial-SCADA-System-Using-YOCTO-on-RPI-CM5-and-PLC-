SUMMARY = "Custom RootFS Overlay & WiFi/BT Firmware"
DESCRIPTION = "Replaces official firmware to avoid file clashes and adds custom scripts"
LICENSE = "CLOSED"

SRC_URI = " \
    file://rootfs_overlay \
    file://downloads/brcmfmac43455-sdio.bin \
    file://downloads/brcmfmac43455-sdio.clm_blob \
    file://downloads/brcmfmac43455-sdio.txt \
    file://downloads/BCM4345C0.hcd \
    file://downloads/isrgrootx1.pem \
"

S = "${WORKDIR}"

# Diese Zeilen verhindern den Fehler "But that file is already provided by package..."
RREPLACES:${PN} = "linux-firmware-rpidistro-bcm43455"
RCONFLICTS:${PN} = "linux-firmware-rpidistro-bcm43455"
RPROVIDES:${PN} = "linux-firmware-rpidistro-bcm43455"

do_install() {
    # Zielverzeichnisse erstellen
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/network
    install -d ${D}${sysconfdir}/mosquitto
    install -d ${D}${sysconfdir}/init.d
    install -d ${D}${sysconfdir}/ssl/certs
    install -d ${D}/lib/firmware/brcm

    # Firmware installieren (mit den spezifischen RPi5 CM Namen)
    install -m 0644 ${WORKDIR}/downloads/brcmfmac43455-sdio.bin ${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin
    install -m 0644 ${WORKDIR}/downloads/brcmfmac43455-sdio.clm_blob ${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob
    install -m 0644 ${WORKDIR}/downloads/brcmfmac43455-sdio.txt ${D}/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt
    install -m 0644 ${WORKDIR}/downloads/BCM4345C0.hcd ${D}/lib/firmware/brcm/BCM4345C0.raspberrypi,5-compute-module.hcd
    
    # SSL Zertifikat & Link
    install -m 0644 ${WORKDIR}/downloads/isrgrootx1.pem ${D}${sysconfdir}/ssl/certs/isrgrootx1.pem
    ln -sf isrgrootx1.pem ${D}${sysconfdir}/ssl/certs/ca-certificates.crt

    # Overlay Installation aus dem bin-Ordner
    if [ -d ${S}/rootfs_overlay/bin ]; then
        install -m 0755 ${S}/rootfs_overlay/bin/*.py ${D}${bindir}/
    fi

    # Overlay Installation aus dem etc-Ordner (entsprechend deiner Baumstruktur)
    [ -f ${S}/rootfs_overlay/etc/network/interfaces ] && install -m 0644 ${S}/rootfs_overlay/etc/network/interfaces ${D}${sysconfdir}/network/
    [ -f ${S}/rootfs_overlay/etc/network/wpa_supplicant.conf ] && install -m 0600 ${S}/rootfs_overlay/etc/network/wpa_supplicant.conf ${D}${sysconfdir}/
    [ -f ${S}/rootfs_overlay/etc/mosquitto/mosquitto.conf ] && install -m 0644 ${S}/rootfs_overlay/etc/mosquitto/mosquitto.conf ${D}${sysconfdir}/mosquitto/
    [ -f ${S}/rootfs_overlay/etc/init.d/S99wifi ] && install -m 0755 ${S}/rootfs_overlay/etc/init.d/S99wifi ${D}${sysconfdir}/init.d/
}

FILES:${PN} = "${bindir}/* ${sysconfdir}/* /lib/firmware/*"
INSANE_SKIP:${PN} = "installed-vs-shipped"
