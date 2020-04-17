{ config, lib, pkgs, nodes, ... }:
{

  imports = [
    ../../profiles/hetzner-vm.nix
    ./prom-targets.nix
    ./prom-rules.nix
    ./grafana-dashboards.nix
    ./xmpp-alerts.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::2/64"
      "172.20.25.1/32"
      "fd21:a07e:735e:ffff::2/128"
    ];
  };

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
        path_prefix = "/";
        static_configs = [ { targets = [ "localhost:${toString config.services.prometheus.alertmanager.port}" ]; } ];
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9090 443 80 ];
  networking.firewall.allowedUDPPorts = [ 11001 ];

  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "localhost";
    extraFlags = [
      "--cluster.listen-address=127.0.0.1:9094"
    ];
    configText = builtins.toJSON {
      route = {
        receiver = "xmpp-notify";
      };
      receivers = [
        {
          name =  "xmpp-notify";
          webhook_configs = [
            { url = "http://127.0.0.1:9199/alert"; }
          ];
        }
      ];
    };
  };

  # use my custom `grafanaPlugins` attribute to enable plugins on the installed grafana
  systemd.tmpfiles.rules = lib.mapAttrsToList (
    pluginName: plugin:
      "L ${config.services.grafana.dataDir}/plugins/${pluginName} - - - - ${plugin}"
  ) (pkgs.grafanaPlugins or {});

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
