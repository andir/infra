{ lib, buildUBoot, armTrustedFirmwareRK3399, callPackage, ffmpeg, mpv-unwrapped, wrapMpv, fetchFromGitHub, libv4l, udev, fetchpatch }:
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
      NIX_LDFLAGS = "-L${udev}/lib -ludev";
      preConfigure = ''
        configureFlags="$configureFlags --enable-v4l2-request --enable-libudev"
      '';
      src = fetchFromGitHub {
        owner = "Kwiboo";
        repo = "FFmpeg";
        rev = "88ed0434a2030b9b3332c5134dc7e6d979054b45";
        sha256 = "1liyfmpyf02bdrpcz1511dliqwy9n7m2vd0d6h42lhmpz8kgcc88";
      };
    });

    mpv-unwrapped = (mpv-unwrapped.override {
      inherit (self) ffmpeg;
    }).overrideAttrs (_: {
      src = fetchFromGitHub {
        owner = "mpv-player";
        repo = "mpv";
        rev = "9b5672ebedf22e1c0d3ba81791c64087e369ee02";
        sha256 = "0x4rh187jyw2a4l5zbnhs470wrsjx4mcsxd40axpw4rrl6wf1nj3";
      };

      preConfigure = ''
        wafConfigureFlags=$(echo "$wafConfigureFlags" | sed -e 's/--disable-libsmbclient//g' -e 's/--disable-sndio//g')
      '';
    });

    mpv = wrapMpv self.mpv-unwrapped { };


    u-boot-spi = self.uboot.overrideAttrs ({ patches, ... }: {
      patches = patches ++ [
        (fetchpatch {
          url = "https://raw.githubusercontent.com/armbian/build/ef96d0862b82582cef2cb4ad711a169106d18eab/patch/u-boot/u-boot-rockchip64-mainline/board-rock-pi-4-enable-spi-flash.patch";
          sha256 = "1zlzcz3l6x0rvab8dlf2l9g2b62xjwd7jr5qrkrx09bxdnlxpvh1";
        })
      ];
      postInstall = ''
        tools/mkimage -n rk3399 -T rkspi -d tpl/u-boot-tpl-dtb.bin:spl/u-boot-spl-dtb.bin spl.bin
        cat <(dd if=spl.bin bs=512K conv=sync) u-boot.itb > $out/u-boot.spiflash.bin
      '';
    });
  };
in
self
