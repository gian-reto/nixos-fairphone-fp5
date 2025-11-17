{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.gnome-mobile;
in {
  options.nixos-fairphone-fp5.gnome-mobile = {
    installDefaultApps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install default mobile-friendly applications in addition to the default
        GNOME apps.

        When enabled, installs a small, curated set of mobile-friendly core GNOME
        apps for SMS/MMS, calls, etc.

        Set to false for a minimal GNOME install or if you prefer different apps.
      '';
    };

    excludedPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
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
      description = ''
        Additional GNOME packages to exclude beyond the defaults.

        By default, several non-mobile-friendly GNOME applications are excluded.
      '';
    };

    powerButton = {
      shortPress = lib.mkOption {
        type = lib.types.enum ["ignore" "suspend" "poweroff"];
        default = "ignore";
        description = ''
          Action to perform on short power button press.

          Options:
          - "ignore": Do nothing.
          - "suspend": Suspend the system immediately.
          - "poweroff": Power off the system immediately.

          Default is "ignore", which lets GNOME handle it (turns off screen).
        '';
      };

      longPress = lib.mkOption {
        type = lib.types.enum ["ignore" "suspend" "poweroff"];
        default = "poweroff";
        description = ''
          Action to perform on long power button press.

          Options:
          - "ignore": Do nothing.
          - "suspend": Suspend the system.
          - "poweroff": Power off the system.

          Default is "poweroff" for emergency shutdown capability.
        '';
      };
    };

    bluetooth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable Bluetooth support.
        '';
      };

      powerOnBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Power on Bluetooth adapter at boot.
        '';
      };
    };

    pipewire = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable PipeWire for audio.
        '';
      };
    };

    locationServices = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable location services (geoclue2).

          Note: This only enables the functionality, and still needs to be
          enabled in GNOME settings for apps to use it.
        '';
      };
    };

    autoRotate = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable rotation detection using IIO sensors.
        '';
      };
    };
  };

  imports = [
    ./dconf.nix
  ];

  config = {
    # Apply the GNOME Mobile overlay.
    nixpkgs.overlays = [
      (import ../../overlays/gnome-mobile)
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
      # Handle power button with custom behavior.
      HandlePowerKey = cfg.powerButton.shortPress;
      HandlePowerKeyLongPress = cfg.powerButton.longPress;
    };

    # Exclude desktop-only GNOME applications that don't make sense on mobile.
    environment.gnome.excludePackages = cfg.excludedPackages;

    # IBus configuration for on-screen keyboard. Unset IM module environment variables to ensure the
    # on-screen keyboard works. NOME has a builtin IBus support through IBus' D-Bus API, so these
    # variables are not neccessary.
    environment.extraInit = ''
      unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS
    '';

    # Install essential mobile packages.
    environment.systemPackages = with pkgs;
      [
        # NetworkManager for connection management.
        networkmanager
      ]
      ++ lib.optionals cfg.installDefaultApps [
        # Mobile-friendly GNOME apps.
        chatty # SMS/MMS messaging app.
        gnome-console # Terminal.
        papers # Document viewer.
        showtime # Video player.
      ];

    programs.calls.enable = cfg.installDefaultApps;

    # Ensure ModemManager is started before NetworkManager.
    systemd.services.ModemManager = lib.mkIf config.nixos-fairphone-fp5.modem.enable {
      aliases = ["dbus-org.freedesktop.ModemManager1.service"];
      wantedBy = ["NetworkManager.service"];
      partOf = ["NetworkManager.service"];
      after = ["NetworkManager.service"];
    };

    # FIXME: Audio hardware is not yet detected on the Fairphone, which is not
    # a problem with PipeWire itself.
    #
    # Enable sound with PipeWire.
    services.pulseaudio = lib.mkIf cfg.pipewire.enable {
      enable = lib.mkForce false;
    };
    security.rtkit.enable = cfg.pipewire.enable;
    services.pipewire = lib.mkIf cfg.pipewire.enable {
      enable = true;

      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Enable Bluetooth.
    hardware.bluetooth = lib.mkIf cfg.bluetooth.enable {
      enable = true;

      powerOnBoot = cfg.bluetooth.powerOnBoot;
    };

    # Enable location services (geoclue) for GNOME.
    services.geoclue2.enable = cfg.locationServices.enable;

    # FIXME: Currently seems broken, or needs userland support in GNOME?
    #
    # Enable automatic screen rotation (if supported by hardware).
    hardware.sensor.iio.enable = lib.mkDefault cfg.autoRotate.enable;
  };
}
