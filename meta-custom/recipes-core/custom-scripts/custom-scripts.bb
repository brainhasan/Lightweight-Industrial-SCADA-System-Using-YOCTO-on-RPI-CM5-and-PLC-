SUMMARY = "Installiert eigene Scripte aus dem Repository"
LICENSE = "CLOSED"

SRC_URI = "file://scripts-dir"

S = "${WORKDIR}/scripts-dir"

do_install() {
    install -d ${D}${bindir}
    if [ -n "$(ls -A ${S} 2>/dev/null)" ]; then
        for f in ${S}/*; do
            if [ -f "$f" ]; then
                install -m 0755 "$f" ${D}${bindir}/
            fi
        done
    fi
}

FILES:${PN} += "${bindir}/*"
