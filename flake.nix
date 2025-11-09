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

    commonNixpkgsOptions = {
      config.allowUnfree = true;
    };

    # Returns nixpkgs for the given build host system architecture.
    mkBuilderPkgs = system: import nixpkgs ({inherit system;} // commonNixpkgsOptions);
    # Given the architecture of the build host system, returns nixpkgs that produces outputs for
    # `aarch64-linux`. Uses cross-compilation when the builder system is not `aarch64-linux`.
    mkTargetPkgs = system:
      if system == targetSystem
      then import nixpkgs ({system = targetSystem;} // commonNixpkgsOptions)
      else (mkBuilderPkgs system).pkgsCross.aarch64-multiplatform;
  in
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      # Pkgs for the build host system.
      builderPkgs = mkBuilderPkgs system;
      # Pkgs for the target system (native on aarch64, cross-compiled from build host arch to
      # `aarch64-linux` otherwise).
      targetPkgs = mkTargetPkgs system;
    in {
      # Per-host devshell.
      devShells.default = builderPkgs.mkShell {
        packages = with builderPkgs; [android-tools file binutils];
        shellHook = ''
          echo "NixOS Fairphone 5 development environment"
          echo "Available tools:"
          echo "  - fastboot:  Flash images to device"
          echo "  - mkbootimg: Build Android boot images"
          echo "  - file:      Inspect file types"
          echo ""
          echo "Build individual packages:"
          echo "  nix build .#firmware"
          echo "  nix build .#kernel"
          echo "  nix build .#pil-squasher"
        '';
      };

      packages = {
        # Firmware package for Fairphone 5.
        firmware = let
          # Extend `builderPkgs` to add custom build-time packages.
          builderPkgs' =
            builderPkgs
            // {
              pil-squasher = builderPkgs.callPackage ./packages/pil-squasher {};
            };
        in
          targetPkgs.callPackage ./packages/firmware {
            builderPkgs = builderPkgs';
          };

        # Custom kernel package for Fairphone 5.
        kernel = targetPkgs.callPackage ./packages/kernel {
          builderPkgs = builderPkgs;
        };

        # Qualcomm firmware squasher to convert split `.mdt` (meta data table) firmware files to
        # monolithic `.mbn` (bulti-binary) format. Note: This is a build-time tool that runs during
        # firmware preparation (not on the device), so we use `builderPkgs` here.
        pil-squasher = builderPkgs.callPackage ./packages/pil-squasher {};
      };
    });
}
