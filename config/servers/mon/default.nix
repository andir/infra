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
    vm.persistentDisks."/postgresql".id = 7750822;
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

  # use my custom `grafanaPlugins` attribute to enable plugins on the installed grafana
  systemd.tmpfiles.rules = [
    "d /postgresql/data 0755 postgres -"
  ] ++
  lib.mapAttrsToList
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

  services.postgresql = {
    enable = true;
    extraPlugins = [
      (config.services.postgresql.package.pkgs.timescaledb.overrideAttrs ({ postInstall ? "", ... }: {
        postInstall = postInstall + ''

        # ensure that non-superusers are allowed to load this extension
        echo "superuser = false" >> $out/share/postgresql/extension/timescaledb.control
        # pg >= 13 requires the following:
        # echo "trusted = true" >> $out/share/postgresql/extension/timescaledb.control
      '';
      }))
    ];
    settings.shared_preload_libraries = "timescaledb";
    dataDir = "/postgresql/data/${config.services.postgresql.package.psqlSchema}";
    ensureDatabases = [ "promscale" ];
    ensureUsers = [
      {
        name = "postgres";
        ensurePermissions = {
          "DATABASE promscale" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  users.users.promscale = { };
  systemd.services.promscale = {
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" ];
    bindsTo = [ "postgresql.service" ];
    environment = {
      TS_PROM_LOG_LEVEL = "debug";
      TS_PROM_DB_CONNECT_RETRIES = "10";
      TS_PROM_DB_HOST = "/run/postgresql";
      TS_PROM_DB_NAME = "promscale";
      TS_PROM_DB_USER = "promscale";
      TS_PROM_DB_SSL_MODE = "prefer";
      TS_PROM_WEB_TELEMETRY_PATH = "/metrics";
      TS_PROM_WEB_LISTEN_ADDRESS = ":9201";
    };
    serviceConfig = {
      User = "promscale";
      ExecStart = "${pkgs.promscale}/bin/promscale";
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHostname = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      LocalPersonality = true;
      RestrictRealtime = true;
      PrivateMounts = true;
      ProtectSystem = "full";
      NoNewPrivileges = true;
    };
  };
}
