{ config, lib, pkgs, nodes, ... }:
{

  imports = [
    ../../profiles/hetzner-vm.nix
    ./prom-targets.nix
    ./prom-external-targets.nix
    ./prom-rules.nix
    ./grafana-dashboards.nix
    ./xmpp-alerts.nix
  ];

  deployment = {
    targetHost = "mon.h4ck.space";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  networking = {
    hostName = "mon";
    domain = "h4ck.space";
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "95.216.144.32/32"
      "2a01:4f9:c010:c50::/128"
    ];
    vm.persistentDisks."/data".id = 6865535;
  };
  fileSystems = {
    "/var/lib/prometheus2" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/data/prometheus2";
    };
  };

  services.prometheus = {
    enable = true;
    extraFlags = [ "--storage.tsdb.retention.time 180d" ];
    globalConfig.scrape_interval = "15s";
    alertmanagers = [
      {
        scheme = "http";
        path_prefix = "/";
        static_configs = [{ targets = [ "localhost:${toString config.services.prometheus.alertmanager.port}" ]; }];
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9090 443 80 ];

  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "localhost";
    extraFlags = [
      "--cluster.listen-address=127.0.0.1:9094"
    ];
    configText = builtins.toJSON {
      route = {
        receiver = "matrix-notify";
        routes = [
          {
            receiver = "ana-xmpp-notify";
            match.external = "ana";
          }
        ];
      };
      receivers = [
        {
          name = "xmpp-notify";
          webhook_configs = [
            { url = "http://127.0.0.1:9199/alert"; }
          ];
        }
        {
          name = "matrix-notify";
          webhook_configs = [
            { url = "http://localhost:4050/services/hooks/YWxlcnRtYW5hZ2VyX3NlcnZpY2U"; }
          ];
        }
        {
          name = "ana-xmpp-notify";
          webhook_configs = [
            { url = "http://127.0.0.1:9199/alert/ana@xmpp.megfau.lt"; }
          ];
        }
      ];
    };
  };

  # use my custom `grafanaPlugins` attribute to enable plugins on the installed grafana
  systemd.tmpfiles.rules = lib.mapAttrsToList
    (
      pluginName: plugin:
        "L ${config.services.grafana.dataDir}/plugins/${pluginName} - - - - ${plugin}"
    )
    (pkgs.grafanaPlugins or { });

  services.grafana = {
    enable = true;
    auth.anonymous.enable = true;
    users = {
      allowOrgCreate = false;
      allowSignUp = false;
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          access = "proxy";
          name = "prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
        }
      ];
    };
  };

  services.grafana-image-renderer = {
    provisionGrafana = true;
    enable = true;
    verbose = true;
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
