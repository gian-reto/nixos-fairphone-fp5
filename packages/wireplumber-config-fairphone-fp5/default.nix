{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "wireplumber-config-fairphone-fp5";
  version = "1.0";

  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 51-qcom.conf \
      "$out/share/wireplumber/wireplumber.conf.d/51-qcom.conf"

    runHook postInstall
  '';

  meta = {
    description = "WirePlumber configuration for Qualcomm audio on Fairphone 5";
    longDescription = ''
      Configures the audio format, sample rate, and period parameters required
      by the Fairphone 5 Qualcomm audio subsystem.
    '';
    license = lib.licenses.mit;
    maintainers = [];
    platforms = lib.platforms.linux;
  };
}
