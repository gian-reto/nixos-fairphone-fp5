{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.hardware;
in {
  options.nixos-fairphone-fp5.hardware = {
    serial = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable USB serial console (ttyGS0) for debugging.

          When enabled, allows access to the device via USB serial connection.
          This is useful for debugging but not needed for normal operation.
        '';
      };

      verbose = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable verbose kernel logging for debugging.

          When enabled, sets kernel to output all log messages (ignore_loglevel)
          and configures systemd to use debug log level. This produces significantly
          more logging output, useful for troubleshooting boot issues.
        '';
      };
    };
  };

  imports = [
    ./resize-rootfs.nix
  ];

  config = {
    # Apply the Fairphone FP5 overlay.
    nixpkgs.overlays = [
      (import ../../overlays/fairphone-fp5)
    ];

    # Target architecture for Fairphone 5.
    nixpkgs.hostPlatform = "aarch64-linux";

    hardware = {
      # Device tree configuration. Note: The DTB will be appended to the kernel `Image.gz`
      # during boot image creation.
      deviceTree = {
        enable = true;

        name = "qcom/qcm6490-fairphone-fp5.dtb";
      };

      # Enable all firmware regardless of license.
      enableAllFirmware = true;
      # Use our custom Fairphone 5 firmware package (see `flake.nix`).
      firmware = with pkgs; [
        firmware-fairphone-fp5
      ];
      # Qualcomm firmware must be uncompressed.
      firmwareCompression = "none";
    };

    boot = {
      # Use our custom `sc7280-mainline` kernel (see `flake.nix`).
      kernelPackages = pkgs.linuxPackagesFor pkgs.kernel-fairphone-fp5;

      initrd = {
        enable = true;

        # Initramfs compression. NixOS defaults to `zstd`, but we use `gzip` because the
        # PostmarketOS kernel doesn't have `CONFIG_RD_ZSTD` enabled and only supports
        # `CONFIG_RD_GZIP=y` for ramdisk decompression.
        compressor = "gzip";

        # Kernel modules required in initramfs for device boot.
        # See: https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/testing/device-fairphone-fp5/modules-initfs.
        availableKernelModules = [
          # Device-specific drivers.
          "fsa4480" # USB-C audio switch.
          "goodix_berlin_core" # Touchscreen core driver.
          "goodix_berlin_spi" # Touchscreen SPI interface.
          "msm"
          "panel-raydium-rm692e5" # Display panel driver.
          "ptn36502" # USB-C redriver.
          "spi-geni-qcom" # Qualcomm SPI controller.
        ];

        # Disable default modules (like `ahci`) that don't exist in our custom kernel.
        includeDefaultModules = false;

        # Use traditional stage-1 init.
        systemd.enable = false;
      };

      # Disable GRUB bootloader, as we use Android boot image format.
      loader.grub.enable = false;

      # On first boot, perform one-time initialization tasks. This is similar to how
      # `sd-image.nix` handles first-boot setup for SD card images, see:
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/sd-card/sd-image.nix.
      postBootCommands = ''
        # On first boot, register the contents of the initial Nix store.
        if [ -f /nix-path-registration ]; then
          set -euo pipefail
          set -x

          # Register the contents of the initial Nix store.
          # The /nix-path-registration file is created by make-ext4-fs.nix and contains
          # the database entries for all store paths included in the rootfs image.
          # Without this step, Nix doesn't know about pre-installed paths and tries to
          # build them, which fails on the device.
          ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

          # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
          touch /etc/NIXOS
          ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

          # Fix ownership of per-user profile directories.
          # During image build, these directories are created by root, but users need
          # to own their own profile directories for home-manager to manage them.
          if [ -d /nix/var/nix/profiles/per-user ]; then
            for profile_dir in /nix/var/nix/profiles/per-user/*; do
              if [ -d "$profile_dir" ]; then
                username=$(basename "$profile_dir")
                echo "Fixing ownership of $profile_dir for user $username"
                chown -R "''${username}:users" "$profile_dir"
              fi
            done
          fi

          # Prevents this from running on later boots.
          rm -f /nix-path-registration
        fi
      '';

      kernelParams =
        lib.mkAfter
        (
          [
            "loglevel=4"
          ]
          ++ lib.optionals cfg.serial.enable [
            # Systemd console output configuration. This makes systemd output boot messages to
            # the console so we can see stage-2 boot.
            "systemd.log_target=console"

            # Console outputs; Order matters for BOTH kernel and initramfs!
            # - Kernel: LAST console becomes `/dev/console`.
            # - Initramfs: FIRST `console=` param sets the `$console` variable.
            #
            # Add USB serial console (ttyGS0) if enabled. List it before ttyMSM0 so init script
            # outputs to USB serial that we can monitor.
            "console=ttyGS0,115200"
          ]
          ++ [
            # See: https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/testing/device-fairphone-fp5/deviceinfo.
            "console=ttyMSM0,115200"
          ]
          # Add verbose logging options if enabled.
          ++ lib.optionals cfg.serial.verbose [
            # Force ALL kernel log messages to console, including userspace writes to `/dev/kmsg`.
            # Without this, initramfs messages written to `/dev/kmsg` don't appear on serial console.
            "ignore_loglevel"
            # Enable debug-level systemd logging.
            "systemd.log_level=debug"
          ]
        );
    };

    # Root filesystem configuration.
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    # Console configuration for serial output.
    console.earlySetup = true;

    # Set getty on both serial consoles for login.
    #
    # `ttyGS0` is the USB serial (only enabled if serial.enable is true).
    systemd.services."serial-getty@ttyGS0" = lib.mkIf cfg.serial.enable {
      enable = true;
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Restart = "always";
      };
    };

    # `ttyMSM0` is the hardware UART serial (always enabled for framebuffer console).
    systemd.services."serial-getty@ttyMSM0" = {
      enable = true;
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Restart = "always";
      };
    };
  };
}
