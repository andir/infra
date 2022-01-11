{ lib, ... }:
{

  boot.initrd.kernelModules = [ "igb" ];
  h4ck.ssh-unlock = {
    enable = lib.mkForce true;
    networking.interface = "eno1";
    networking.ipv4 = {
      address = "130.83.166.135/28";
      gateway = "130.83.166.142";
    };
  };

  networking.useDHCP = false;
  systemd.network = {
    enable = true;

    networks.uplink = {
      matchConfig.MACAddress = "00:25:90:79:63:6a";
      address = [
        "130.83.166.135/28"
      ];
      gateway = [
        "130.83.166.142"
      ];

      dns = [
        "1.1.1.1"
      ];
    };
  };
}
