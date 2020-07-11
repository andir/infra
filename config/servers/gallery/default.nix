{ pkgs, config, ... }:
{
  environment.systemPackages = [ pkgs.photoprism ];
  imports = [
    ../../profiles/hetzner-vm.nix
  ];

  deployment = {
    targetHost = "159.69.192.67";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "159.69.192.67/32"
      "2a01:4f8:c2c:2ae2::/128"
    ];
  };

  networking.hostName = "gallery.rammhold.de";

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    virtualHosts."gallery.rammhold.de" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.h4ck.photoprism.port}";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 100M;
        '';
      };
    };
  };

  h4ck.photoprism.enable = true;

  fileSystems."/".fsType = "btrfs";
}
