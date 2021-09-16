{ config, pkgs, lib, ... }:
let
  version = "5.13.12"; # 5.13.11 works
  kernelPkg = pkgs.linux_5_13.override {
    modDirVersionArg = version;
    argsOverride = {
      inherit version;
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v5.x/linux-${version}.tar.xz";
        sha256 = "0948w1zc2gqnl8x60chjqngfzdi0kcxm12i1nx3nx4ksiwj5vc98";
      };
    };
  };
in
{

  boot.kernelPackages =
    pkgs.linuxPackagesFor (kernelPkg.override {
      # extraConfig = ''
      #   STAGING_MEDIA y
      #   VIDEO_ROCKCHIP_VDEC m
      # '';
      # kernelPatches = with pkgs.kernelPatches; [
      #   bridge_stp_helper
      #   request_key_helper
      #   {
      #     name = "enable-rockpi4-spi";
      #     patch = ./enable-spi.patch;
      #   }
      #   {
      #     name = "enable-rockpi4-spi-flash";
      #     patch = ./support-spi-flash.patch;
      #   }

      # ];
    });
  # zfs isn't supported on 5.10 as of this writing so we have to remove it from the supported filesystems
  boot.supportedFilesystems = lib.mkForce [ "btfs" "resiferfs" "vfat" "xfs" "ntfs" "cifs" ];
}
