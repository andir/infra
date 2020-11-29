{ pkgs, ... }:
{
  mods.hetzner.vm.persistentDisks."/var/lib/nixos.cloud".id = 8242864;
  users.groups."nixos.cloud" = {
    members = [ "nginx" ];
  };

  users.users."nixos.cloud" = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ6V4lM1/oukxhEh3iRhBRkzjnfmaOBg1uQFpX77Ngyi nixos.cloud"
    ];
    home = "/var/lib/nixos.cloud";
    packages = [
      pkgs.rsync
    ];
    group = "nixos.cloud";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nixos.cloud/pub 750 nixos.cloud nixos.cloud"
  ];

  services.nginx.virtualHosts."nixos.cloud" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/lib/nixos.cloud/pub/dist";
  };
}
