{ modulesPath, ... }:
{
  imports =
    [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "sr_mod"
    "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/7de6cece-a04e-4b17-a7c8-21badb361890";
      fsType = "ext4";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/7a82b354-f6c2-41c1-9226-3135851df203"; }];

  boot.loader.grub.devices = [ "/dev/disk/by-path/pci-0000:00:10.0" ];
}
