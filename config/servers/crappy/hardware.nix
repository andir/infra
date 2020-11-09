{ pkgs, config, ... }:
{
  # ensure we are building for the right architecture
  nixpkgs.system = "aarch64-linux";

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  # These options are just not worth the time I spent on them.
  # The generic image, which I am using, (rightfully) does not support
  # the RPi specific u-boot and whatnot configuration.
  # The FAT partition isn't big enough to hold the kernels + firmware.
  # U-Boot would be able to read the kernel from the filesystem but u-boot
  # isn't really helpful when you have to set cusotm settings in the
  # config.txt.
  # Instead of building a custom installer image (or using u-boot) I decided to
  # just roll my own as activation script. (At the end of this file).
  boot.loader.raspberryPi.enable = false;
  boot.loader.raspberryPi.version = 3;
  boot.loader.raspberryPi.uboot.enable = false;

  boot.loader.raspberryPi.firmwareConfig = ''
    dtparam=audio=off
    dtoverlay=vc4-kms-v3d
    # disable_overscan=1
    # gpu_mem=64
    # hdmi_drive=2
    # hdmi_force_hotplug=1
    # hdmi_force_edid_audio=1
    # gpu_freq=250
  '';
  hardware.enableRedistributableFirmware = true;

  #  !!! If your board is a Raspberry Pi 3, select not latest (5.8 at the time)
  #  !!! as it is currently broken (see https://github.com/NixOS/nixpkgs/issues/97064)
  boot.kernelPackages = pkgs.linuxPackages;

  # !!! Needed for the virtual console to work on the RPi 3, as the default of 16M doesn't seem to be enough.
  # If X.org behaves weirdly (I only saw the cursor) then try increasing this to 256M.
  # On a Raspberry Pi 4 with 4 GB, you should either disable this parameter or
  # increase to at least 64M if you want the USB ports to work.
  boot.kernelParams = [ "cma=32M" ];

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
    "/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
    };
  };

  # !!! Adding a swap file is optional, but strongly recommended!
  swapDevices = [{ device = "/swapfile"; size = 1024; }];

  # be gentle to the SD card
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
  '';

  systemd.network = {
    networks = {
      "0-default" = {
        matchConfig.Name = "eth0";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
      };
    };
  };

  # Hack to do *some* management of the files, it will not work for rebuild
  # boot but that is acceptable compared to having to do this manually..
  system.activationScripts.install-rpi-firmware-and-config = ''
    echo "Installing RPi firmware & config.txt"
    ${pkgs.substituteAll {
      src = ./install-firmware-and-config.sh;
      isExecutable = true;
      inherit (pkgs.buildPackages) bash;
      path = with pkgs.buildPackages; [ coreutils gnused gnugrep ];
      firmware = pkgs.unstable.raspberrypifw;
      targetDir = "/firmware";
      configTxt = pkgs.writeText "config.txt" ''
        kernel=u-boot-rpi3.bin
        arm_control=0x200

        # U-Boot used to need this to work, regardless of whether UART is actually used or not.
        # TODO: check when/if this can be removed.
        enable_uart=1

        # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
        # when attempting to show low-voltage or overtemperature warnings.
        avoid_warnings=1

        ${config.boot.loader.raspberryPi.firmwareConfig}
      '';
    }}
  '';
}
