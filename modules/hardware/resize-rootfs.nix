{pkgs, ...}: {
  # Automatically resize the root filesystem to fill the entire partition on first boot.
  # This is necessary because the flashed ext4 image is sized to fit only the initial
  # rootfs contents (~9-10 GB), while the userdata partition is much larger (214 GB on
  # Fairphone 5). This service expands the filesystem to utilize the full partition.
  systemd.services.resize-rootfs = {
    description = "Resize root filesystem to fill partition";
    wantedBy = ["local-fs.target"];
    after = ["local-fs.target"];
    before = ["systemd-user-sessions.service"];

    # This is a oneshot service that should only run once.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    # Ensure we have the required tools available.
    path = with pkgs; [e2fsprogs gawk util-linux];

    script = ''
      # Marker file to track if we've already resized.
      MARKER="/var/lib/rootfs-resized"

      # If marker exists, we've already resized - exit early.
      if [ -f "$MARKER" ]; then
        echo "Root filesystem already resized, skipping..."
        exit 0
      fi

      echo "Checking root filesystem size..."

      # Get the root filesystem device.
      # We use findmnt to reliably get the actual block device (not the by-label symlink).
      ROOT_DEV=$(findmnt -n -o SOURCE /)

      if [ -z "$ROOT_DEV" ]; then
        echo "ERROR: Could not determine root device"
        exit 1
      fi

      echo "Root filesystem is on: $ROOT_DEV"

      # Get the current filesystem size.
      FS_SIZE=$(dumpe2fs -h "$ROOT_DEV" 2>/dev/null | grep -E "^Block count:" | awk '{print $3}')
      BLOCK_SIZE=$(dumpe2fs -h "$ROOT_DEV" 2>/dev/null | grep -E "^Block size:" | awk '{print $3}')

      if [ -z "$FS_SIZE" ] || [ -z "$BLOCK_SIZE" ]; then
        echo "ERROR: Could not determine filesystem size"
        exit 1
      fi

      FS_SIZE_BYTES=$((FS_SIZE * BLOCK_SIZE))
      echo "Current filesystem size: $FS_SIZE blocks × $BLOCK_SIZE bytes = $FS_SIZE_BYTES bytes"

      # Get the partition size.
      PART_SIZE=$(blockdev --getsize64 "$ROOT_DEV")
      echo "Partition size: $PART_SIZE bytes"

      # Calculate size difference (with 1% tolerance to account for rounding).
      SIZE_DIFF=$((PART_SIZE - FS_SIZE_BYTES))
      TOLERANCE=$((PART_SIZE / 100))

      if [ $SIZE_DIFF -gt $TOLERANCE ]; then
        echo "Filesystem is smaller than partition by $SIZE_DIFF bytes"
        echo "Expanding filesystem to fill partition..."

        # Run resize2fs to expand the filesystem.
        # The filesystem is mounted read-write, and resize2fs can handle online resizing.
        if resize2fs "$ROOT_DEV"; then
          echo "Successfully resized root filesystem!"

          # Create marker directory and file.
          mkdir -p "$(dirname "$MARKER")"
          touch "$MARKER"
          echo "Created marker file: $MARKER"
        else
          echo "ERROR: Failed to resize filesystem"
          exit 1
        fi
      else
        echo "Filesystem is already at maximum size, no resize needed"
        # Still create marker to prevent future checks.
        mkdir -p "$(dirname "$MARKER")"
        touch "$MARKER"
      fi

      echo "Root filesystem resize check complete!"
    '';
  };
}
