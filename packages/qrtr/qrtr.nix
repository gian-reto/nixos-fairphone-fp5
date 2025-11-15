{
  stdenv,
  lib,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  systemd,
}:
stdenv.mkDerivation {
  pname = "qrtr";
  # No versioned releases, so let's use the commit hash for now.
  version = "5923eea97377f4a3ed9121b358fd919e3659db7b";

  src = fetchFromGitHub {
    owner = "linux-msm";
    repo = "qrtr";
    rev = "5923eea97377f4a3ed9121b358fd919e3659db7b";
    hash = "sha256-iHjF/2SQsvB/qC/UykNITH/apcYSVD+n4xA0S/rIfnM=";
  };

  nativeBuildInputs = [meson ninja pkg-config];

  buildInputs = [systemd];

  meta = with lib; {
    description = "Qualcomm IPC Router userspace tools and library";
    homepage = "https://github.com/linux-msm/qrtr";
    license = licenses.bsd3;
    maintainers = [];
    platforms = platforms.linux;
  };
}
