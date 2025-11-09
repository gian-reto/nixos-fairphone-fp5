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
    mkBuilderPkgs = system: import nixpkgs {inherit system;} // commonNixpkgsOptions;
    # Given the architecture of the build host system, returns nixpkgs that produces outputs for
    # `aarch64-linux`. Uses cross-compilation when the builder system is not `aarch64-linux`.
    mkTargetPkgs = system:
      if system == targetSystem
      then import nixpkgs {system = targetSystem;} // commonNixpkgsOptions
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
        '';
      };
    });
}
