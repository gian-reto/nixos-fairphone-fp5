# Nixpkgs overlay to add custom Fairphone 5 packages.
final: prev: {
  # Qualcomm firmware squasher to convert split `.mdt` (meta data table) firmware files
  # to monolithic `.mbn` (multi-binary) format. Note: This is a build-time tool that
  # runs during firmware preparation (not on the device).
  pil-squasher = final.callPackage ../../packages/pil-squasher {};

  # Firmware package for Fairphone 5.
  firmware-fairphone-fp5 = final.callPackage ../../packages/firmware {};

  # Custom kernel package for Fairphone 5.
  kernel-fairphone-fp5 = final.callPackage ../../packages/kernel {};

  # Protection domain mapper for Qualcomm modems.
  pd-mapper = final.callPackage ../../packages/qrtr/pd-mapper.nix {};

  # QMI IDL compiler (build dependency for rmtfs).
  qmic = final.callPackage ../../packages/qrtr/qmic.nix {};

  # QRTR (Qualcomm IPC Router) userspace tools.
  qrtr = final.callPackage ../../packages/qrtr/qrtr.nix {};

  # Remote filesystem service for Qualcomm modems.
  rmtfs = final.callPackage ../../packages/qrtr/rmtfs.nix {};

  # TFTP server over QRTR for Qualcomm modems.
  tqftpserv = final.callPackage ../../packages/qrtr/tqftpserv.nix {};
}
