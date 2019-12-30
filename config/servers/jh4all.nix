{ pkgs, config, ... }:
let siteName = "foo.bar.nixos.dev"; in
{
  imports = [
    ../profiles/hetzner-vm.nix
    ../profiles/webserver.nix
  ];

  deployment = {
    targetHost = "foo.bar.nixos.dev";
    targetUser = "morph";
    substituteOnDestination = true;
    healthChecks = {
      http = [
        {
          scheme = "http";
          port = 80;
          path = "/";
          description = "Check whether nginx is running.";
          period = 1;
        }
        {
          scheme = "https";
          port = 443;
          path = "/";
          description = "Check whether nginx is running.";
          period = 1;
        }
      ];
    };
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "78.46.187.204/32"
      "2a01:4f8:c17:7a6::/128"
    ];
    vm.persistentDisks."/data".id = 3842340;
  };

  fileSystems = {
    "/var/lib/wordpress/" = {
       fsType = "none";
       options = [ "bind" ];
       device = "/data/wordpress";
    };
    "/var/lib/mysql" = {
       fsType = "none";
       options = [ "bind" ];
       device = "/data/mysql";
    };
  };

  services.prometheus.exporters.nginx = {
    enable = true;
    openFirewall = true;
  };

  mods.webhost.virtualHosts = {
    "foo.bar.nixos.dev" = {
      aliases = [ ];
      domain = "foo.bar.nixos.dev";
      application = "wordpress";
    };
  };

  system.stateVersion = "19.03";
}
