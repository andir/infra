{ config, pkgs, lib, ... }:
let
  version = "5.16-rc8"; # 5.13.11, 5.13.12 works
  kernelPkg = pkgs.linux_latest.override {
    modDirVersionArg = "5.16.0-rc8";
    argsOverride = {
      inherit version;
      src = pkgs.fetchurl {
        url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
        sha256 = "1f732wy75vid6d8rbmkgv3iwhshf7zcra6pp362z2xrriv2b4r2d";
      };
    };
  };
in
{

  boot.kernelPackages =
    pkgs.linuxPackagesFor (kernelPkg.override {
      #   STAGING_MEDIA y
      #   VIDEO_ROCKCHIP_VDEC m
      extraConfig = ''
        FB_SIMPLE m
      '';
      kernelPatches = with pkgs.kernelPatches; [
        bridge_stp_helper
        request_key_helper
        #   {
        #     name = "enable-rockpi4-spi";
        #     patch = ./enable-spi.patch;
        #   }
        #   {
        #     name = "enable-rockpi4-spi-flash";
        #     patch = ./support-spi-flash.patch;
        #   }
      ];
    });
  # zfs isn't supported on 5.10 as of this writing so we have to remove it from the supported filesystems
  boot.supportedFilesystems = lib.mkForce [ "btfs" "resiferfs" "vfat" "xfs" "ntfs" "cifs" ];
}
