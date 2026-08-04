# NixOS module for audio support on Fairphone 5.
#
# This module enables playback and capture through the Qualcomm QCM6490 audio
# subsystem. It configures:
# - FastRPC access to the audio DSP firmware files.
# - PipeWire and WirePlumber with Qualcomm-specific settings.
# - Fairphone 5 ALSA UCM2 profiles.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.audio;
in {
  options.nixos-fairphone-fp5.audio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable audio support for Fairphone 5.

        This configures the FastRPC service, PipeWire, WirePlumber, and the
        device-specific ALSA UCM profiles required for playback and capture.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Attach the FastRPC server to the ADSP sensors protection domain and expose
    # its HexagonFS files. The explicit device path is required because the
    # conventional /usr/share/qcom path does not contain package files on NixOS.
    systemd.services.hexagonrpcd-adsp-sensorspd = {
      description = "Qualcomm ADSP FastRPC server (sensorspd)";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];

      serviceConfig = {
        ExecStart = "${pkgs.hexagonrpc}/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s -R ${pkgs.firmware-fairphone-fp5}/usr/share/qcom/qcm6490/Fairphone/fp5";
        Restart = "on-failure";
        RestartSec = "3";
      };
    };

    # Use PipeWire with the Qualcomm-specific WirePlumber configuration.
    services.pulseaudio.enable = lib.mkForce false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;

      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      wireplumber.configPackages = [pkgs.wireplumber-config-fairphone-fp5];
    };

    # Point both audio user services at the Fairphone 5 UCM2 profile tree.
    systemd.user.services.pipewire.environment = {
      ALSA_CONFIG_UCM2 = "${pkgs.alsa-ucm-conf-fairphone-fp5}/share/alsa/ucm2";
    };
    systemd.user.services.wireplumber.environment = {
      ALSA_CONFIG_UCM2 = "${pkgs.alsa-ucm-conf-fairphone-fp5}/share/alsa/ucm2";
    };
  };
}
