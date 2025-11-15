{
  description = "NixOS on Fairphone 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }: let
    # System architecture of the Fairphone 5; always `aarch64-linux`.
    targetSystem = "aarch64-linux";

    # Nixpkgs overlay to add our custom, Fairphone-specific packages.
    fairphoneOverlay = final: prev: {
      # Qualcomm firmware squasher to convert split `.mdt` (meta data table) firmware files
      # to monolithic `.mbn` (bulti-binary) format. Note: This is a build-time tool that
      # runs during firmware preparation (not on the device), so we use `builderPkgs` here.
      pil-squasher = final.callPackage ./packages/pil-squasher {};

      # Firmware package for Fairphone 5.
      firmware-fairphone-fp5 = final.callPackage ./packages/firmware {
        builderPkgs = final.buildPackages;
      };

      # Custom kernel package for Fairphone 5.
      kernel-fairphone-fp5 = final.callPackage ./packages/kernel {
        builderPkgs = final.buildPackages;
      };

      # Protection domain mapper for Qualcomm modems.
      pd-mapper = final.callPackage ./packages/qrtr/pd-mapper.nix {};

      # QMI IDL compiler (build dependency for rmtfs).
      qmic = final.callPackage ./packages/qrtr/qmic.nix {};

      # QRTR (Qualcomm IPC Router) userspace tools.
      qrtr = final.callPackage ./packages/qrtr/qrtr.nix {};

      # Remote filesystem service for Qualcomm modems.
      rmtfs = final.callPackage ./packages/qrtr/rmtfs.nix {};

      # TFTP server over QRTR for Qualcomm modems.
      tqftpserv = final.callPackage ./packages/qrtr/tqftpserv.nix {};
    };

    # Fix cross-compilation issues where build-time tools are incorrectly cross-compiled.
    # These tools must run on the build platform, not the target platform.
    mkCrossFixesOverlay = builderPkgs: final: prev: {
      xxd = builderPkgs.xxd;
      tinyxxd = builderPkgs.tinyxxd;
    };

    # Given a specific system architecture, returns Nixpkgs with some common configuration,
    # as well as the curstom Fairphone overlay.
    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [fairphoneOverlay];

        config = {
          allowUnfree = true;

          # FIXME: This is needed because of `chatty`, which supports Matrix and therefore
          # unfortunately includes a dependency on `olm`, which is currently marked as
          # insecure. This should be removed or fixed ASAP.
          permittedInsecurePackages = [
            "olm-3.2.16"
          ];
        };
      };

    # Given the architecture of the build host system, returns Nixpkgs that compile to the
    # architecture of `targetSystem`, using cross-compilation if the builder system is not
    # `aarch64-linux`.
    mkTargetPkgs = builderPkgs:
      if builderPkgs.stdenv.hostPlatform.system == targetSystem
      then builderPkgs
      else
        builderPkgs.pkgsCross.aarch64-multiplatform.extend
        (nixpkgs.lib.composeManyExtensions [
          fairphoneOverlay
          (mkCrossFixesOverlay builderPkgs)
        ]);

    hostConfigs = {
      gnome-mobile = [./hosts/gnome-mobile];
      minimal = [./hosts/minimal];
    };
    mkNixosConfiguration = pkgs: modules:
      nixpkgs.lib.nixosSystem {
        inherit modules pkgs;
        system = targetSystem;
      };

    # Builds the boot image that can be flashed to the `boot` partition using fastboot.
    mkBootImage = nixosConfig: builderPkgs:
      builderPkgs.runCommand "boot.img" {
        nativeBuildInputs = with builderPkgs; [android-tools];
      } ''
        # Get paths from NixOS configuration.
        kernelPath="${nixosConfig.config.system.build.kernel}"
        initrdPath="${nixosConfig.config.system.build.initialRamdisk}/initrd"
        initPath="${builtins.unsafeDiscardStringContext nixosConfig.config.system.build.toplevel}/init"

        # Build kernel command line from NixOS config parameters.
        # Add init= parameter to kernel params from config.
        kernelParams="${builtins.toString nixosConfig.config.boot.kernelParams}"
        cmdline="$kernelParams init=$initPath"

        # Concatenate kernel (Image.gz) with device tree blob.
        # The bootloader expects them as a single file.
        echo "Concatenating kernel and DTB..."
        cat "$kernelPath/Image.gz" "$kernelPath/dtbs/qcom/qcm6490-fairphone-fp5.dtb" > Image-with-dtb.gz

        # Build Android boot image using mkbootimg.
        # Parameters based on PostmarketOS deviceinfo.
        echo "Building boot image with mkbootimg..."
        echo "Using cmdline: $cmdline"
        mkbootimg \
          --header_version 2 \
          --kernel Image-with-dtb.gz \
          --ramdisk "$initrdPath" \
          --cmdline "$cmdline" \
          --base 0x00000000 \
          --kernel_offset 0x00008000 \
          --ramdisk_offset 0x01000000 \
          --dtb_offset 0x01f00000 \
          --tags_offset 0x00000100 \
          --pagesize 4096 \
          --dtb "$kernelPath/dtbs/qcom/qcm6490-fairphone-fp5.dtb" \
          -o "$out"

        echo "Boot image created successfully: $out"
        echo "Size: $(stat -c%s "$out") bytes"
      '';

    # Builds an `ext4` image containing the NixOS system that can be flashed to the `userdata`
    # partition using fastboot.
    mkRootfsImage = nixosConfig: targetPkgs:
      targetPkgs.callPackage "${targetPkgs.path}/nixos/lib/make-ext4-fs.nix" {
        storePaths = [nixosConfig.config.system.build.toplevel];
        # Don't compress, as firmware needs to be uncompressed.
        compressImage = false;
        # Must match `fileSystems."/".device` label defined in`modules/hardware/default.nix`!
        volumeLabel = "nixos";
        populateImageCommands = ''
          # Create the profile directory structure.
          mkdir -p ./files/nix/var/nix/profiles

          # Create first-generation NixOS profile and point to our initial toplevel.
          ln -s ${nixosConfig.config.system.build.toplevel} ./files/nix/var/nix/profiles/system-1-link

          # Set "system" to point to first-generation profile.
          ln -s system-1-link ./files/nix/var/nix/profiles/system

          # The bootloader expects /init, so point it to the profile's init.
          # This symlink never needs to change!

          # The Android bootloader appends init=/init to the kernel cmdline, which
          # overrides our init=/nix/var/.../init parameter. Instead of fighting the
          # bootloader, we create the symlink it expects. Note: This symlink is
          # stable and always points to the current generation.
          ln -s /nix/var/nix/profiles/system/init ./files/init
        '';
      };
  in
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      # Nixpkgs for the given build host system architecture.
      builderPkgs = mkPkgs system;

      # Nixpkgs for the target architecture (`aarch64-linux`), possibly cross-compiled.
      targetPkgs = mkTargetPkgs builderPkgs;

      # A map of NixOS configurations compiled (or cross-compiled) for the target system
      # architecture.
      targetNixosConfigurations =
        nixpkgs.lib.mapAttrs (_: modules: mkNixosConfiguration targetPkgs modules) hostConfigs;
    in {
      # Per-host devshell.
      devShells.default = builderPkgs.mkShell {
        packages = with builderPkgs; [android-tools binutils file];
        shellHook = ''
          # Only print help message in interactive shells.
          if [[ $- == *i* ]]
          then
              echo "NixOS Fairphone 5 development environment"
              echo ""
              echo "Available tools:"
              echo "  - fastboot:  Flash images to device"
              echo "  - mkbootimg: Build Android boot images"
              echo "  - file:      Inspect file types"
              echo ""
              echo "Build individual packages:"
              echo "  nix build .#firmware-fairphone-fp5"
              echo "  nix build .#kernel-fairphone-fp5"
              echo "  nix build .#pil-squasher"
              echo "  nix build .#pd-mapper"
              echo "  nix build .#qmic"
              echo "  nix build .#qrtr"
              echo "  nix build .#rmtfs"
              echo "  nix build .#tqftpserv"
              echo ""
              echo "Build individual images:"
              echo "  nix build .#boot-image-gnome-mobile"
              echo "  nix build .#boot-image-minimal"
              echo "  nix build .#rootfs-image-gnome-mobile"
              echo "  nix build .#rootfs-image-minimal"
          fi
        '';
      };

      packages =
        {
          inherit (builderPkgs) pil-squasher;
          inherit (targetPkgs) firmware-fairphone-fp5 kernel-fairphone-fp5 pd-mapper qmic qrtr rmtfs tqftpserv;
        }
        # Map over NixOS configurations and provide package aliases for building their images.
        // nixpkgs.lib.foldlAttrs
        (acc: name: nixosConfig:
          acc
          // {
            "boot-image-${name}" = mkBootImage nixosConfig builderPkgs;
            "rootfs-image-${name}" = mkRootfsImage nixosConfig targetPkgs;
          })
        {}
        targetNixosConfigurations;
    })
    // {
      # Native `aarch64-linux` NixOS configurations for on-device rebuilds.
      nixosConfigurations = let
        targetPkgsNative = mkPkgs targetSystem;
      in
        nixpkgs.lib.mapAttrs (_: modules: mkNixosConfiguration targetPkgsNative modules) hostConfigs;
    };
}
