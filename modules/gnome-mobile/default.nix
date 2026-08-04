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
        default = false;
        description = ''
          Power on Bluetooth adapter at boot.
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
  };

  imports = [
    ./dconf.nix
  ];

  config = {
    nixpkgs.overlays = [
      # Downgrade core GNOME packages first, then apply `gnome-mobile` overlay.
      (lib.composeManyExtensions [
        (import ../../overlays/gnome-48)
        (import ../../overlays/gnome-mobile)
      ])
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

    # Enable GDM (GNOME Display Manager).
    services.displayManager = {
      gdm.enable = true;

      # Set GNOME as the default session.
      defaultSession = "gnome";
    };

    # FIXME: The following fixes were added to get GDM to work after downgrading to GNOME 48 from 49.
    # Remove them once we move to a proper GNOME 49-based mobile overlay. See also:
    # https://github.com/NixOS/nixpkgs/commit/23a2bfcf8a4bc47d53273163cba84afa4f5f08f3.
    #
    # Configure GDM user with proper home directory.
    # GDM 48 needs a writable home directory; without it, GDM fails with
    # "Failed to set owner of /var/empty: Operation not permitted".
    users.users.gdm = {
      home = lib.mkForce "/run/gdm";
    };
    systemd.tmpfiles.rules = [
      # Create GDM runtime directory with proper permissions.
      "d /run/gdm 0755 gdm gdm -"
    ];

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

    # Enable Bluetooth.
    hardware.bluetooth = lib.mkIf cfg.bluetooth.enable {
      enable = true;

      powerOnBoot = cfg.bluetooth.powerOnBoot;
    };

    # Enable location services (geoclue) for GNOME.
    services.geoclue2.enable = cfg.locationServices.enable;
  };
}
