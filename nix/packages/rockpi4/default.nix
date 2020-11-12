{ lib, buildUBoot, armTrustedFirmwareRK3399 }:
rec {
  uboot =
    let
      drv = buildUBoot {
        defconfig = "rock-pi-4-rk3399_defconfig";
        extraMeta.platforms = [ "aarch64-linux" ];
        BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
        filesToInstall = [ "u-boot.itb" "idbloader.img" ];
        postBuild = ''
          ./tools/mkimage -n rk3399 -T rksd -d tpl/u-boot-tpl.bin idbloader.img
          cat spl/u-boot-spl.bin >> idbloader.img
        '';
      };
      # assert that u-boot is at least version 2020.10
    in
    assert (lib.versionAtLeast drv.version "2020.10"); drv;
}
