# NixOS module for sensor support on Fairphone 5.
#
# The sensors are exposed by the ADSP Sensor Subsystem Controller through
# `libssc` and the FastRPC device, rather than as kernel-visible IIO devices.
{
  config,
  lib,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.sensors;
in {
  options.nixos-fairphone-fp5.sensors = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable accelerometer and proximity sensor support for Fairphone 5
        through the Qualcomm Sensor Subsystem Controller.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The audio module currently owns the shared FastRPC service required to
    # communicate with the ADSP sensor protection domain.
    assertions = [
      {
        assertion = config.nixos-fairphone-fp5.audio.enable;
        message = ''
          Fairphone 5 sensor support requires
          `nixos-fairphone-fp5.audio.enable` to provide the ADSP FastRPC service.
        '';
      }
    ];

    # Run `iio-sensor-proxy` with its stock SSC backend.
    hardware.sensor.iio.enable = true;

    # If the proxy starts before the ADSP has registered its sensor service, it
    # exits successfully without exposing sensors. Retry until discovery works.
    systemd.services.iio-sensor-proxy = {
      after = ["hexagonrpcd-adsp-sensorspd.service"];
      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Restart = "always";
        RestartSec = "5";
      };
    };

    # Enable the SSC accelerometer and proximity backends and transform the
    # accelerometer readings into the Fairphone 5 display coordinate system.
    services.udev.extraRules = ''
      SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity"
      SUBSYSTEM=="misc", KERNEL=="fastrpc-*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, -1"
    '';
  };
}
