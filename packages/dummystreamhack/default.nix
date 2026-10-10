{
  lib,
  stdenv,
  fetchurl,
  meson,
  ninja,
  pkg-config,
  alsa-lib,
}:
stdenv.mkDerivation {
  pname = "dummystreamhack";
  version = "0-unstable-2026-05-26";

  src = fetchurl {
    url = "https://codeberg.org/valpackett/dummystreamhack/archive/f82b9a9f1583bfa44ae32a408318af1e44af3c5e.tar.gz";
    hash = "sha256-OFMwI1iQo7/tlgz2abgDOybnN8OPXqMiFK0DokUb6wM=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [alsa-lib];

  meta = {
    description = "Open ALSA hostless streams for Qualcomm voice calls";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
