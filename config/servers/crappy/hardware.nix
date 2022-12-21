{ pkgs, config, ... }:
{
  # ensure we are building for the right architecture
  nixpkgs.system = "aarch64-linux";

  imports = [ ./kernel.nix ];

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  boot.kernelParams = [
    "console=ttyS2,1500000n8"
    "earlycon=uart8250,mmio32,0xff1a0000"
    "earlyprint"
    "boot.shell_on_fail"
    # "console=tty0"
  ];

  boot.initrd.kernelModules = [
    "nvme"
    "rockchip_rga"
    "phy_rockchip_pcie"
    "rockchip_thermal"
    "pcie_rockchip_host"
    "rockchip_saradc"
  ];
  boot.kernelModules = [
    "spi-nor"
  ];

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_NVME";
      fsType = "ext4";
    };
    "/sdcard" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
    "/boot" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/sdcard/boot";
    };
    # "/boot/firmware" = {
    #   device = "/dev/disk/by-label/FIRMWARE";
    #   fsType = "vfat";
    #   options = [ "nofail" "noauto" ];
    # };
  };

  # !!! Adding a swap file is optional, but strongly recommended!
  swapDevices = [{ device = "/swapfile"; size = 1024; }];

  # be gentle to the SD card
  #services.journald.extraConfig = ''
  #  Storage=volatile
  #  RuntimeMaxUse=64M
  #'';

  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network = {
    networks = {
      "0-default" = {
        matchConfig.Name = "end0";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
      };
    };
  };

}
