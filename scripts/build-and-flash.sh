#!/usr/bin/env -S nix develop --command nix shell nixpkgs#gum --command bash
# shellcheck shell=bash
set -euo pipefail
IFS=$'\n\t'

# Get list of fastboot devices.
DEVICE_LIST=$(fastboot devices 2>/dev/null | awk '{print $1}')
if [ -z "$DEVICE_LIST" ]; then
  gum log --structured --level error "No fastboot devices detected. Please ensure your device is in fastboot mode and connected via USB."
  exit 1
fi

# Select device.
DEVICE_OPTIONS=$(echo "Not listed"; echo "$DEVICE_LIST")
DEVICE_SERIAL=$(echo "$DEVICE_OPTIONS" | gum choose --header "Select a device to flash:")
if [ "$DEVICE_SERIAL" = "Not listed" ]; then
  gum log --structured --level error "Device not listed. Please ensure your device is properly connected and in fastboot mode."
  exit 1
fi

# Select configuration.
CONFIG=$(echo "minimal" | gum choose --header "Select a configuration:")

# Build boot image.
gum log --structured --level info "Building boot image for configuration: $CONFIG."
nix build ".#boot-image-$CONFIG"
gum log --structured --level info "Boot image built successfully."

# Flash boot image.
gum log --structured --level info "Flashing boot image to device: $DEVICE_SERIAL."
fastboot -s "$DEVICE_SERIAL" flash boot result
gum log --structured --level info "Boot image flashed successfully."

# Build rootfs image.
gum log --structured --level info "Building rootfs image for configuration: $CONFIG."
nix build ".#rootfs-image-$CONFIG"
gum log --structured --level info "Rootfs image built successfully."

# Flash rootfs image.
gum log --structured --level info "Flashing rootfs image to device: $DEVICE_SERIAL."
fastboot -s "$DEVICE_SERIAL" flash userdata result
gum log --structured --level info "Rootfs image flashed successfully."

# Ask for confirmation.
PROCEED=$(gum choose "Yes" "No" --header "Reboot now?")
if [ "$PROCEED" = "No" ]; then
  gum log --structured --level info "Successfully flashed boot and rootfs images to device: $DEVICE_SERIAL. Please reboot the device manually."
  exit 0
fi

# Reboot device.
gum spin --spinner dot --title "Rebooting device..." -- fastboot -s "$DEVICE_SERIAL" reboot
gum log --structured --level info "Reboot command sent."