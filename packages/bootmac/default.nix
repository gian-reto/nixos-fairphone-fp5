{
  lib,
  stdenv,
  fetchFromGitLab,
  bluez,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  iproute2,
  util-linux,
  makeWrapper,
}: let
  version = "0.7.0";
in
  stdenv.mkDerivation {
    inherit version;

    pname = "bootmac";

    src = fetchFromGitLab {
      domain = "gitlab.postmarketos.org";
      owner = "postmarketOS";
      repo = "bootmac";
      rev = "v${version}";
      hash = "sha256-HMXre5oyVhit+nFJlqTiZtZi+GWjn5++2Js/JjqJWus=";
    };

    nativeBuildInputs = [makeWrapper];

    buildInputs = [
      bluez
      coreutils
      gnugrep
      gnused
      gawk
      iproute2
      util-linux
    ];

    # No build phase needed, it's just a shell script.
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      # Install the main script.
      install -Dm755 bootmac $out/bin/bootmac

      # Wrap the script to ensure all dependencies are in PATH.
      wrapProgram $out/bin/bootmac \
        --prefix PATH : ${lib.makeBinPath [
        bluez
        coreutils
        gnugrep
        gnused
        gawk
        iproute2
        util-linux
      ]}

      runHook postInstall
    '';

    meta = with lib; {
      description = "Configure MAC addresses at boot for WLAN and Bluetooth interfaces";
      homepage = "https://gitlab.postmarketos.org/postmarketOS/bootmac";
      license = licenses.gpl3Plus;
      maintainers = [];
      platforms = platforms.linux;
    };
  }
