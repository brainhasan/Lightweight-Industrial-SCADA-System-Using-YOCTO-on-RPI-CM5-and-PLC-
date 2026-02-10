#!/bin/bash

# 1. Source the environment
source poky/oe-init-build-env build

# 2. Add layers (only if they aren't already there)
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-multimedia

# 3. Append CM5 configuration to local.conf automatically
# We use 'grep' to check if we already added it so we don't double-append
if ! grep -q "raspberrypi5" conf/local.conf; then
cat <<EOT >> conf/local.conf

# CM5/RPI5 Configuration
MACHINE = "raspberrypi5"
ENABLE_UART = "1"
VC4GRAPHICS = "1"
IMAGE_FSTYPES = "wic.bz2 wic.bmap"
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"
EOT
fi

echo "--- Setup Complete ---"
echo "To start building, run: bitbake core-image-base"
