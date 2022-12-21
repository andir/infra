{ config, pkgs, lib, ... }:
let
  # LibreElec has a couple of interesting rockchip patches that are
  # worth trying out to fix my HDMI audi situation
  patches =
    let
      src = pkgs.fetchFromGitHub {
        owner = "LibreELEC";
        repo = "LibreELEC.tv";
        rev = "5fc1868d8610dadb91c380a88997583d554d97d8";
        sha256 = "sha256-RnU61sDXivFDxI19afPNFnLLtgjYX+K6EQl9/qmPCZ8=";
      };
      prefix = "projects/Rockchip/patches/linux/default";
    in
    map
      (path: {
        name = path;
        patch = "${src}/${prefix}/${path}";
      }) [
      "linux-0002-rockchip-from-list.patch"
      "linux-0011-v4l2-from-list.patch"
      "linux-0020-drm-from-list.patch"
      "linux-1000-drm-rockchip.patch"
      "linux-1001-v4l2-rockchip.patch"
      "linux-1002-for-libreelec.patch"
      "linux-2000-v4l2-wip-rkvdec-hevc.patch"
      "linux-2001-v4l2-wip-iep-driver.patch"
    ];


  version = "5.16-rc8"; # 5.13.11, 5.13.12 works
  kernelPkg = pkgs.linux_latest.override {
    #  modDirVersionArg = "5.16.0-rc8";
    #  argsOverride = {
    #    inherit version;
    #    src = pkgs.fetchurl {
    #      url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
    #      sha256 = "1f732wy75vid6d8rbmkgv3iwhshf7zcra6pp362z2xrriv2b4r2d";
    #    };
    #  };
  };
in
{
  boot.kernelPackages =
    pkgs.linuxPackagesFor (kernelPkg.override {
      #  #   STAGING_MEDIA y
      #  #   VIDEO_ROCKCHIP_VDEC m
      #  extraConfig = ''
      #    FB_SIMPLE m
      #  '';
      kernelPatches = with pkgs.kernelPatches; [
        bridge_stp_helper
        request_key_helper
      ] ++ patches;
      #   {
      #     name = "enable-rockpi4-spi";
      #     patch = ./enable-spi.patch;
      #   }
      #   {
      #     name = "enable-rockpi4-spi-flash";
      #     patch = ./support-spi-flash.patch;
      #   }
    });
  # zfs isn't supported on 5.10 as of this writing so we have to remove it from the supported filesystems
  boot.supportedFilesystems = lib.mkForce [ "btfs" "resiferfs" "vfat" "xfs" "ntfs" "cifs" ];
}
