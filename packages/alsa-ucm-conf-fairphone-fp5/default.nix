{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "alsa-ucm-conf-fairphone-fp5";
  version = "f051a09";

  src = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "alsa-ucm-conf";
    rev = "f051a09ade09b918c63e1fcf06663a022470b24a";
    hash = "sha256-QNREx+sv7n8naSel3csvVXW1+3rUFB+YNeQ53asxkcI=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install the complete UCM2 tree, including the Fairphone 5 profiles.
    mkdir -p "$out/share/alsa"
    cp -r ucm2 "$out/share/alsa/"

    # UCM2 resolves profiles by ALSA card long name. U-Boot's UEFI handoff
    # exposes SMBIOS/DMI data, so ALSA uses "fairphone-Fairphone5" instead of
    # "Fairphone 5".
    ln -s "Fairphone 5.conf" \
      "$out/share/alsa/ucm2/conf.d/qcm6490/fairphone-Fairphone5.conf"

    runHook postInstall
  '';

  meta = {
    description = "ALSA UCM2 profiles for Fairphone 5";
    longDescription = ''
      Device-specific ALSA Use Case Manager configuration for the Fairphone 5
      Qualcomm QCM6490 audio subsystem. Provides playback and microphone
      capture profiles derived from the sc7280-mainline ALSA configuration.
    '';
    homepage = "https://github.com/sc7280-mainline/alsa-ucm-conf";
    license = lib.licenses.bsd3;
    maintainers = [];
    platforms = lib.platforms.linux;
  };
}
