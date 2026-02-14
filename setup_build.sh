#!/bin/bash

# 1. Source the environment
# We use '.' instead of 'source' for maximum compatibility
source poky/oe-init-build-env build

# 2. Add layers (only if they aren't already there)
echo "Configuring layers..."
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia

# 3. Append CM5 configuration and Checksum Fix to local.conf
if ! grep -q "raspberrypi5" conf/local.conf; then
echo "Appending CM5 configurations to local.conf..."
cat <<EOT >> conf/local.conf

# CM5/RPI5 Configuration
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

# Workaround for rpi-bootfiles checksum issue
BB_STRICT_CHECKSUM = "0"
EOT
fi

echo "--- Setup Complete ---"
echo "Starting the build for core-image-base..."

# 4. Clear the error state for the bootfiles and start the build
bitbake -c cleansstate rpi-bootfiles
bitbake core-image-base
