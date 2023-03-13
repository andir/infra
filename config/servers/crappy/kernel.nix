{ config, pkgs, lib, ... }:
{
  boot.kernelPackages = pkgs.rockpi4.kernelPackages;
  # zfs isn't supported on 5.10 as of this writing so we have to remove it from the supported filesystems
  boot.supportedFilesystems = lib.mkForce [ "btfs" "resiferfs" "vfat" "xfs" "ntfs" "cifs" ];
}
