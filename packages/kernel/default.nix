{
  fetchFromGitHub,
  lib,
  linuxKernel,
  runCommand,
  ...
}: let
  # Note: Keep this in sync with the Makefile in the pinned
  # https://github.com/sc7280-mainline/linux source.
  kernelVersion = "7.1.2";

  # Kernel source from https://github.com/sc7280-mainline/linux.
  kernelSrc = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "linux";
    # Note: Update the `kernelVersion` above when updating this revision.
    rev = "17425f528fe51fef6e86847e92baffab3b78623e";
    hash = "sha256-Q4mFSrRUS1+RIoPpdTxHr1lg5Ba2H9EPGJB20yOnKT0=";
  };

  # Upstream postmarketOS configuration for the SC7280 device, see:
  # https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/main/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64.
  pmosConfigFile = builtins.fetchurl {
    url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/c9dbdc23ae775aa5cea8b857c123f1696c04528f/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64";
    sha256 = "1vjffmn4wx6b6yxp7cn80qpzm744n8h5wci5xwxrpf5f17rq9w87";
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

    # Android boot-image compatibility.
    #
    # Keep the validated non-EFI `Image.gz` boot flow used by the stock bootloader.
    # With `EFI_ZBOOT` enabled, the kernel's `zinstall` target would install
    # `vmlinuz.efi` instead.
    EFI = "n";
    EFI_STUB = "n";
    EFI_ZBOOT = "n";

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
    kernelPatches = [
      {
        name = "hci-qca-drop-unused-event";
        patch = ./patches/hci-qca-drop-unused-event.patch;
      }
      {
        name = "pinctrl-lpass-lpi-defer-on-clk-timeout";
        patch = ./patches/pinctrl-lpass-lpi-defer-on-clk-timeout.patch;
      }
    ];
    modDirVersion = kernelVersion;
    src = kernelSrc;
    # Produce compressed kernel image target expected by the bootloader.
    target = "Image.gz";
    version = kernelVersion;
  }
