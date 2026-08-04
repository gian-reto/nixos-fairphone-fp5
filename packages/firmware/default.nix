{
  fetchFromGitHub,
  findutils,
  lib,
  pil-squasher,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "fp5-firmware";
  # No versioned releases, so let's use the commit hash for now.
  version = "a4908f548e6f88965e78b1478af1751b6a854fc9";

  # Source: https://github.com/FairBlobs/FP5-firmware.
  src = fetchFromGitHub {
    owner = "FairBlobs";
    repo = "FP5-firmware";
    rev = "a4908f548e6f88965e78b1478af1751b6a854fc9";
    hash = "sha256-XRklo4XfRrskmIxdyY9duU8nF0svoQV90KwaF15ISjk=";
  };

  meta = {
    description = "Firmware files for Fairphone 5";
    longDescription = ''
      Proprietary firmware files required for Fairphone 5 hardware components
      including GPU, DSP, modem, and Bluetooth. Converted from Qualcomm split
      format to monolithic .mbn files for mainline Linux kernel.
    '';
    homepage = "https://github.com/FairBlobs/FP5-firmware";
    license = lib.licenses.unfree;
    maintainers = [];
    platforms = lib.platforms.linux;
  };

  nativeBuildInputs = [pil-squasher findutils];

  buildPhase = ''
    runHook preBuild

    # Squash all .mdt firmware files to .mbn format.
    echo "Squashing firmware files..."
    find . -name "*.mdt" -type f | while read -r mdtfile; do
      echo "Processing: $mdtfile"
      pil-squasher "''${mdtfile%.mdt}.mbn" "$mdtfile"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install GPU/DSP/modem firmware to qcom/qcm6490/fairphone5/.
    # These are the .mbn files created by pil-squasher from .mdt files.
    mkdir -p "$out/lib/firmware/qcom/qcm6490/fairphone5"
    install -Dm644 -t "$out/lib/firmware/qcom/qcm6490/fairphone5" \
      a660_zap.mbn \
      adsp.mbn \
      cdsp.mbn \
      modem.mbn \
      wpss.mbn

    # Install JSON config files.
    install -Dm644 -t "$out/lib/firmware/qcom/qcm6490/fairphone5" \
      adspr.jsn \
      adsps.jsn \
      adspua.jsn \
      battmgr.jsn \
      cdspr.jsn \
      modemr.jsn

    # Install IPA firmware (renamed to ipa_fws.mbn for kernel compatibility).
    install -Dm644 yupik_ipa_fws.mbn \
      "$out/lib/firmware/qcom/qcm6490/fairphone5/ipa_fws.mbn"

    # Install audio amplifier firmware for the AW88261 codec.
    install -Dm644 aw882xx_acf.bin \
      "$out/lib/firmware/qcom/qcm6490/fairphone5/aw88261_acf.bin"

    # Install Venus video firmware (renamed to venus.mbn for kernel compatibility).
    install -Dm644 vpu20_1v.mbn \
      "$out/lib/firmware/qcom/qcm6490/fairphone5/venus.mbn"

    # Install Bluetooth firmware to qca/.
    mkdir -p "$out/lib/firmware/qca"
    install -Dm644 -t "$out/lib/firmware/qca" \
      msbtfw11.mbn \
      msnv11.bin

    # Install modem_pr directory recursively.
    mkdir -p "$out/lib/firmware/qcom/qcm6490/fairphone5"
    cp -r modem_pr "$out/lib/firmware/qcom/qcm6490/fairphone5/"

    # Set permissions to 0644 for all modem_pr files.
    find "$out/lib/firmware/qcom/qcm6490/fairphone5/modem_pr" -type f -exec chmod 0644 {} \;

    # Install HexagonFS to /usr/share. The FastRPC server exposes these files
    # directly from the device-specific directory to the ADSP.
    mkdir -p "$out/usr/share/qcom/qcm6490/Fairphone/fp5"
    cp -r hexagonfs/. "$out/usr/share/qcom/qcm6490/Fairphone/fp5/"

    # Set permissions to 0644 for HexagonFS files.
    find "$out/usr/share/qcom/qcm6490/Fairphone/fp5" -type f -exec chmod 0644 {} \;

    runHook postInstall
  '';
}
