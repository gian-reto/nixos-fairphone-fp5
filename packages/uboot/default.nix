{
  buildUBoot,
  fetchFromGitHub,
  xxd,
}:
(buildUBoot {
  version = "2026.04-unstable";

  src = fetchFromGitHub {
    owner = "u-boot";
    repo = "u-boot";
    rev = "987c93fc68a641cc735c9828872511a947e54191";
    hash = "sha256-5282c4RTo5cr3mtCnnECd5boQo79vnG21T8EHR+F5PM=";
  };

  defconfig = "qcom_defconfig qcom-phone.config";
  extraMakeFlags = ["DEVICE_TREE=qcom/qcm6490-fairphone-fp5"];
  extraMeta.platforms = ["aarch64-linux"];

  extraConfig = ''
    CONFIG_CMD_HASH=y
    CONFIG_CMD_BLKMAP=y
    CONFIG_BLKMAP=y
    CONFIG_CMD_UFETCH=y
    CONFIG_CMD_SELECT_FONT=y
    CONFIG_VIDEO_FONT_8X16=n
    CONFIG_VIDEO_FONT_16X32=y
  '';

  prePatch = ''
    substituteInPlace board/qualcomm/qcom-phone.env \
      --replace-fail 'preboot=scsi scan' \
      'preboot=scsi scan; part start scsi 0 userdata ustart; part size scsi 0 userdata usize; blkmap create root; blkmap map root 0 0x''${usize} linear scsi 0 0x''${ustart}'
  '';

  filesToInstall = [
    "u-boot*"
    "dts/upstream/src/arm64/qcom/qcm6490-fairphone-fp5.dtb"
  ];
}).overrideAttrs (oldAttrs: {
  # U-Boot converts `qcom-phone.env` into a C array with xxd. Append it to
  # buildUBoot's native tools without replacing its standard build inputs.
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [xxd];
})
