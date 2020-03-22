{ lib, pkgs, nodes, ... }:
{

  imports = [
    ../../profiles/hetzner-vm.nix
    ./prom-targets.nix
    ./prom-rules.nix
    ./grafana-dashboards.nix
  ];

  deployment = {
    targetHost = "95.216.144.32";
    targetUser = "morph";
  };

  networking.hostName = "mon.h4ck.space";

  mods.hetzner = {
    networking.ipAddresses = [
      "95.216.144.32/32"
      "2a01:4f9:c010:c50::/128"
    ];
  };

  services.prometheus = {
    enable = true;
    extraFlags = [ "--storage.tsdb.retention.time 720d" ];
    globalConfig.scrape_interval = "15s";
    alertmanagers = [
      {
        scheme = "http";
        path_prefix = "/alertmanager";
        static_configs = [ { targets = [ "localhost" ]; } ];
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9090 443 80 ];

  #services.prometheus.alertmanager = {
  #  enable = true;
  #  listenAddress = "localhost";
  #};

  services.grafana = {
    enable = true;
    auth.anonymous.enable = true;
    users = {
      allowOrgCreate = false;
      allowSignUp = false;
    };
    provision = {
      enable = true;
      datasources = [
        {
          access = "proxy";
          name = "prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
        }
      ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."mon.h4ck.space" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:3000/";
    };
  };
}
