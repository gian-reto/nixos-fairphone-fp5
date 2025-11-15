{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./resize-rootfs.nix
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

    kernelParams = lib.mkAfter [
      # Console outputs; Order matters for BOTH kernel and initramfs!
      # - Kernel: LAST console becomes `/dev/console`.
      # - Initramfs: FIRST `console=` param sets the `$console` variable.
      #
      # List ttyGS0 first so init script outputs to USB serial that we can monitor.
      "console=ttyGS0,115200"
      # See: https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/testing/device-fairphone-fp5/deviceinfo.
      "console=ttyMSM0,115200"

      "loglevel=4"
      # Force ALL kernel log messages to console, including userspace writes to `/dev/kmsg`.
      # Without this, initramfs messages written to `/dev/kmsg` don't appear on serial console.
      "ignore_loglevel"

      # Systemd console output configuration. This makes systemd output boot messages to
      # the console so we can see stage-2 boot.
      "systemd.log_target=console"
      "systemd.log_level=info"
    ];
  };

  # Root filesystem configuration.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Console configuration for serial output.
  console = {
    earlySetup = true;
  };

  # Set getty on both serial consoles for login.
  #
  # `ttyGS0` is the USB serial.
  systemd.services."serial-getty@ttyGS0" = {
    enable = true;
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Restart = "always";
    };
  };

  # `ttyMSM0` is the hardware UART serial.
  systemd.services."serial-getty@ttyMSM0" = {
    enable = true;
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Restart = "always";
    };
  };
}
