#!/bin/bash

# 1. Umgebung initialisieren
source poky/oe-init-build-env build

# 2. Layer hinzufügen
echo "Konfiguriere Layer..."
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia

# 3. Konfiguration schreiben
if ! grep -q "raspberrypi5" conf/local.conf; then
echo "Schreibe CM5 & Pakete in local.conf..."
cat <<EOT >> conf/local.conf

# --- CM5 / RPI5 Basis-Setup ---
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

# --- Software-Pakete ---
# Hinweis: Falls python3-pydotenv wieder fehlschlägt, ersetze es durch python3-dotenv
IMAGE_INSTALL:append = " \\
    python3-core \\
    python3-modules \\
    python3-paho-mqtt \\
    python3-requests \\
    python3-pydotenv \\
    mosquitto \\
    mosquitto-clients \\
    ca-certificates \\
"

# --- GitHub Runner Optimierung ---
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
BB_STRICT_CHECKSUM = "0"
SSTATE_DIR = "\${TOPDIR}/sstate-cache"
EOT
fi

echo "--- Setup abgeschlossen ---"
bitbake -c cleansstate rpi-bootfiles
bitbake core-image-base
