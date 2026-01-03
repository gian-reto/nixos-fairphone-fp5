{pkgs, ...}: {
  # Import hardware-specific configuration for Fairphone 5 and Phosh.
  imports = [
    ../../modules/bootmac
    ../../modules/hardware
    ../../modules/modem
    ../../modules/phosh
  ];

  networking.hostName = "fairphone";

  # Set the user for Phosh (required).
  services.xserver.desktopManager.phosh.user = "admin";

  # Enable Qualcomm modem support.
  nixos-fairphone-fp5.modem.enable = true;

  # Enable experimental Nix features (flakes).
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Disable documentation (hides desktop icon).
  documentation.nixos.enable = false;

  # Core apps are set by the `gui` module. The additional packages
  # listed here can be seen as an example of other useful apps for mobile use.
  environment.systemPackages = with pkgs; [
    # Miscellaneous packages.
    wl-clipboard # Wayland clipboard util, also used for Waydroid clipboard sharing.

    # Apps.
    dialect # Translation app.
    firefox-mobile
    gnome-decoder # QR code scanner & generator.
    gnome-software
    resources # System resource monitor.
    warp # Magic wormhole file transfer.
  ];

  # Enable Flatpak.
  services.flatpak.enable = true;
  systemd.services.flatpak-remote-add-flathub = {
    description = "Add Flathub repository for Flatpak";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
      # Restart on failure (e.g., network not actually connected yet).
      Restart = "on-failure";
      RestartSec = "30s";
      # Give up after 20 attempts to avoid infinite retries.
      StartLimitBurst = 20;
    };
  };

  # Enable Waydroid.
  virtualisation.waydroid.enable = true;

  # Create admin user with default password for testing.
  users = {
    mutableUsers = true;

    users.admin = {
      isNormalUser = true;
      # Default password: "admin" (insecure, for testing only).
      # Users should change this with `passwd` after first login.
      initialPassword = "admin";
      # Add to wheel group for sudo access and other groups for functionality.
      extraGroups = [
        "dialout" # Serial port access.
        "feedbackd" # Haptic, visual and audio feedback daemon.
        "networkmanager" # Network configuration.
        "video" # Video device access.
        "wheel" # Sudo.
      ];
    };
  };

  system.stateVersion = "25.05";
}
