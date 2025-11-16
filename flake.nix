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
    # Builds the boot image that can be flashed to the `boot` partition using fastboot.
    mkBootImage = nixosConfig: pkgs:
      pkgs.runCommand "boot.img" {
        nativeBuildInputs = with pkgs; [android-tools];
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
    mkRootfsImage = nixosConfig: pkgs:
      pkgs.callPackage "${pkgs.path}/nixos/lib/make-ext4-fs.nix" {
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
    flake-utils.lib.eachSystem ["aarch64-linux"] (system: let
      # Nixpkgs for building test images.
      exampleConfigPkgs = import nixpkgs {
        inherit system;

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

      # NixOS configurations for building example images for testing.
      exampleNixosConfigurations = {
        gnome-mobile = nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [./hosts/gnome-mobile];
          pkgs = exampleConfigPkgs;
        };
        minimal = nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [./hosts/minimal];
          pkgs = exampleConfigPkgs;
        };
      };
    in {
      # Example images built from internal host configs for testing.
      packages =
        nixpkgs.lib.foldlAttrs
        (acc: name: nixosConfig:
          acc
          // {
            "boot-image-${name}" = mkBootImage nixosConfig exampleConfigPkgs;
            "rootfs-image-${name}" = mkRootfsImage nixosConfig exampleConfigPkgs;
          })
        {}
        exampleNixosConfigurations;
    })
    // {
      # Reusable library functions.
      lib = {
        inherit mkBootImage mkRootfsImage;
      };

      # NixOS modules for external consumption.
      nixosModules = {
        minimal = {
          imports = [
            ./modules/hardware
            ./modules/modem
          ];
        };

        gnome-mobile = {
          imports = [
            ./modules/hardware
            ./modules/modem
            ./modules/gnome-mobile
          ];
        };

        # Export `gnome-mobile` as the default module.
        default = {
          imports = [
            ./modules/hardware
            ./modules/modem
            ./modules/gnome-mobile
          ];
        };
      };

      # Separate overlays for more custom use cases.
      overlays = let
        fairphone-fp5 = import ./overlays/fairphone-fp5;
      in {
        inherit fairphone-fp5;

        # Export `fairphone-fp5` as the default overlay.
        default = fairphone-fp5;
      };
    };
}
