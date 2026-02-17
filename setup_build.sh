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

# 3. local.conf zurücksetzen und neu schreiben
LOCAL_CONF="conf/local.conf"
echo "Lösche alte $LOCAL_CONF und erstelle sie neu..."
rm -f $LOCAL_CONF

echo "Schreibe CM5 & Pakete in local.conf..."
cat <<EOT >> $LOCAL_CONF
# --- Automatisch generiertes Setup ---

# --- CM5 / RPI5 Basis-Setup ---
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

# --- Software-Pakete ---
# python3-dotenv/pydotenv vorerst entfernt wegen Layer-Inkompatibilität
IMAGE_INSTALL:append = " \\
    python3-core \\
    python3-modules \\
    python3-paho-mqtt \\
    python3-requests \\
    mosquitto \\
    mosquitto-clients \\
    ca-certificates \\
"

# --- GitHub Runner Optimierung (Vermeidung von OOM) ---
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
BB_STRICT_CHECKSUM = "0"
SSTATE_DIR = "\${TOPDIR}/sstate-cache"

# Standard Poky Einstellungen beibehalten
DISTRO ?= "poky"
PACKAGE_CLASSES ?= "package_rpm"
USER_CLASSES ?= "buildstats"
PATCHRESOLVE = "noop"
EOT

echo "--- Setup abgeschlossen (local.conf ist sauber) ---"

# 4. Build starten
bitbake -c cleansstate rpi-bootfiles
bitbake core-image-base
