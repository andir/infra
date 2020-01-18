{ pkgs, config, lib, ... }:
let siteName = "jh4all.e"; in
{
  imports = [
    ../profiles/hetzner-vm.nix
    ../profiles/webserver.nix
  ];

  deployment = {
    targetHost = "jh4all.de";
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
    "/var/www/" = {
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

  h4ck.backup.paths =
    [ "/var/lib/mysql" ]
    ++ map (name: config.users.users.${name}.home) (lib.attrNames config.mods.webhost.virtualHosts);

  services.borgbackup.jobs = {
    "kack-it" = {
      inherit (config.h4ck.backup) paths;
      compression = "lz4";
      repo = "borg@epsilon.rammhold.de:/home/borg/backups/www.jh4all.de";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };
    };
  };

  mods.webhost.virtualHosts = {
    "jh4all.de" = {
      aliases = [
        "www.jh4all.de"
        "broadcastmuseum.de"
        "www.broadcastmuseum.de"
        "bts-broadcast.de"
        "www.bts-broadcast.de"
      ];
      domain = "jh4all.de";
      application = "wordpress";
    };

    "bergstraesser_bilderbox.de" = {
      aliases = [
        "www.bergstraesser-bilderbox.de"
      ];
      domain = "bergstraesser-bilderbox.de";
      application = "wordpress";
    };
  };


  system.stateVersion = "19.09";
}
