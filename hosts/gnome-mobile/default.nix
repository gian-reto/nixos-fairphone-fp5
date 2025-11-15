{
  # Import hardware-specific configuration for Fairphone 5 and GNOME Mobile.
  imports = [
    ../../modules/hardware
    ../../modules/gnome-mobile
  ];

  networking.hostName = "fairphone";

  # Enable experimental Nix features (flakes).
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Create admin user with default password for testing.
  users = {
    mutableUsers = true;

    users.admin = {
      isNormalUser = true;
      # Default password: "admin" (insecure, for testing only).
      # Users should change this with `passwd` after first login.
      initialPassword = "admin";
      # Add to wheel group for sudo access and other groups for GNOME functionality.
      extraGroups = [
        "networkmanager" # Network configuration.
        "video" # Video device access.
        "wheel" # Sudo.
      ];
    };
  };

  system.stateVersion = "25.05";
}
