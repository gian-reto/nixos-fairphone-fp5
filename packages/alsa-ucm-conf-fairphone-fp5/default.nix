{
  fetchFromGitHub,
  fetchurl,
  lib,
  stdenvNoCC,
  systemd,
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

  postInstall = let
    voiceCall = fetchurl {
      url = "https://raw.githubusercontent.com/wrenix/sc7280-alsa-ucm-conf/b0b1e95af962f6da022c0365fba1092cd611ea70/ucm2/Fairphone/fp5/VoiceCall.conf";
      hash = "sha256-QE/Dhb3u0HFTOiEsYwPYCyOq1FXyjqDAZ3xl88NiwjU=";
    };
  in ''
    profile="$out/share/alsa/ucm2/Fairphone/fp5/VoiceCall.conf"
    install -m644 ${voiceCall} "$profile"

    # Use an absolute systemctl path under NixOS.
    substituteInPlace "$profile" \
      --replace-fail \
        'exec "systemctl ' \
        'exec "${systemd}/bin/systemctl '

    # Restore the current speaker level instead of maximum volume.
    substituteInPlace "$profile" \
      --replace-fail \
        "PCM Playback Volume' 360" \
        "PCM Playback Volume' 308"

    # Also open the receive stream when using speakerphone.
    substituteInPlace "$profile" \
      --replace-fail \
        'Comment "Speaker Playback"' \
        'Comment "Speaker Playback"

        EnableSequence [
          cset "name='\'''Amplifier L Profile Set'\''' Music"
          cset "name='\'''Amplifier R Profile Set'\''' Music"
          cset "name='\'''Amplifier L PCM Playback Volume'\''' 308"
          cset "name='\'''Amplifier R PCM Playback Volume'\''' 308"
          exec "${systemd}/bin/systemctl --user start dummystreamhack@Rhw:''${CardId},7"
        ]

        DisableSequence [
          exec "${systemd}/bin/systemctl --user stop dummystreamhack@Rhw:''${CardId},7"
        ]'

    cat >> "$out/share/alsa/ucm2/Fairphone/fp5/fp5.conf" <<'EOF'

    SectionUseCase."Voice Call" {
      File "/Fairphone/fp5/VoiceCall.conf"
      Comment "Phone call quality."
    }
    EOF
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
