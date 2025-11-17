{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.gnome-mobile;
in {
  options.nixos-fairphone-fp5.gnome-mobile = {
    defaultWallpaper = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable to set a custom default wallpaper for GNOME.

          Note: This can still be changed by the user later in GNOME settings.
        '';
      };

      path = lib.mkOption {
        type = lib.types.path;
        default = ./wallpaper.jpg;
        description = ''
          Path to the wallpaper image file.

          By default, this uses a custom wallpaper included in this module.
        '';
      };
    };

    colorScheme = lib.mkOption {
      type = lib.types.enum ["default" "prefer-dark"];
      default = "default";
      description = ''
        Default color scheme for GNOME (light or dark mode).

        Note: This can still be changed by the user later in GNOME settings.
      '';
    };
  };

  config = let
    # Wallpaper configuration package.
    nixos-fairphone-wallpaper-info = pkgs.writeTextFile {
      name = "nixos-fairphone-wallpaper-info";
      text = ''
        <?xml version="1.0"?>
        <!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
        <wallpapers>
          <wallpaper deleted="false">
            <name>NixOS Fairphone</name>
            <filename>${cfg.defaultWallpaper.path}</filename>
            <filename-dark>${cfg.defaultWallpaper.path}</filename-dark>
            <options>zoom</options>
            <shade_type>solid</shade_type>
            <pcolor>#000000</pcolor>
            <scolor>#000000</scolor>
          </wallpaper>
        </wallpapers>
      '';
      destination = "/share/gnome-background-properties/nixos-fairphone-wallpaper.xml";
    };
  in {
    # Install wallpaper metadata if wallpaper is enabled.
    environment.systemPackages = lib.optionals cfg.defaultWallpaper.enable [
      nixos-fairphone-wallpaper-info
    ];

    programs.dconf = {
      enable = true;

      profiles.user.databases = [
        {
          settings =
            {
              "org/gnome/desktop/interface" = {
                color-scheme = cfg.colorScheme;
              };
            }
            // lib.optionalAttrs cfg.defaultWallpaper.enable {
              "org/gnome/desktop/background" = {
                color-shading-type = "solid";
                picture-options = "zoom";
                picture-uri = "file:///${cfg.defaultWallpaper.path}";
                picture-uri-dark = "file:///${cfg.defaultWallpaper.path}";
                primary-color = "#000000";
                secondary-color = "#000000";
              };
            };
        }
      ];
    };
  };
}
