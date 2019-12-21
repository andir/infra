{ pkgs, config, ... }:
let siteName = "foo.bar.nixos.dev"; in
{
  imports = [
    ../profiles/hetzner-vm.nix
  ];

  deployment = {
    targetHost = "foo.bar.nixos.dev";
    targetUser = "morph";
    substituteOnDestination = true;
    healthChecks = {
      cmd = [
        {
          cmd = ["/run/wrappers/bin/ping" "-6" "${config.networking.hostName}" ];
          description = "Check whether the server responds to ICMPv6";
        }
        {
          cmd = ["/run/wrappers/bin/ping" "-4" "${config.networking.hostName}" ];
          description = "Check whether the server responds to ICMPv4";
        }
      ];

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

  hetzner = {
    ipv4Address = "78.46.187.204";
    ipv6Address = "2a01:4f8:c17:7a6::";
    persistentDisks = [
      {
        id = 3842340;
        mountPoint = "/data";
      }
    ];
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

  wordpress.instances = {
    "foo.bar.nixos.dev" = {
      aliases = [ ];
    };
    "www.foo.bar.nixos.dev" = {
      aliases = [ ];
    };
  };

  system.stateVersion = "19.03";
}
