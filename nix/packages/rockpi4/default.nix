{ lib, buildUBoot, armTrustedFirmwareRK3399, callPackage, ffmpeg, mpv-unwrapped, wrapMpv, fetchFromGitHub, libv4l, udev }:
let
  self = {
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

    mpp = callPackage ./mpp.nix { };

    ffmpeg = ffmpeg.overrideAttrs ({ buildInputs, ... }: {
      buildInputs = buildInputs ++ [
        libv4l
        udev
      ];
      preConfigure = ''
        configureFlags="$configureFlags --enable-v4l2-request --enable-libudev"
      '';
      src = fetchFromGitHub {
        owner = "Kwiboo";
        repo = "FFmpeg";
        rev = "43570a6663361d81840d990587e9cce42c6d3d93";
        sha256 = "1gf2zc450nak0h22p0la463ncqi38r7jiqp7j16k92y2k18gdc90";
      };
    });

    mpv-unwrapped = mpv-unwrapped.override {
      inherit (self) ffmpeg;
    };

    mpv = wrapMpv self.mpv-unwrapped { };
  };
in
self
