SUMMARY = "SCADA System Configuration and Scripts"
DESCRIPTION = "Kopiert Python-Scripte und Netzwerkeinstellungen vom Buildroot-Overlay"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Alle Dateien auflisten, die in files/ liegen
SRC_URI = " \
    file://bin/all_Bridges.py \
    file://bin/plc_test.py \
    file://bin/test_broker.py \
    file://etc/mosquitto/mosquitto.conf \
    file://etc/network/interfaces \
    file://etc/wpa_supplicant.conf \
"

S = "${WORKDIR}"

do_install() {
    # 1. Python Scripte nach /usr/bin installieren
    install -d ${D}${bindir}
    install -m 0755 ${S}/bin/all_Bridges.py ${D}${bindir}/
    install -m 0755 ${S}/bin/plc_test.py ${D}${bindir}/
    install -m 0755 ${S}/bin/test_broker.py ${D}${bindir}/

    # 2. Mosquitto Config
    install -d ${D}${sysconfdir}/mosquitto
    install -m 0644 ${S}/etc/mosquitto/mosquitto.conf ${D}${sysconfdir}/mosquitto/

    # 3. Netzwerk (Interfaces & WPA Supplicant)
    install -d ${D}${sysconfdir}/network
    install -m 0644 ${S}/etc/network/interfaces ${D}${sysconfdir}/network/
    install -m 0600 ${S}/etc/wpa_supplicant.conf ${D}${sysconfdir}/wpa_supplicant.conf
}

# Wichtig: Damit die Dateien im Image landen
FILES:${PN} += " \
    ${bindir}/* \
    ${sysconfdir}/mosquitto/mosquitto.conf \
    ${sysconfdir}/network/interfaces \
    ${sysconfdir}/wpa_supplicant.conf \
"
