{
  fetchFromGitHub,
  fetchFromGitLab,
  gzip,
  lib,
  linuxKernel,
  stdenv,
  ...
}: let
  # Kernel source from `sc7280-mainline` repository.
  kernelSrc = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "linux";
    rev = "v6.17.0-sc7280";
    hash = "sha256-k6Fp5Dhy1s7Jnpc1qywHZxmkH2+OAYk1Yy8vSBSyR5k=";
  };

  # Source of postmarketOS `pmaports` repository.
  pmaportsSrc = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "pmaports";
    rev = "305cddc07f3739747f0662c824e4febccf0e1e28";
    hash = "sha256-QInrf7Sf9j+bB26bsC1hYOnWPz/n5K3WlC50cq7megQ=";
  };

  # Use the kernel configuration from PostmarketOS for the `sc7280` chipset as the base.
  #
  # However, we need to override some options that are disabled in PostmarketOS config to
  # make it compatible with NixOS and enable some useful stuff:
  # - CONFIG_DMIID: NixOS asserts that this is enabled for some reason...
  # - CONFIG_U_SERIAL_CONSOLE: Enables USB serial gadget console output for debugging.
  # - CONFIG_USB_G_SERIAL: Classic USB serial gadget driver.
  # - CONFIG_ANDROID_BINDERFS: Required for Waydroid (Android container support).
  configfile = stdenv.mkDerivation {
    name = "kernel-config";
    src = "${pmaportsSrc}/device/testing/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64";
    dontUnpack = true;

    buildPhase = ''
      # Read the original config and apply our modifications.
      sed \
        -e 's/# CONFIG_DMIID is not set/CONFIG_DMIID=y/' \
        -e 's/# CONFIG_U_SERIAL_CONSOLE is not set/CONFIG_U_SERIAL_CONSOLE=y/' \
        -e 's/# CONFIG_USB_G_SERIAL is not set/CONFIG_USB_G_SERIAL=y/' \
        -e 's/# CONFIG_ANDROID_BINDERFS is not set/CONFIG_ANDROID_BINDERFS=y/' \
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
    configfile = configfile;
    modDirVersion = modDirVersion;
    src = kernelSrc;
    stdenv =
      # Override `stdenv` to produce compressed kernel image target.
      stdenv.override {
        hostPlatform =
          stdenv.hostPlatform
          // {
            linux-kernel =
              stdenv.hostPlatform.linux-kernel
              // {
                target = "Image.gz";
                installTarget = "zinstall";
              };
          };
      };
    version = kernelVersion.string;
  }).overrideAttrs (oldAttrs: {
    # Also install the uncompressed `Image` for NixOS compatibility. NixOS expects `Image` to exist,
    # even though we'll use `Image.gz` for boot.
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # Decompress Image.gz to Image for NixOS compatibility.
        if [ -f "$out/Image.gz" ] && [ ! -f "$out/Image" ]; then
          echo "Decompressing Image.gz to Image for NixOS compatibility..."
          ${lib.getExe' gzip "gunzip"} -c "$out/Image.gz" > "$out/Image"
        fi
      '';
  })
