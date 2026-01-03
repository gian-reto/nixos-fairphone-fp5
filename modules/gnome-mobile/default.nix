{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.gnome-mobile;
in {
  options.nixos-fairphone-fp5.gnome-mobile = {
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
  };

  imports = [
    ../gui
  ];

  config = {
    # Enable our custom `dconf` settings, as this is a GNOME-based DE.
    nixos-fairphone-fp5.gui.dconf.enable = true;

    nixpkgs.overlays = [
      # Downgrade core GNOME packages first, then apply `gnome-mobile` overlay.
      (lib.composeManyExtensions [
        (import ../../overlays/gnome-48)
        (import ../../overlays/gnome-mobile)
      ])
    ];

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

    # Exclude desktop-only GNOME applications that don't make sense on mobile.
    environment.gnome.excludePackages = cfg.excludedPackages;

    # IBus configuration for on-screen keyboard. Unset IM module environment variables to ensure the
    # on-screen keyboard works. GNOME has a builtin IBus support through IBus' D-Bus API, so these
    # variables are not necessary.
    environment.extraInit = ''
      unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS
    '';
  };
}
