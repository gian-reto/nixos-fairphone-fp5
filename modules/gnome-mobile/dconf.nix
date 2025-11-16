{pkgs, ...}: let
  wallpaper = ./wallpaper.jpg;
  nixos-fairphone-wallpaper-info = pkgs.writeTextFile {
    name = "nixos-fairphone-wallpaper-info";
    text = ''
      <?xml version="1.0"?>
      <!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
      <wallpapers>
        <wallpaper deleted="false">
          <name>NixOS Fairphone</name>
          <filename>${wallpaper}</filename>
          <filename-dark>${wallpaper}</filename-dark>
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
  environment.systemPackages = [nixos-fairphone-wallpaper-info];

  programs.dconf = {
    enable = true;

    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };
          "org/gnome/desktop/background" = {
            color-shading-type = "solid";
            picture-options = "zoom";
            picture-uri = "file:///${wallpaper}";
            picture-uri-dark = "file:///${wallpaper}";
            primary-color = "#000000";
            secondary-color = "#000000";
          };
        };
      }
    ];
  };
}
