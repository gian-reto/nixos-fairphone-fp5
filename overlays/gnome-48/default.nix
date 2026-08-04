# Overlay to downgrade some core GNOME packages to version 48.
#
# The custom GNOME mobile packages we used are still based on GNOME 48,
# so let's downgrade for now to ensure compatibility.
#
# Note: This is kind of cursed, but ¯\_( ͡° ͜ʖ ͡°)_/¯
final: prev: let
  # Pinned Nixpkgs tarball with GNOME 48 packages.
  nixpkgs-gnome-48 = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/91c9a64ce2a84e648d0cf9671274bb9c2fb9ba60.tar.gz";
    sha256 = "19myp93spfsf5x62k6ncan7020bmbn80kj4ywcykqhb9c3q8fdr1";
  };

  # Import the pinned nixpkgs containing GNOME 48 packages.
  pkgs-gnome-48 = import nixpkgs-gnome-48 {
    system = final.stdenv.hostPlatform.system;
    # Forward only settings that are compatible with the pinned nixpkgs revision.
    config = {
      inherit (final.config) allowUnfree permittedInsecurePackages;
    };
  };
in {
  adwaita-icon-theme = pkgs-gnome-48.adwaita-icon-theme;
  calls = pkgs-gnome-48.calls;
  dconf = pkgs-gnome-48.dconf;
  epiphany = pkgs-gnome-48.epiphany;
  gdm = pkgs-gnome-48.gdm;
  gnome-control-center = pkgs-gnome-48.gnome-control-center;
  gnome-initial-setup = pkgs-gnome-48.gnome-initial-setup;
  gnome-online-accounts = pkgs-gnome-48.gnome-online-accounts;
  gnome-remote-desktop = pkgs-gnome-48.gnome-remote-desktop;
  gnome-session = pkgs-gnome-48.gnome-session;
  gnome-session-ctl = pkgs-gnome-48.gnome-session-ctl;
  gnome-settings-daemon = pkgs-gnome-48.gnome-settings-daemon;
  gnome-shell = pkgs-gnome-48.gnome-shell;
  gsettings-desktop-schemas = pkgs-gnome-48.gsettings-desktop-schemas;
  gvfs = pkgs-gnome-48.gvfs;
  mutter = pkgs-gnome-48.mutter;
  nautilus = pkgs-gnome-48.nautilus;
  orca = pkgs-gnome-48.orca;
  xdg-desktop-portal-gnome = pkgs-gnome-48.xdg-desktop-portal-gnome;
}
