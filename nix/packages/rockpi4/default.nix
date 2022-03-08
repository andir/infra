{ lib, ubootRockPi4, armTrustedFirmwareRK3399, callPackage, ffmpeg, mpv-unwrapped, wrapMpv, fetchFromGitHub, libv4l, udev, fetchpatch, jdk11_headless }:
let
  self = {
    uboot =
      let
        drv = ubootRockPi4;
        # assert that u-boot is at least version 2020.10
      in
      assert (lib.versionAtLeast drv.version "2020.10"); drv;
    mpp = callPackage ./mpp.nix { };

    kodi = callPackage ./kodi {
      jre_headless = jdk11_headless;
      waylandSupport = true;
    };

    ffmpeg = ffmpeg.overrideAttrs ({ buildInputs, patches ? [ ], ... }: {
      patches = patches ++ [
        ./ffmpeg-4.3-v4l.patch
        #(fetchpatch {
        #  url = "https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/4888409c3ad97630a270543b56822aa318871fa8/packages/multimedia/ffmpeg/patches/v4l2-request/ffmpeg-001-v4l2-request.patch";
        #  sha256 = "1rqam7jl6k0swn87rvpk9k08bwvvxlp5ydkang71bj6m4gg9yffa";
        #})

        #(fetchpatch {
        #  url = "https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/8a018bd987e70aed2c95792702f9bbb894dc5df2/packages/multimedia/ffmpeg/patches/v4l2-drmprime/ffmpeg-001-v4l2-drmprime.patch";
        #  sha256 = "0z0h8nqpmk17vg98krw9bs8226fhb5phx7iavq0sc9sfys9wg5lg";
        #})

        #(fetchpatch {
        #  url = "https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/4888409c3ad97630a270543b56822aa318871fa8/packages/multimedia/ffmpeg/patches/libreelec/ffmpeg-001-libreelec.patch";
        #  sha256 = "0vmd24lidvwwp4akphvvnkmawdsmrqqc72vzdqvi8parzzsf7rx9";
        #})
        #(fetchpatch {
        #  url = "https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/4888409c3ad97630a270543b56822aa318871fa8/packages/multimedia/ffmpeg/patches/rpi/ffmpeg-001-rpi.patch";
        #  sha256 = "0bgrw6wkd0ywfzzh54vb6ac53nb71vdgqsphbqkdpljswzl5avl9";
        #})

      ];
      buildInputs = buildInputs ++ [
        libv4l
        udev
      ];
      NIX_LDFLAGS = "-L${udev}/lib -ludev";
      preConfigure = ''
        configureFlags="$configureFlags --enable-v4l2-request --enable-libudev --enable-libdrm --enable-v4l2_m2m --enable-hwaccels"
      '';
      src = fetchFromGitHub {
        owner = "xbmc";
        repo = "FFmpeg";
        rev = "4.3.2-Matrix-19.1";
        sha256 = "0pxxf5bbap4g4v64ayimd78qz6p7d2qks3lfsqni71y50fis24wz";
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


    # conversation on the curren findings on how to properly build these:
    # https://logs.nix.samueldr.com/nixos-aarch64/2021-01-06#4441416
    # https://github.com/sigmaris/u-boot/blob/v2020.01-ci/azure-pipelines.yml#L94-L100
    u-boot-spi = self.uboot.overrideAttrs ({ patches, ... }: {
      patches = patches ++ [
        ./board-rock-pi-4-enable-spi-flash.patch
        #(fetchpatch {
        #  url = "https://raw.githubusercontent.com/armbian/build/ef96d0862b82582cef2cb4ad711a169106d18eab/patch/u-boot/u-boot-rockchip64-mainline/board-rock-pi-4-enable-spi-flash.patch";
        #  sha256 = "1zlzcz3l6x0rvab8dlf2l9g2b62xjwd7jr5qrkrx09bxdnlxpvh1";
        #})
      ];
      postInstall = ''
        tools/mkimage -n rk3399 -T rkspi -d tpl/u-boot-tpl-dtb.bin:spl/u-boot-spl-dtb.bin spl.bin
        cat <(dd if=spl.bin bs=512K conv=sync) u-boot.itb > $out/u-boot.spiflash.bin
      '';
    });
  };
in
self
