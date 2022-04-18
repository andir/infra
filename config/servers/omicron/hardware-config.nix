{ modulesPath, lib, config, ... }:
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];


  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.extraConfig = ''
    serial --speed=115200 --unit=1 --word=8 --parity=no --stop=1
    terminal_input serial;
    terminal_output serial;

  '';
  boot.loader.efi.efiSysMountPoint = "/boot/EFI";
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS1,115200n8" "earlyprint" ];

  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "isci" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "rpool/root";
      fsType = "zfs";
    };

  fileSystems."/home" =
    {
      device = "rpool/home";
      fsType = "zfs";
    };

  fileSystems."/nix" =
    {
      device = "rpool/nix";
      fsType = "zfs";
    };

  fileSystems."/etc" =
    {
      device = "rpool/etc";
      fsType = "zfs";
    };

  fileSystems."/var" =
    {
      device = "rpool/var";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/9aabfa61-58b5-473f-9fb7-be8529a9ea00";
      fsType = "ext4";
    };

  fileSystems."/boot/EFI" =
    {
      device = "/dev/disk/by-uuid/B66D-F3D5";
      fsType = "vfat";
    };

  fileSystems."/tank" = {
    device = "tank";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/tank/backups" = {
    device = "tank/backups";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/tank/backups/zrepl" = {
    device = "tank/backups/zrepl";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/tank/gitea" = {
    device = "tank/gitea";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/tank/drone" = {
    device = "tank/drone";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };


  swapDevices = [ ];

  networking.hostId = "291b1e74";

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
