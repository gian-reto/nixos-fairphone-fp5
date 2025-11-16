{
  config,
  lib,
  pkgs,
  ...
}: {
  # Apply the GNOME Mobile overlay.
  nixpkgs.overlays = [
    (import ../../overlays/gnome-mobile)
  ];

  imports = [
    ./dconf.nix
  ];

  services.xserver = {
    # Disable the X11 windowing system (we use Wayland instead).
    enable = false;

    # Use modesetting driver for mobile GPU (same option for X11 and Wayland).
    videoDrivers = ["modesetting"];
  };

  # Enable GNOME Desktop Manager.
  services.desktopManager.gnome = {
    enable = true;

    # Mobile-specific GSettings overrides:
    # - Dynamic workspaces make more sense on mobile.
    # - Enable the experimental fractional scaling feature.
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      dynamic-workspaces=true
      experimental-features=['scale-monitor-framebuffer']
    '';

    extraGSettingsOverridePackages = [pkgs.mutter];
  };

  # Enable GDM (GNOME Display Manager) with Wayland.
  services.displayManager = {
    gdm = {
      enable = true;

      # Wayland is enabled by default, but let's be explicit.
      wayland = true;
    };

    # Set GNOME as the default session.
    defaultSession = "gnome";
  };

  services.logind.settings.Login = {
    # Handle power button with custom behavior:
    # - Short press: ignore (let GNOME handle it).
    # - Long press: power off.
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };

  # Exclude desktop-only GNOME applications that don't make sense on mobile.
  environment.gnome.excludePackages = with pkgs; [
    # Media apps that are too heavy or desktop-focused.
    totem # Video player.
    gnome-music # Music player.

    # Utilities that aren't useful on mobile.
    simple-scan # Document scanner.
    gnome-system-monitor # System monitor.
    baobab # Disk usage analyzer.
    evince # Document viewer.

    # Desktop-specific tools.
    gnome-connections # Remote desktop client.
    gnome-tour # GNOME tour (desktop-focused).
    yelp # Help browser.
  ];

  # IBus configuration for on-screen keyboard. Unset IM module environment variables to ensure the
  # on-screen keyboard works. NOME has a builtin IBus support through IBus' D-Bus API, so these
  # variables are not neccessary.
  environment.extraInit = ''
    unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS
  '';

  # Install essential mobile packages.
  environment.systemPackages = with pkgs; [
    # NetworkManager for connection management.
    networkmanager

    # Mobile-friendly GNOME apps.
    chatty # SMS/MMS messaging app.
    gnome-console # Terminal.
    papers # Document viewer.
    showtime # Video player.
  ];
  programs = {
    calls.enable = true; # Phone calls.
  };

  # Ensure ModemManager is started before NetworkManager.
  systemd.services.ModemManager = lib.mkIf config.nixos-fairphone-fp5.modem.enable {
    aliases = ["dbus-org.freedesktop.ModemManager1.service"];
    wantedBy = ["NetworkManager.service"];
    partOf = ["NetworkManager.service"];
    after = ["NetworkManager.service"];
  };

  # Enable sound with PipeWire.
  services.pulseaudio.enable = lib.mkForce false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable Bluetooth.
  hardware.bluetooth = {
    enable = true;

    powerOnBoot = true;
  };

  # Enable location services (geoclue) for GNOME.
  services.geoclue2.enable = true;

  # Enable automatic screen rotation (if supported by hardware).
  hardware.sensor.iio.enable = lib.mkDefault true;
}
