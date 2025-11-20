# NixOS module for WiFi and Bluetooth MAC address configuration at boot using
# bootmac.
#
# This module configures MAC addresses for WLAN and Bluetooth interfaces at boot.
# It generates deterministic MAC addresses from the device's serial number.
#
# Without this, both WiFi and Bluetooth will use randomly generated MAC addresses
# that change on every reboot, causing issues with network identification and
# Bluetooth pairing.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.bootmac;
in {
  options.nixos-fairphone-fp5.bootmac = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable bootmac to configure MAC addresses at boot.
      '';
    };

    bluetooth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable Bluetooth MAC address configuration.
        '';
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "hci0";
        description = "Name of the Bluetooth interface to configure.";
      };
    };

    wifi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable WiFi MAC address configuration.
        '';
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "wlan0";
        description = "Name of the WiFi interface to configure.";
      };
    };

    macPrefix = lib.mkOption {
      type = lib.types.str;
      default = "0200";
      description = ''
        MAC address prefix to use when generating addresses.

        The default "0200" indicates a locally administered unicast address.
        Can be set to a longer value like an IEEE OUI if needed.
      '';
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = ''
        Timeout in seconds for setting MAC addresses.

        If the interface is not ready, bootmac will retry for this many seconds
        before giving up.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure bootmac package is available.
    environment.systemPackages = with pkgs; [
      bootmac
    ];

    # Install udev rules to trigger bootmac when interfaces appear.
    services.udev.extraRules = lib.concatStringsSep "\n" (
      lib.optional cfg.bluetooth.enable
      ''ACTION=="add", SUBSYSTEM=="bluetooth", KERNEL=="${cfg.bluetooth.interface}", RUN+="${pkgs.bootmac}/bin/bootmac --bluetooth-if ${cfg.bluetooth.interface} --prefix ${cfg.macPrefix}"''
      ++ lib.optional cfg.wifi.enable
      ''ACTION=="add", SUBSYSTEM=="net", KERNEL=="${cfg.wifi.interface}", RUN+="${pkgs.bootmac}/bin/bootmac --wlan-if ${cfg.wifi.interface} --prefix ${cfg.macPrefix}"''
    );

    # Set environment variables for bootmac configuration.
    environment.variables = {
      BT_TIMEOUT = toString cfg.timeout;
      WLAN_TIMEOUT = toString cfg.timeout;
    };

    # Ensure bluez is available for btmgmt command (required for Bluetooth).
    services.blueman.enable = lib.mkIf cfg.bluetooth.enable true;
  };
}
