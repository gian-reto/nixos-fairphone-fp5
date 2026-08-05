{
  stdenv,
  fetchgit,
  lib,
  meson,
  ninja,
  pkg-config,
  makeFontsConf,
  openssl,
  libdrm,
  libevent,
  libyaml,
  libyuv,
  gst_all_1,
  gtest,
  graphviz,
  doxygen,
  python3,
  python3Packages,
  udev,
  libpisp,
  libglvnd,
  withTracing ? lib.meta.availableOn stdenv.hostPlatform lttng-ust,
  lttng-ust,
  withSoftispGPU ? true,
  # QCam cannot be enabled by default because it causes infinite recursion.
  withQcam ? false,
  qt6,
  libjpeg,
  libtiff,
  SDL2,
}:
stdenv.mkDerivation rec {
  pname = "libcamera";
  version = "0.7.2";

  src = fetchgit {
    url = "https://git.libcamera.org/libcamera/libcamera.git";
    rev = "v${version}";
    hash = "sha256-vhFkeT1j2KKm+CVvGrtH5BEYJSEdaX7N7DRdA0a9EWk=";
  };

  outputs = [
    "out"
    "dev"
  ];

  # Register sensor helpers and static properties for the FP5 cameras.
  patches = [
    ./0001-add-fp5-sensor-helpers.patch
    ./0002-add-fp5-sensor-properties.patch
  ];

  postPatch = ''
    patchShebangs src/py/ utils/
  '';

  # Libcamera signs IPA modules at install time, before stripping and RPATH
  # fixup modify them. Re-sign the final modules with a reproducible key so they
  # can be loaded in-process instead of through IPA process isolation.
  preBuild = ''
    ninja src/ipa-priv-key.pem
    install -D ${./ipa-priv-key.pem} src/ipa-priv-key.pem
  '';

  postFixup = ''
    ../src/ipa/ipa-sign-install.sh src/ipa-priv-key.pem $out/lib/libcamera/ipa/ipa_*.so
  '';

  strictDeps = true;

  buildInputs =
    [
      # IPA signing.
      openssl

      # GStreamer integration.
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base

      # Cam integration.
      libevent
      libdrm

      # Hotplugging.
      udev

      # Python bindings.
      python3Packages.pybind11

      libyuv

      # YAML parsing.
      libyaml

      gtest
    ]
    ++ lib.optionals stdenv.hostPlatform.isAarch [libpisp]
    ++ lib.optionals withTracing [lttng-ust]
    ++ lib.optionals withSoftispGPU [libglvnd]
    ++ lib.optionals withQcam [
      libjpeg
      libtiff
      qt6.qtbase
      qt6.qttools
      SDL2
    ];

  nativeBuildInputs =
    [
      meson
      ninja
      pkg-config
      python3
      python3Packages.jinja2
      python3Packages.pyyaml
      python3Packages.ply
      python3Packages.sphinx
      graphviz
      doxygen
      openssl
    ]
    ++ lib.optional withQcam qt6.wrapQtAppsHook;

  mesonFlags =
    [
      "-Dv4l2=enabled"
      (lib.mesonEnable "tracing" withTracing)
      (lib.mesonEnable "qcam" withQcam)
      (lib.mesonEnable "apps-output-dng" withQcam)
      (lib.mesonEnable "cam-output-sdl2" withQcam)
      (lib.mesonEnable "cam-jpeg" withQcam)
      (lib.mesonEnable "softisp-gpu" withSoftispGPU)
      "-Dlibunwind=disabled"
      "-Dlibdw=disabled"
      # This option tries to download GTest unconditionally when enabled.
      "-Dlc-compliance=disabled"
      # Avoid blanket -Werror failures on less-tested compilers.
      "-Dwerror=false"
      # Upstream provides public documentation, and its documentation build
      # breaks binary compatibility.
      "-Ddocumentation=disabled"
    ]
    ++ lib.optionals stdenv.hostPlatform.isAarch [
      # TensorFlow Lite is unavailable for this build.
      "-Drpi-awb-nn=disabled"
    ];

  env = {
    # Allow a deprecated declaration used by libcamera 0.7.2.
    NIX_CFLAGS_COMPILE = "-Wno-error=deprecated-declarations";

    # Silence fontconfig warnings about a missing configuration.
    FONTCONFIG_FILE = makeFontsConf {fontDirectories = [];};
  };

  # Install the FP5 Simple-IPA tuning files from postmarketOS.
  postInstall = ''
    install -Dm644 ${./tuning/s5kjn1.yaml} \
      "$out/share/libcamera/ipa/simple/s5kjn1.yaml"
    install -Dm644 ${./tuning/imx858.yaml} \
      "$out/share/libcamera/ipa/simple/imx858.yaml"
  '';

  meta = {
    description = "Open source camera stack and framework for Linux, Android, and ChromeOS";
    homepage = "https://libcamera.org";
    changelog = "https://git.libcamera.org/libcamera/libcamera.git/tag/?h=${src.rev}";
    license = lib.licenses.lgpl2Plus;
    maintainers = [];
    platforms = lib.platforms.linux;
    badPlatforms = [
      # Libcamera requires shared libraries.
      lib.systems.inspect.platformPatterns.isStatic
    ];
  };
}
