{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.gui;
in {
  imports = [
    ./dconf.nix
  ];

  options.nixos-fairphone-fp5.gui = {
    installDefaultApps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install default mobile-friendly applications.

        When enabled, installs a small, curated set of mobile-friendly core
        apps for SMS/MMS, calls, document viewing, etc.

        Set to false for a minimal install or if you prefer different apps.
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

          Default is "ignore", which lets the desktop environment handle it.
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
          enabled in the desktop environment's settings for apps to use it.
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

  config = {
    services.xserver = {
      # Disable the X11 windowing system (we use Wayland instead).
      enable = false;

      # Use modesetting driver for mobile GPU (same option for X11 and Wayland).
      videoDrivers = ["modesetting"];
    };

    services.logind.settings.Login = {
      # Handle power button with custom behavior.
      HandlePowerKey = cfg.powerButton.shortPress;
      HandlePowerKeyLongPress = cfg.powerButton.longPress;
    };

    # Install essential mobile packages.
    environment.systemPackages = with pkgs;
      [
        # NetworkManager for connection management.
        networkmanager
      ]
      ++ lib.optionals cfg.installDefaultApps [
        # Mobile-friendly apps.
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

    # Enable location services (geoclue).
    services.geoclue2.enable = cfg.locationServices.enable;

    # FIXME: Currently seems broken, or needs userland support?
    #
    # Enable automatic screen rotation (if supported by hardware).
    hardware.sensor.iio.enable = lib.mkDefault cfg.autoRotate.enable;
  };
}
