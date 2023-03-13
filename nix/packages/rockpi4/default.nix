{ lib, ubootRockPi4, armTrustedFirmwareRK3399, callPackage, ffmpeg_5, mpv-unwrapped, wrapMpv, fetchFromGitHub, libv4l, udev, fetchpatch, jdk11_headless, linux_latest, kernelPatches, linuxPackagesFor, kodi-wayland, sources }:
let
  libreElecSrc = fetchFromGitHub {
    owner = "LibreELEC";
    repo = "LibreELEC.tv";
    rev = "0405d900a5a7054ed3231c40a3c2181f4b9d2e07";
    sha256 = "sha256-7y+xS8tTwoSyGI/jynB/K4Z/afO3qAmcyH/I7DGNzrs=";
  };

  libreEleckernelPatches =
    let
      prefix = "projects/Rockchip/patches/linux/default";
    in
    map
      (path: {
        name = path;
        patch = "${libreElecSrc}/${prefix}/${path}";
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


  self = {
    kodi = kodi-wayland.withPackages (p: with p; [
      youtube
      netflix
      pvr-iptvsimple
      a4ksubtitles
      (p.buildKodiAddon {
        pname = "plugin.video.media-ccc-de";
        version = "git+" + sources."plugin.video.media-ccc-de".revision;
        namespace = "plugin.video.media-ccc-de";
        src = sources."plugin.video.media-ccc-de";
        propagatedBuildInputs = with p; [
          requests
          routing
        ];
      })
      (p.buildKodiAddon {
        pname = "plugin.video.mediathekview";
        version = "git" + sources."plugin.video.mediathekview".revision;
        namespace = "plugin.video.mediathekview";
        src = sources."plugin.video.mediathekview";
        propagatedBuildInputs = with p; [
          myconnpy
        ];
      })
    ]);

    kernel = linux_latest.override {
      kernelPatches = with kernelPatches; [
        bridge_stp_helper
        request_key_helper
      ] ++ libreEleckernelPatches;
    };
    kernelPackages = linuxPackagesFor self.kernel;

    uboot =
      let
        drv = ubootRockPi4;
        # assert that u-boot is at least version 2020.10
      in
      assert (lib.versionAtLeast drv.version "2020.10"); drv;
    mpp = callPackage ./mpp.nix { };

    ffmpeg = ffmpeg_5.overrideAttrs ({ buildInputs, patches ? [ ], preConfigure ? "", ... }: {
      #  buildInputs = buildInputs ++ [
      #    libv4l
      #    udev
      #  ];
      #  NIX_LDFLAGS = "-L${udev}/lib -ludev";
      #  # --enable-v4l2-request
      #  # --enable-libudev
      #  preConfigure = ''
      #    ${preConfigure}
      #    configureFlags="$configureFlags --enable-libdrm --enable-v4l2_m2m --enable-hwaccels"
      #  '';
      #  src = fetchFromGitHub {
      #    owner = "FFmpeg";
      #    repo = "FFmpeg";
      #    rev = "ed519a36908e2009389c7321ed73da36c586930e";
      #    sha256 = "sha256-vqe4MtkZB+vTCciU3z8LOHgEamoRY2GMQBrBF1F80wY=";
      #  };
    });

    mpv-unwrapped = (mpv-unwrapped.override {
      #  ffmpeg_5 = self.ffmpeg;
    }).overrideAttrs (_: {
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
