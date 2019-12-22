{ lib, modulesPath, config, ... }:
{
  imports = [
    ./server.nix
  ];

  mods.hetzner = {
    vm.enable = true;
  };

  boot.loader.grub.devices = [ "/dev/sda" ];
  fileSystems."/" = {
    fsType = lib.mkDefault "ext4";
    device = lib.mkDefault "/dev/disk/by-label/nixos";
  };
}
