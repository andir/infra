{ lib, modulesPath, config, ... }:
let

  persistentDiskOptions.options = {
    id = lib.mkOption {
      type = lib.types.int;
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
    };
  };

in {
  imports = [
    ./server.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  options.hetzner = {
    ipv4Address = lib.mkOption {
      type = lib.types.str;
    };
    ipv6Address = lib.mkOption {
      type = lib.types.str;
    };

    persistentDisks = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule persistentDiskOptions);
      default = [];
    };
  };

  config = {
    fileSystems = {
      "/" = lib.mkDefault {
        fsType = "ext4";
        device = "/dev/disk/by-label/nixos";
      };
    } // lib.listToAttrs (map (p: (
      lib.nameValuePair p.mountPoint ({
        fsType = "ext4";
        device = "/dev/disk/by-id/scsi-0HC_Volume_${toString p.id}";
        options = [ "defaults" "x-systemd.growfs" "x-systemd.makefs" ];
      })
    )) config.hetzner.persistentDisks);

    boot.loader.grub.devices = [ "/dev/sda" ];

    networking.useNetworkd = true;
    networking.useDHCP = false;
    systemd.network.networks = {
      "10-uplink" = {
        matchConfig = {
          Virtualization = true;
          Name = "en* eth*";
        };
        addresses = map (a: { addressConfig.Address = a; }) [
          "${config.hetzner.ipv4Address}/32"
          "${config.hetzner.ipv6Address}/64"
        ];
        routes = [
          {
            routeConfig = {
              Gateway = "172.31.1.1";
              GatewayOnLink = true;
            };
          }
          {
            routeConfig = {
              Gateway = "fe80::1";
              GatewayOnLink = true;
            };
          }

        ];
      };
    };
  };
}
