{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  losetup = lib.getExe' pkgs.util-linux "losetup";
  loaderTimeout =
    if config.boot.loader.timeout == null
    then "menu-force"
    else toString config.boot.loader.timeout;
  closureInfo = pkgs.closureInfo {
    rootPaths = [config.system.build.toplevel];
  };
in {
  imports = ["${modulesPath}/image/repart.nix"];

  fileSystems = {
    "/".autoResize = true;

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };
  };

  systemd.repart = {
    enable = true;
    partitions."03-root".Type = "root";
  };

  boot = {
    uki = {
      name = "nixos-bootstrap";
      version = null;
    };

    loader = {
      timeout = 5;

      efi.canTouchEfiVariables = false;

      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        installDeviceTree = true;
        edk2-uefi-shell.enable = true;
      };
    };

    initrd = {
      availableKernelModules.loop = true;
      services.udev = {
        binPackages = [pkgs.util-linux];
        rules = ''
          SUBSYSTEM=="block", ACTION=="add", ENV{ID_PART_ENTRY_NAME}=="userdata", RUN+="${losetup} --partscan --find --nooverlap --sector-size 4096 --loop-ref userdata /dev/%k"
        '';
      };
    };
  };

  image.repart = {
    name = "image";
    version = null;
    sectorSize = 4096;
    compression.enable = false;

    partitions = {
      "00-padding".repartConfig = {
        Type = "linux-generic";
        SizeMinBytes = "15M";
        SizeMaxBytes = "15M";
      };

      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/systemd/systemd-boot${efiArch}.efi".source =
            "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          "/efi/edk2-uefi-shell/shell.efi".source = "${pkgs.edk2-uefi-shell}/shell.efi";
          "/loader/loader.conf".source = pkgs.writeText "loader.conf" ''
            timeout ${loaderTimeout}
            console-mode ${config.boot.loader.systemd-boot.consoleMode}
          '';
          "/loader/entries/edk2-uefi-shell.conf".source = pkgs.writeText "edk2-uefi-shell.conf" ''
            title  EDK2 UEFI Shell
            efi    /efi/edk2-uefi-shell/shell.efi
            sort-key ${config.boot.loader.systemd-boot.edk2-uefi-shell.sortKey}
          '';
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "ESP";
          FileSystemSectorSize = 4096;
          SizeMinBytes = "1G";
          SizeMaxBytes = "1G";
        };
      };

      "20-root" = {
        storePaths = [config.system.build.toplevel];
        contents = {
          "/boot".source = pkgs.runCommand "boot-mount-point" {} "mkdir $out";
          "/nix-path-registration".source = "${closureInfo}/registration";
        };
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          FileSystemSectorSize = 4096;
          Minimize = "guess";
          GrowFileSystem = true;
        };
      };
    };
  };
}
