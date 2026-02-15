#!/bin/bash

# 1. Umgebung initialisieren
# 'source' ist notwendig, um die BitBake-Umgebung in die aktuelle Shell zu laden
source poky/oe-init-build-env build

# 2. Layer hinzufügen (nur falls noch nicht vorhanden)
echo "Konfiguriere Layer..."
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia

# 3. CM5 Konfiguration, Pakete und GitHub-Optimierungen in local.conf schreiben
if ! grep -q "raspberrypi5" conf/local.conf; then
echo "Schreibe CM5, Pakete & GitHub Konfigurationen in local.conf..."
cat <<EOT >> conf/local.conf

# --- CM5 / RPI5 Basis-Setup ---
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

# --- Zusätzliche Software-Pakete ---
IMAGE_INSTALL:append = " \\
    python3-core \\
    python3-modules \\
    python3-paho-mqtt \\
    python3-requests \\
    python3-dotenv \\
    mosquitto \\
    mosquitto-clients \\
    ca-certificates \\
"

# --- GitHub Runner Optimierung (Verhindert OOM Crashes) ---
# Da GitHub Runner ca. 7GB RAM haben, begrenzen wir die Threads
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"

# --- Fehlerbehebung & Caching ---
# Verhindert Abbruch bei Prüfsummen-Änderungen der Firmware
BB_STRICT_CHECKSUM = "0"
# Stellt sicher, dass der SSTATE-Ordner für die GitHub Cache Action am richtigen Ort ist
SSTATE_DIR = "\${TOPDIR}/sstate-cache"
EOT
fi

echo "--- Setup abgeschlossen ---"
echo "Starte Build für core-image-base..."

# 4. Bootfiles bereinigen und Build starten
bitbake -c cleansstate rpi-bootfiles
bitbake core-image-base
