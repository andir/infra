let
  pkgs = import ../nix/nixpkgs-for-machine.nix {
    name = "crappy";
    system = "aarch64-linux";
  };
  inherit (pkgs) lib;

  # nixos = name: configuration: import (pkgs.path + "/nixos/lib/eval-config.nix") {
  #   inherit (pkgs.stdenv.hostPlatform) system;
  #   modules = { lib, ... }: {
  #     config.nixpkgs
  #   };
  # };

in
rec {
  uboot = pkgs.rockpi4.uboot;
  system = pkgs.nixos {

    # some options to mock so it remains compatible
    options.deployment = {
      secrets = lib.mkOption { };
    };

    imports = [
      (pkgs.path + "/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix")
      ../config/profiles/server.nix
      {
        _module.args.name = "rockpi4";
      }
      ({ config, pkgs, lib, ... }: {
        # ensure that we have at least kernel 5.9 as otherwise we do not have the required DTBs
        boot.kernelPackages =
          if lib.versionAtLeast pkgs.linux.version "5.10"
          then pkgs.linuxPackages else assert lib.versionAtLeast pkgs.linux_testing.version "5.10"; pkgs.linuxPackages_testing;

        # zfs isn't supported on 5.10 as of this writing so we have to remove it from the supported filesystems
        boot.supportedFilesystems = lib.mkForce [ "btfs" "resiferfs" "vfat" "xfs" "ntfs" "cifs" ];
      })
    ];
    config = {

      # FIXME: these will be the same on the installed device, ensure we only set it once
      boot = {
        loader.grub.enable = false;
        loader.generic-extlinux-compatible.enable = true;
        consoleLogLevel = lib.mkDefault 7;
        kernelParams = [
          "console=ttyS0,1500000n8"
          "console=tty0"
        ];
      };

      sdImage = {
        populateFirmwareCommands = lib.mkForce "";
        postBuildCommands = ''
          dd if=${uboot}/idbloader.img of=$img seek=64 conv=notrunc
          dd if=${uboot}/u-boot.itb of=$img seek=16384 conv=notrunc
        '';
      };
    };
  };
}
