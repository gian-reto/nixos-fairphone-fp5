{
  fetchFromGitHub,
  fetchFromGitLab,
  gzip,
  lib,
  linuxKernel,
  stdenv,
  ...
}:
let
  # Kernel source from `sc7280-mainline` repository.
  kernelSrc = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "linux";
    rev = "v7.0.8-sc7280";
    hash = "sha256-dU+UeCr8aVIg226ZnqryPlLuOPsKkKgR/KN/LkvHDGo=";
  };

  # Source of postmarketOS `pmaports` repository.
  pmaportsSrc = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "pmaports";
    rev = "6ff32835f458c490e008373eeaac3d2a5f82f311";
    hash = "sha256-1vrNlbwFbaJmHTAmu/vW0tIcmRYHpRx/lWHvqvhY/sk=";
  };

  # Use the kernel configuration from PostmarketOS for the `sc7280` chipset as the base.
  #
  # However, we need to override some options that are disabled in PostmarketOS config to
  # make it compatible with NixOS and enable some useful stuff:
  # - CONFIG_DMIID: NixOS asserts that this is enabled for some reason...
  # - CONFIG_U_SERIAL_CONSOLE: Enables USB serial gadget console output for debugging.
  # - CONFIG_USB_G_SERIAL: Classic USB serial gadget driver.
  # - CONFIG_ANDROID_BINDERFS: Required for Waydroid (Android container support).
  #
  # Additional netfilter/iptables extensions required by NixOS firewall:
  # - CONFIG_NETFILTER_XT_MATCH_PKTTYPE: Packet type matching.
  # - CONFIG_NETFILTER_XT_MATCH_LIMIT: Rate limiting for firewall rules.
  # - CONFIG_NETFILTER_XT_MATCH_RECENT: Recent connections tracking.
  # - CONFIG_NETFILTER_XT_MATCH_STATE: Connection state matching.
  # - CONFIG_NETFILTER_XT_TARGET_LOG: Logging target for firewall rules.
  #
  # DisplayPort output over USB-C:
  # - CONFIG_TYPEC_DP_ALTMODE: Required for DP Alt Mode over USB-C to work.
  # - CONFIG_TYPEC_UCSI: Unchanged, as upstream already uses `=y`.
  configfile = stdenv.mkDerivation {
    name = "kernel-config";
    src = "${pmaportsSrc}/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64";
    dontUnpack = true;

    buildPhase = ''
      # Read the original config and apply our modifications.
      sed \
        -e 's/# CONFIG_DMIID is not set/CONFIG_DMIID=y/' \
        -e 's/# CONFIG_U_SERIAL_CONSOLE is not set/CONFIG_U_SERIAL_CONSOLE=y/' \
        -e 's/# CONFIG_USB_G_SERIAL is not set/CONFIG_USB_G_SERIAL=y/' \
        -e 's/# CONFIG_ANDROID_BINDERFS is not set/CONFIG_ANDROID_BINDERFS=y/' \
        -e 's/# CONFIG_NETFILTER_XT_MATCH_PKTTYPE is not set/CONFIG_NETFILTER_XT_MATCH_PKTTYPE=m/' \
        -e 's/# CONFIG_NETFILTER_XT_MATCH_LIMIT is not set/CONFIG_NETFILTER_XT_MATCH_LIMIT=m/' \
        -e 's/# CONFIG_NETFILTER_XT_MATCH_RECENT is not set/CONFIG_NETFILTER_XT_MATCH_RECENT=m/' \
        -e 's/# CONFIG_NETFILTER_XT_MATCH_STATE is not set/CONFIG_NETFILTER_XT_MATCH_STATE=m/' \
        -e 's/# CONFIG_NETFILTER_XT_TARGET_LOG is not set/CONFIG_NETFILTER_XT_TARGET_LOG=m/' \
        -e 's/# CONFIG_TYPEC_DP_ALTMODE is not set/CONFIG_TYPEC_DP_ALTMODE=y/' \
        -e 's/^CONFIG_EFI=y/# CONFIG_EFI is not set/' \
        -e 's/^CONFIG_EFI_STUB=y/# CONFIG_EFI_STUB is not set/' \
        $src > config
    '';

    installPhase = ''
      cp config $out
    '';
  };

  # Parse kernel version from Makefile.
  kernelVersion = rec {
    file = "${kernelSrc}/Makefile";
    version = lib.head (builtins.match ".*VERSION = ([0-9]+).*" (builtins.readFile file));
    patchlevel = lib.head (builtins.match ".*PATCHLEVEL = ([0-9]+).*" (builtins.readFile file));
    sublevel = lib.head (builtins.match ".*SUBLEVEL = ([0-9]+).*" (builtins.readFile file));
    string = "${version}.${patchlevel}.${sublevel}";
  };
  modDirVersion = kernelVersion.string;
in
(linuxKernel.manualConfig {
  inherit lib;

  allowImportFromDerivation = true;
  inherit configfile modDirVersion;
  kernelPatches = [
    {
      name = "hci-qca-drop-unused-event";
      patch = ./patches/hci-qca-drop-unused-event.patch;
    }
  ];
  src = kernelSrc;
  stdenv =
    # Override `stdenv` to produce compressed kernel image target.
    stdenv.override {
      hostPlatform = stdenv.hostPlatform // {
        linux-kernel = stdenv.hostPlatform.linux-kernel // {
          target = "Image.gz";
          installTarget = "zinstall";
        };
      };
    };
  version = kernelVersion.string;
}).overrideAttrs
  (oldAttrs: {
    # Also install the uncompressed `Image` for NixOS compatibility. NixOS expects `Image` to exist,
    # even though we'll use `Image.gz` for boot.
    postInstall = (oldAttrs.postInstall or "") + ''
      # Decompress Image.gz to Image for NixOS compatibility.
      if [ -f "$out/Image.gz" ] && [ ! -f "$out/Image" ]; then
        echo "Decompressing Image.gz to Image for NixOS compatibility..."
        ${lib.getExe' gzip "gunzip"} -c "$out/Image.gz" > "$out/Image"
      fi
    '';
  })
