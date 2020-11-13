{ config, pkgs, lib, ... }:
let
  # ensure that we have at least kernel 5.9 as otherwise we do not have the required DTBs
  kernelPkg =
    if lib.versionAtLeast pkgs.linux.version "5.10"
    then pkgs.linux else assert lib.versionAtLeast pkgs.linux_testing.version "5.10"; pkgs.linux_testing;
in
{

  boot.kernelPackages = pkgs.linuxPackagesFor (kernelPkg.override {
    extraConfig = ''
      STAGING_MEDIA y
      VIDEO_ROCKCHIP_VDEC m
    '';
  });
  # zfs isn't supported on 5.10 as of this writing so we have to remove it from the supported filesystems
  boot.supportedFilesystems = lib.mkForce [ "btfs" "resiferfs" "vfat" "xfs" "ntfs" "cifs" ];
}
