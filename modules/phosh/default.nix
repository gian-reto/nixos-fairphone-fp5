{
  config,
  lib,
  options,
  pkgs,
  ...
}: {
  imports = [
    ../gui
  ];

  config = {
    # Assertion to ensure user is set.
    assertions = [
      {
        assertion = options.services.xserver.desktopManager.phosh.user.isDefined;
        message = ''
          `services.xserver.desktopManager.phosh.user` not set.
          When importing the phosh configuration in your system, you need to set `services.xserver.desktopManager.phosh.user` to the username of the session user.
        '';
      }
    ];

    # Enable our custom `dconf` settings, as this is a GNOME-based DE.
    nixos-fairphone-fp5.gui.dconf.enable = true;

    # Enable Phosh desktop environment.
    services.xserver.desktopManager.phosh = {
      enable = true;

      group = "users";
    };

    # Install essential mobile packages.
    environment.systemPackages = lib.mkIf config.nixos-fairphone-fp5.gui.installDefaultApps (with pkgs; [
      phosh-mobile-settings
      portfolio-filemanager
    ]);
  };
}
