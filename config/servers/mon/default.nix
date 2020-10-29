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

  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::2/64"
      "172.20.25.1/32"
      "fd21:a07e:735e:ffff::2/128"
    ];
  };

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
    vm.persistentDisks."/influx".id = 7753050;
  };
  fileSystems = {
    "/var/lib/prometheus2" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/data/prometheus2";
    };
    "/var/db/influxdb" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/influx/data";
    };
  };

  services.prometheus = {
    enable = true;
    extraFlags = [ "--storage.tsdb.retention.time 720d" ];
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
        receiver = "xmpp-notify";
        routes = [
          {
            receiver = "ana-xmpp-notify";
            match.external = "ana";
          }
          {
            receiver = "maralorn-xmpp-notify";
            match.external = "maralorn";
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
          name = "ana-xmpp-notify";
          webhook_configs = [
            { url = "http://127.0.0.1:9199/alert/ana@xmpp.megfau.lt"; }
          ];
        }
        {
          name = "maralorn-xmpp-notify";
          webhook_configs = [
            { url = "http://127.0.0.1:9199/alert/maralorn@darmstadt.ccc.de"; }
          ];
        }
      ];
    };
  };

  services.influxdb = {
    enable = true;
  };
  systemd.services."influxdb-init-database" = {
    wantedBy = [ "multi-user.target" ];
    after = [ "influxdb.service" ];
    path = [
      config.services.influxdb.package
    ];
    script = ''
      influx -execute 'CREATE DATABASE prometheus WITH DURATION 104w'
    '';
    serviceConfig = {
      Type = "oneshot";
      User = config.services.influxdb.user;
      Group = config.services.influxdb.group;
    };
  };

  systemd.services.influxdb = {
    serviceConfig.RequiresMountsFor = "/var/db/influxdb";
  };

  # use my custom `grafanaPlugins` attribute to enable plugins on the installed grafana
  systemd.tmpfiles.rules = [
    "d /influx/data 0755 influxdb influxdb"
  ] ++ lib.mapAttrsToList
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
