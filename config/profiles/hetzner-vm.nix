{ lib, modulesPath, config, ... }:
{
  imports = [
    ./server.nix
  ];

  mods.hetzner = {
    vm.enable = true;
  };

  boot.loader.grub.devices = [ "/dev/sda" ];
  fileSystems."/" = lib.mkDefault {
    fsType = "ext4";
    device = "/dev/disk/by-label/nixos";
  };
}
