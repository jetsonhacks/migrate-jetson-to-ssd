#!/bin/bash

# Function to print usage and exit
usage() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo
  echo "Script to update system configurations on the SSD for booting after cloning."
  echo
  echo "Options:"
  echo "  -d, --destination <device>  Destination disk (default: /dev/nvme0n1)"
  echo "  -h, --help                 Show this help message and exit"
  echo
  exit 1
}

# Parse command-line arguments
DESTINATION="/dev/nvme0n1"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--destination)
      DESTINATION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Define root partition
ROOT_PART="${DESTINATION}p1"

# Get all partitions on the destination disk
PARTITIONS=$(lsblk -nr -o NAME -x NAME "$DESTINATION" | sed "s|^|/dev/|")

# Search for EFI partition
EFI_PART=""
for PART in $PARTITIONS; do
  if [[ "$(blkid -o value -s PARTLABEL "$PART" 2>/dev/null)" == "esp" ]] &&
     [[ "$(blkid -o value -s TYPE "$PART" 2>/dev/null)" == "vfat" ]]; then
    EFI_PART="$PART"
    break
  fi
done

if [[ -z "$EFI_PART" ]]; then
  echo "Error: No EFI (esp) partition found on $DESTINATION with PARTLABEL=esp and TYPE=vfat." >&2
  exit 1
fi

echo "Detected EFI partition: $EFI_PART"

# Ensure partitions exist
for PART in "$ROOT_PART" "$EFI_PART"; do
  if [[ ! -b "$PART" ]]; then
    echo "Error: Partition $PART does not exist." >&2
    exit 1
  fi
done

# Prevent modifying the current root filesystem
CURRENT_ROOT=$(findmnt -o SOURCE -n /)
if [[ "$CURRENT_ROOT" == "$ROOT_PART" ]]; then
  echo "Error: Attempting to modify the current root filesystem. Run from a live environment." >&2
  exit 1
fi

# Mount the root partition
MOUNT_POINT="/mnt/ssd"
mkdir -p "$MOUNT_POINT"
mount "$ROOT_PART" "$MOUNT_POINT" || {
  echo "Error: Failed to mount $ROOT_PART." >&2
  exit 1
}

# Get UUID of the EFI partition
EFI_UUID=$(blkid -o value -s UUID "$EFI_PART") || {
  echo "Error: Failed to get UUID of $EFI_PART." >&2
  umount "$MOUNT_POINT"
  exit 1
}

echo "EFI partition UUID: $EFI_UUID"

# Update extlinux.conf
EXTLINUX_CONF="$MOUNT_POINT/boot/extlinux/extlinux.conf"
if [[ ! -f "$EXTLINUX_CONF" ]]; then
  echo "Error: $EXTLINUX_CONF not found." >&2
  umount "$MOUNT_POINT"
  exit 1
fi

cp -p "$EXTLINUX_CONF" "${EXTLINUX_CONF}.bak" || {
  echo "Error: Failed to create backup of $EXTLINUX_CONF." >&2
  umount "$MOUNT_POINT"
  exit 1
}

sed "s|root=[^ ]*|root=${ROOT_PART}|" "$EXTLINUX_CONF" > "${EXTLINUX_CONF}.tmp" && mv "${EXTLINUX_CONF}.tmp" "$EXTLINUX_CONF" || {
  echo "Error: Failed to update $EXTLINUX_CONF." >&2
  umount "$MOUNT_POINT"
  exit 1
}

echo "Updated $EXTLINUX_CONF with root=${ROOT_PART}"

# Update fstab
FSTAB="$MOUNT_POINT/etc/fstab"
if [[ ! -f "$FSTAB" ]]; then
  echo "Error: $FSTAB not found." >&2
  umount "$MOUNT_POINT"
  exit 1
fi

cp -p "$FSTAB" "${FSTAB}.bak" || {
  echo "Error: Failed to create backup of $FSTAB." >&2
  umount "$MOUNT_POINT"
  exit 1
}

sed "/\\/boot\\/efi / s|UUID=[^ ]*|UUID=${EFI_UUID}|" "$FSTAB" > "${FSTAB}.tmp" && mv "${FSTAB}.tmp" "$FSTAB" || {
  echo "Error: Failed to update $FSTAB." >&2
  umount "$MOUNT_POINT"
  exit 1
}

echo "Updated $FSTAB with EFI UUID=${EFI_UUID}"
sync
# Unmount the root partition and clean up
if mountpoint -q "$MOUNT_POINT"; then
  umount "$MOUNT_POINT"
fi
rmdir "$MOUNT_POINT"

echo "System configurations updated on the SSD."
echo "You may need to change the boot order to prioritize the SSD."
