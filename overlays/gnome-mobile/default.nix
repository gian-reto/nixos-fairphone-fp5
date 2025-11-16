final: prev: let
  gvc = prev.fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "GNOME";
    repo = "libgnome-volume-control";
    rev = "5f9768a2eac29c1ed56f1fbb449a77a3523683b6";
    hash = "sha256-gdgTnxzH8BeYQAsvv++Yq/8wHi7ISk2LTBfU8hk12NM=";
  };

  # GVDB (GNOME Variant Database).
  gvdb = prev.fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "GNOME";
    repo = "gvdb";
    rev = "4758f6fb7f889e074e13df3f914328f3eecb1fd3";
    hash = "sha256-4mqoHPlrMPenoGPwDqbtv4/rJ/uq9Skcm82pRvOxNIk=";
  };
in {
  # Override GNOME Shell with mobile-optimized version.
  gnome-shell = prev.gnome-shell.overrideAttrs (old: rec {
    version = "48.mobile.0";
    src = prev.fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "verdre";
      repo = "gnome-shell-mobile";
      rev = version;
      hash = "sha256-Iu61qtK0j4OIWpuFjzx8v2G7H7jAbmSBpayuf2h5zUE=";
      fetchSubmodules = true;
    };
    postPatch = ''
      patchShebangs \
        src/data-to-c.py \
        meson/generate-app-list.py

      # Don't generate manpage, we don't need it.
      rm -f man/gnome-shell.1

      ln -sf ${gvc} subprojects/gvc
    '';
    buildInputs =
      old.buildInputs
      ++ [
        prev.modemmanager # `/org/gnome/shell/misc/modemManager.js`
        prev.libgudev # `/org/gnome/gjs/modules/esm/gi.js`
      ];
    postFixup =
      old.postFixup
      + ''
        wrapGApp $out/share/gnome-shell/org.gnome.Shell.SensorDaemon
      '';
  });

  # Mobile-specific GNOME Settings Daemon package.
  gnome-settings-daemon-mobile = prev.gnome-settings-daemon.overrideAttrs (old: rec {
    version = "48.mobile.0";
    src = prev.fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "verdre";
      repo = "gnome-settings-daemon-mobile";
      rev = version;
      hash = "sha256-gLYcjlQ0IcItktRkMEP9k/thYX9sWFzm5P2KF4CS1u8=";
    };
    postPatch =
      old.postPatch
      + ''
        rm -r subprojects/gvc
        ln -sf ${gvc} subprojects/gvc
      '';
  });

  # Override Mutter with mobile-optimized version. This also ensures it uses the mobile GNOME Settings Daemon.
  mutter =
    (prev.mutter.override {gnome-settings-daemon = final.gnome-settings-daemon-mobile;}).overrideAttrs
    (old: rec {
      version = "48.mobile.0";
      src = prev.fetchFromGitLab {
        domain = "gitlab.gnome.org";
        owner = "verdre";
        repo = "mutter-mobile";
        rev = version;
        hash = "sha256-Qv2a9siPMHJ2dFTpYqDkaHML0jQ89RDpgDu6z6j9Xrc=";
      };
      postPatch =
        old.postPatch
        + ''
          ln -sf ${gvdb} subprojects/gvdb
        '';
    });
}
