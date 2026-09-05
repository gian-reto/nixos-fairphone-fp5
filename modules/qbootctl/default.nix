{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixos-fairphone-fp5.qbootctl;
in {
  options.nixos-fairphone-fp5.qbootctl.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Enable marking the current A/B boot slot as successful at boot via
      qbootctl, preventing the slot from being marked unbootable.
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.qbootctl];

    systemd.services.qbootctl-mark-boot-successful = {
      description = "Mark current A/B slot as successfully booted";
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.qbootctl}/bin/qbootctl -m";
      };
    };
  };
}
