{
  fetchFromGitHub,
  lib,
  linuxKernel,
  runCommand,
  stdenv,
  ...
}: let
  # Note: Keep this in sync with the Makefile in the pinned
  # https://github.com/sc7280-mainline/linux source.
  kernelVersion = "7.2.9";

  # Kernel source from https://github.com/sc7280-mainline/linux.
  kernelSrc = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "linux";
    # Tag `v7.2.9-sc7280`, the release postmarketOS packages as
    # `linux-postmarketos-qcom-sc7280` 7.2.9-r3. Update the `kernelVersion`
    # above when updating this revision.
    rev = "0ccea71930dbc8e32344a41be96944db4215c3c3";
    hash = "sha256-hhrOL2GrReoIY0w392S6Cc7RAnPEE3kHUKfe8HchWso=";
  };

  # Upstream postmarketOS configuration for the SC7280 device, see:
  # https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/main/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64.
  pmosConfigFile = builtins.fetchurl {
    # Pinned to the last pmaports commit that changed the config
    # ("linux-postmarketos-qcom-sc7280: enable RAID kconfig options").
    url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/b31424eba8ce39ffa1352e7bcb406627de2ac4d0/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64";
    sha256 = "03zbrfd8vza1r11kddmfl87gfi9fdgdakn1hnzzcl97vhsahbiqr";
  };

  # Parse enabled module and built-in options in the same format as nixpkgs.
  parseConfig = content: let
    parseLine = line: let
      match = builtins.match "(CONFIG_[^=]+)=([ym])" line;
    in
      lib.optional (match != null) {
        name = builtins.elemAt match 0;
        value = builtins.elemAt match 1;
      };
  in
    builtins.listToAttrs (lib.concatMap parseLine (lib.splitString "\n" content));

  pmosConfig = parseConfig (builtins.readFile pmosConfigFile);

  # Overrides to the postmarketOS SC7280 base configuration.
  configOverrides = {
    # NixOS compatibility.
    #
    # Required by NixOS assertions.
    DMIID = "y";

    # USB serial console support.
    #
    # Enables console output through the USB serial gadget.
    U_SERIAL_CONSOLE = "y";
    # Enables the USB serial gadget driver.
    USB_G_SERIAL = "y";

    # NixOS firewall support.
    #
    # Enables packet-type matching.
    NETFILTER_XT_MATCH_PKTTYPE = "m";
    # Enables rate limiting.
    NETFILTER_XT_MATCH_LIMIT = "m";
    # Enables recent-connection tracking.
    NETFILTER_XT_MATCH_RECENT = "m";
    # Enables connection-state matching.
    NETFILTER_XT_MATCH_STATE = "m";
    # Enables firewall logging.
    NETFILTER_XT_TARGET_LOG = "m";

    # EFI boot compatibility.
    #
    # U-Boot provides the UEFI environment used by systemd-boot.
    EFI = "y";
    EFI_STUB = "y";
    EFI_ZBOOT = "y";

    # Misc. features.
    #
    # Required by Waydroid.
    ANDROID_BINDERFS = "y";
    # Enables DisplayPort Alt Mode negotiation.
    TYPEC_DP_ALTMODE = "y";
  };

  overrideLines =
    lib.mapAttrsToList (
      name: value:
        if value == "n"
        then "# CONFIG_${name} is not set"
        else "CONFIG_${name}=${value}"
    )
    configOverrides;

  # Build-time configuration consumed by the kernel build. The complete postmarketOS
  # config is preserved, and our overrides are appended before `make oldconfig`.
  configfile = runCommand "kernel-config" {} ''
    cat ${pmosConfigFile} > $out
    cat >> $out <<'EOF'
    ${lib.concatStringsSep "\n" overrideLines}
    EOF
  '';

  # Evaluation-time configuration metadata consumed by nixpkgs. This y/m/n summary
  # mirrors the build-time config without realizing and parsing `configfile`.
  mergedConfig =
    pmosConfig
    // lib.mapAttrs' (name: value: lib.nameValuePair "CONFIG_${name}" value) configOverrides;
in
  linuxKernel.manualConfig {
    inherit configfile lib;

    config = mergedConfig;
    features.efiBootStub = true;
    kernelPatches = [
      {
        name = "hci-qca-drop-unused-event";
        patch = ./patches/hci-qca-drop-unused-event.patch;
      }
      {
        name = "pinctrl-lpass-lpi-defer-on-clk-timeout";
        patch = ./patches/pinctrl-lpass-lpi-defer-on-clk-timeout.patch;
      }
      {
        # Report the FP5 sensors' native and active pixel-array geometry so
        # libcamera can derive crop and binning relationships correctly.
        name = "media-fp5-sensor-crop-selection";
        patch = ./patches/media-fp5-sensor-crop-selection.patch;
      }
      {
        # Enable IMX858 MCLK before releasing reset and wait for the sensor to
        # start, preventing I2C bus hangs after runtime power cycles.
        name = "media-imx858-power-on-ordering";
        patch = ./patches/media-imx858-power-on-ordering.patch;
      }
      {
        # Let USB-C Alt Mode switch the QMP Combo PHY to four-lane DisplayPort
        # and expose all four fixed DP lanes for the Fairphone 5.
        name = "dts-kodiak-4lane-dp-mode-switch";
        patch = ./patches/dts-kodiak-4lane-dp-mode-switch.patch;
      }
      {
        # Retry dual-display resource allocation without a DSPP when the sole
        # hardware color-processing block is unavailable.
        name = "dpu-dspp-reservation-fallback";
        patch = ./patches/dpu-dspp-reservation-fallback.patch;
      }
    ];
    modDirVersion = kernelVersion;
    src = kernelSrc;
    # Produce the compressed EFI application loaded by systemd-boot.
    target = "vmlinuz.efi";
    stdenv = stdenv.override {
      hostPlatform = stdenv.hostPlatform // {
        linux-kernel = stdenv.hostPlatform.linux-kernel // {
          target = "vmlinuz.efi";
          installTarget = "zinstall";
        };
      };
    };
    version = kernelVersion;
  }
