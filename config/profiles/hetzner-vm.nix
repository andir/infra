{ lib, modulesPath, config, ... }:
{
  imports = [
    ./server.nix
  ];

  mods.hetzner = {
    vm.enable = true;
  };

  networking.usePredictableInterfaceNames = false; # stick with eth0 for the first device (for now)
  boot.loader.grub.devices = [ "/dev/sda" ];
  fileSystems."/" = {
    fsType = lib.mkDefault "ext4";
    device = lib.mkDefault "/dev/disk/by-label/nixos";
  };

  h4ck.ssh-unlock = {
    networking.interface = "eth0";
    networking.ipv4 = {
      gateway = "172.31.1.1";
    };
    networking.ipv6 = {
      gateway = "fe80::1";
    };
  };

  # ensure that all the hetzner hosts have a proper route to their default
  # gateway. If we don't add this some blackholes might make it impossible to
  # reach the gateway since on-link gateways are still resolved through the
  # routing table.
  systemd.network.networks."10-uplink".routes = [
    {
      routeConfig.Destination = "172.31.1.1/32";
    }
  ];
}
