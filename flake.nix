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
    nixosModules = rec {
      # Complete non-graphical Fairphone 5 configuration.
      minimal = {
        imports = [
          ./modules/audio
          ./modules/bootmac
          ./modules/hardware
          ./modules/modem
          ./modules/qbootctl
          ./modules/sensors
        ];
      };

      # Add the GNOME Mobile desktop to the minimal configuration.
      gnome-mobile = {
        imports = [
          minimal
          ./modules/gnome-mobile
        ];
      };

      # Use `gnome-mobile` as the default module.
      default = gnome-mobile;
    };

    # Builds the persistent U-Boot image flashed to an Android `boot` slot.
    mkUbootImage = pkgs: let
      uboot = pkgs.uboot-fairphone-fp5 or (pkgs.callPackage ./packages/uboot {});
    in
      pkgs.runCommand "uboot.img" {
        nativeBuildInputs = with pkgs; [android-tools gzip];
      } ''
        gzip --no-name --stdout "${uboot}/u-boot-nodtb.bin" > u-boot-nodtb.bin.gz

        mkbootimg \
          --header_version 2 \
          --kernel u-boot-nodtb.bin.gz \
          --dtb "${uboot}/qcm6490-fairphone-fp5.dtb" \
          --base 0x00000000 \
          --kernel_offset 0x00008000 \
          --ramdisk_offset 0x01000000 \
          --second_offset 0x00000000 \
          --tags_offset 0x00000100 \
          --dtb_offset 0x01f00000 \
          --pagesize 4096 \
          --output "$out"
      '';

    # Returns the repart disk image built by the supplied NixOS configuration.
    mkDiskImage = nixosConfig: nixosConfig.config.system.build.image;
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

          modules = [
            nixosModules.gnome-mobile
            ./hosts/gnome-mobile
          ];
          pkgs = exampleConfigPkgs;
        };
        minimal = nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [
            nixosModules.minimal
            ./hosts/minimal
          ];
          pkgs = exampleConfigPkgs;
        };
      };
    in {
      # Example images built from internal host configs for testing.
      packages =
        (nixpkgs.lib.foldlAttrs
          (acc: name: nixosConfig:
            acc
            // {
              "disk-image-${name}" = mkDiskImage nixosConfig;
            })
          {}
          exampleNixosConfigurations)
        // {
          uboot-image = mkUbootImage exampleConfigPkgs;
        };
    })
    // {
      # Reusable library functions.
      lib = {
        inherit mkDiskImage mkUbootImage;
      };

      # NixOS modules for external consumption.
      inherit nixosModules;

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
